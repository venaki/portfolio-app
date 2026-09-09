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

test('search preserves six-character alphanumeric Korean codes without widening supported markets', async (t) => {
  // KRX KIND confirms 0195R0 (KR70195R0008), listed on 2026-05-27:
  // https://kind.krx.co.kr/disclosure/etfisudetail.do?method=searchEtfIsuSummary&strIsurCd=0195R
  // Hanwha's issuer IR confirms its 00088K preferred-share code:
  // https://www.hanwhacorp.co.kr/common/fileDownload.do?name=Hanwha+Corp._IR+news%282020.07%29.pdf&path=%2Fupload%2Fhanwha%2FIRData%2Fpr%2F20210422%2F36248571-70b0-46b3-ab07-cbd326c5fe2b.pdf
  t.mock.method(globalThis, 'fetch', async () => Response.json({ quotes: [
    { symbol: '0195R0.KS', exchange: 'KSC', quoteType: 'ETF', shortname: 'TIGER 삼성전자단일종목레버리지' },
    { symbol: '00088k.ks', exchange: 'KSC', quoteType: 'EQUITY', shortname: '한화3우B' },
    // Synthetic code exercises KQ normalization independently of an actual listing.
    { symbol: '0123A4.KQ', exchange: 'KOE', quoteType: 'EQUITY', shortname: 'KOSDAQ fixture' },
    { symbol: '0195R.KS', exchange: 'KSC', quoteType: 'ETF' },
    { symbol: '00195R0.KS', exchange: 'KSC', quoteType: 'ETF' },
    { symbol: '0195-0.KS', exchange: 'KSC', quoteType: 'ETF' },
    { symbol: '0195R0.L', exchange: 'LSE', quoteType: 'ETF' },
    { symbol: '0195R0-USD', exchange: 'CCC', quoteType: 'CRYPTOCURRENCY' },
    { symbol: '0195R0', exchange: 'KSC', quoteType: 'ETF' },
  ] }));
  const response = await worker.fetch(request('0195R0'), env);
  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), [
    { ticker: '0195R0', name: 'TIGER 삼성전자단일종목레버리지', exchange: 'KRX' },
    { ticker: '00088K', name: '한화3우B', exchange: 'KRX' },
    { ticker: '0123A4', name: 'KOSDAQ fixture', exchange: 'KOSDAQ' },
  ]);
});

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
