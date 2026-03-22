import { Transaction, Owner } from './types';
import { v4 as uuid } from 'uuid';

const SEED_DATE = '2026-03-22T00:00:00.000Z';

function opening(owner: Owner, ticker: string, shares: number, price: number, exchangeRate: number): Transaction {
  return {
    id: uuid(),
    owner,
    ticker,
    type: 'opening_balance',
    shares,
    price,
    exchangeRate,
    executedAt: SEED_DATE,
    memo: '초기 시드 데이터',
  };
}

export const SEED_TRANSACTIONS: Transaction[] = [
  opening('본석', 'TSLA', 500, 318.01, 1450.51),
  opening('본석', 'TSLL', 2089, 16.86, 1430.00),
  opening('본석', 'TQQQ', 1200, 25.85, 1391.50),
  opening('연지', 'TSLA', 1053, 387.85, 1434.42),
  opening('연지', 'TSLL', 7300, 29.41, 1462.41),
  opening('연지', 'TQQQ', 406, 53.18, 1377.25),
  opening('연지', 'TSLY', 1000, 8.92, 1388.65),
  opening('연지', 'GOOGL', 4, 190.88, 1386.00),
  opening('연지', 'SGOV', 200, 100.51, 1450.50),
  opening('연지', 'NVDA', 14, 204.71, 1427.40),
  opening('연지', 'NFLX', 5, 88.74, 1473.60),
  opening('연지', 'MP', 4, 69.79, 1473.60),
  opening('나은', 'TQQQ', 1037, 38.10, 1467.16),
];
