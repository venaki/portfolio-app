import { type Attempt, type StoredToken } from './auth-state';
import { ApiError, type Env, checkState, errorResponse, fetchWithTimeout, json, randomToken, readBody, stateCall, stringField } from './common';
import { verifyFirebaseToken, verifyGoogleToken } from './identity';
export { AuthState } from './auth-state';

const GOOGLE_TOKEN_URL = 'https://oauth2.googleapis.com/token';
export const REQUIRED_SCOPES = [
  'https://www.googleapis.com/auth/spreadsheets',
  'https://www.googleapis.com/auth/drive.metadata.readonly',
];
const ATTEMPT_TTL_MS = 10 * 60 * 1000;

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const origin = request.headers.get('Origin');
    const allowed = env.ALLOWED_ORIGINS.split(',').map((value) => value.trim()).filter(Boolean);
    const cors: Record<string, string> = origin && allowed.includes(origin) ? {
      'Access-Control-Allow-Origin': origin, 'Vary': 'Origin',
      'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, Authorization',
    } : {};
    try {
      const url = new URL(request.url);
      if (origin && !allowed.includes(origin)) throw new ApiError(403, 'origin_not_allowed');
      if (request.method === 'OPTIONS') {
        if (!origin) throw new ApiError(403, 'origin_required');
        return new Response(null, { status: 204, headers: cors });
      }
      // Popup navigations do not necessarily have an Origin header.
      if (url.pathname === '/auth/login' && request.method === 'GET') return await login(url, env, allowed);
      if (url.pathname === '/auth/callback' && request.method === 'GET') return await callback(url, env);
      if (url.pathname === '/search' && request.method === 'GET') {
        const q = url.searchParams.get('q')?.trim();
        if (!q || q.length > 100) throw new ApiError(400, 'invalid_search');
        const response = await fetchWithTimeout(
          `https://query2.finance.yahoo.com/v1/finance/search?q=${encodeURIComponent(q)}&quotesCount=10&newsCount=0`,
          { headers: { 'User-Agent': 'Mozilla/5.0' } },
        );
        if (!response.ok) throw new ApiError(502, 'upstream_unavailable');
        return json(searchResults(await response.json()), 200, {
          ...cors, 'Cache-Control': 'public, max-age=300',
        });
      }
      if (request.method !== 'POST') throw new ApiError(404, 'not_found');
      if (url.pathname === '/auth/exchange') {
        if (!origin) throw new ApiError(403, 'origin_required');
        return json(await exchange(await readBody(request), origin, env), 200, cors);
      }
      if (!['/auth/complete', '/auth/refresh', '/auth/revoke'].includes(url.pathname)) {
        throw new ApiError(404, 'not_found'); // The insecure migrate API is intentionally removed.
      }
      const bearer = request.headers.get('Authorization')?.match(/^Bearer ([^\s]+)$/)?.[1];
      if (!bearer) throw new ApiError(401, 'identity_token_required');
      const identity = await verifyFirebaseToken(bearer, env.FIREBASE_PROJECT_ID);
      const userKey = `user:${identity.uid}`;
      if (url.pathname === '/auth/complete') {
        if (!origin) throw new ApiError(403, 'origin_required');
        const body = await readBody(request);
        const state = checkState(stringField(body, 'state', 43));
        const result = await stateCall<{ refreshToken: string; googleSub: string; attemptStartedAt: number }>(env, `attempt:${state}`, 'claim-complete', {
          origin, verifier: stringField(body, 'verifier', 128), googleSub: identity.googleSub,
        });
        await stateCall(env, userKey, 'put-token', { ...result, version: randomToken() });
        return json({ ok: true }, 200, cors);
      }
      if (url.pathname === '/auth/revoke') {
        await stateCall(env, userKey, 'revoke');
        return json({ ok: true }, 200, cors);
      }
      const saved = await stateCall<StoredToken>(env, userKey, 'get-token');
      if (saved.googleSub !== identity.googleSub) throw new ApiError(403, 'identity_mismatch');
      const response = await googleToken(env, { grant_type: 'refresh_token', refresh_token: saved.refreshToken });
      const data = await response.json<Record<string, unknown>>();
      if (!response.ok) {
        if (data.error === 'invalid_grant') {
          await stateCall(env, userKey, 'delete-token-version', { version: saved.version });
          throw new ApiError(401, 'relogin_required');
        }
        throw new ApiError(502, 'upstream_unavailable');
      }
      const tokens = accessTokenResult(data);
      await stateCall(env, userKey, 'check-token-version', { version: saved.version });
      return json(tokens, 200, cors);
    } catch (error) { return errorResponse(error, cors); }
  },
};

const US_EXCHANGES: Record<string, string> = {
  NMS: 'NASDAQ', NGM: 'NASDAQ', NCM: 'NASDAQ',
  NYQ: 'NYSE', PCX: 'NYSEARCA', ASE: 'NYSEAMERICAN', BTS: 'BATS', PNK: 'OTC',
};

function searchResults(data: unknown): { ticker: string; name: string; exchange: string }[] {
  if (!data || typeof data !== 'object' || !('quotes' in data) || !Array.isArray(data.quotes)) {
    throw new ApiError(502, 'invalid_search_response');
  }
  return data.quotes.flatMap((quote: unknown) => {
    if (!quote || typeof quote !== 'object') return [];
    const item = quote as Record<string, unknown>;
    if (typeof item.symbol !== 'string' || !item.symbol.trim() ||
      !['EQUITY', 'ETF'].includes(String(item.quoteType)) || item.isYahooFinance === false) return [];
    const symbol = item.symbol.trim().toUpperCase();
    const korean = /^(\d{6})\.(KS|KQ)$/.exec(symbol);
    const exchangeCode = typeof item.exchange === 'string' ? item.exchange : '';
    // The app supports US and Korean securities; another market must not become a USD holding.
    const exchange = korean ? (korean[2] === 'KQ' ? 'KOSDAQ' : 'KRX')
      : Object.hasOwn(US_EXCHANGES, exchangeCode) ? US_EXCHANGES[exchangeCode] : undefined;
    if (!exchange) return [];
    const name = [item.longname, item.shortname].find((value) => typeof value === 'string' && value.trim());
    return [{ ticker: korean?.[1] ?? symbol, name: typeof name === 'string' ? name : symbol, exchange }];
  }).slice(0, 10);
}

async function login(url: URL, env: Env, allowed: string[]): Promise<Response> {
  const origin = url.searchParams.get('origin');
  if (!origin || !allowed.includes(origin)) throw new ApiError(403, 'origin_not_allowed');
  const state = checkState(url.searchParams.get('state'));
  const challenge = checkState(url.searchParams.get('challenge'));
  const nonce = randomToken();
  const redirectUri = `${url.origin}/auth/callback`;
  const createdAt = Date.now();
  await stateCall(env, `attempt:${state}`, 'create', {
    origin, challenge, nonce, redirectUri, createdAt, expiresAt: createdAt + ATTEMPT_TTL_MS, phase: 'pending',
  } satisfies Attempt);
  const params = new URLSearchParams({
    client_id: env.GOOGLE_CLIENT_ID, redirect_uri: redirectUri,
    response_type: 'code', scope: ['openid', 'email', 'profile', ...REQUIRED_SCOPES].join(' '),
    access_type: 'offline', prompt: 'consent select_account', state, nonce,
    code_challenge: challenge, code_challenge_method: 'S256',
  });
  return new Response(null, { status: 302, headers: {
    Location: `https://accounts.google.com/o/oauth2/v2/auth?${params}`,
    'Cache-Control': 'no-store', 'Referrer-Policy': 'no-referrer',
  } });
}

async function callback(url: URL, env: Env): Promise<Response> {
  const state = checkState(url.searchParams.get('state'));
  const { origin } = await stateCall<{ origin: string }>(env, `attempt:${state}`, 'inspect');
  const code = url.searchParams.get('code');
  if (url.searchParams.has('error') || !code || code.length > 4096) {
    return popupResponse({ type: 'auth-error', state, error: 'authorization_denied' }, origin);
  }
  const issuer = url.searchParams.get('iss');
  if (issuer && issuer !== 'https://accounts.google.com') throw new ApiError(400, 'invalid_issuer');
  return popupResponse({ type: 'auth-code', state, code }, origin);
}

async function exchange(body: Record<string, unknown>, origin: string, env: Env): Promise<object> {
  const state = checkState(stringField(body, 'state', 43));
  const verifier = stringField(body, 'verifier', 128);
  const code = stringField(body, 'code');
  const attempt = await stateCall<Attempt>(env, `attempt:${state}`, 'claim-exchange', { origin, verifier });
  const response = await googleToken(env, {
    grant_type: 'authorization_code', code, code_verifier: verifier, redirect_uri: attempt.redirectUri,
  });
  const data = await response.json<Record<string, unknown>>();
  if (!response.ok) throw new ApiError(401, 'authorization_exchange_failed');
  const tokens = accessTokenResult(data);
  const idToken = stringField(data, 'id_token', 16_384);
  const googleSub = await verifyGoogleToken(idToken, env.GOOGLE_CLIENT_ID, attempt.nonce);
  const grantedScopes = typeof data.scope === 'string' ? data.scope.split(' ') : [];
  if (REQUIRED_SCOPES.some((scope) => !grantedScopes.includes(scope))) throw new ApiError(403, 'consent_required');
  if (typeof data.refresh_token !== 'string' || !data.refresh_token) throw new ApiError(401, 'relogin_required');
  await stateCall(env, `attempt:${state}`, 'finish-exchange', { refreshToken: data.refresh_token, googleSub });
  return { ...tokens, id_token: idToken };
}

function accessTokenResult(data: Record<string, unknown>): { access_token: string; expires_in: number } {
  if (typeof data.access_token !== 'string' || !data.access_token ||
    typeof data.expires_in !== 'number' || !Number.isFinite(data.expires_in) || data.expires_in <= 60) {
    throw new ApiError(502, 'invalid_token_response');
  }
  return { access_token: data.access_token, expires_in: data.expires_in };
}

function googleToken(env: Env, params: Record<string, string>): Promise<Response> {
  return fetchWithTimeout(GOOGLE_TOKEN_URL, {
    method: 'POST', headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({ ...params, client_id: env.GOOGLE_CLIENT_ID, client_secret: env.GOOGLE_CLIENT_SECRET }).toString(),
  });
}

export function popupResponse(data: Record<string, unknown>, origin: string): Response {
  // JSON alone does not escape the HTML script closing tag.
  const encode = (value: unknown) => JSON.stringify(value).replaceAll('<', '\\u003c').replaceAll('\u2028', '\\u2028').replaceAll('\u2029', '\\u2029');
  const nonce = randomToken();
  return new Response(`<!doctype html><html><head><meta charset="utf-8"><title>Portfolio 로그인</title></head><body><script nonce="${nonce}">if(window.opener){window.opener.postMessage(${encode(data)},${encode(origin)});}window.close();</script><p>이 창을 닫고 Portfolio로 돌아가세요.</p></body></html>`, {
    headers: {
      'Content-Type': 'text/html; charset=utf-8', 'Cache-Control': 'no-store', 'Referrer-Policy': 'no-referrer',
      'X-Content-Type-Options': 'nosniff',
      'Content-Security-Policy': `default-src 'none'; script-src 'nonce-${nonce}'; base-uri 'none'; frame-ancestors 'none'`,
    },
  });
}
