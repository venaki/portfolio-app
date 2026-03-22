import { Holding } from '../types';

export function calcProfitUSD(holding: Holding, currentPrice: number): number {
  return (currentPrice - holding.avgCost) * holding.shares;
}

export function calcProfitPercentUSD(holding: Holding, currentPrice: number): number {
  if (holding.avgCost === 0) return 0;
  return ((currentPrice - holding.avgCost) / holding.avgCost) * 100;
}

export function calcTotalValueKRW(holding: Holding, currentPrice: number, currentRate: number): number {
  return currentPrice * holding.shares * currentRate;
}

export function calcCostKRW(holding: Holding): number {
  return holding.avgCost * holding.shares * holding.avgExchangeRate;
}

export function calcProfitKRW(holding: Holding, currentPrice: number, currentRate: number): number {
  return calcTotalValueKRW(holding, currentPrice, currentRate) - calcCostKRW(holding);
}

export function calcProfitPercentKRW(holding: Holding, currentPrice: number, currentRate: number): number {
  const cost = calcCostKRW(holding);
  if (cost === 0) return 0;
  return ((calcTotalValueKRW(holding, currentPrice, currentRate) - cost) / cost) * 100;
}

export function calcDailyChangeKRW(
  holding: Holding,
  currentPrice: number,
  previousClose: number,
  currentRate: number,
): number {
  return (currentPrice - previousClose) * holding.shares * currentRate;
}

export function calcRealizedPL(
  sellShares: number,
  sellPrice: number,
  sellRate: number,
  avgCost: number,
  avgRate: number,
): { usd: number; krw: number } {
  return {
    usd: (sellPrice - avgCost) * sellShares,
    krw: sellPrice * sellShares * sellRate - avgCost * sellShares * avgRate,
  };
}
