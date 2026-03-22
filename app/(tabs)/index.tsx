import { View, Text, ScrollView, TouchableOpacity, ActivityIndicator, StyleSheet } from 'react-native';
import { useApp } from '../../src/context/AppContext';
import { useResponsive } from '../../src/hooks/useResponsive';
import { calcTotalValueKRW, calcCostKRW, calcDailyChangeKRW } from '../../src/engine/calculations';
import { formatKRW, formatUSD, formatRelativeTime } from '../../src/utils/format';
import { COLORS } from '../../src/constants';
import { TotalAssetCard } from '../../src/components/TotalAssetCard';
import { AccountCard } from '../../src/components/AccountCard';

const OWNERS = ['본석', '연지', '나은'];

export default function Dashboard() {
  const { holdings, settings, market, isLoading } = useApp();
  const { isMobile, isPC } = useResponsive();

  // Aggregate totals
  let totalValueKRW = 0;
  let totalCostKRW = 0;
  let totalValueUSD = 0;

  holdings.forEach(h => {
    const quote = market.quotes[h.ticker];
    if (!quote) return;
    totalValueKRW += calcTotalValueKRW(h, quote.price, market.exchangeRate);
    totalCostKRW += calcCostKRW(h);
    totalValueUSD += quote.price * h.shares;
  });

  const totalProfitKRW = totalValueKRW - totalCostKRW;
  const totalProfitPctKRW = totalCostKRW > 0 ? (totalProfitKRW / totalCostKRW) * 100 : 0;

  // Aggregate per owner
  const ownerData = OWNERS.map(owner => {
    const ownerHoldings = holdings.filter(h => h.owner === owner);
    let valueKRW = 0;
    let costKRW = 0;
    let valueUSD = 0;

    ownerHoldings.forEach(h => {
      const quote = market.quotes[h.ticker];
      if (!quote) return;
      valueKRW += calcTotalValueKRW(h, quote.price, market.exchangeRate);
      costKRW += calcCostKRW(h);
      valueUSD += quote.price * h.shares;
    });

    const profitKRW = valueKRW - costKRW;
    const profitPctKRW = costKRW > 0 ? (profitKRW / costKRW) * 100 : 0;

    return { owner, valueKRW, valueUSD, profitKRW, profitPctKRW };
  });

  const exchangeRateText = market.exchangeRate > 0
    ? `1 USD = ${formatKRW(market.exchangeRate)}`
    : '환율 불러오는 중...';

  const lastUpdatedText = market.lastUpdated
    ? formatRelativeTime(market.lastUpdated)
    : '-';

  return (
    <ScrollView
      style={styles.container}
      contentContainerStyle={[
        styles.content,
        isPC && styles.contentPC,
        isMobile && styles.contentMobile,
      ]}
      showsVerticalScrollIndicator={false}
    >
      {/* Header */}
      <View style={[styles.header, isPC && styles.headerPC]}>
        <Text style={styles.headerTitle}>자산 현황</Text>
        <TouchableOpacity
          onPress={market.refresh}
          disabled={market.isLoading}
          style={styles.refreshButton}
          hitSlop={{ top: 8, bottom: 8, left: 8, right: 8 }}
        >
          {market.isLoading ? (
            <ActivityIndicator size="small" color={settings.accentColor} />
          ) : (
            <Text style={[styles.refreshIcon, { color: settings.accentColor }]}>↻</Text>
          )}
        </TouchableOpacity>
      </View>

      {/* Total Asset Card */}
      <TotalAssetCard
        totalValueKRW={totalValueKRW}
        totalValueUSD={totalValueUSD}
        totalCostKRW={totalCostKRW}
        totalProfitKRW={totalProfitKRW}
        totalProfitPctKRW={totalProfitPctKRW}
        accentColor={settings.accentColor}
      />

      {/* Meta row: exchange rate + last update */}
      <View style={[styles.metaRow, isPC && styles.metaRowPC]}>
        <Text style={styles.metaText}>{exchangeRateText}</Text>
        {market.isStale && (
          <Text style={[styles.metaStale, { color: settings.accentColor }]}>● 업데이트 필요</Text>
        )}
        <Text style={styles.metaText}>{lastUpdatedText}</Text>
      </View>

      {/* BY ACCOUNT section */}
      <Text style={[styles.sectionLabel, isPC && styles.sectionLabelPC]}>BY ACCOUNT</Text>

      <View style={[styles.accountsContainer, isPC && styles.accountsContainerPC]}>
        {ownerData.map((data, idx) => (
          <View
            key={data.owner}
            style={[
              styles.accountCardWrapper,
              isPC && styles.accountCardWrapperPC,
              isPC && idx < ownerData.length - 1 && { marginRight: 12 },
              isMobile && idx < ownerData.length - 1 && { marginBottom: 10 },
            ]}
          >
            <AccountCard
              owner={data.owner}
              valueKRW={data.valueKRW}
              valueUSD={data.valueUSD}
              profitKRW={data.profitKRW}
              profitPctKRW={data.profitPctKRW}
              accentColor={settings.accentColor}
            />
          </View>
        ))}
      </View>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: COLORS.background,
  },
  content: {
    paddingBottom: 24,
  },
  contentPC: {
    paddingHorizontal: 24,
    paddingTop: 8,
  },
  contentMobile: {
    paddingBottom: 100,
  },
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingHorizontal: 16,
    paddingTop: 20,
    paddingBottom: 4,
  },
  headerPC: {
    paddingHorizontal: 0,
    paddingTop: 24,
  },
  headerTitle: {
    fontFamily: 'Newsreader_500Medium',
    fontSize: 22,
    color: COLORS.textPrimary,
  },
  refreshButton: {
    width: 32,
    height: 32,
    justifyContent: 'center',
    alignItems: 'center',
  },
  refreshIcon: {
    fontSize: 22,
    fontFamily: 'Inter_500Medium',
  },
  metaRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingHorizontal: 16,
    marginTop: 8,
  },
  metaRowPC: {
    paddingHorizontal: 0,
  },
  metaText: {
    fontFamily: 'JetBrainsMono_500Medium',
    fontSize: 12,
    color: COLORS.textMuted,
  },
  metaStale: {
    fontFamily: 'Inter_400Regular',
    fontSize: 11,
  },
  sectionLabel: {
    fontFamily: 'JetBrainsMono_600SemiBold',
    fontSize: 11,
    color: COLORS.textTertiary,
    letterSpacing: 2,
    paddingHorizontal: 16,
    marginTop: 24,
    marginBottom: 10,
  },
  sectionLabelPC: {
    paddingHorizontal: 0,
  },
  accountsContainer: {
    paddingHorizontal: 16,
    flexDirection: 'column',
  },
  accountsContainerPC: {
    paddingHorizontal: 0,
    flexDirection: 'row',
  },
  accountCardWrapper: {
    flex: 1,
  },
  accountCardWrapperPC: {
    flex: 1,
  },
});
