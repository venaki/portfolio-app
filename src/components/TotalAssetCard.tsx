import { useState } from 'react';
import { View, Text, Pressable, StyleSheet } from 'react-native';
import { COLORS, NEGATIVE_COLOR, POSITIVE_COLOR } from '../constants';
import { formatKRW, formatUSD, formatPercent } from '../utils/format';
import { useResponsive } from '../hooks/useResponsive';

interface Props {
  totalValueKRW: number;
  totalValueUSD: number;
  totalCostKRW: number;
  totalProfitKRW: number;
  totalProfitPctKRW: number;
  dailyChangeKRW: number;
  dailyChangePct: number;
  accentColor: string;
}

export function TotalAssetCard({
  totalValueKRW,
  totalValueUSD,
  totalCostKRW,
  totalProfitKRW,
  totalProfitPctKRW,
  dailyChangeKRW,
  dailyChangePct,
  accentColor,
}: Props) {
  const { isPC } = useResponsive();
  const [expanded, setExpanded] = useState(false);

  // Daily change colors
  const dailyPositive = dailyChangeKRW >= 0;
  const dailyColor = dailyPositive ? POSITIVE_COLOR : NEGATIVE_COLOR;
  const dailyBg = dailyPositive ? '#E8F5E9' : '#FFF0EB';
  const dailySign = dailyPositive ? '+' : '';

  // Total profit colors (for expanded section)
  const profitPositive = totalProfitKRW >= 0;
  const profitColor = profitPositive ? POSITIVE_COLOR : NEGATIVE_COLOR;

  // Today's date
  const today = new Date();
  const dateStr = `${today.getFullYear()}년 ${today.getMonth() + 1}월 ${today.getDate()}일`;

  return (
    <View style={[styles.card, isPC && styles.cardPC]}>
      {/* Date */}
      <Text style={styles.dateText}>{dateStr}</Text>

      <View style={styles.mainRow}>
        <View style={styles.left}>
          <Text style={styles.label}>TOTAL ASSETS</Text>
          <Text style={[styles.totalValue, isPC && styles.totalValuePC]}>
            {formatKRW(totalValueKRW)}
          </Text>

          {/* Daily change (always visible) */}
          <View style={styles.badgeRow}>
            <View style={[styles.badge, { backgroundColor: dailyBg }]}>
              <Text style={[styles.badgeText, { color: dailyColor }]}>
                {dailySign}{formatKRW(dailyChangeKRW)}
              </Text>
            </View>
            <View style={[styles.badge, { backgroundColor: dailyBg, marginLeft: 6 }]}>
              <Text style={[styles.badgeText, { color: dailyColor }]}>
                {formatPercent(dailyChangePct)}
              </Text>
            </View>
            <Text style={styles.dailyLabel}>오늘</Text>
          </View>
        </View>

        {/* PC: USD always visible on right */}
        {isPC && (
          <View style={styles.right}>
            <Text style={styles.rightLabel}>USD</Text>
            <Text style={styles.rightValue}>{formatUSD(totalValueUSD)}</Text>
          </View>
        )}
      </View>

      {/* Expanded section */}
      {expanded && (
        <View style={styles.expandedSection}>
          <View style={styles.expandedRow}>
            {/* 왼쪽: 수익금/수익률 배지 */}
            <View style={styles.badgeRow}>
              <View style={[styles.badge, { backgroundColor: profitPositive ? '#E8F5E9' : '#FFF0EB' }]}>
                <Text style={[styles.badgeText, { color: profitColor }]}>
                  {profitPositive ? '+' : ''}{formatKRW(totalProfitKRW)}
                </Text>
              </View>
              <View style={[styles.badge, { backgroundColor: profitPositive ? '#E8F5E9' : '#FFF0EB', marginLeft: 6 }]}>
                <Text style={[styles.badgeText, { color: profitColor }]}>
                  {formatPercent(totalProfitPctKRW)}
                </Text>
              </View>
              <Text style={styles.dailyLabel}>원금 대비</Text>
            </View>

            {/* 오른쪽: 원금 + USD */}
            <View style={styles.expandedRight}>
              <View style={styles.rightItem}>
                <Text style={styles.rightLabel}>원금</Text>
                <Text style={styles.rightValue}>{formatKRW(totalCostKRW)}</Text>
              </View>
              {!isPC && (
                <View style={[styles.rightItem, { marginTop: 8 }]}>
                  <Text style={styles.rightLabel}>USD</Text>
                  <Text style={styles.rightValue}>{formatUSD(totalValueUSD)}</Text>
                </View>
              )}
            </View>
          </View>
        </View>
      )}

      {/* More/Less toggle */}
      <Pressable onPress={() => setExpanded(!expanded)} style={styles.toggleButton}>
        <Text style={[styles.toggleText, { color: accentColor }]}>
          {expanded ? '접기' : '더보기'}
        </Text>
      </Pressable>
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
  dateText: {
    fontWeight: '500',
    fontSize: 11,
    color: COLORS.textMuted,
    marginBottom: 12,
    fontVariant: ['tabular-nums'],
  },
  mainRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'flex-start',
  },
  left: {
    flex: 1,
  },
  label: {
    fontWeight: '600',
    fontSize: 11,
    color: COLORS.textTertiary,
    letterSpacing: 2,
    marginBottom: 8,
  },
  totalValue: {
    fontWeight: '700',
    fontSize: 32,
    color: COLORS.textPrimary,
    marginBottom: 10,
    fontVariant: ['tabular-nums'],
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
    fontWeight: '600',
    fontSize: 13,
    fontVariant: ['tabular-nums'],
  },
  dailyLabel: {
    fontSize: 11,
    color: COLORS.textMuted,
    marginLeft: 8,
  },
  right: {
    alignItems: 'flex-end',
    paddingLeft: 16,
  },
  rightLabel: {
    fontWeight: '600',
    fontSize: 11,
    color: COLORS.textTertiary,
    letterSpacing: 1.5,
    marginBottom: 2,
    textAlign: 'right',
    fontVariant: ['tabular-nums'],
  },
  rightValue: {
    fontWeight: '500',
    fontSize: 15,
    color: COLORS.textSecondary,
    fontVariant: ['tabular-nums'],
  },
  expandedSection: {
    marginTop: 16,
    paddingTop: 16,
    borderTopWidth: 1,
    borderTopColor: COLORS.divider,
  },
  expandedRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  expandedRight: {
    alignItems: 'flex-end',
  },
  toggleButton: {
    marginTop: 12,
    alignItems: 'center',
    paddingVertical: 4,
  },
  toggleText: {
    fontWeight: '500',
    fontSize: 12,
  },
});
