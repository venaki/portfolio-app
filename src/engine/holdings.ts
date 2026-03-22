import { Transaction, Holding } from '../types';

export function replayTransactions(transactions: Transaction[]): Holding[] {
  const sorted = [...transactions].sort(
    (a, b) => new Date(a.executedAt).getTime() - new Date(b.executedAt).getTime()
  );

  const map = new Map<string, Holding>();

  for (const tx of sorted) {
    const key = `${tx.owner}::${tx.ticker}`;
    const existing = map.get(key);

    switch (tx.type) {
      case 'buy':
      case 'opening_balance':
      case 'adjustment': {
        if (existing) {
          const totalShares = existing.shares + tx.shares;
          const newAvgCost = (existing.shares * existing.avgCost + tx.shares * tx.price) / totalShares;
          const newAvgRate = (existing.shares * existing.avgExchangeRate + tx.shares * tx.exchangeRate) / totalShares;
          existing.shares = totalShares;
          existing.avgCost = newAvgCost;
          existing.avgExchangeRate = newAvgRate;
        } else {
          map.set(key, {
            owner: tx.owner,
            ticker: tx.ticker,
            shares: tx.shares,
            avgCost: tx.price,
            avgExchangeRate: tx.exchangeRate,
          });
        }
        break;
      }
      case 'sell': {
        if (existing) {
          existing.shares -= tx.shares;
          if (existing.shares <= 0) {
            map.delete(key);
          }
        }
        break;
      }
    }
  }

  return Array.from(map.values());
}
