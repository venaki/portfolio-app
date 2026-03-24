import { useState, useMemo, useEffect } from 'react';
import { View, Text, ScrollView, TouchableOpacity, TextInput, Pressable, Alert, StyleSheet } from 'react-native';
import { useApp } from '../../src/context/AppContext';
import { useResponsive } from '../../src/hooks/useResponsive';
import { COLORS, NEGATIVE_COLOR, getStatusColors } from '../../src/constants';
import { CARD_BASE, BADGE, MODAL, PAGE, SECTION } from '../../src/styles/shared';
import { FilterTabs } from '../../src/components/FilterTabs';
import { formatKRW, formatUSD } from '../../src/utils/format';
import { Owner, Currency } from '../../src/types';
import { BaseModal } from '../../src/components/BaseModal';

const ASSET_TYPES = ['예금', '채권', '대출', '기타'] as const;
type CashAssetType = typeof ASSET_TYPES[number];

export default function Assets() {
  const { holdings, transactions, settings, market, addTransaction, deleteTransaction, updateTransaction, accounts } = useApp();
  const OWNER_OPTIONS = ['전체', ...accounts];
  const { isMobile } = useResponsive();

  const [selectedOwner, setSelectedOwner] = useState('전체');
  const [showAddModal, setShowAddModal] = useState(false);
  const [editTarget, setEditTarget] = useState<{ owner: string; ticker: string } | null>(null);

  // Add form state
  const [addForm, setAddForm] = useState({
    owner: accounts[0] ?? '', type: '예금' as CashAssetType, name: '', amount: '', currency: 'KRW' as Currency, memo: '',
  });
  const updateAddField = (field: string, value: any) => setAddForm(prev => ({ ...prev, [field]: value }));

  const cashHoldings = useMemo(() => {
    return holdings
      .filter(h => h.assetClass === 'cash')
      .filter(h => selectedOwner === '전체' || h.owner === selectedOwner);
  }, [holdings, selectedOwner]);

  const totalKRW = useMemo(() => {
    return cashHoldings.reduce((sum, h) => {
      if (h.currency === 'KRW') return sum + h.avgCost * h.shares;
      return sum + h.avgCost * h.shares * market.exchangeRate;
    }, 0);
  }, [cashHoldings, market.exchangeRate]);

  const handleAdd = async () => {
    if (!addForm.name.trim() || !addForm.amount.trim()) {
      Alert.alert('입력 오류', '자산명과 금액을 입력해주세요.');
      return;
    }
    const amount = parseFloat(addForm.amount);
    if (isNaN(amount) || amount <= 0) {
      Alert.alert('입력 오류', '올바른 금액을 입력해주세요.');
      return;
    }

    // 대출은 음수로 저장
    const finalAmount = addForm.type === '대출' ? -amount : amount;
    const memoText = [addForm.type, addForm.memo.trim()].filter(Boolean).join(' · ');

    await addTransaction({
      owner: addForm.owner,
      ticker: addForm.name.trim(),
      type: 'opening_balance',
      assetClass: 'cash',
      currency: addForm.currency,
      shares: 1,
      price: finalAmount,
      exchangeRate: addForm.currency === 'KRW' ? 1 : market.exchangeRate,
      executedAt: new Date().toISOString(),
      memo: memoText || undefined,
    });

    setAddForm({ owner: addForm.owner, type: '예금', name: '', amount: '', currency: 'KRW', memo: '' });
    setShowAddModal(false);
  };

  // Edit modal
  const editHolding = editTarget
    ? cashHoldings.find(h => h.owner === editTarget.owner && h.ticker === editTarget.ticker)
    : null;
  const editTxRecord = editTarget
    ? transactions.find(t => t.assetClass === 'cash' && t.ticker === editTarget.ticker && t.owner === editTarget.owner)
    : null;

  // Edit form state
  const [editForm, setEditForm] = useState({
    name: '', owner: accounts[0] ?? '' as Owner, type: '예금' as CashAssetType, amount: '', currency: 'KRW' as Currency, memo: '',
  });
  const updateEditField = (field: string, value: any) => setEditForm(prev => ({ ...prev, [field]: value }));

  useEffect(() => {
    if (editHolding && editTxRecord) {
      const amount = Math.abs(editHolding.avgCost * editHolding.shares);
      const memo = editTxRecord.memo ?? '';
      const typePart = memo.split(' · ')[0];
      const memoPart = memo.split(' · ').slice(1).join(' · ');
      setEditForm({
        name: editHolding.ticker,
        owner: editHolding.owner,
        type: ASSET_TYPES.includes(typePart as any) ? typePart as CashAssetType : '기타',
        amount: String(amount),
        currency: editHolding.currency,
        memo: memoPart,
      });
    }
  }, [editTarget]);

  const handleSaveEdit = async () => {
    if (!editTxRecord) return;
    const amount = parseFloat(editForm.amount);
    if (isNaN(amount) || amount <= 0) {
      Alert.alert('입력 오류', '올바른 금액을 입력해주세요.');
      return;
    }
    const finalAmount = editForm.type === '대출' ? -amount : amount;
    const memoText = [editForm.type, editForm.memo.trim()].filter(Boolean).join(' · ');
    await updateTransaction(editTxRecord.id, {
      ticker: editForm.name.trim(),
      owner: editForm.owner,
      currency: editForm.currency,
      price: finalAmount,
      exchangeRate: editForm.currency === 'KRW' ? 1 : market.exchangeRate,
      memo: memoText || undefined,
    });
    setEditTarget(null);
  };

  const handleDeleteOne = () => {
    if (!editTarget) return;
    const doDelete = () => {
      const toDelete = transactions.filter(
        t => t.assetClass === 'cash' && t.ticker === editTarget.ticker && t.owner === editTarget.owner
      );
      toDelete.forEach(t => deleteTransaction(t.id));
      setEditTarget(null);
    };
    if (typeof window !== 'undefined' && window.confirm) {
      if (window.confirm(`"${editTarget.ticker}" 자산을 삭제하시겠습니까?`)) doDelete();
    } else {
      Alert.alert('삭제 확인', `"${editTarget.ticker}" 자산을 삭제하시겠습니까?`, [
        { text: '취소', style: 'cancel' },
        { text: '삭제', style: 'destructive', onPress: doDelete },
      ]);
    }
  };

  return (
    <View style={styles.container}>
      <View style={[styles.header, !isMobile && styles.headerPC]}>
        <Text style={PAGE.title}>기타 자산</Text>
        <TouchableOpacity
          style={[PAGE.addBtn, { backgroundColor: settings.accentColor }]}
          onPress={() => setShowAddModal(true)}
        >
          <Text style={PAGE.addBtnText}>추가</Text>
        </TouchableOpacity>
      </View>

      <View style={[styles.filterWrapper, !isMobile && styles.filterWrapperPC]}>
        <FilterTabs options={OWNER_OPTIONS} selected={selectedOwner} onSelect={setSelectedOwner} />
      </View>

      {/* Total */}
      <View style={[styles.totalRow, !isMobile && styles.totalRowPC]}>
        <Text style={styles.totalLabel}>합계</Text>
        <Text style={styles.totalValue}>{formatKRW(totalKRW)}</Text>
      </View>

      <ScrollView
        style={styles.scroll}
        contentContainerStyle={[styles.scrollContent, isMobile && { paddingBottom: 100 }]}
      >
        {cashHoldings.length === 0 ? (
          <View style={PAGE.emptyContainer}>
            <Text style={PAGE.emptyText}>기타 자산이 없습니다</Text>
            <Text style={styles.emptySubText}>현금, 예금, 채권 등을 추가해보세요</Text>
          </View>
        ) : (
          cashHoldings.map(h => {
            const memo = transactions.find(t => t.assetClass === 'cash' && t.ticker === h.ticker && t.owner === h.owner)?.memo;
            const statusColors = getStatusColors(h.avgCost);
            return (
            <Pressable
              key={`${h.owner}-${h.ticker}`}
              style={[styles.card, !isMobile && styles.cardPC]}
              onPress={() => setEditTarget({ owner: h.owner, ticker: h.ticker })}
            >
              <View style={styles.cardLeft}>
                <Text style={styles.cardName}>{h.ticker}</Text>
                <View style={styles.cardMeta}>
                  <View style={BADGE.container}>
                    <Text style={BADGE.text}>{h.owner}</Text>
                  </View>
                  {memo && (
                    <View style={[styles.typeBadge, h.avgCost < 0 && { backgroundColor: statusColors.bg }]}>
                      <Text style={[styles.typeText, h.avgCost < 0 && { color: statusColors.color }]}>
                        {memo.split(' · ')[0]}
                      </Text>
                    </View>
                  )}
                  <Text style={styles.currencyBadge}>{h.currency}</Text>
                </View>
              </View>
              <View style={styles.cardRight}>
                <Text style={[styles.cardAmount, h.avgCost < 0 && { color: statusColors.color }]}>
                  {h.currency === 'KRW' ? formatKRW(h.avgCost * h.shares) : formatUSD(h.avgCost * h.shares)}
                </Text>
                {h.currency === 'USD' && market.exchangeRate > 0 && (
                  <Text style={styles.cardAmountSub}>
                    {formatKRW(h.avgCost * h.shares * market.exchangeRate)}
                  </Text>
                )}
              </View>
            </Pressable>
          );})
        )}
      </ScrollView>

      {/* Add Modal */}
      <BaseModal visible={showAddModal} onClose={() => setShowAddModal(false)} cardStyle={!isMobile ? styles.modalContentPC : undefined}>
            <Text style={MODAL.title}>기타 자산 추가</Text>

            <Text style={MODAL.fieldLabel}>명의</Text>
            <FilterTabs
              options={accounts}
              selected={addForm.owner}
              onSelect={(v) => updateAddField('owner', v)}
            />

            <Text style={[MODAL.fieldLabel, styles.fieldLabelSpacedLg]}>유형</Text>
            <FilterTabs
              options={[...ASSET_TYPES]}
              selected={addForm.type}
              onSelect={(v) => updateAddField('type', v)}
            />

            <Text style={[MODAL.fieldLabel, styles.fieldLabelSpaced]}>자산명</Text>
            <TextInput
              style={MODAL.input}
              value={addForm.name}
              onChangeText={(v) => updateAddField('name', v)}
              placeholder="예: 신한은행 예금"
              placeholderTextColor={COLORS.textMuted}
            />

            <Text style={[MODAL.fieldLabel, styles.fieldLabelSpaced]}>통화</Text>
            <FilterTabs
              options={['KRW', 'USD']}
              selected={addForm.currency}
              onSelect={(v) => updateAddField('currency', v)}
            />

            <Text style={[MODAL.fieldLabel, styles.fieldLabelSpaced]}>금액</Text>
            <TextInput
              style={MODAL.input}
              value={addForm.amount}
              onChangeText={(v) => updateAddField('amount', v)}
              placeholder={addForm.currency === 'KRW' ? '₩ 금액' : '$ 금액'}
              placeholderTextColor={COLORS.textMuted}
              keyboardType="numeric"
            />

            <Text style={[MODAL.fieldLabel, styles.fieldLabelSpaced]}>메모 (선택)</Text>
            <TextInput
              style={MODAL.input}
              value={addForm.memo}
              onChangeText={(v) => updateAddField('memo', v)}
              placeholder="메모"
              placeholderTextColor={COLORS.textMuted}
            />

            <View style={MODAL.buttons}>
              <Pressable style={MODAL.btnSecondary} onPress={() => setShowAddModal(false)}>
                <Text style={MODAL.btnSecondaryText}>취소</Text>
              </Pressable>
              <Pressable
                style={[MODAL.btnPrimary, { backgroundColor: settings.accentColor }]}
                onPress={handleAdd}
              >
                <Text style={MODAL.btnPrimaryText}>추가</Text>
              </Pressable>
            </View>
      </BaseModal>

      {/* Edit Modal */}
      <BaseModal visible={!!editTarget} onClose={() => setEditTarget(null)} cardStyle={!isMobile ? styles.modalContentPC : undefined}>
            <View style={MODAL.header}>
              <Text style={MODAL.title}>자산 편집</Text>
              <Pressable onPress={() => setEditTarget(null)} hitSlop={8}>
                <Text style={MODAL.closeX}>✕</Text>
              </Pressable>
            </View>

            {editHolding && (
              <View style={styles.editFormGap}>
                <View>
                  <Text style={MODAL.fieldLabel}>자산명</Text>
                  <TextInput style={MODAL.input} value={editForm.name} onChangeText={(v) => updateEditField('name', v)} />
                </View>

                <View>
                  <Text style={MODAL.fieldLabel}>명의</Text>
                  <FilterTabs options={accounts} selected={editForm.owner} onSelect={(v) => updateEditField('owner', v)} />
                </View>

                <View>
                  <Text style={MODAL.fieldLabel}>유형</Text>
                  <FilterTabs options={[...ASSET_TYPES]} selected={editForm.type} onSelect={(v) => updateEditField('type', v)} />
                </View>

                <View>
                  <Text style={MODAL.fieldLabel}>통화</Text>
                  <FilterTabs options={['KRW', 'USD']} selected={editForm.currency} onSelect={(v) => updateEditField('currency', v)} />
                </View>

                <View>
                  <Text style={MODAL.fieldLabel}>금액</Text>
                  <TextInput style={MODAL.input} value={editForm.amount} onChangeText={(v) => updateEditField('amount', v)} keyboardType="numeric" />
                </View>

                <View>
                  <Text style={MODAL.fieldLabel}>메모 (선택)</Text>
                  <TextInput style={MODAL.input} value={editForm.memo} onChangeText={(v) => updateEditField('memo', v)} placeholder="메모" placeholderTextColor={COLORS.textMuted} />
                </View>
              </View>
            )}

            <View style={[MODAL.buttons, styles.editButtonsTop]}>
              <Pressable
                style={[MODAL.btnPrimary, { backgroundColor: NEGATIVE_COLOR }]}
                onPress={handleDeleteOne}
              >
                <Text style={MODAL.btnPrimaryText}>삭제</Text>
              </Pressable>
              <Pressable style={[MODAL.btnPrimary, { backgroundColor: settings.accentColor }]} onPress={handleSaveEdit}>
                <Text style={MODAL.btnPrimaryText}>저장</Text>
              </Pressable>
            </View>
      </BaseModal>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: COLORS.background },
  header: {
    flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center',
    paddingHorizontal: 16, paddingTop: 20, paddingBottom: 8,
  },
  headerPC: { paddingHorizontal: 24, paddingTop: 24 },
  filterWrapper: { paddingHorizontal: 16, marginBottom: 8 },
  filterWrapperPC: { paddingHorizontal: 24 },
  totalRow: {
    flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center',
    paddingHorizontal: 16, paddingVertical: 12,
    borderBottomWidth: 1, borderBottomColor: COLORS.divider,
  },
  totalRowPC: { paddingHorizontal: 24 },
  totalLabel: { fontWeight: '600', fontSize: 12, color: COLORS.textTertiary, letterSpacing: 1 },
  totalValue: { fontWeight: '700', fontSize: 16, color: COLORS.textPrimary, fontVariant: ['tabular-nums'] },
  scroll: { flex: 1 },
  scrollContent: { paddingHorizontal: 16, paddingTop: 8, gap: 8 },
  emptySubText: { fontSize: 12, color: COLORS.textMuted, marginTop: 4 },
  card: {
    backgroundColor: COLORS.card, borderRadius: 12, borderWidth: 1, borderColor: COLORS.border,
    padding: 16, flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center',
  },
  cardPC: { marginHorizontal: 8 },
  cardLeft: { flex: 1, marginRight: 12 },
  cardName: { fontWeight: '600', fontSize: 14, color: COLORS.textPrimary, marginBottom: 4 },
  cardMeta: { flexDirection: 'row', alignItems: 'center', gap: 6, marginBottom: 2 },
  typeBadge: { backgroundColor: '#E8F5E9', borderRadius: 4, paddingHorizontal: 5, paddingVertical: 1 },
  typeText: { fontWeight: '500', fontSize: 10, color: '#16A34A' },
  currencyBadge: { fontWeight: '500', fontSize: 10, color: COLORS.textMuted, fontVariant: ['tabular-nums'] },
  cardMemo: { fontSize: 11, color: COLORS.textMuted, marginTop: 2 },
  cardRight: { alignItems: 'flex-end' },
  cardAmount: { fontWeight: '700', fontSize: 16, color: COLORS.textPrimary, fontVariant: ['tabular-nums'] },
  cardAmountSub: { fontWeight: '500', fontSize: 11, color: COLORS.textTertiary, marginTop: 2, fontVariant: ['tabular-nums'] },
  // Modal
  modalContentPC: { width: 560, maxWidth: 560 },
  fieldLabelSpacedLg: { marginTop: 16 },
  fieldLabelSpaced: { marginTop: 12 },
  editFormGap: { gap: 12 },
  editButtonsTop: { marginTop: 16 },
  editRow: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center' },
  editLabel: { fontWeight: '500', fontSize: 12, color: COLORS.textTertiary, fontVariant: ['tabular-nums'] },
  editValue: { fontWeight: '600', fontSize: 14, color: COLORS.textPrimary, fontVariant: ['tabular-nums'] },
});
