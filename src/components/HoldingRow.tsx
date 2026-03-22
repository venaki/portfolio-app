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

export function HoldingRow({ holding, quote, exchangeRate, accentColor }: Props) {
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

  const dailyPositive = dailyChangePct >= 0;
  const dailyColor = dailyPositive ? POSITIVE_COLOR : NEGATIVE_COLOR;
  const profitPositive = profitPct >= 0;
  const profitColor = profitPositive ? POSITIVE_COLOR : NEGATIVE_COLOR;

  const formatPrice = isKRW ? formatKRW : formatUSD;

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
        {!isCash && quote?.name && (
          <Text style={styles.tickerName} numberOfLines={1}>{quote.name}</Text>
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
