export interface Env {
  ALLOWED_ORIGINS: string;
  FIREBASE_PROJECT_ID: string;
  GOOGLE_CLIENT_ID: string;
  GOOGLE_CLIENT_SECRET: string;
  AUTH_STATE: DurableObjectNamespace;
}

export class ApiError extends Error {
  constructor(public readonly status: number, public readonly code: string) { super(code); }
}

export function json(body: unknown, status = 200, headers: HeadersInit = {}): Response {
  return new Response(JSON.stringify(body), {
    status, headers: { 'Content-Type': 'application/json', 'Cache-Control': 'no-store', ...headers },
  });
}

export function errorResponse(error: unknown, headers: HeadersInit = {}): Response {
  return error instanceof ApiError
    ? json({ error: error.code }, error.status, headers)
    : json({ error: 'upstream_unavailable' }, 502, headers);
}

export async function readBody(request: Request): Promise<Record<string, unknown>> {
  if (!request.headers.get('Content-Type')?.startsWith('application/json')) throw new ApiError(415, 'json_required');
  const reader = request.body?.getReader();
  const decoder = new TextDecoder();
  let text = '';
  let size = 0;
  if (reader) {
    try {
      for (;;) {
        const { value, done } = await reader.read();
        if (done) break;
        size += value.byteLength;
        if (size > 16_384) {
          await reader.cancel();
          throw new ApiError(413, 'request_too_large');
        }
        text += decoder.decode(value, { stream: true });
      }
      text += decoder.decode();
    } finally { reader.releaseLock(); }
  }
  try {
    const body: unknown = JSON.parse(text);
    if (!body || typeof body !== 'object' || Array.isArray(body)) throw new Error();
    return body as Record<string, unknown>;
  } catch { throw new ApiError(400, 'invalid_json'); }
}

export function stringField(body: Record<string, unknown>, key: string, max = 4096): string {
  const value = body[key];
  if (typeof value !== 'string' || !value || value.length > max) throw new ApiError(400, 'invalid_request');
  return value;
}

export function randomToken(): string { return base64url(crypto.getRandomValues(new Uint8Array(32))); }

export function base64url(bytes: Uint8Array): string {
  return btoa(String.fromCharCode(...bytes)).replaceAll('+', '-').replaceAll('/', '_').replaceAll('=', '');
}

export async function challengeFor(verifier: string): Promise<string> {
  if (!/^[A-Za-z0-9_-]{43,128}$/.test(verifier)) throw new ApiError(400, 'invalid_verifier');
  return base64url(new Uint8Array(await crypto.subtle.digest('SHA-256', new TextEncoder().encode(verifier))));
}

export function checkState(value: string | null): string {
  if (!value || !/^[A-Za-z0-9_-]{43}$/.test(value)) throw new ApiError(400, 'invalid_state');
  return value;
}

export async function stateCall<T>(env: Env, name: string, action: string, body: unknown = {}): Promise<T> {
  const response = await env.AUTH_STATE.get(env.AUTH_STATE.idFromName(name)).fetch(
    new Request(`https://auth.internal/${action}`, {
      method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body),
    }),
  );
  const data = await response.json<Record<string, unknown>>();
  if (!response.ok) throw new ApiError(response.status, typeof data.error === 'string' ? data.error : 'session_unavailable');
  return data as T;
}

export async function fetchWithTimeout(input: string, init: RequestInit = {}): Promise<Response> {
  try { return await fetch(input, { ...init, signal: AbortSignal.timeout(15_000) }); }
  catch { throw new ApiError(502, 'upstream_unavailable'); }
}
