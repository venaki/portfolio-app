import { View, Text, StyleSheet } from 'react-native';
import { Holding, StockQuote } from '../types';
import { COLORS } from '../constants';
import { BADGE } from '../styles/shared';
import { formatUSD, formatKRW, formatPercent, formatShares } from '../utils/format';
import { useHoldingCalc } from '../hooks/useHoldingCalc';

interface Props {
  holding: Holding;
  quote: StockQuote | undefined;
  exchangeRate: number;
  accentColor: string;
}

export function HoldingRow({ holding, quote, exchangeRate, accentColor }: Props) {
  const { isCash, isKR, isKRW, price, dailyChangePct, profitKRW, totalValueKRW, profitPct, dailyColor, profitColor } = useHoldingCalc(holding, quote, exchangeRate);

  const formatPrice = isKRW ? formatKRW : formatUSD;

  return (
    <View style={styles.row}>
      {/* 종목 + 명의 */}
      <View style={styles.colTicker}>
        <View style={styles.tickerRow}>
          <Text style={styles.ticker}>{isKR && quote?.name ? quote.name : holding.ticker}</Text>
          <View style={BADGE.container}>
            <Text style={BADGE.text}>{holding.owner}</Text>
          </View>
        </View>
        {!isCash && (isKR
          ? <Text style={styles.tickerName} numberOfLines={1}>{holding.ticker}</Text>
          : quote?.name && <Text style={styles.tickerName} numberOfLines={1}>{quote.name}</Text>
        )}
      </View>

      {/* 현재가 + 변동% */}
      <View style={styles.colFill}>
        {isCash ? (
          <Text style={styles.valueText}>-</Text>
        ) : (
          <>
            <Text style={styles.price}>{quote ? formatPrice(price) : '-'}</Text>
            <Text style={[styles.subText, { color: dailyColor }]}>
              {quote ? formatPercent(dailyChangePct) : '-'}
            </Text>
          </>
        )}
      </View>

      {/* 수익금 + 수익률 */}
      <View style={styles.colFill}>
        {isCash ? (
          <Text style={styles.valueText}>-</Text>
        ) : (
          <>
            <Text style={[styles.price, { color: profitColor }]}>
              {quote ? `${profitKRW >= 0 ? '+' : ''}${formatKRW(profitKRW)}` : '-'}
            </Text>
            <Text style={[styles.subText, { color: profitColor }]}>
              {quote ? formatPercent(profitPct) : '-'}
            </Text>
          </>
        )}
      </View>

      {/* 평단가 */}
      <View style={styles.colFill}>
        <Text style={styles.valueText}>
          {isCash ? '-' : formatPrice(holding.avgCost)}
        </Text>
      </View>

      {/* 수량 */}
      <View style={styles.colFill}>
        <Text style={styles.valueText}>
          {isCash ? '-' : formatShares(holding.shares)}
        </Text>
      </View>

      {/* 평가금액 */}
      <View style={styles.colFill}>
        <Text style={styles.valueText}>
          {isCash ? formatKRW(totalValueKRW) : (quote ? formatKRW(totalValueKRW) : '-')}
        </Text>
        {!isCash && !isKR && quote && (
          <Text style={styles.subText}>{formatUSD(price * holding.shares)}</Text>
        )}
      </View>

      {/* 매입환율 */}
      <View style={styles.colFill}>
        <Text style={styles.valueText}>
          {isKRW ? '-' : formatKRW(holding.avgExchangeRate)}
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
    fontWeight: '700',
    fontSize: 13,
    color: COLORS.textPrimary,
    fontVariant: ['tabular-nums'],
  },
  tickerName: {
    fontSize: 11,
    color: COLORS.textTertiary,
    marginTop: 2,
  },
  price: {
    fontWeight: '600',
    fontSize: 13,
    color: COLORS.textPrimary,
    fontVariant: ['tabular-nums'],
  },
  valueText: {
    fontWeight: '500',
    fontSize: 13,
    color: COLORS.textPrimary,
    fontVariant: ['tabular-nums'],
  },
  subText: {
    fontSize: 10,
    color: COLORS.textTertiary,
    marginTop: 2,
    fontVariant: ['tabular-nums'],
  },
});
