interface Env {
  ALLOWED_ORIGINS: string;
  GOOGLE_CLIENT_ID: string;
  GOOGLE_CLIENT_SECRET: string;
  AUTH_TOKENS: KVNamespace;
}

const YAHOO_SEARCH_BASE = 'https://query2.finance.yahoo.com/v1/finance/search';
const GOOGLE_AUTH_URL = 'https://accounts.google.com/o/oauth2/v2/auth';
const GOOGLE_TOKEN_URL = 'https://oauth2.googleapis.com/token';

const SCOPES = [
  'openid',
  'email',
  'profile',
  'https://www.googleapis.com/auth/spreadsheets',
  'https://www.googleapis.com/auth/drive.readonly',
].join(' ');

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const origin = request.headers.get('Origin') ?? '';
    const allowed = env.ALLOWED_ORIGINS.split(',');
    const allowedOrigin = allowed.includes(origin) ? origin : allowed[0];

    const corsHeaders: Record<string, string> = {
      'Access-Control-Allow-Origin': allowedOrigin,
      'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type',
    };

    if (request.method === 'OPTIONS') {
      return new Response(null, { headers: corsHeaders });
    }

    const url = new URL(request.url);

    try {
      // ── Auth: OAuth login redirect ─────────────────────
      if (url.pathname === '/auth/login' && request.method === 'GET') {
        return handleLogin(url, env);
      }

      // ── Auth: OAuth callback ───────────────────────────
      if (url.pathname === '/auth/callback' && request.method === 'GET') {
        return handleCallback(url, env);
      }

      // ── Auth: refresh token → new access token ─────────
      if (url.pathname === '/auth/refresh' && request.method === 'POST') {
        return handleRefresh(request, env, corsHeaders);
      }

      // ── Auth: migrate pending → real uid ──────────────
      if (url.pathname === '/auth/migrate' && request.method === 'POST') {
        return handleMigrate(request, env, corsHeaders);
      }

      // ── Auth: revoke (logout) ──────────────────────────
      if (url.pathname === '/auth/revoke' && request.method === 'POST') {
        return handleRevoke(request, env, corsHeaders);
      }

      // ── Yahoo Finance: 종목 검색 ───────────────────────
      if (url.pathname === '/search' && request.method === 'GET') {
        const q = url.searchParams.get('q');
        if (!q) {
          return jsonResponse({ error: 'q parameter required' }, 400, corsHeaders);
        }
        const yahooUrl = `${YAHOO_SEARCH_BASE}?q=${encodeURIComponent(q)}&quotesCount=10&newsCount=0`;
        const yahooRes = await fetch(yahooUrl, {
          headers: { 'User-Agent': 'Mozilla/5.0' },
        });
        const data = await yahooRes.text();
        return new Response(data, {
          status: yahooRes.status,
          headers: { ...corsHeaders, 'Content-Type': 'application/json', 'Cache-Control': 'public, max-age=300' },
        });
      }

      return jsonResponse({ error: 'Not found' }, 404, corsHeaders);
    } catch (err: any) {
      return jsonResponse({ error: err.message }, 502, corsHeaders);
    }
  },
};

// ── Auth handlers ──────────────────────────────────────────

/**
 * GET /auth/login?uid=xxx
 * Google OAuth 인증 페이지로 리다이렉트.
 * uid를 state에 포함시켜 callback에서 refresh token을 저장할 키로 사용.
 */
function handleLogin(url: URL, env: Env): Response {
  const uid = url.searchParams.get('uid') || 'anonymous';
  const callbackUrl = `${url.origin}/auth/callback`;

  const params = new URLSearchParams({
    client_id: env.GOOGLE_CLIENT_ID,
    redirect_uri: callbackUrl,
    response_type: 'code',
    scope: SCOPES,
    access_type: 'offline',
    prompt: 'consent',
    state: uid,
  });

  return Response.redirect(`${GOOGLE_AUTH_URL}?${params.toString()}`, 302);
}

/**
 * GET /auth/callback?code=xxx&state=uid
 * Google에서 돌아온 authorization code를 교환.
 * access_token + refresh_token 획득, KV에 저장.
 * postMessage로 팝업 opener에게 결과 전달 후 팝업 닫기.
 */
async function handleCallback(url: URL, env: Env): Promise<Response> {
  const code = url.searchParams.get('code');
  const uid = url.searchParams.get('state') || 'anonymous';
  const error = url.searchParams.get('error');

  if (error || !code) {
    return postMessageResponse({ type: 'auth-error', error: error || 'no_code' });
  }

  const callbackUrl = `${url.origin}/auth/callback`;

  const params = new URLSearchParams({
    code,
    client_id: env.GOOGLE_CLIENT_ID,
    client_secret: env.GOOGLE_CLIENT_SECRET,
    redirect_uri: callbackUrl,
    grant_type: 'authorization_code',
  });

  const res = await fetch(GOOGLE_TOKEN_URL, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: params.toString(),
  });

  const data = await res.json<{
    access_token?: string;
    refresh_token?: string;
    id_token?: string;
    expires_in?: number;
    error?: string;
  }>();

  if (!res.ok || data.error) {
    return postMessageResponse({ type: 'auth-error', error: data.error || 'exchange_failed' });
  }

  // refresh token 저장
  if (data.refresh_token) {
    await env.AUTH_TOKENS.put(`refresh:${uid}`, data.refresh_token);
  }

  return postMessageResponse({
    type: 'auth-success',
    access_token: data.access_token,
    id_token: data.id_token,
    expires_in: data.expires_in,
  });
}

/**
 * POST /auth/refresh { uid }
 * KV에 저장된 refresh token으로 새 access token 발급.
 */
async function handleRefresh(
  request: Request, env: Env, corsHeaders: Record<string, string>,
): Promise<Response> {
  const body = await request.json<{ uid: string }>();
  if (!body.uid) {
    return jsonResponse({ error: 'uid required' }, 400, corsHeaders);
  }

  const refreshToken = await env.AUTH_TOKENS.get(`refresh:${body.uid}`);
  if (!refreshToken) {
    return jsonResponse({ error: 'no_refresh_token' }, 401, corsHeaders);
  }

  const params = new URLSearchParams({
    refresh_token: refreshToken,
    client_id: env.GOOGLE_CLIENT_ID,
    client_secret: env.GOOGLE_CLIENT_SECRET,
    grant_type: 'refresh_token',
  });

  const res = await fetch(GOOGLE_TOKEN_URL, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: params.toString(),
  });

  const data = await res.json<{
    access_token?: string;
    expires_in?: number;
    error?: string;
  }>();

  if (!res.ok || data.error) {
    if (data.error === 'invalid_grant') {
      await env.AUTH_TOKENS.delete(`refresh:${body.uid}`);
    }
    return jsonResponse({ error: data.error || 'Refresh failed' }, 401, corsHeaders);
  }

  return jsonResponse({
    access_token: data.access_token,
    expires_in: data.expires_in,
  }, 200, corsHeaders);
}

/**
 * POST /auth/revoke { uid }
 * 로그아웃: KV에서 refresh token 삭제.
 */
async function handleRevoke(
  request: Request, env: Env, corsHeaders: Record<string, string>,
): Promise<Response> {
  const body = await request.json<{ uid: string }>();
  if (!body.uid) {
    return jsonResponse({ error: 'uid required' }, 400, corsHeaders);
  }

  await env.AUTH_TOKENS.delete(`refresh:${body.uid}`);
  return jsonResponse({ ok: true }, 200, corsHeaders);
}

/**
 * POST /auth/migrate { from_uid, to_uid }
 * pending → 실제 Firebase uid로 refresh token 키 이동.
 */
async function handleMigrate(
  request: Request, env: Env, corsHeaders: Record<string, string>,
): Promise<Response> {
  const body = await request.json<{ from_uid: string; to_uid: string }>();
  if (!body.from_uid || !body.to_uid) {
    return jsonResponse({ error: 'from_uid and to_uid required' }, 400, corsHeaders);
  }

  const token = await env.AUTH_TOKENS.get(`refresh:${body.from_uid}`);
  if (!token) {
    return jsonResponse({ error: 'no token to migrate' }, 404, corsHeaders);
  }

  await env.AUTH_TOKENS.put(`refresh:${body.to_uid}`, token);
  await env.AUTH_TOKENS.delete(`refresh:${body.from_uid}`);
  return jsonResponse({ ok: true }, 200, corsHeaders);
}

// ── Helpers ────────────────────────────────────────────────

function jsonResponse(body: object, status: number, headers: Record<string, string>): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...headers, 'Content-Type': 'application/json' },
  });
}

/**
 * postMessage로 결과를 opener에 전달하고 팝업을 닫는 HTML 반환.
 */
function postMessageResponse(data: Record<string, unknown>): Response {
  const html = `<!DOCTYPE html>
<html><body><script>
  if (window.opener) {
    window.opener.postMessage(${JSON.stringify(data)}, '*');
  }
  window.close();
</script></body></html>`;
  return new Response(html, {
    headers: { 'Content-Type': 'text/html; charset=utf-8' },
  });
}
