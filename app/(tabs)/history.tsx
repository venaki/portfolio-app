import { useState, useMemo, useEffect } from 'react';
import { View, Text, ScrollView, TextInput, TouchableOpacity, Pressable, Alert, RefreshControl, StyleSheet } from 'react-native';
import { useApp } from '../../src/context/AppContext';
import { useResponsive } from '../../src/hooks/useResponsive';
import { formatKRW, formatUSD, formatDate } from '../../src/utils/format';
import { COLORS, ASSET_CLASS_OPTIONS, ASSET_CLASS_LABELS, TRANSACTION_TYPE_LABELS } from '../../src/constants';
import { FilterTabs } from '../../src/components/FilterTabs';
import { FilterChips } from '../../src/components/FilterChips';
import { TransactionCard } from '../../src/components/TransactionCard';
import { AddTransactionModal } from '../../src/components/AddTransactionModal';
import { replayTransactions } from '../../src/engine/holdings';
import { Transaction, Owner, Holding } from '../../src/types';
import { BaseModal } from '../../src/components/BaseModal';
import { MODAL, PAGE } from '../../src/styles/shared';

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
  const { transactions, settings, market, deleteTransaction, updateTransaction, accounts } = useApp();
  const OWNER_OPTIONS = ['전체', ...accounts];
  const { isMobile } = useResponsive();

  const [selectedType, setSelectedType] = useState<TypeFilter>('전체');
  const [selectedOwner, setSelectedOwner] = useState<string>('전체');
  const [selectedAssetClass, setSelectedAssetClass] = useState<string>('전체');
  const [showModal, setShowModal] = useState(false);
  const [editTx, setEditTx] = useState<Transaction | null>(null);

  // Edit form state
  const [editForm, setEditForm] = useState({
    ticker: '', type: 'buy', owner: '', shares: '', price: '', rate: '', date: '', memo: '',
  });
  const updateField = (field: string, value: string) => setEditForm(prev => ({ ...prev, [field]: value }));

  // Populate form when editTx changes
  useEffect(() => {
    if (editTx) {
      setEditForm({
        ticker: editTx.ticker,
        type: editTx.type,
        owner: editTx.owner,
        shares: String(editTx.shares),
        price: String(editTx.price),
        rate: String(editTx.exchangeRate),
        date: formatDate(editTx.executedAt),
        memo: editTx.memo ?? '',
      });
    }
  }, [editTx]);

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

  const handleSaveTx = async () => {
    if (!editTx) return;
    const shares = parseFloat(editForm.shares);
    const price = parseFloat(editForm.price);
    const rate = parseFloat(editForm.rate);
    if (isNaN(shares) || isNaN(price) || isNaN(rate)) {
      Alert.alert('입력 오류', '수량, 가격, 환율을 올바르게 입력해주세요.');
      return;
    }
    await updateTransaction(editTx.id, {
      ticker: editForm.ticker.trim(),
      type: editForm.type as any,
      owner: editForm.owner as any,
      shares,
      price,
      exchangeRate: rate,
      executedAt: editForm.date ? `${editForm.date}T00:00:00.000Z` : editTx.executedAt,
      memo: editForm.memo.trim() || undefined,
    });
    setEditTx(null);
  };

  const handleDeleteTx = () => {
    if (!editTx) return;
    if (typeof window !== 'undefined' && window.confirm) {
      if (window.confirm('이 거래를 삭제하시겠습니까?')) {
        deleteTransaction(editTx.id);
        setEditTx(null);
      }
    } else {
      Alert.alert('삭제 확인', '이 거래를 삭제하시겠습니까?', [
        { text: '취소', style: 'cancel' },
        {
          text: '삭제', style: 'destructive',
          onPress: () => { deleteTransaction(editTx.id); setEditTx(null); },
        },
      ]);
    }
  };

  return (
    <View style={styles.container}>
      {/* Header */}
      <View style={[styles.header, isMobile ? styles.headerMobile : styles.headerPC]}>
        <Text style={PAGE.title}>거래내역</Text>
        <TouchableOpacity
          style={[styles.addBtn, { backgroundColor: settings.accentColor }]}
          onPress={() => setShowModal(true)}
          activeOpacity={0.8}
        >
          <Text style={PAGE.addBtnText}>추가</Text>
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
          <View style={PAGE.emptyContainer}>
            <Text style={PAGE.emptyText}>거래내역이 없습니다</Text>
          </View>
        ) : (
          groups.map((group) => (
            <View key={group.label}>
              <Text style={styles.monthLabel}>{group.label}</Text>
              <View style={styles.groupCards}>
                {group.transactions.map((tx) => (
                  <Pressable key={tx.id} onPress={() => setEditTx(tx)}>
                    <TransactionCard
                      transaction={tx}
                      accentColor={settings.accentColor}
                      holdingBeforeSell={holdingBeforeSellMap.get(tx.id)}
                      stockName={market.quotes[tx.ticker]?.name}
                    />
                  </Pressable>
                ))}
              </View>
            </View>
          ))
        )}
      </ScrollView>

      <AddTransactionModal visible={showModal} onClose={() => setShowModal(false)} />

      {/* Edit/Detail Modal */}
      <BaseModal visible={!!editTx} onClose={() => setEditTx(null)} cardStyle={!isMobile ? styles.modalContentPC : undefined}>
            <View style={MODAL.header}>
              <Text style={MODAL.title}>거래 편집</Text>
              <Pressable onPress={() => setEditTx(null)} hitSlop={8}>
                <Text style={MODAL.closeX}>✕</Text>
              </Pressable>
            </View>

            {editTx && (
              <ScrollView style={isMobile ? { maxHeight: 400 } : undefined} showsVerticalScrollIndicator={true} scrollEnabled={isMobile}>
                <View style={{ gap: 12 }}>
                  <View>
                    <Text style={MODAL.fieldLabel}>종목코드</Text>
                    <TextInput style={MODAL.input} value={editForm.ticker} onChangeText={(v) => updateField('ticker', v)} />
                  </View>

                  <View>
                    <Text style={MODAL.fieldLabel}>거래유형</Text>
                    <FilterTabs
                      options={['매수', '매도']}
                      selected={TRANSACTION_TYPE_LABELS[editForm.type] ?? editForm.type}
                      onSelect={(v) => {
                        const reverse: Record<string, string> = { '매수': 'buy', '매도': 'sell' };
                        updateField('type', reverse[v] ?? v);
                      }}
                    />
                  </View>

                  <View>
                    <Text style={MODAL.fieldLabel}>명의</Text>
                    <FilterTabs
                      options={accounts}
                      selected={editForm.owner}
                      onSelect={(v) => updateField('owner', v)}
                    />
                  </View>

                  <View>
                    <Text style={MODAL.fieldLabel}>수량</Text>
                    <TextInput style={MODAL.input} value={editForm.shares} onChangeText={(v) => updateField('shares', v)} keyboardType="numeric" />
                  </View>

                  <View>
                    <Text style={MODAL.fieldLabel}>가격 ({editTx.currency})</Text>
                    <TextInput style={MODAL.input} value={editForm.price} onChangeText={(v) => updateField('price', v)} keyboardType="numeric" />
                  </View>

                  {editTx.currency === 'USD' && (
                    <View>
                      <Text style={MODAL.fieldLabel}>환율 (KRW/USD)</Text>
                      <TextInput style={MODAL.input} value={editForm.rate} onChangeText={(v) => updateField('rate', v)} keyboardType="numeric" />
                    </View>
                  )}

                  <View>
                    <Text style={MODAL.fieldLabel}>날짜 (YYYY-MM-DD)</Text>
                    <TextInput style={MODAL.input} value={editForm.date} onChangeText={(v) => updateField('date', v)} />
                  </View>

                  <View>
                    <Text style={MODAL.fieldLabel}>메모</Text>
                    <TextInput style={MODAL.input} value={editForm.memo} onChangeText={(v) => updateField('memo', v)} placeholder="선택" placeholderTextColor={COLORS.textMuted} />
                  </View>
                </View>
              </ScrollView>
            )}

            <View style={[MODAL.buttons, { marginTop: 16 }]}>
              <Pressable style={[MODAL.btnPrimary, { backgroundColor: '#E07B54' }]} onPress={handleDeleteTx}>
                <Text style={MODAL.btnPrimaryText}>삭제</Text>
              </Pressable>
              <Pressable style={[MODAL.btnSecondary, { backgroundColor: settings.accentColor, borderWidth: 0 }]} onPress={handleSaveTx}>
                <Text style={[MODAL.btnSecondaryText, { color: COLORS.white, fontWeight: '600' }]}>저장</Text>
              </Pressable>
            </View>
      </BaseModal>
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
  addBtn: {
    paddingHorizontal: 14,
    paddingVertical: 7,
    borderRadius: 8,
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
    fontWeight: '500',
    fontVariant: ['tabular-nums'],
    fontSize: 11,
    color: '#888888',
    marginBottom: 8,
  },
  groupCards: {
    gap: 8,
  },
  modalContentPC: { width: 560, maxWidth: 560 },
});
