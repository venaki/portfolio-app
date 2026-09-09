import assert from 'node:assert/strict';
import { before, test } from 'node:test';
import { createLocalJWKSet, exportJWK, generateKeyPair, SignJWT } from 'jose';
import worker, { popupResponse, REQUIRED_SCOPES } from '../src/index';
import { AuthState, type Attempt } from '../src/auth-state';
import { challengeFor, type Env, randomToken, stateCall } from '../src/common';
import { verifyFirebaseToken, verifyGoogleToken } from '../src/identity';

const origin = 'https://app.example';
const project = 'test-project';
const clientId = 'test-client';
let privateKey: CryptoKey;
let jwk: Awaited<ReturnType<typeof exportJWK>>;
let keys: ReturnType<typeof createLocalJWKSet>;
before(async () => {
  const pair = await generateKeyPair('RS256');
  privateKey = pair.privateKey;
  jwk = { ...await exportJWK(pair.publicKey), kid: 'test-key', alg: 'RS256' };
  keys = createLocalJWKSet({ keys: [jwk] });
});

// This adapter serializes transactions like Durable Object storage. Production handlers run unchanged.
class MemoryStorage {
  values = new Map<string, unknown>();
  alarmAt: number | null = null;
  queue = Promise.resolve();
  async get<T>(key: string): Promise<T | undefined> { return structuredClone(this.values.get(key)) as T | undefined; }
  async put(key: string, value: unknown) { this.values.set(key, structuredClone(value)); }
  async delete(key: string) { return this.values.delete(key); }
  async setAlarm(at: number) { this.alarmAt = at; }
  async deleteAll() { this.values.clear(); this.alarmAt = null; }
  async transaction<T>(callback: (tx: MemoryStorage) => Promise<T>): Promise<T> {
    const previous = this.queue;
    let release!: () => void;
    this.queue = new Promise<void>((resolve) => { release = resolve; });
    await previous;
    const snapshot = structuredClone(this.values);
    try { return await callback(this); }
    catch (error) { this.values = snapshot; throw error; }
    finally { release(); }
  }
}

function environment() {
  const objects = new Map<string, { object: AuthState; storage: MemoryStorage }>();
  const env = {
    ALLOWED_ORIGINS: origin, FIREBASE_PROJECT_ID: project,
    GOOGLE_CLIENT_ID: clientId, GOOGLE_CLIENT_SECRET: 'test-only-client-secret',
    AUTH_STATE: {
      idFromName: (name: string) => name,
      get: (name: string) => {
        if (!objects.has(name)) {
          const storage = new MemoryStorage();
          objects.set(name, { object: new AuthState({ storage } as unknown as DurableObjectState), storage });
        }
        return { fetch: (request: Request) => objects.get(name)!.object.fetch(request) };
      },
    },
  } as unknown as Env;
  return { env, objects };
}

async function attempt(env: Env, overrides: Partial<Attempt> = {}) {
  const state = randomToken();
  const verifier = randomToken();
  const value: Attempt = {
    origin, challenge: await challengeFor(verifier), nonce: randomToken(),
    createdAt: Date.now(), expiresAt: Date.now() + 600_000, redirectUri: 'https://worker.example/auth/callback', phase: 'pending',
    ...overrides,
  };
  await stateCall(env, `attempt:${state}`, 'create', value);
  return { state, verifier, value };
}

async function firebaseToken(overrides: Record<string, unknown> = {}): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  return new SignJWT({
    iss: `https://securetoken.google.com/${project}`, aud: project, sub: 'user-a',
    iat: now, exp: now + 3600, auth_time: now,
    firebase: { identities: { 'google.com': ['google-a'] }, sign_in_provider: 'google.com' },
    ...overrides,
  }).setProtectedHeader({ alg: 'RS256', kid: 'test-key' }).sign(privateKey);
}

function post(path: string, body: unknown = {}, token?: string, requestOrigin: string | null = origin): Request {
  return new Request(`https://worker.example${path}`, {
    method: 'POST', headers: {
      'Content-Type': 'application/json', ...(requestOrigin ? { Origin: requestOrigin } : {}),
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    }, body: JSON.stringify(body),
  });
}

test('refresh/revoke require a verified identity even without an Origin; migrate is removed', async () => {
  const { env, objects } = environment();
  for (const path of ['/auth/refresh', '/auth/revoke', '/auth/complete']) {
    assert.equal((await worker.fetch(post(path, { uid: 'victim' }, undefined, null), env)).status, 401);
  }
  assert.equal((await worker.fetch(post('/auth/migrate', { from_uid: 'pending', to_uid: 'victim' }), env)).status, 404);
  assert.equal(objects.size, 0);
});

test('foreign origins are rejected and Authorization is permitted in allowed preflights', async () => {
  const { env } = environment();
  const rejected = await worker.fetch(post('/auth/refresh', {}, undefined, 'https://foreign.example'), env);
  assert.equal(rejected.status, 403);
  assert.equal(rejected.headers.get('Access-Control-Allow-Origin'), null);
  const allowed = await worker.fetch(new Request('https://worker.example/auth/refresh', {
    method: 'OPTIONS', headers: { Origin: origin },
  }), env);
  assert.equal(allowed.status, 204);
  assert.match(allowed.headers.get('Access-Control-Allow-Headers')!, /Authorization/);
});

test('public exchange rejects malformed and oversized JSON before touching storage', async () => {
  const { env, objects } = environment();
  const malformed = new Request('https://worker.example/auth/exchange', {
    method: 'POST', headers: { Origin: origin, 'Content-Type': 'application/json' }, body: '{',
  });
  assert.equal((await worker.fetch(malformed, env)).status, 400);
  assert.equal((await worker.fetch(post('/auth/exchange', { data: 'x'.repeat(17_000) }), env)).status, 413);
  assert.equal(objects.size, 0);
});

test('Firebase signatures, audience, issuer, expiry, auth_time and Google subject are validated', async () => {
  assert.deepEqual(await verifyFirebaseToken(await firebaseToken(), project, keys), { uid: 'user-a', googleSub: 'google-a' });
  for (const changes of [
    { aud: 'another-project' }, { iss: 'https://attacker.example' }, { exp: 1 },
    { iat: 9_999_999_999 }, { auth_time: 9_999_999_999 }, { sub: '' },
    { firebase: { sign_in_provider: 'password' } },
  ]) await assert.rejects(verifyFirebaseToken(await firebaseToken(changes), project, keys));
  const otherPair = await generateKeyPair('RS256');
  const forged = await new SignJWT({ sub: 'user-a' }).setProtectedHeader({ alg: 'RS256', kid: 'test-key' }).sign(otherPair.privateKey);
  await assert.rejects(verifyFirebaseToken(forged, project, keys));
});

test('Google ID tokens require the expected audience and one-time nonce', async () => {
  const token = await new SignJWT({ sub: 'google-a', nonce: 'expected' }).setProtectedHeader({ alg: 'RS256', kid: 'test-key' })
    .setIssuer('https://accounts.google.com').setAudience(clientId).setIssuedAt().setExpirationTime('1h').sign(privateKey);
  assert.equal(await verifyGoogleToken(token, clientId, 'expected', keys), 'google-a');
  await assert.rejects(verifyGoogleToken(token, clientId, 'other', keys));
  await assert.rejects(verifyGoogleToken(token, 'other-client', 'expected', keys));
});

test('PKCE proof and origin must match; concurrent claims admit exactly one exchange', async () => {
  const { env } = environment();
  const login = await attempt(env);
  await assert.rejects(stateCall(env, `attempt:${login.state}`, 'claim-exchange', { origin, verifier: randomToken() }));
  await assert.rejects(stateCall(env, `attempt:${login.state}`, 'claim-exchange', { origin: 'https://foreign.example', verifier: login.verifier }));
  const result = await Promise.allSettled(Array.from({ length: 10 }, () => stateCall(env, `attempt:${login.state}`, 'claim-exchange', {
    origin, verifier: login.verifier,
  })));
  assert.equal(result.filter((entry) => entry.status === 'fulfilled').length, 1);
});

test('attempts expire; cleanup removes pending secrets; different users cannot claim each other', async () => {
  const { env, objects } = environment();
  const expired = await attempt(env, { expiresAt: Date.now() - 1 });
  await assert.rejects(stateCall(env, `attempt:${expired.state}`, 'inspect'));
  const login = await attempt(env, { phase: 'exchanged', refreshToken: 'test-refresh', googleSub: 'google-a' });
  await assert.rejects(stateCall(env, `attempt:${login.state}`, 'claim-complete', {
    origin, verifier: login.verifier, googleSub: 'google-b',
  }));
  const claim = () => stateCall(env, `attempt:${login.state}`, 'claim-complete', { origin, verifier: login.verifier, googleSub: 'google-a' });
  assert.deepEqual(await claim(), { refreshToken: 'test-refresh', googleSub: 'google-a', attemptStartedAt: login.value.createdAt });
  await assert.rejects(claim());
  await assert.rejects(stateCall(env, `attempt:${login.state}`, 'create', login.value));
  await objects.get(`attempt:${login.state}`)!.object.alarm();
  assert.equal(objects.get(`attempt:${login.state}`)!.storage.values.size, 0);
});

test('late invalid_grant cannot delete a newer login; revocation invalidates ongoing refresh', async () => {
  const { env } = environment();
  await stateCall(env, 'user:user-a', 'put-token', { refreshToken: 'new', googleSub: 'google-a', version: 'new-version' });
  await stateCall(env, 'user:user-a', 'delete-token-version', { version: 'old-version' });
  assert.equal((await stateCall<{ version: string }>(env, 'user:user-a', 'get-token')).version, 'new-version');
  await stateCall(env, 'user:user-a', 'revoke');
  await assert.rejects(stateCall(env, 'user:user-a', 'check-token-version', { version: 'new-version' }));
});

test('an OAuth completion arriving after logout cannot restore an older attempt', async () => {
  const { env } = environment();
  const started = Date.now() - 1000;
  await stateCall(env, 'user:user-a', 'revoke');
  await assert.rejects(stateCall(env, 'user:user-a', 'put-token', {
    refreshToken: 'stale', googleSub: 'google-a', version: 'stale', attemptStartedAt: started,
  }));
  await assert.rejects(stateCall(env, 'user:user-a', 'get-token'));
});

test('callback HTML cannot be closed by query content and sends only to the bound origin', async () => {
  const payload = '</script><script>UNTRUSTED_MARKER</script>';
  const response = popupResponse({ type: 'auth-error', error: payload }, origin);
  const html = await response.text();
  assert.equal((html.match(/<script\b/g) ?? []).length, 1);
  assert.equal((html.match(/<\/script>/g) ?? []).length, 1);
  assert.ok(html.includes('\\u003c/script>'));
  assert.ok(html.includes(JSON.stringify(origin)));
  assert.ok(!html.includes(", '*'") && !html.includes(',"*"'));
  assert.match(response.headers.get('Content-Security-Policy')!, /default-src 'none'/);
  assert.equal(response.headers.get('Cache-Control'), 'no-store');
});

test('login binds a unique attempt and callback rejects unknown state without reflecting errors', async () => {
  const { env } = environment();
  const state = randomToken();
  const params = new URLSearchParams({ state, challenge: await challengeFor(randomToken()), origin });
  const login = await worker.fetch(new Request(`https://worker.example/auth/login?${params}`), env);
  assert.equal(login.status, 302);
  const redirect = new URL(login.headers.get('Location')!);
  assert.equal(redirect.searchParams.get('state'), state);
  assert.equal(redirect.searchParams.get('code_challenge_method'), 'S256');
  assert.ok(redirect.searchParams.get('nonce'));
  assert.ok(REQUIRED_SCOPES.every((scope) => redirect.searchParams.get('scope')!.includes(scope)));
  const bad = await worker.fetch(new Request(`https://worker.example/auth/callback?state=${randomToken()}&error=UNTRUSTED_MARKER`), env);
  assert.equal(bad.status, 401);
  assert.ok(!(await bad.text()).includes('UNTRUSTED_MARKER'));
  const denied = await worker.fetch(new Request(`https://worker.example/auth/callback?state=${state}&error=UNTRUSTED_MARKER`), env);
  assert.equal(denied.status, 200);
  assert.ok(!(await denied.text()).includes('UNTRUSTED_MARKER'));
});

test('full exchange binds the refresh token to the verified Firebase user, ignoring supplied uid', async () => {
  const { env } = environment();
  const login = await attempt(env);
  const googleId = await new SignJWT({ sub: 'google-a', nonce: login.value.nonce })
    .setProtectedHeader({ alg: 'RS256', kid: 'test-key' }).setIssuer('https://accounts.google.com')
    .setAudience(clientId).setIssuedAt().setExpirationTime('1h').sign(privateKey);
  const originalFetch = globalThis.fetch;
  globalThis.fetch = async (input, init) => {
    const url = input.toString();
    if (url.includes('/certs') || url.includes('/jwk/')) return Response.json({ keys: [jwk] });
    assert.equal(url, 'https://oauth2.googleapis.com/token');
    const params = new URLSearchParams(init?.body as string);
    if (params.get('grant_type') === 'authorization_code') {
      assert.equal(params.get('code_verifier'), login.verifier);
      return Response.json({ access_token: 'test-access', expires_in: 3600, id_token: googleId,
        refresh_token: 'test-refresh', scope: REQUIRED_SCOPES.join(' ') });
    }
    assert.equal(params.get('refresh_token'), 'test-refresh');
    return Response.json({ access_token: 'renewed-test-access', expires_in: 3600 });
  };
  try {
    const result = await worker.fetch(post('/auth/exchange', { state: login.state, verifier: login.verifier, code: 'test-code' }), env);
    assert.equal(result.status, 200);
    assert.equal((await result.json<Record<string, unknown>>()).refresh_token, undefined);
    const firebaseId = await firebaseToken();
    const wrongUser = await firebaseToken({ sub: 'user-b', firebase: { identities: { 'google.com': ['google-b'] }, sign_in_provider: 'google.com' } });
    const completeBody = { state: login.state, verifier: login.verifier, uid: 'victim' };
    assert.equal((await worker.fetch(post('/auth/complete', completeBody, wrongUser), env)).status, 403);
    assert.equal((await worker.fetch(post('/auth/complete', completeBody, firebaseId), env)).status, 200);
    await assert.rejects(stateCall(env, 'user:victim', 'get-token'));
    const refreshed = await worker.fetch(post('/auth/refresh', { uid: 'victim' }, firebaseId), env);
    assert.equal(refreshed.status, 200);
    assert.equal((await refreshed.json<Record<string, unknown>>()).access_token, 'renewed-test-access');
    assert.equal((await worker.fetch(post('/auth/complete', completeBody, firebaseId), env)).status, 401);
    assert.equal((await worker.fetch(post('/auth/revoke', { uid: 'victim' }, firebaseId), env)).status, 200);
    assert.equal((await worker.fetch(post('/auth/refresh', {}, firebaseId), env)).status, 401);
  } finally { globalThis.fetch = originalFetch; }
});
