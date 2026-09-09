import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';
import worker from '../src/index';
import type { Env } from '../src/common';

const origin = 'https://app.example';
// Search must not touch authentication storage or require a Firebase token.
const env = { ALLOWED_ORIGINS: origin } as Env;
const request = (q: string) => new Request(`https://worker.example/search?${new URLSearchParams({ q })}`, {
  headers: { Origin: origin },
});
const fixture = (name: string) => JSON.parse(readFileSync(new URL(`./fixtures/yahoo-search-${name}.json`, import.meta.url), 'utf8'));

for (const [name, query, expected] of [
  ['us', 'TSLA', [
    { ticker: 'TSLA', name: 'Tesla, Inc.', exchange: 'NASDAQ' },
    { ticker: 'TSLL', name: 'Direxion Daily TSLA Bull 2X Shares', exchange: 'NASDAQ' },
    { ticker: 'CRSH', name: 'YieldMax Short TSLA Option Inco', exchange: 'NYSEARCA' },
    { ticker: 'TSLQ', name: 'Tradr 2X Short TSLA Daily ETF', exchange: 'NASDAQ' },
    { ticker: 'TSII', name: 'REX TSLA Growth & Income ETF', exchange: 'BATS' },
  ]],
  ['krx', '005930', [{ ticker: '005930', name: 'Samsung Electronics Co., Ltd.', exchange: 'KRX' }]],
  ['kosdaq', '247540', [{ ticker: '247540', name: 'EcoPro BM Co., Ltd.', exchange: 'KOSDAQ' }]],
] as const) {
  test(`real Yahoo ${name} fixture becomes the client ticker/name/exchange array`, async (t) => {
    const captured = fixture(name);
    t.mock.method(globalThis, 'fetch', async (input: string, init: RequestInit) => {
      assert.equal(input, captured.source);
      assert.equal(new Headers(init.headers).get('User-Agent'), 'Mozilla/5.0');
      assert.ok(init.signal);
      return Response.json(captured.body);
    });
    const response = await worker.fetch(request(query), env);
    assert.equal(response.status, 200);
    assert.equal(response.headers.get('Access-Control-Allow-Origin'), origin);
    assert.equal(response.headers.get('Cache-Control'), 'public, max-age=300');
    assert.deepEqual(await response.json(), expected);
  });
}

test('search maps exchange codes and keeps only supported equity/ETF records', async (t) => {
  t.mock.method(globalThis, 'fetch', async () => Response.json({ quotes: [
    { symbol: 'JPM', exchange: 'NYQ', quoteType: 'EQUITY', shortname: 'JPMorgan Chase & Co.' },
    { symbol: 'SPY', exchange: 'PCX', quoteType: 'ETF' },
    { symbol: 'SMALL', exchange: 'NCM', quoteType: 'EQUITY', longname: '' },
    { symbol: 'AMEX', exchange: 'ASE', quoteType: 'EQUITY' },
    { symbol: 'PINK', exchange: 'PNK', quoteType: 'EQUITY' },
    { symbol: 'BTC-USD', exchange: 'CCC', quoteType: 'CRYPTOCURRENCY' },
    { symbol: 'VOD.L', exchange: 'LSE', quoteType: 'EQUITY' },
    { symbol: 'INVALID', exchange: 'constructor', quoteType: 'EQUITY' },
    { symbol: 'NOPE', exchange: 'NYQ', quoteType: 'EQUITY', isYahooFinance: false },
    { symbol: '', exchange: 'NYQ', quoteType: 'EQUITY' },
    { symbol: 123, exchange: 'NYQ', quoteType: 'EQUITY' },
    null,
  ] }));
  const response = await worker.fetch(request('mixed'), env);
  assert.deepEqual(await response.json(), [
    { ticker: 'JPM', name: 'JPMorgan Chase & Co.', exchange: 'NYSE' },
    { ticker: 'SPY', name: 'SPY', exchange: 'NYSEARCA' },
    { ticker: 'SMALL', name: 'SMALL', exchange: 'NASDAQ' },
    { ticker: 'AMEX', name: 'AMEX', exchange: 'NYSEAMERICAN' },
    { ticker: 'PINK', name: 'PINK', exchange: 'OTC' },
  ]);
});

test('an empty Yahoo result remains a successful empty client array', async (t) => {
  t.mock.method(globalThis, 'fetch', async () => Response.json({ quotes: [], news: [] }));
  const response = await worker.fetch(request('no-results'), env);
  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), []);
});

test('upstream HTTP, JSON, and schema failures are not cached as successful search results', async (t) => {
  const responses = [
    new Response('<html>Yahoo rate limited</html>', { status: 429 }),
    new Response('invalid JSON'),
    Response.json({ finance: { error: { description: 'upstream detail' } } }),
    Response.json({ quotes: {} }),
  ];
  t.mock.method(globalThis, 'fetch', async () => responses.shift()!);
  for (let i = 0; i < 4; i++) {
    const response = await worker.fetch(request('TSLA'), env);
    assert.equal(response.status, 502);
    assert.equal(response.headers.get('Cache-Control'), 'no-store');
    assert.equal(response.headers.get('Access-Control-Allow-Origin'), origin);
    assert.match((await response.json() as { error: string }).error, /^(upstream_unavailable|invalid_search_response)$/);
  }
});

test('empty or oversized search queries are rejected before fetching Yahoo', async (t) => {
  const fetch = t.mock.method(globalThis, 'fetch', async () => { throw new Error('must not fetch'); });
  for (const q of ['', '   ', 'x'.repeat(101)]) {
    assert.equal((await worker.fetch(request(q), env)).status, 400);
  }
  assert.equal(fetch.mock.callCount(), 0);
});
