import { View, Text, StyleSheet } from 'react-native';
import { COLORS, NEGATIVE_COLOR } from '../constants';
import { formatKRW, formatUSD, formatPercent } from '../utils/format';
import { useResponsive } from '../hooks/useResponsive';

interface Props {
  totalValueKRW: number;
  totalValueUSD: number;
  totalCostKRW: number;
  totalProfitKRW: number;
  totalProfitPctKRW: number;
  accentColor: string;
}

export function TotalAssetCard({
  totalValueKRW,
  totalValueUSD,
  totalCostKRW,
  totalProfitKRW,
  totalProfitPctKRW,
  accentColor,
}: Props) {
  const { isPC } = useResponsive();
  const isPositive = totalProfitKRW >= 0;
  const profitColor = isPositive ? accentColor : NEGATIVE_COLOR;
  const badgeBg = isPositive ? '#E8F5E9' : '#FFF0EB';
  const profitSign = isPositive ? '+' : '';

  return (
    <View style={[styles.card, isPC && styles.cardPC]}>
      <View style={styles.row}>
        {/* Left */}
        <View style={styles.left}>
          <Text style={styles.label}>TOTAL ASSETS</Text>
          <Text style={[styles.totalValue, isPC && styles.totalValuePC]}>
            {formatKRW(totalValueKRW)}
          </Text>
          <View style={styles.badgeRow}>
            <View style={[styles.badge, { backgroundColor: badgeBg }]}>
              <Text style={[styles.badgeText, { color: profitColor }]}>
                {profitSign}{formatKRW(totalProfitKRW)}
              </Text>
            </View>
            <View style={[styles.badge, { backgroundColor: badgeBg, marginLeft: 6 }]}>
              <Text style={[styles.badgeText, { color: profitColor }]}>
                {formatPercent(totalProfitPctKRW)}
              </Text>
            </View>
          </View>
        </View>

        {/* PC: Right side shows USD + 원금 */}
        {isPC && (
          <View style={styles.right}>
            <View style={styles.rightItem}>
              <Text style={styles.rightLabel}>USD</Text>
              <Text style={styles.rightValue}>{formatUSD(totalValueUSD)}</Text>
            </View>
            <View style={[styles.rightItem, { marginTop: 12 }]}>
              <Text style={styles.rightLabel}>원금</Text>
              <Text style={styles.rightValue}>{formatKRW(totalCostKRW)}</Text>
            </View>
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
    padding: 20,
    marginHorizontal: 16,
    marginTop: 12,
  },
  cardPC: {
    marginHorizontal: 0,
  },
  row: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'flex-start',
  },
  left: {
    flex: 1,
  },
  label: {
    fontFamily: 'JetBrainsMono_600SemiBold',
    fontSize: 11,
    color: COLORS.textTertiary,
    letterSpacing: 2,
    marginBottom: 8,
  },
  totalValue: {
    fontFamily: 'JetBrainsMono_700Bold',
    fontSize: 32,
    color: COLORS.textPrimary,
    marginBottom: 10,
  },
  totalValuePC: {
    fontSize: 36,
  },
  badgeRow: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  badge: {
    borderRadius: 6,
    paddingHorizontal: 8,
    paddingVertical: 3,
  },
  badgeText: {
    fontFamily: 'JetBrainsMono_600SemiBold',
    fontSize: 13,
  },
  right: {
    alignItems: 'flex-end',
    paddingLeft: 16,
  },
  rightItem: {
    alignItems: 'flex-end',
  },
  rightLabel: {
    fontFamily: 'JetBrainsMono_600SemiBold',
    fontSize: 11,
    color: COLORS.textTertiary,
    letterSpacing: 1.5,
    marginBottom: 2,
  },
  rightValue: {
    fontFamily: 'JetBrainsMono_500Medium',
    fontSize: 15,
    color: COLORS.textSecondary,
  },
});
