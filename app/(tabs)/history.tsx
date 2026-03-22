import { useState, useMemo } from 'react';
import { View, Text, ScrollView, TouchableOpacity, RefreshControl, StyleSheet } from 'react-native';
import { useApp } from '../../src/context/AppContext';
import { useResponsive } from '../../src/hooks/useResponsive';
import { COLORS, ASSET_CLASS_OPTIONS, ASSET_CLASS_LABELS } from '../../src/constants';
import { FilterTabs } from '../../src/components/FilterTabs';
import { FilterChips } from '../../src/components/FilterChips';
import { TransactionCard } from '../../src/components/TransactionCard';
import { AddTransactionModal } from '../../src/components/AddTransactionModal';
import { replayTransactions } from '../../src/engine/holdings';
import { Transaction, Owner, Holding } from '../../src/types';

const OWNER_OPTIONS = ['전체', '본석', '연지', '나은'];

const TYPE_CHIP_OPTIONS = [
  { label: '전체', value: '전체' },
  { label: '매수', value: '매수' },
  { label: '매도', value: '매도' },
];

type TypeFilter = '전체' | '매수' | '매도';

function matchesTypeFilter(tx: Transaction, filter: TypeFilter): boolean {
  if (filter === '전체') return true;
  if (filter === '매수') return tx.type === 'buy' || tx.type === 'opening_balance' || tx.type === 'adjustment';
  if (filter === '매도') return tx.type === 'sell';
  return true;
}

function getMonthLabel(executedAt: string): string {
  const date = new Date(executedAt);
  return `${date.getFullYear()}년 ${date.getMonth() + 1}월`;
}

interface MonthGroup {
  label: string;
  transactions: Transaction[];
}

function groupByMonth(transactions: Transaction[]): MonthGroup[] {
  const groups: MonthGroup[] = [];
  const seen = new Map<string, MonthGroup>();

  for (const tx of transactions) {
    const label = getMonthLabel(tx.executedAt);
    if (!seen.has(label)) {
      const group: MonthGroup = { label, transactions: [] };
      seen.set(label, group);
      groups.push(group);
    }
    seen.get(label)!.transactions.push(tx);
  }

  return groups;
}

export default function History() {
  const { transactions, settings, market } = useApp();
  const { isMobile } = useResponsive();

  const [selectedType, setSelectedType] = useState<TypeFilter>('전체');
  const [selectedOwner, setSelectedOwner] = useState<string>('전체');
  const [selectedAssetClass, setSelectedAssetClass] = useState<string>('전체');
  const [showModal, setShowModal] = useState(false);

  // Sort all transactions newest-first (used as reference for replay)
  const sortedDesc = useMemo(
    () => [...transactions].sort(
      (a, b) => new Date(b.executedAt).getTime() - new Date(a.executedAt).getTime()
    ),
    [transactions]
  );

  // For each sell tx, pre-compute the holding state just before that sell
  const holdingBeforeSellMap = useMemo(() => {
    const map = new Map<string, Holding>();
    // Sort ascending for replay
    const sortedAsc = [...transactions].sort(
      (a, b) => new Date(a.executedAt).getTime() - new Date(b.executedAt).getTime()
    );

    for (let i = 0; i < sortedAsc.length; i++) {
      const tx = sortedAsc[i];
      if (tx.type === 'sell') {
        // Replay all transactions up to (not including) this sell
        const priorTxs = sortedAsc.slice(0, i);
        const holdings = replayTransactions(priorTxs);
        const holding = holdings.find(
          (h) => h.owner === tx.owner && h.ticker === tx.ticker
        );
        if (holding) {
          map.set(tx.id, holding);
        }
      }
    }
    return map;
  }, [transactions]);

  const filtered = useMemo(() => {
    return sortedDesc.filter((tx) => {
      if (!matchesTypeFilter(tx, selectedType)) return false;
      if (selectedOwner !== '전체' && tx.owner !== (selectedOwner as Owner)) return false;
      // Asset class filter
      const acFilter = ASSET_CLASS_LABELS[selectedAssetClass];
      if (acFilter !== 'all' && tx.assetClass !== acFilter) return false;
      return true;
    });
  }, [sortedDesc, selectedType, selectedOwner, selectedAssetClass]);

  const groups = useMemo(() => groupByMonth(filtered), [filtered]);

  return (
    <View style={styles.container}>
      {/* Header */}
      <View style={[styles.header, isMobile ? styles.headerMobile : styles.headerPC]}>
        <Text style={styles.title}>거래내역</Text>
        <TouchableOpacity
          style={[styles.addBtn, { backgroundColor: '#16A34A' }]}
          onPress={() => setShowModal(true)}
          activeOpacity={0.8}
        >
          <Text style={styles.addBtnText}>기록</Text>
        </TouchableOpacity>
      </View>

      {/* Asset class filter */}
      <View style={styles.filterTabsWrapper}>
        <FilterTabs
          options={ASSET_CLASS_OPTIONS}
          selected={selectedAssetClass}
          onSelect={setSelectedAssetClass}
        />
      </View>

      {/* Owner filter */}
      <View style={styles.filterTabsWrapper}>
        <FilterTabs
          options={OWNER_OPTIONS}
          selected={selectedOwner}
          onSelect={setSelectedOwner}
        />
      </View>

      {/* Type filter chips */}
      <View style={styles.filterChipsWrapper}>
        <FilterChips
          options={TYPE_CHIP_OPTIONS}
          selected={selectedType}
          onSelect={(v) => setSelectedType(v as TypeFilter)}
          accentColor={settings.accentColor}
        />
      </View>

      {/* Grouped transaction list */}
      <ScrollView
        style={styles.scrollView}
        contentContainerStyle={[
          styles.listContent,
          isMobile && styles.listContentMobile,
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
        {groups.length === 0 ? (
          <View style={styles.emptyContainer}>
            <Text style={styles.emptyText}>거래내역이 없습니다</Text>
          </View>
        ) : (
          groups.map((group) => (
            <View key={group.label}>
              <Text style={styles.monthLabel}>{group.label}</Text>
              <View style={styles.groupCards}>
                {group.transactions.map((tx) => (
                  <TransactionCard
                    key={tx.id}
                    transaction={tx}
                    accentColor={settings.accentColor}
                    holdingBeforeSell={holdingBeforeSellMap.get(tx.id)}
                  />
                ))}
              </View>
            </View>
          ))
        )}
      </ScrollView>

      <AddTransactionModal visible={showModal} onClose={() => setShowModal(false)} />
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: COLORS.background,
  },
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  headerMobile: {
    paddingHorizontal: 16,
    paddingTop: 20,
    paddingBottom: 12,
  },
  headerPC: {
    paddingHorizontal: 24,
    paddingTop: 24,
    paddingBottom: 16,
  },
  title: {
    fontFamily: 'Newsreader_500Medium',
    fontSize: 22,
    color: COLORS.textPrimary,
  },
  addBtn: {
    paddingHorizontal: 14,
    paddingVertical: 7,
    borderRadius: 8,
  },
  addBtnText: {
    fontFamily: 'Inter_600SemiBold',
    fontSize: 13,
    color: '#FFFFFF',
  },
  filterTabsWrapper: {
    paddingHorizontal: 16,
    marginBottom: 8,
  },
  filterChipsWrapper: {
    marginBottom: 12,
  },
  scrollView: {
    flex: 1,
  },
  listContent: {
    paddingHorizontal: 16,
    gap: 16,
  },
  listContentMobile: {
    paddingBottom: 100,
  },
  monthLabel: {
    fontFamily: 'JetBrainsMono_500Medium',
    fontSize: 11,
    color: '#888888',
    marginBottom: 8,
  },
  groupCards: {
    gap: 8,
  },
  emptyContainer: {
    paddingVertical: 48,
    alignItems: 'center',
  },
  emptyText: {
    fontFamily: 'Inter_400Regular',
    fontSize: 14,
    color: COLORS.textTertiary,
  },
});
