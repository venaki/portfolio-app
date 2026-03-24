import { View, Text, StyleSheet } from 'react-native';
import { Holding, StockQuote } from '../types';
import { COLORS } from '../constants';
import { CARD_BASE, BADGE } from '../styles/shared';
import { formatUSD, formatKRW, formatPercent, formatShares } from '../utils/format';
import { useHoldingCalc } from '../hooks/useHoldingCalc';

interface Props {
  holding: Holding;
  quote: StockQuote | undefined;
  exchangeRate: number;
  accentColor: string;
}

export function HoldingCard({ holding, quote, exchangeRate, accentColor }: Props) {
  const { isCash, isKR, isKRW, price, dailyChangePct, profitKRW, totalValueKRW, profitPct, dailyColor, profitColor } = useHoldingCalc(holding, quote, exchangeRate);

  const formatPrice = isKRW ? formatKRW : formatUSD;
  const formatAvgCost = isKRW ? formatKRW : formatUSD;

  return (
    <View style={styles.card}>
      {/* Top: ticker + owner + price */}
      <View style={styles.topRow}>
        <View style={styles.tickerArea}>
          <Text style={styles.ticker}>{isKR && quote?.name ? quote.name : holding.ticker}</Text>
          <View style={BADGE.container}>
            <Text style={BADGE.text}>{holding.owner}</Text>
          </View>
        </View>
        <View style={styles.priceArea}>
          {isCash ? (
            <Text style={styles.price}>{formatPrice(holding.avgCost * holding.shares)}</Text>
          ) : (
            <>
              <Text style={styles.price}>{quote ? formatPrice(price) : '-'}</Text>
              <Text style={[styles.dailyChange, { color: dailyColor }]}>
                {quote ? formatPercent(dailyChangePct) : '-'}
              </Text>
            </>
          )}
        </View>
      </View>

      {/* Sub title */}
      {!isCash && (isKR
        ? <Text style={styles.name} numberOfLines={1}>{holding.ticker}</Text>
        : quote?.name && <Text style={styles.name} numberOfLines={1}>{quote.name}</Text>
      )}

      {/* Bottom: grid */}
      <View style={styles.grid}>
        {!isCash && (
          <>
            <View style={styles.gridItem}>
              <Text style={styles.gridLabel}>수익</Text>
              <Text style={[styles.gridValue, { color: profitColor }]}>
                {quote ? `${profitKRW >= 0 ? '+' : ''}${formatKRW(profitKRW)}` : '-'}
              </Text>
              <Text style={[styles.gridSub, { color: profitColor }]}>
                {quote ? formatPercent(profitPct) : '-'}
              </Text>
            </View>
            <View style={styles.gridItem}>
              <Text style={styles.gridLabel}>평단가</Text>
              <Text style={styles.gridValue}>{formatAvgCost(holding.avgCost)}</Text>
            </View>
            <View style={styles.gridItem}>
              <Text style={styles.gridLabel}>수량</Text>
              <Text style={styles.gridValue}>{formatShares(holding.shares)}주</Text>
            </View>
          </>
        )}
        <View style={styles.gridItem}>
          <Text style={styles.gridLabel}>평가금액</Text>
          <Text style={styles.gridValue}>
            {isCash ? formatKRW(totalValueKRW) : (quote ? formatKRW(totalValueKRW) : '-')}
          </Text>
        </View>
        {!isCash && !isKR && (
          <View style={styles.gridItem}>
            <Text style={styles.gridLabel}>매입환율</Text>
            <Text style={styles.gridValue}>{formatKRW(holding.avgExchangeRate)}</Text>
          </View>
        )}
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  card: {
    ...CARD_BASE,
  },
  topRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'flex-start',
    marginBottom: 4,
  },
  tickerArea: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
  },
  ticker: {
    fontWeight: '700',
    fontSize: 16,
    color: COLORS.textPrimary,
    fontVariant: ['tabular-nums'],
  },
  priceArea: {
    alignItems: 'flex-end',
  },
  price: {
    fontWeight: '700',
    fontSize: 16,
    color: COLORS.textPrimary,
    fontVariant: ['tabular-nums'],
  },
  dailyChange: {
    fontWeight: '500',
    fontSize: 11,
    marginTop: 2,
    fontVariant: ['tabular-nums'],
  },
  name: {
    fontSize: 11,
    color: COLORS.textMuted,
    marginBottom: 12,
  },
  grid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 8,
  },
  gridItem: {
    flex: 1,
    minWidth: '30%',
    gap: 2,
  },
  gridLabel: {
    fontWeight: '500',
    fontSize: 10,
    color: COLORS.textMuted,
    fontVariant: ['tabular-nums'],
  },
  gridValue: {
    fontWeight: '600',
    fontSize: 13,
    color: COLORS.textPrimary,
    fontVariant: ['tabular-nums'],
  },
  gridSub: {
    fontWeight: '500',
    fontSize: 10,
    marginTop: 1,
    fontVariant: ['tabular-nums'],
  },
});
