import { View, Text, StyleSheet } from 'react-native';
import { Holding, StockQuote } from '../types';
import { COLORS, NEGATIVE_COLOR, POSITIVE_COLOR } from '../constants';
import { calcProfitPercentUSD, calcTotalValueKRW, calcProfitKRW } from '../engine/calculations';
import { formatUSD, formatKRW, formatPercent, formatShares } from '../utils/format';

interface Props {
  holding: Holding;
  quote: StockQuote | undefined;
  exchangeRate: number;
  accentColor: string;
}

export function HoldingCard({ holding, quote, exchangeRate, accentColor }: Props) {
  const isCash = holding.assetClass === 'cash';
  const isKR = holding.assetClass === 'kr_stock';
  const isKRW = holding.currency === 'KRW';

  const price = quote?.price ?? 0;
  const dailyChangePct = quote?.changesPercentage ?? 0;

  // For cash: no market quote needed
  const profitKRW = isCash ? 0 : (quote ? calcProfitKRW(holding, price, exchangeRate) : 0);
  const totalValueKRW = isCash
    ? (isKRW ? holding.avgCost * holding.shares : holding.avgCost * holding.shares * exchangeRate)
    : (quote ? calcTotalValueKRW(holding, price, exchangeRate) : 0);

  const profitPct = isCash ? 0 : (quote ? calcProfitPercentUSD(holding, price) : 0);

  const dailyPositive = dailyChangePct >= 0;
  const dailyColor = dailyPositive ? POSITIVE_COLOR : NEGATIVE_COLOR;
  const profitPositive = profitPct >= 0;
  const profitColor = profitPositive ? POSITIVE_COLOR : NEGATIVE_COLOR;

  const formatPrice = isKRW ? formatKRW : formatUSD;
  const formatAvgCost = isKRW ? formatKRW : formatUSD;

  return (
    <View style={styles.card}>
      {/* Top: ticker + owner + price */}
      <View style={styles.topRow}>
        <View style={styles.tickerArea}>
          <Text style={styles.ticker}>{isKR && quote?.name ? quote.name : holding.ticker}</Text>
          <View style={styles.ownerBadge}>
            <Text style={styles.ownerText}>{holding.owner}</Text>
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
    backgroundColor: COLORS.card,
    borderRadius: 12,
    borderWidth: 1,
    borderColor: COLORS.border,
    padding: 16,
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
    fontFamily: 'JetBrainsMono_700Bold',
    fontSize: 16,
    color: COLORS.textPrimary,
  },
  ownerBadge: {
    backgroundColor: COLORS.muted,
    borderRadius: 4,
    paddingHorizontal: 6,
    paddingVertical: 2,
  },
  ownerText: {
    fontFamily: 'Inter_500Medium',
    fontSize: 10,
    color: COLORS.textTertiary,
  },
  priceArea: {
    alignItems: 'flex-end',
  },
  price: {
    fontFamily: 'JetBrainsMono_700Bold',
    fontSize: 16,
    color: COLORS.textPrimary,
  },
  dailyChange: {
    fontFamily: 'JetBrainsMono_500Medium',
    fontSize: 11,
    marginTop: 2,
  },
  name: {
    fontFamily: 'Inter_400Regular',
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
    fontFamily: 'JetBrainsMono_500Medium',
    fontSize: 10,
    color: COLORS.textMuted,
  },
  gridValue: {
    fontFamily: 'JetBrainsMono_600SemiBold',
    fontSize: 13,
    color: COLORS.textPrimary,
  },
  gridSub: {
    fontFamily: 'JetBrainsMono_500Medium',
    fontSize: 10,
    marginTop: 1,
  },
});
