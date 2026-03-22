import { replayTransactions } from '../../src/engine/holdings';
import { Transaction, Holding } from '../../src/types';

function tx(overrides: Partial<Transaction> & Pick<Transaction, 'owner' | 'ticker' | 'type' | 'shares' | 'price' | 'exchangeRate'>): Transaction {
  return {
    id: Math.random().toString(),
    executedAt: '2026-01-01T00:00:00Z',
    ...overrides,
  };
}

describe('replayTransactions', () => {
  it('returns empty array for no transactions', () => {
    expect(replayTransactions([])).toEqual([]);
  });

  it('creates holding from opening_balance', () => {
    const txs = [tx({ owner: '본석', ticker: 'TSLA', type: 'opening_balance', shares: 500, price: 318.01, exchangeRate: 1450.51 })];
    const holdings = replayTransactions(txs);
    expect(holdings).toHaveLength(1);
    expect(holdings[0]).toEqual({
      owner: '본석',
      ticker: 'TSLA',
      shares: 500,
      avgCost: 318.01,
      avgExchangeRate: 1450.51,
    });
  });

  it('calculates moving average on multiple buys', () => {
    const txs = [
      tx({ owner: '연지', ticker: 'TSLA', type: 'buy', shares: 100, price: 300, exchangeRate: 1400, executedAt: '2026-01-01T00:00:00Z' }),
      tx({ owner: '연지', ticker: 'TSLA', type: 'buy', shares: 200, price: 450, exchangeRate: 1500, executedAt: '2026-01-02T00:00:00Z' }),
    ];
    const holdings = replayTransactions(txs);
    expect(holdings).toHaveLength(1);
    expect(holdings[0].shares).toBe(300);
    expect(holdings[0].avgCost).toBeCloseTo(400, 2);
    expect(holdings[0].avgExchangeRate).toBeCloseTo(1466.67, 1);
  });

  it('sell reduces shares but keeps avgCost', () => {
    const txs = [
      tx({ owner: '본석', ticker: 'TSLA', type: 'buy', shares: 500, price: 300, exchangeRate: 1400, executedAt: '2026-01-01T00:00:00Z' }),
      tx({ owner: '본석', ticker: 'TSLA', type: 'sell', shares: 100, price: 400, exchangeRate: 1500, executedAt: '2026-01-02T00:00:00Z' }),
    ];
    const holdings = replayTransactions(txs);
    expect(holdings[0].shares).toBe(400);
    expect(holdings[0].avgCost).toBe(300);
    expect(holdings[0].avgExchangeRate).toBe(1400);
  });

  it('removes holding when fully sold', () => {
    const txs = [
      tx({ owner: '본석', ticker: 'TSLA', type: 'buy', shares: 100, price: 300, exchangeRate: 1400, executedAt: '2026-01-01T00:00:00Z' }),
      tx({ owner: '본석', ticker: 'TSLA', type: 'sell', shares: 100, price: 400, exchangeRate: 1500, executedAt: '2026-01-02T00:00:00Z' }),
    ];
    const holdings = replayTransactions(txs);
    expect(holdings).toHaveLength(0);
  });

  it('separates holdings by owner', () => {
    const txs = [
      tx({ owner: '본석', ticker: 'TSLA', type: 'buy', shares: 100, price: 300, exchangeRate: 1400 }),
      tx({ owner: '연지', ticker: 'TSLA', type: 'buy', shares: 200, price: 400, exchangeRate: 1500 }),
    ];
    const holdings = replayTransactions(txs);
    expect(holdings).toHaveLength(2);
  });

  it('sorts transactions by executedAt before replay', () => {
    const txs = [
      tx({ owner: '본석', ticker: 'TSLA', type: 'sell', shares: 50, price: 400, exchangeRate: 1500, executedAt: '2026-02-01T00:00:00Z' }),
      tx({ owner: '본석', ticker: 'TSLA', type: 'buy', shares: 500, price: 300, exchangeRate: 1400, executedAt: '2026-01-01T00:00:00Z' }),
    ];
    const holdings = replayTransactions(txs);
    expect(holdings[0].shares).toBe(450);
  });

  it('oversell removes holding', () => {
    const txs = [
      tx({ owner: '본석', ticker: 'TSLA', type: 'buy', shares: 100, price: 300, exchangeRate: 1400, executedAt: '2026-01-01T00:00:00Z' }),
      tx({ owner: '본석', ticker: 'TSLA', type: 'sell', shares: 150, price: 400, exchangeRate: 1500, executedAt: '2026-01-02T00:00:00Z' }),
    ];
    const holdings = replayTransactions(txs);
    expect(holdings).toHaveLength(0);
  });

  it('sell without prior buy is silently ignored', () => {
    const txs = [
      tx({ owner: '본석', ticker: 'TSLA', type: 'sell', shares: 100, price: 400, exchangeRate: 1500 }),
    ];
    const holdings = replayTransactions(txs);
    expect(holdings).toHaveLength(0);
  });

  it('handles adjustment type (treated like buy)', () => {
    const txs = [
      tx({ owner: '본석', ticker: 'TSLA', type: 'buy', shares: 100, price: 300, exchangeRate: 1400, executedAt: '2026-01-01T00:00:00Z' }),
      tx({ owner: '본석', ticker: 'TSLA', type: 'adjustment', shares: 50, price: 320, exchangeRate: 1420, executedAt: '2026-01-02T00:00:00Z' }),
    ];
    const holdings = replayTransactions(txs);
    expect(holdings[0].shares).toBe(150);
    expect(holdings[0].avgCost).toBeCloseTo(306.67, 1);
  });
});
