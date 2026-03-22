import { View, Text, StyleSheet } from 'react-native';
import { Holding, StockQuote } from '../types';
import { COLORS, NEGATIVE_COLOR } from '../constants';
import { calcProfitPercentUSD, calcTotalValueKRW } from '../engine/calculations';
import { formatUSD, formatKRW, formatPercent, formatShares } from '../utils/format';

interface Props {
  holding: Holding;
  quote: StockQuote | undefined;
  exchangeRate: number;
  accentColor: string;
}

export function HoldingRow({ holding, quote, exchangeRate, accentColor }: Props) {
  const price = quote?.price ?? 0;
  const changePercent = quote ? calcProfitPercentUSD(holding, price) : 0;
  const totalValueKRW = quote ? calcTotalValueKRW(holding, price, exchangeRate) : 0;
  const isPositive = changePercent >= 0;
  const changeColor = isPositive ? accentColor : NEGATIVE_COLOR;

  return (
    <View style={styles.row}>
      {/* 종목 */}
      <View style={styles.colTicker}>
        <Text style={styles.ticker}>{holding.ticker}</Text>
        {quote?.name && (
          <Text style={styles.tickerName} numberOfLines={1}>{quote.name}</Text>
        )}
      </View>

      {/* 명의 */}
      <View style={styles.colOwner}>
        <Text style={styles.ownerText}>{holding.owner}</Text>
      </View>

      {/* 현재가 */}
      <View style={styles.colFill}>
        <Text style={styles.price}>{quote ? formatUSD(price) : '-'}</Text>
        <Text style={[styles.change, { color: changeColor }]}>
          {quote ? formatPercent(changePercent) : '-'}
        </Text>
      </View>

      {/* 수량 */}
      <View style={styles.colFill}>
        <Text style={styles.shares}>{formatShares(holding.shares)}</Text>
      </View>

      {/* 평가금액 */}
      <View style={styles.colFill}>
        <Text style={styles.valueKRW}>{quote ? formatKRW(totalValueKRW) : '-'}</Text>
        {quote && (
          <Text style={styles.valueUSD}>{formatUSD(price * holding.shares)}</Text>
        )}
      </View>

      {/* 수익률 */}
      <View style={styles.colFill}>
        <Text style={[styles.profitPct, { color: changeColor }]}>
          {quote ? formatPercent(changePercent) : '-'}
        </Text>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  row: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: 14,
    paddingHorizontal: 16,
    borderBottomWidth: 1,
    borderBottomColor: COLORS.border,
    backgroundColor: COLORS.card,
  },
  colTicker: {
    width: 160,
  },
  colOwner: {
    width: 70,
  },
  colFill: {
    flex: 1,
    alignItems: 'flex-end',
  },
  ticker: {
    fontFamily: 'JetBrainsMono_700Bold',
    fontSize: 14,
    color: COLORS.textPrimary,
  },
  tickerName: {
    fontFamily: 'Inter_400Regular',
    fontSize: 11,
    color: COLORS.textTertiary,
    marginTop: 2,
  },
  ownerText: {
    fontFamily: 'Inter_500Medium',
    fontSize: 13,
    color: COLORS.textSecondary,
  },
  price: {
    fontFamily: 'JetBrainsMono_600SemiBold',
    fontSize: 13,
    color: COLORS.textPrimary,
  },
  change: {
    fontFamily: 'Inter_500Medium',
    fontSize: 11,
    marginTop: 2,
  },
  shares: {
    fontFamily: 'JetBrainsMono_500Medium',
    fontSize: 13,
    color: COLORS.textPrimary,
  },
  valueKRW: {
    fontFamily: 'JetBrainsMono_600SemiBold',
    fontSize: 13,
    color: COLORS.textPrimary,
  },
  valueUSD: {
    fontFamily: 'JetBrainsMono_400Regular',
    fontSize: 11,
    color: COLORS.textTertiary,
    marginTop: 2,
  },
  profitPct: {
    fontFamily: 'JetBrainsMono_600SemiBold',
    fontSize: 13,
  },
});
