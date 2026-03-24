import { View, Text, ScrollView, TouchableOpacity, ActivityIndicator, RefreshControl, StyleSheet } from 'react-native';
import { useApp } from '../../src/context/AppContext';
import { useResponsive } from '../../src/hooks/useResponsive';
import { calcTotalValueKRW, calcCostKRW, calcDailyChangeKRW } from '../../src/engine/calculations';
import { formatKRW, formatUSD, formatRelativeTime } from '../../src/utils/format';
import { COLORS, getAccountColor } from '../../src/constants';
import { PAGE, SECTION } from '../../src/styles/shared';
import { TotalAssetCard } from '../../src/components/TotalAssetCard';
import { AccountCard } from '../../src/components/AccountCard';

export default function Dashboard() {
  const { holdings, settings, market, isLoading, accounts } = useApp();
  const { isMobile, isPC } = useResponsive();

  // Aggregate totals
  let totalValueKRW = 0;
  let totalCostKRW = 0;
  let totalValueUSD = 0;
  let totalDailyChangeKRW = 0;
  let totalPrevValueKRW = 0;

  holdings.forEach(h => {
    const isCash = h.assetClass === 'cash';
    const quote = market.quotes[h.ticker];

    if (isCash) {
      // Cash: value = avgCost * shares, convert to KRW if USD
      const valueKRW = calcTotalValueKRW(h, 0, market.exchangeRate);
      totalValueKRW += valueKRW;
      totalCostKRW += calcCostKRW(h);
      totalPrevValueKRW += valueKRW; // No daily change for cash
      if (h.currency === 'USD') {
        totalValueUSD += h.avgCost * h.shares;
      }
      return;
    }

    if (!quote) return;
    totalValueKRW += calcTotalValueKRW(h, quote.price, market.exchangeRate);
    totalCostKRW += calcCostKRW(h);
    if (h.currency === 'USD') {
      totalValueUSD += quote.price * h.shares;
    }
    totalDailyChangeKRW += calcDailyChangeKRW(h, quote.price, quote.previousClose, market.exchangeRate);
    totalPrevValueKRW += calcTotalValueKRW(h, quote.previousClose, market.exchangeRate);
  });

  const totalProfitKRW = totalValueKRW - totalCostKRW;
  const totalProfitPctKRW = totalCostKRW > 0 ? (totalProfitKRW / totalCostKRW) * 100 : 0;
  const dailyChangePct = totalPrevValueKRW > 0 ? (totalDailyChangeKRW / totalPrevValueKRW) * 100 : 0;

  // Aggregate per owner with asset class breakdown
  const ownerData = accounts.map(owner => {
    const ownerHoldings = holdings.filter(h => h.owner === owner);
    let valueKRW = 0;
    let costKRW = 0;
    let valueUSD = 0;
    let usValueKRW = 0;
    let krValueKRW = 0;
    let cashValueKRW = 0;

    ownerHoldings.forEach(h => {
      const isCash = h.assetClass === 'cash';
      const quote = market.quotes[h.ticker];

      if (isCash) {
        const v = calcTotalValueKRW(h, 0, market.exchangeRate);
        valueKRW += v;
        costKRW += calcCostKRW(h);
        cashValueKRW += v;
        if (h.currency === 'USD') {
          valueUSD += h.avgCost * h.shares;
        }
        return;
      }

      if (!quote) return;
      const v = calcTotalValueKRW(h, quote.price, market.exchangeRate);
      valueKRW += v;
      costKRW += calcCostKRW(h);
      if (h.assetClass === 'us_stock') {
        usValueKRW += v;
        valueUSD += quote.price * h.shares;
      } else if (h.assetClass === 'kr_stock') {
        krValueKRW += v;
      }
    });

    const profitKRW = valueKRW - costKRW;
    const profitPctKRW = costKRW > 0 ? (profitKRW / costKRW) * 100 : 0;

    const breakdown = [
      { label: '미국', valueKRW: usValueKRW },
      { label: '한국', valueKRW: krValueKRW },
      { label: '기타', valueKRW: cashValueKRW },
    ].filter(b => b.valueKRW > 0);

    return { owner, valueKRW, valueUSD, profitKRW, profitPctKRW, breakdown };
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
      refreshControl={
        <RefreshControl
          refreshing={market.isLoading}
          onRefresh={market.refresh}
          tintColor={settings.accentColor}
        />
      }
    >
      {/* Header */}
      <View style={[styles.header, isPC && styles.headerPC]}>
        <Text style={PAGE.title}>자산 현황</Text>
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
        dailyChangeKRW={totalDailyChangeKRW}
        dailyChangePct={dailyChangePct}
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
      <Text style={[SECTION.label, styles.sectionLabelLocal, isPC && styles.sectionLabelPC]}>BY ACCOUNT</Text>

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
              dotColor={getAccountColor(idx)}
              breakdown={data.breakdown}
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
  refreshButton: {
    width: 32,
    height: 32,
    justifyContent: 'center',
    alignItems: 'center',
  },
  refreshIcon: {
    fontSize: 22,
    fontWeight: '500',
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
    fontWeight: '500',
    fontVariant: ['tabular-nums'],
    fontSize: 12,
    color: COLORS.textMuted,
  },
  metaStale: {
    fontSize: 11,
  },
  sectionLabelLocal: {
    paddingHorizontal: 16,
    marginTop: 24,
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
