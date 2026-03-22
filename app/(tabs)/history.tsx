import { useState, useMemo, useEffect } from 'react';
import { View, Text, ScrollView, TextInput, TouchableOpacity, Pressable, Modal, Alert, RefreshControl, StyleSheet } from 'react-native';
import { useApp } from '../../src/context/AppContext';
import { useResponsive } from '../../src/hooks/useResponsive';
import { formatKRW, formatUSD, formatDate } from '../../src/utils/format';
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

const TYPE_LABELS: Record<string, string> = {
  buy: '매수', sell: '매도', opening_balance: '최초잔고',
};
const ASSET_LABELS: Record<string, string> = {
  us_stock: '미국', kr_stock: '한국', cash: '기타',
};

export default function History() {
  const { transactions, settings, market, deleteTransaction, updateTransaction } = useApp();
  const { isMobile } = useResponsive();

  const [selectedType, setSelectedType] = useState<TypeFilter>('전체');
  const [selectedOwner, setSelectedOwner] = useState<string>('전체');
  const [selectedAssetClass, setSelectedAssetClass] = useState<string>('전체');
  const [showModal, setShowModal] = useState(false);
  const [editTx, setEditTx] = useState<Transaction | null>(null);

  // Edit form state
  const [editTicker, setEditTicker] = useState('');
  const [editType, setEditType] = useState('buy');
  const [editOwner, setEditOwner] = useState('본석');
  const [editShares, setEditShares] = useState('');
  const [editPrice, setEditPrice] = useState('');
  const [editRate, setEditRate] = useState('');
  const [editDate, setEditDate] = useState('');
  const [editMemo, setEditMemo] = useState('');

  // Populate form when editTx changes
  useEffect(() => {
    if (editTx) {
      setEditTicker(editTx.ticker);
      setEditType(editTx.type);
      setEditOwner(editTx.owner);
      setEditShares(String(editTx.shares));
      setEditPrice(String(editTx.price));
      setEditRate(String(editTx.exchangeRate));
      setEditDate(formatDate(editTx.executedAt));
      setEditMemo(editTx.memo ?? '');
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
    const shares = parseFloat(editShares);
    const price = parseFloat(editPrice);
    const rate = parseFloat(editRate);
    if (isNaN(shares) || isNaN(price) || isNaN(rate)) {
      Alert.alert('입력 오류', '수량, 가격, 환율을 올바르게 입력해주세요.');
      return;
    }
    await updateTransaction(editTx.id, {
      ticker: editTicker.trim(),
      type: editType as any,
      owner: editOwner as any,
      shares,
      price,
      exchangeRate: rate,
      executedAt: editDate ? `${editDate}T00:00:00.000Z` : editTx.executedAt,
      memo: editMemo.trim() || undefined,
    });
    setEditTx(null);
  };

  const handleDeleteTx = () => {
    if (!editTx) return;
    Alert.alert('삭제 확인', '이 거래를 삭제하시겠습니까?', [
      { text: '취소', style: 'cancel' },
      {
        text: '삭제', style: 'destructive',
        onPress: () => { deleteTransaction(editTx.id); setEditTx(null); },
      },
    ]);
  };

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
                  <Pressable key={tx.id} onPress={() => setEditTx(tx)}>
                    <TransactionCard
                      transaction={tx}
                      accentColor={settings.accentColor}
                      holdingBeforeSell={holdingBeforeSellMap.get(tx.id)}
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
      <Modal visible={!!editTx} transparent animationType="none">
        <Pressable style={styles.modalOverlay} onPress={() => setEditTx(null)}>
          <Pressable style={[styles.modalContent, !isMobile && styles.modalContentPC]} onPress={(e) => e.stopPropagation()}>
            <View style={styles.modalHeader}>
              <Text style={styles.modalTitle}>거래 편집</Text>
              <Pressable onPress={() => setEditTx(null)} hitSlop={8}>
                <Text style={styles.closeX}>✕</Text>
              </Pressable>
            </View>

            {editTx && (
              <ScrollView style={isMobile ? { maxHeight: 400 } : undefined} showsVerticalScrollIndicator={true} scrollEnabled={isMobile}>
                <View style={{ gap: 12 }}>
                  <View>
                    <Text style={styles.fieldLabel}>종목코드</Text>
                    <TextInput style={styles.input} value={editTicker} onChangeText={setEditTicker} />
                  </View>

                  <View>
                    <Text style={styles.fieldLabel}>거래유형</Text>
                    <FilterTabs
                      options={['매수', '매도', '최초잔고']}
                      selected={TYPE_LABELS[editType] ?? editType}
                      onSelect={(v) => {
                        const reverse: Record<string, string> = { '매수': 'buy', '매도': 'sell', '최초잔고': 'opening_balance' };
                        setEditType(reverse[v] ?? v);
                      }}
                    />
                  </View>

                  <View>
                    <Text style={styles.fieldLabel}>명의</Text>
                    <FilterTabs
                      options={['본석', '연지', '나은']}
                      selected={editOwner}
                      onSelect={setEditOwner}
                    />
                  </View>

                  <View>
                    <Text style={styles.fieldLabel}>수량</Text>
                    <TextInput style={styles.input} value={editShares} onChangeText={setEditShares} keyboardType="numeric" />
                  </View>

                  <View>
                    <Text style={styles.fieldLabel}>가격 ({editTx.currency})</Text>
                    <TextInput style={styles.input} value={editPrice} onChangeText={setEditPrice} keyboardType="numeric" />
                  </View>

                  {editTx.currency === 'USD' && (
                    <View>
                      <Text style={styles.fieldLabel}>환율 (KRW/USD)</Text>
                      <TextInput style={styles.input} value={editRate} onChangeText={setEditRate} keyboardType="numeric" />
                    </View>
                  )}

                  <View>
                    <Text style={styles.fieldLabel}>날짜 (YYYY-MM-DD)</Text>
                    <TextInput style={styles.input} value={editDate} onChangeText={setEditDate} />
                  </View>

                  <View>
                    <Text style={styles.fieldLabel}>메모</Text>
                    <TextInput style={styles.input} value={editMemo} onChangeText={setEditMemo} placeholder="선택" placeholderTextColor={COLORS.textMuted} />
                  </View>
                </View>
              </ScrollView>
            )}

            <View style={[styles.modalButtons, { marginTop: 16 }]}>
              <Pressable style={styles.deleteBtn} onPress={handleDeleteTx}>
                <Text style={styles.deleteBtnText}>삭제</Text>
              </Pressable>
              <Pressable style={[styles.closeBtn, { backgroundColor: settings.accentColor, borderWidth: 0 }]} onPress={handleSaveTx}>
                <Text style={[styles.closeBtnText, { color: '#FFF', fontFamily: 'Inter_600SemiBold' }]}>저장</Text>
              </Pressable>
            </View>
          </Pressable>
        </Pressable>
      </Modal>
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
  modalOverlay: { flex: 1, backgroundColor: 'rgba(0,0,0,0.4)', justifyContent: 'center', alignItems: 'center' },
  modalContent: {
    backgroundColor: COLORS.card, borderRadius: 20,
    padding: 24, maxHeight: '90%', width: '90%', maxWidth: 480,
  },
  modalContentPC: { width: 560, maxWidth: 560, maxHeight: '90%' },
  modalHeader: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', marginBottom: 20 },
  modalTitle: { fontFamily: 'Newsreader_500Medium', fontSize: 20, color: COLORS.textPrimary },
  closeX: { fontFamily: 'Inter_500Medium', fontSize: 20, color: COLORS.textMuted, padding: 4 },
  fieldLabel: { fontFamily: 'Inter_500Medium', fontSize: 12, color: COLORS.textTertiary, marginBottom: 4 },
  input: {
    backgroundColor: '#F8F8F8', borderRadius: 8, paddingHorizontal: 14, paddingVertical: 10,
    fontFamily: 'JetBrainsMono_400Regular', fontSize: 13, color: COLORS.textPrimary,
  },
  modalButtons: { flexDirection: 'row', gap: 12, marginTop: 24 },
  deleteBtn: {
    flex: 1, paddingVertical: 12, borderRadius: 8, alignItems: 'center',
    backgroundColor: '#E07B54',
  },
  deleteBtnText: { fontFamily: 'Inter_600SemiBold', fontSize: 14, color: '#FFF' },
  closeBtn: {
    flex: 1, paddingVertical: 12, borderRadius: 8, alignItems: 'center',
    borderWidth: 1, borderColor: COLORS.border,
  },
  closeBtnText: { fontFamily: 'Inter_500Medium', fontSize: 14, color: COLORS.textSecondary },
});
