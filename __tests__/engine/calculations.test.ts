import {
  calcProfitUSD,
  calcProfitKRW,
  calcProfitPercentUSD,
  calcProfitPercentKRW,
  calcRealizedPL,
  calcTotalValueKRW,
  calcDailyChangeKRW,
} from '../../src/engine/calculations';
import { Holding } from '../../src/types';

const holding: Holding = {
  owner: '본석',
  ticker: 'TSLA',
  assetClass: 'us_stock',
  currency: 'USD',
  shares: 500,
  avgCost: 318.01,
  avgExchangeRate: 1450.51,
};

describe('calcProfitUSD', () => {
  it('calculates USD profit', () => {
    const result = calcProfitUSD(holding, 367.96);
    expect(result).toBeCloseTo((367.96 - 318.01) * 500, 0);
  });
});

describe('calcProfitPercentUSD', () => {
  it('calculates USD profit percent', () => {
    const result = calcProfitPercentUSD(holding, 367.96);
    expect(result).toBeCloseTo(((367.96 - 318.01) / 318.01) * 100, 1);
  });
});

describe('calcTotalValueKRW', () => {
  it('calculates total KRW value', () => {
    const result = calcTotalValueKRW(holding, 367.96, 1505.32);
    expect(result).toBeCloseTo(367.96 * 500 * 1505.32, 0);
  });
});

describe('calcProfitKRW', () => {
  it('calculates KRW profit with exchange rate difference', () => {
    const currentRate = 1505.32;
    const evalKRW = 367.96 * 500 * currentRate;
    const costKRW = 318.01 * 500 * 1450.51;
    const result = calcProfitKRW(holding, 367.96, currentRate);
    expect(result).toBeCloseTo(evalKRW - costKRW, 0);
  });
});

describe('calcProfitPercentKRW', () => {
  it('calculates KRW profit percent including exchange rate effect', () => {
    const result = calcProfitPercentKRW(holding, 367.96, 1505.32);
    const costKRW = 318.01 * 500 * 1450.51;
    const evalKRW = 367.96 * 500 * 1505.32;
    expect(result).toBeCloseTo(((evalKRW - costKRW) / costKRW) * 100, 1);
  });
});

describe('calcDailyChangeKRW', () => {
  it('calculates daily change in KRW', () => {
    const result = calcDailyChangeKRW(holding, 367.96, 355.62, 1505.32);
    expect(result).toBeCloseTo((367.96 - 355.62) * 500 * 1505.32, 0);
  });
});

describe('calcRealizedPL', () => {
  it('calculates realized P&L on sell', () => {
    const result = calcRealizedPL(100, 400, 1500, 300, 1400);
    expect(result.usd).toBeCloseTo(10000, 0);
    expect(result.krw).toBeCloseTo(18000000, 0);
  });
});
