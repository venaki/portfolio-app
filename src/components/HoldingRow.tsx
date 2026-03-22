import { View, Text, StyleSheet } from 'react-native';
import { Holding, StockQuote } from '../types';
import { COLORS, NEGATIVE_COLOR } from '../constants';
import { calcProfitPercentUSD, calcProfitUSD, calcTotalValueKRW, calcProfitKRW, calcProfitPercentKRW } from '../engine/calculations';
import { formatUSD, formatKRW, formatPercent, formatShares } from '../utils/format';

interface Props {
  holding: Holding;
  quote: StockQuote | undefined;
  exchangeRate: number;
  accentColor: string;
}

export function HoldingRow({ holding, quote, exchangeRate, accentColor }: Props) {
  const price = quote?.price ?? 0;
  const dailyChangePct = quote?.changesPercentage ?? 0;
  const profitPctUSD = quote ? calcProfitPercentUSD(holding, price) : 0;
  const profitKRW = quote ? calcProfitKRW(holding, price, exchangeRate) : 0;
  const totalValueKRW = quote ? calcTotalValueKRW(holding, price, exchangeRate) : 0;

  const dailyPositive = dailyChangePct >= 0;
  const dailyColor = dailyPositive ? accentColor : NEGATIVE_COLOR;
  const profitPositive = profitPctUSD >= 0;
  const profitColor = profitPositive ? accentColor : NEGATIVE_COLOR;

  return (
    <View style={styles.row}>
      {/* 종목 + 명의 */}
      <View style={styles.colTicker}>
        <View style={styles.tickerRow}>
          <Text style={styles.ticker}>{holding.ticker}</Text>
          <View style={styles.ownerBadge}>
            <Text style={styles.ownerText}>{holding.owner}</Text>
          </View>
        </View>
        {quote?.name && (
          <Text style={styles.tickerName} numberOfLines={1}>{quote.name}</Text>
        )}
      </View>

      {/* 현재가 + 변동% */}
      <View style={styles.colFill}>
        <Text style={styles.price}>{quote ? formatUSD(price) : '-'}</Text>
        <Text style={[styles.subText, { color: dailyColor }]}>
          {quote ? formatPercent(dailyChangePct) : '-'}
        </Text>
      </View>

      {/* 수익금 + 수익률 */}
      <View style={styles.colFill}>
        <Text style={[styles.price, { color: profitColor }]}>
          {quote ? `${profitKRW >= 0 ? '+' : ''}${formatKRW(profitKRW)}` : '-'}
        </Text>
        <Text style={[styles.subText, { color: profitColor }]}>
          {quote ? formatPercent(profitPctUSD) : '-'}
        </Text>
      </View>

      {/* 평단가 */}
      <View style={styles.colFill}>
        <Text style={styles.valueText}>{formatUSD(holding.avgCost)}</Text>
      </View>

      {/* 수량 */}
      <View style={styles.colFill}>
        <Text style={styles.valueText}>{formatShares(holding.shares)}</Text>
      </View>

      {/* 평가금액 */}
      <View style={styles.colFill}>
        <Text style={styles.valueText}>{quote ? formatKRW(totalValueKRW) : '-'}</Text>
        {quote && (
          <Text style={styles.subText}>{formatUSD(price * holding.shares)}</Text>
        )}
      </View>

      {/* 매입환율 */}
      <View style={styles.colFill}>
        <Text style={styles.valueText}>{formatKRW(holding.avgExchangeRate)}</Text>
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
    borderBottomColor: COLORS.divider,
    backgroundColor: COLORS.card,
  },
  colTicker: {
    width: 160,
  },
  colFill: {
    flex: 1,
    alignItems: 'flex-end',
  },
  tickerRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
  },
  ticker: {
    fontFamily: 'JetBrainsMono_700Bold',
    fontSize: 13,
    color: COLORS.textPrimary,
  },
  ownerBadge: {
    backgroundColor: COLORS.muted,
    borderRadius: 4,
    paddingHorizontal: 5,
    paddingVertical: 1,
  },
  ownerText: {
    fontFamily: 'Inter_500Medium',
    fontSize: 9,
    color: COLORS.textTertiary,
  },
  tickerName: {
    fontFamily: 'Inter_400Regular',
    fontSize: 11,
    color: COLORS.textTertiary,
    marginTop: 2,
  },
  price: {
    fontFamily: 'JetBrainsMono_600SemiBold',
    fontSize: 13,
    color: COLORS.textPrimary,
  },
  valueText: {
    fontFamily: 'JetBrainsMono_500Medium',
    fontSize: 13,
    color: COLORS.textPrimary,
  },
  subText: {
    fontFamily: 'JetBrainsMono_400Regular',
    fontSize: 10,
    color: COLORS.textTertiary,
    marginTop: 2,
  },
});
