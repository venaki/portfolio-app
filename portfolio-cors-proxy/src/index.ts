interface Env {
  ALLOWED_ORIGINS: string;
}

const YAHOO_CHART_BASE = 'https://query1.finance.yahoo.com/v8/finance/chart';
const YAHOO_SEARCH_BASE = 'https://query2.finance.yahoo.com/v1/finance/search';

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const origin = request.headers.get('Origin') ?? '';
    const allowed = env.ALLOWED_ORIGINS.split(',');
    const allowedOrigin = allowed.includes(origin) ? origin : allowed[0];

    const corsHeaders = {
      'Access-Control-Allow-Origin': allowedOrigin,
      'Access-Control-Allow-Methods': 'GET, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type',
    };

    if (request.method === 'OPTIONS') {
      return new Response(null, { headers: corsHeaders });
    }

    if (request.method !== 'GET') {
      return new Response('Method not allowed', { status: 405, headers: corsHeaders });
    }

    const url = new URL(request.url);

    try {
      // /search endpoint: stock search
      if (url.pathname === '/search') {
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

      // Existing: /quote (backward compatible)
      const symbol = url.searchParams.get('symbol');
      const range = url.searchParams.get('range') || '1d';
      const interval = url.searchParams.get('interval') || '1d';

      if (!symbol) {
        return jsonResponse({ error: 'symbol parameter required' }, 400, corsHeaders);
      }

      const yahooUrl = `${YAHOO_CHART_BASE}/${encodeURIComponent(symbol)}?range=${range}&interval=${interval}`;
      const yahooRes = await fetch(yahooUrl, {
        headers: { 'User-Agent': 'Mozilla/5.0' },
      });
      const data = await yahooRes.text();
      return new Response(data, {
        status: yahooRes.status,
        headers: { ...corsHeaders, 'Content-Type': 'application/json', 'Cache-Control': 'public, max-age=60' },
      });
    } catch (err: any) {
      return jsonResponse({ error: err.message }, 502, corsHeaders);
    }
  },
};

function jsonResponse(body: object, status: number, headers: Record<string, string>): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...headers, 'Content-Type': 'application/json' },
  });
}
