import { View, Text, StyleSheet } from 'react-native';
import { COLORS, POSITIVE_COLOR, NEGATIVE_COLOR } from '../constants';
import { CARD_BASE } from '../styles/shared';
import { formatKRW, formatUSD, formatPercent } from '../utils/format';
import { useResponsive } from '../hooks/useResponsive';

interface AssetBreakdown {
  label: string;
  valueKRW: number;
}

interface Props {
  owner: string;
  valueKRW: number;
  valueUSD: number;
  profitKRW: number;
  profitPctKRW: number;
  accentColor: string;
  dotColor?: string;
  breakdown?: AssetBreakdown[];
}

export function AccountCard({
  owner,
  valueKRW,
  valueUSD,
  profitKRW,
  profitPctKRW,
  accentColor,
  dotColor,
  breakdown,
}: Props) {
  const { isPC } = useResponsive();
  const resolvedDotColor = dotColor ?? accentColor;
  const isPositive = profitKRW >= 0;
  const profitColor = isPositive ? POSITIVE_COLOR : NEGATIVE_COLOR;

  return (
    <View style={[styles.card, isPC && styles.cardPC]}>
      {/* Top row: dot + owner name | profit percent */}
      <View style={styles.topRow}>
        <View style={styles.ownerRow}>
          <View style={[styles.dot, { backgroundColor: resolvedDotColor }]} />
          <Text style={styles.ownerName}>{owner}</Text>
        </View>
        <Text style={[styles.profitPct, { color: profitColor }]}>
          {formatPercent(profitPctKRW)}
        </Text>
      </View>

      {/* Value row: KRW | USD */}
      <View style={styles.bottomRow}>
        <Text style={[styles.krwValue, isPC && styles.krwValuePC]}>
          {formatKRW(valueKRW)}
        </Text>
        <Text style={styles.usdValue}>{formatUSD(valueUSD)}</Text>
      </View>

      {/* Breakdown: 미국/한국/기타 */}
      {breakdown && breakdown.length > 0 && (
        <View style={styles.breakdown}>
          {breakdown.map(item => (
            <View key={item.label} style={styles.breakdownRow}>
              <Text style={styles.breakdownLabel}>{item.label}</Text>
              <Text style={styles.breakdownValue}>{formatKRW(item.valueKRW)}</Text>
            </View>
          ))}
        </View>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  card: {
    ...CARD_BASE,
    flex: 1,
  },
  cardPC: {
    padding: 20,
  },
  topRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 10,
  },
  ownerRow: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  dot: {
    width: 8,
    height: 8,
    borderRadius: 4,
    marginRight: 7,
  },
  ownerName: {
    fontWeight: '500',
    fontSize: 18,
    color: COLORS.textPrimary,
  },
  profitPct: {
    fontWeight: '500',
    fontSize: 13,
    fontVariant: ['tabular-nums'],
  },
  bottomRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'baseline',
  },
  krwValue: {
    fontWeight: '700',
    fontSize: 18,
    color: COLORS.textPrimary,
    fontVariant: ['tabular-nums'],
  },
  krwValuePC: {
    fontSize: 22,
  },
  usdValue: {
    fontWeight: '500',
    fontSize: 13,
    color: COLORS.textSecondary,
    fontVariant: ['tabular-nums'],
  },
  breakdown: {
    marginTop: 12,
    paddingTop: 10,
    borderTopWidth: 1,
    borderTopColor: COLORS.divider,
    gap: 6,
  },
  breakdownRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  breakdownLabel: {
    fontWeight: '500',
    fontSize: 11,
    color: COLORS.textMuted,
    fontVariant: ['tabular-nums'],
  },
  breakdownValue: {
    fontWeight: '500',
    fontSize: 11,
    color: COLORS.textSecondary,
    fontVariant: ['tabular-nums'],
  },
});
