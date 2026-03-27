interface Env {
  ALLOWED_ORIGINS: string;
  GOOGLE_CLIENT_ID: string;
  GOOGLE_CLIENT_SECRET: string;
  AUTH_TOKENS: KVNamespace;
}

const YAHOO_SEARCH_BASE = 'https://query2.finance.yahoo.com/v1/finance/search';
const GOOGLE_TOKEN_URL = 'https://oauth2.googleapis.com/token';

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
      // ── Auth endpoints ─────────────────────────────────

      if (url.pathname === '/auth/exchange' && request.method === 'POST') {
        return handleExchange(request, env, corsHeaders);
      }

      if (url.pathname === '/auth/refresh' && request.method === 'POST') {
        return handleRefresh(request, env, corsHeaders);
      }

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

async function handleExchange(
  request: Request, env: Env, corsHeaders: Record<string, string>,
): Promise<Response> {
  const body = await request.json<{ code: string; redirect_uri: string; uid: string }>();
  if (!body.code || !body.uid) {
    return jsonResponse({ error: 'code and uid required' }, 400, corsHeaders);
  }

  const params = new URLSearchParams({
    code: body.code,
    client_id: env.GOOGLE_CLIENT_ID,
    client_secret: env.GOOGLE_CLIENT_SECRET,
    redirect_uri: body.redirect_uri || '',
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
    expires_in?: number;
    error?: string;
  }>();

  if (!res.ok || data.error) {
    return jsonResponse({ error: data.error || 'Token exchange failed' }, 400, corsHeaders);
  }

  if (data.refresh_token) {
    await env.AUTH_TOKENS.put(`refresh:${body.uid}`, data.refresh_token);
  }

  return jsonResponse({
    access_token: data.access_token,
    expires_in: data.expires_in,
  }, 200, corsHeaders);
}

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

// ── Helpers ────────────────────────────────────────────────

function jsonResponse(body: object, status: number, headers: Record<string, string>): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...headers, 'Content-Type': 'application/json' },
  });
}
