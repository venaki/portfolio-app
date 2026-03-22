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

export function HoldingCard({ holding, quote, exchangeRate, accentColor }: Props) {
  const price = quote?.price ?? 0;
  const changePercent = quote ? calcProfitPercentUSD(holding, price) : 0;
  const totalValueKRW = quote ? calcTotalValueKRW(holding, price, exchangeRate) : 0;
  const isPositive = changePercent >= 0;
  const changeColor = isPositive ? accentColor : NEGATIVE_COLOR;

  return (
    <View style={styles.card}>
      <View style={styles.left}>
        <Text style={styles.ticker}>{holding.ticker}</Text>
        <View style={styles.ownerBadge}>
          <Text style={styles.ownerText}>{holding.owner}</Text>
        </View>
        {quote?.name && (
          <Text style={styles.name} numberOfLines={1}>{quote.name}</Text>
        )}
        <Text style={styles.detail}>
          {formatShares(holding.shares)}주 · 평단 {formatUSD(holding.avgCost)}
        </Text>
      </View>

      <View style={styles.right}>
        <Text style={styles.price}>{quote ? formatUSD(price) : '-'}</Text>
        <Text style={[styles.change, { color: changeColor }]}>
          {quote ? formatPercent(changePercent) : '-'}
        </Text>
        <Text style={styles.valueKRW}>{quote ? formatKRW(totalValueKRW) : '-'}</Text>
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
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'flex-start',
  },
  left: {
    flex: 1,
    marginRight: 12,
  },
  ticker: {
    fontFamily: 'JetBrainsMono_700Bold',
    fontSize: 16,
    color: COLORS.textPrimary,
    marginBottom: 4,
  },
  ownerBadge: {
    backgroundColor: COLORS.muted,
    borderRadius: 4,
    paddingHorizontal: 6,
    paddingVertical: 2,
    alignSelf: 'flex-start',
    marginBottom: 4,
  },
  ownerText: {
    fontFamily: 'Inter_500Medium',
    fontSize: 10,
    color: COLORS.textSecondary,
  },
  name: {
    fontFamily: 'Inter_400Regular',
    fontSize: 12,
    color: COLORS.textTertiary,
    marginBottom: 4,
  },
  detail: {
    fontFamily: 'JetBrainsMono_500Medium',
    fontSize: 10,
    color: COLORS.textMuted,
  },
  right: {
    alignItems: 'flex-end',
  },
  price: {
    fontFamily: 'JetBrainsMono_700Bold',
    fontSize: 16,
    color: COLORS.textPrimary,
    marginBottom: 4,
  },
  change: {
    fontFamily: 'Inter_500Medium',
    fontSize: 12,
    marginBottom: 4,
  },
  valueKRW: {
    fontFamily: 'JetBrainsMono_500Medium',
    fontSize: 10,
    color: COLORS.textTertiary,
  },
});
