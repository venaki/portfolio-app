import { View, Text, StyleSheet } from 'react-native';
import { Transaction } from '../types';
import { Holding } from '../types';
import { calcRealizedPL } from '../engine/calculations';
import { formatKRW, formatUSD, formatDate } from '../utils/format';
import { COLORS, POSITIVE_COLOR } from '../constants';

interface TransactionCardProps {
  transaction: Transaction;
  accentColor: string;
  holdingBeforeSell?: Holding;
}

type BadgeConfig = {
  bg: string;
  color: string;
  label: string;
};

function getBadge(type: Transaction['type']): BadgeConfig {
  switch (type) {
    case 'buy':
    case 'opening_balance':
    case 'adjustment':
      return { bg: '#E8F5E9', color: POSITIVE_COLOR, label: '매수' };
    case 'sell':
      return { bg: '#FFF0EB', color: '#E07B54', label: '매도' };
  }
}

export function TransactionCard({ transaction: tx, accentColor, holdingBeforeSell }: TransactionCardProps) {
  const isCashAsset = tx.assetClass === 'cash';
  const cashType = isCashAsset && tx.memo ? tx.memo.split(' · ')[0] : '';
  const isLoan = cashType === '대출';

  // For cash assets, show asset type badge instead of buy/sell
  const badge = isCashAsset
    ? { bg: isLoan ? '#FFF0EB' : '#F0F0F0', color: isLoan ? '#E07B54' : '#888888', label: cashType || '기타' }
    : getBadge(tx.type);
  const isKRW = tx.currency === 'KRW';
  const isCash = tx.assetClass === 'cash';
  const formatPrice = isKRW ? formatKRW : formatUSD;

  const totalNative = tx.shares * tx.price;
  const totalKRW = isKRW ? totalNative : totalNative * tx.exchangeRate;

  let realizedPL: { usd: number; krw: number } | null = null;
  if (tx.type === 'sell' && holdingBeforeSell) {
    realizedPL = calcRealizedPL(
      tx.shares,
      tx.price,
      tx.exchangeRate,
      holdingBeforeSell.avgCost,
      holdingBeforeSell.avgExchangeRate,
    );
  }

  const plIsPositive = realizedPL ? realizedPL.usd >= 0 : true;
  const plColor = plIsPositive ? POSITIVE_COLOR : '#E07B54';
  const plSign = plIsPositive ? '+' : '';

  // Detail line differs by asset type
  let detailText: string;
  if (isCash) {
    detailText = `${formatPrice(tx.price)}`;
  } else if (isKRW) {
    detailText = `${tx.shares.toLocaleString('ko-KR')}주 × ${formatKRW(tx.price)}`;
  } else {
    detailText = `${tx.shares.toLocaleString('ko-KR')}주 × ${formatUSD(tx.price)} · ₩${Math.round(tx.exchangeRate).toLocaleString('ko-KR')}`;
  }

  return (
    <View style={styles.card}>
      {/* Left side */}
      <View style={styles.left}>
        {/* Top row: badge + ticker + owner */}
        <View style={styles.topRow}>
          <View style={[styles.badge, { backgroundColor: badge.bg }]}>
            <Text style={[styles.badgeText, { color: badge.color }]}>{badge.label}</Text>
          </View>
          <Text style={styles.ticker}>{tx.ticker}</Text>
          <View style={styles.ownerBadge}>
            <Text style={styles.ownerText}>{tx.owner}</Text>
          </View>
        </View>

        {/* Detail row */}
        <Text style={styles.detail}>{detailText}</Text>

        {/* Realized P&L for sells */}
        {realizedPL !== null && (
          <Text style={[styles.realizedPL, { color: plColor }]}>
            실현 {plSign}{formatUSD(realizedPL.usd)}
          </Text>
        )}

        {/* Date */}
        <Text style={styles.date}>{formatDate(tx.executedAt)}</Text>
      </View>

      {/* Right side */}
      <View style={styles.right}>
        {isKRW ? (
          <Text style={styles.amountUSD}>{formatKRW(totalKRW)}</Text>
        ) : (
          <>
            <Text style={styles.amountUSD}>{formatUSD(totalNative)}</Text>
            <Text style={styles.amountKRW}>{formatKRW(totalKRW)}</Text>
          </>
        )}
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  card: {
    backgroundColor: '#FFFFFF',
    borderRadius: 12,
    borderWidth: 1,
    borderColor: '#E5E5E5',
    padding: 16,
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'flex-start',
  },
  left: {
    flex: 1,
    gap: 4,
  },
  topRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
    flexWrap: 'wrap',
  },
  badge: {
    paddingHorizontal: 6,
    paddingVertical: 2,
    borderRadius: 4,
  },
  badgeText: {
    fontFamily: 'JetBrainsMono_500Medium',
    fontSize: 11,
  },
  ticker: {
    fontFamily: 'JetBrainsMono_700Bold',
    fontSize: 14,
    color: COLORS.textPrimary,
  },
  ownerBadge: {
    backgroundColor: '#F0F0F0',
    paddingHorizontal: 6,
    paddingVertical: 2,
    borderRadius: 4,
  },
  ownerText: {
    fontFamily: 'Inter_500Medium',
    fontSize: 11,
    color: '#888888',
  },
  detail: {
    fontFamily: 'JetBrainsMono_500Medium',
    fontSize: 11,
    color: '#888888',
  },
  realizedPL: {
    fontFamily: 'JetBrainsMono_500Medium',
    fontSize: 11,
  },
  date: {
    fontFamily: 'JetBrainsMono_500Medium',
    fontSize: 10,
    color: '#AAAAAA',
  },
  right: {
    alignItems: 'flex-end',
    gap: 2,
    marginLeft: 12,
  },
  amountUSD: {
    fontFamily: 'JetBrainsMono_700Bold',
    fontSize: 13,
    color: COLORS.textPrimary,
  },
  amountKRW: {
    fontFamily: 'JetBrainsMono_500Medium',
    fontSize: 11,
    color: '#888888',
  },
});
