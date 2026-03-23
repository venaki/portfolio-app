import { useMemo } from 'react';
import { Holding, StockQuote } from '../types';
import { NEGATIVE_COLOR, POSITIVE_COLOR } from '../constants';
import { calcProfitPercentUSD, calcTotalValueKRW, calcProfitKRW } from '../engine/calculations';

export interface HoldingCalcResult {
  isCash: boolean;
  isKR: boolean;
  isKRW: boolean;
  price: number;
  dailyChangePct: number;
  profitKRW: number;
  totalValueKRW: number;
  profitPct: number;
  dailyColor: string;
  profitColor: string;
}

export function useHoldingCalc(
  holding: Holding,
  quote: StockQuote | undefined,
  exchangeRate: number,
): HoldingCalcResult {
  return useMemo(() => {
    const isCash = holding.assetClass === 'cash';
    const isKR = holding.assetClass === 'kr_stock';
    const isKRW = holding.currency === 'KRW';

    const price = quote?.price ?? 0;
    const dailyChangePct = quote?.changesPercentage ?? 0;

    const profitKRW = isCash ? 0 : (quote ? calcProfitKRW(holding, price, exchangeRate) : 0);
    const totalValueKRW = isCash
      ? (isKRW ? holding.avgCost * holding.shares : holding.avgCost * holding.shares * exchangeRate)
      : (quote ? calcTotalValueKRW(holding, price, exchangeRate) : 0);
    const profitPct = isCash ? 0 : (quote ? calcProfitPercentUSD(holding, price) : 0);

    const dailyColor = dailyChangePct >= 0 ? POSITIVE_COLOR : NEGATIVE_COLOR;
    const profitColor = profitPct >= 0 ? POSITIVE_COLOR : NEGATIVE_COLOR;

    return { isCash, isKR, isKRW, price, dailyChangePct, profitKRW, totalValueKRW, profitPct, dailyColor, profitColor };
  }, [holding, quote, exchangeRate]);
}
