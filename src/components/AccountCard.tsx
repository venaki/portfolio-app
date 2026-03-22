import { View, Text, StyleSheet } from 'react-native';
import { COLORS, OWNER_COLORS, NEGATIVE_COLOR } from '../constants';
import { formatKRW, formatUSD, formatPercent } from '../utils/format';
import { useResponsive } from '../hooks/useResponsive';

interface Props {
  owner: string;
  valueKRW: number;
  valueUSD: number;
  profitKRW: number;
  profitPctKRW: number;
  accentColor: string;
}

export function AccountCard({
  owner,
  valueKRW,
  valueUSD,
  profitKRW,
  profitPctKRW,
  accentColor,
}: Props) {
  const { isPC } = useResponsive();
  const dotColor = OWNER_COLORS[owner] ?? accentColor;
  const isPositive = profitKRW >= 0;
  const profitColor = isPositive ? accentColor : NEGATIVE_COLOR;

  return (
    <View style={[styles.card, isPC && styles.cardPC]}>
      {/* Top row: dot + owner name | profit percent */}
      <View style={styles.topRow}>
        <View style={styles.ownerRow}>
          <View style={[styles.dot, { backgroundColor: dotColor }]} />
          <Text style={styles.ownerName}>{owner}</Text>
        </View>
        <Text style={[styles.profitPct, { color: profitColor }]}>
          {formatPercent(profitPctKRW)}
        </Text>
      </View>

      {/* Bottom row: KRW value | USD value */}
      <View style={styles.bottomRow}>
        <Text style={[styles.krwValue, isPC && styles.krwValuePC]}>
          {formatKRW(valueKRW)}
        </Text>
        <Text style={styles.usdValue}>{formatUSD(valueUSD)}</Text>
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
    fontFamily: 'Newsreader_500Medium',
    fontSize: 18,
    color: COLORS.textPrimary,
  },
  profitPct: {
    fontFamily: 'JetBrainsMono_500Medium',
    fontSize: 13,
  },
  bottomRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'baseline',
  },
  krwValue: {
    fontFamily: 'JetBrainsMono_700Bold',
    fontSize: 18,
    color: COLORS.textPrimary,
  },
  krwValuePC: {
    fontSize: 22,
  },
  usdValue: {
    fontFamily: 'JetBrainsMono_500Medium',
    fontSize: 13,
    color: COLORS.textSecondary,
  },
});
