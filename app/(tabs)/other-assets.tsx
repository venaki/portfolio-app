import { useState, useMemo } from 'react';
import { View, Text, ScrollView, TouchableOpacity, TextInput, Modal, Pressable, Alert, StyleSheet } from 'react-native';
import { useApp } from '../../src/context/AppContext';
import { useResponsive } from '../../src/hooks/useResponsive';
import { COLORS, POSITIVE_COLOR, NEGATIVE_COLOR } from '../../src/constants';
import { FilterTabs } from '../../src/components/FilterTabs';
import { formatKRW, formatUSD } from '../../src/utils/format';
import { Owner, Currency } from '../../src/types';

const OWNER_OPTIONS = ['전체', '본석', '연지', '나은'];
const ASSET_TYPES = ['예금', '채권', '대출', '기타'] as const;
type CashAssetType = typeof ASSET_TYPES[number];

export default function Assets() {
  const { holdings, transactions, settings, market, addTransaction, deleteTransaction } = useApp();
  const { isMobile } = useResponsive();

  const [selectedOwner, setSelectedOwner] = useState('전체');
  const [showAddModal, setShowAddModal] = useState(false);
  const [editTarget, setEditTarget] = useState<{ owner: string; ticker: string } | null>(null);

  // Form state
  const [formOwner, setFormOwner] = useState<Owner>('본석');
  const [formType, setFormType] = useState<CashAssetType>('예금');
  const [formName, setFormName] = useState('');
  const [formAmount, setFormAmount] = useState('');
  const [formCurrency, setFormCurrency] = useState<Currency>('KRW');
  const [formMemo, setFormMemo] = useState('');

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
    if (!formName.trim() || !formAmount.trim()) {
      Alert.alert('입력 오류', '자산명과 금액을 입력해주세요.');
      return;
    }
    const amount = parseFloat(formAmount);
    if (isNaN(amount) || amount <= 0) {
      Alert.alert('입력 오류', '올바른 금액을 입력해주세요.');
      return;
    }

    // 대출은 음수로 저장
    const finalAmount = formType === '대출' ? -amount : amount;
    const memoText = [formType, formMemo.trim()].filter(Boolean).join(' · ');

    await addTransaction({
      owner: formOwner,
      ticker: formName.trim(),
      type: 'opening_balance',
      assetClass: 'cash',
      currency: formCurrency,
      shares: 1,
      price: finalAmount,
      exchangeRate: formCurrency === 'KRW' ? 1 : market.exchangeRate,
      executedAt: new Date().toISOString(),
      memo: memoText || undefined,
    });

    setFormName('');
    setFormAmount('');
    setFormMemo('');
    setFormType('예금');
    setShowAddModal(false);
  };

  // Edit modal: load data from target holding + memo from transaction
  const editHolding = editTarget
    ? cashHoldings.find(h => h.owner === editTarget.owner && h.ticker === editTarget.ticker)
    : null;
  const editMemo = editTarget
    ? transactions.find(t => t.assetClass === 'cash' && t.ticker === editTarget.ticker && t.owner === editTarget.owner)?.memo
    : undefined;

  const handleDeleteOne = () => {
    if (!editTarget) return;
    Alert.alert('삭제 확인', `"${editTarget.ticker}" 자산을 삭제하시겠습니까?`, [
      { text: '취소', style: 'cancel' },
      {
        text: '삭제', style: 'destructive',
        onPress: () => {
          const toDelete = transactions.filter(
            t => t.assetClass === 'cash' && t.ticker === editTarget.ticker && t.owner === editTarget.owner
          );
          toDelete.forEach(t => deleteTransaction(t.id));
          setEditTarget(null);
        },
      },
    ]);
  };

  return (
    <View style={styles.container}>
      <View style={[styles.header, !isMobile && styles.headerPC]}>
        <Text style={styles.headerTitle}>기타 자산</Text>
        <TouchableOpacity
          style={[styles.addBtn, { backgroundColor: settings.accentColor }]}
          onPress={() => setShowAddModal(true)}
        >
          <Text style={styles.addBtnText}>추가</Text>
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
          <View style={styles.empty}>
            <Text style={styles.emptyText}>기타 자산이 없습니다</Text>
            <Text style={styles.emptySubText}>현금, 예금, 채권 등을 추가해보세요</Text>
          </View>
        ) : (
          cashHoldings.map(h => {
            const memo = transactions.find(t => t.assetClass === 'cash' && t.ticker === h.ticker && t.owner === h.owner)?.memo;
            return (
            <Pressable
              key={`${h.owner}-${h.ticker}`}
              style={[styles.card, !isMobile && styles.cardPC]}
              onPress={() => setEditTarget({ owner: h.owner, ticker: h.ticker })}
            >
              <View style={styles.cardLeft}>
                <Text style={styles.cardName}>{h.ticker}</Text>
                <View style={styles.cardMeta}>
                  <View style={styles.ownerBadge}>
                    <Text style={styles.ownerText}>{h.owner}</Text>
                  </View>
                  {memo && (
                    <View style={[styles.typeBadge, h.avgCost < 0 && { backgroundColor: '#FFF0EB' }]}>
                      <Text style={[styles.typeText, h.avgCost < 0 && { color: NEGATIVE_COLOR }]}>
                        {memo.split(' · ')[0]}
                      </Text>
                    </View>
                  )}
                  <Text style={styles.currencyBadge}>{h.currency}</Text>
                </View>
              </View>
              <View style={styles.cardRight}>
                <Text style={[styles.cardAmount, h.avgCost < 0 && { color: NEGATIVE_COLOR }]}>
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
      <Modal visible={showAddModal} transparent animationType="fade">
        <Pressable style={styles.modalOverlay} onPress={() => setShowAddModal(false)}>
          <Pressable style={[styles.modalContent, !isMobile && styles.modalContentPC]} onPress={(e) => e.stopPropagation()}>
            <Text style={styles.modalTitle}>기타 자산 추가</Text>

            <Text style={styles.fieldLabel}>명의</Text>
            <FilterTabs
              options={['본석', '연지', '나은']}
              selected={formOwner}
              onSelect={(v) => setFormOwner(v as Owner)}
            />

            <Text style={[styles.fieldLabel, { marginTop: 16 }]}>유형</Text>
            <FilterTabs
              options={[...ASSET_TYPES]}
              selected={formType}
              onSelect={(v) => setFormType(v as CashAssetType)}
            />

            <Text style={[styles.fieldLabel, { marginTop: 12 }]}>자산명</Text>
            <TextInput
              style={styles.input}
              value={formName}
              onChangeText={setFormName}
              placeholder="예: 신한은행 예금"
              placeholderTextColor={COLORS.textMuted}
            />

            <Text style={[styles.fieldLabel, { marginTop: 12 }]}>통화</Text>
            <FilterTabs
              options={['KRW', 'USD']}
              selected={formCurrency}
              onSelect={(v) => setFormCurrency(v as Currency)}
            />

            <Text style={[styles.fieldLabel, { marginTop: 12 }]}>금액</Text>
            <TextInput
              style={styles.input}
              value={formAmount}
              onChangeText={setFormAmount}
              placeholder={formCurrency === 'KRW' ? '₩ 금액' : '$ 금액'}
              placeholderTextColor={COLORS.textMuted}
              keyboardType="numeric"
            />

            <Text style={[styles.fieldLabel, { marginTop: 12 }]}>메모 (선택)</Text>
            <TextInput
              style={styles.input}
              value={formMemo}
              onChangeText={setFormMemo}
              placeholder="메모"
              placeholderTextColor={COLORS.textMuted}
            />

            <View style={styles.modalButtons}>
              <Pressable style={styles.cancelBtn} onPress={() => setShowAddModal(false)}>
                <Text style={styles.cancelBtnText}>취소</Text>
              </Pressable>
              <Pressable
                style={[styles.submitBtn, { backgroundColor: settings.accentColor }]}
                onPress={handleAdd}
              >
                <Text style={styles.submitBtnText}>추가</Text>
              </Pressable>
            </View>
          </Pressable>
        </Pressable>
      </Modal>

      {/* Edit Modal */}
      <Modal visible={!!editTarget} transparent animationType="fade">
        <Pressable style={styles.modalOverlay} onPress={() => setEditTarget(null)}>
          <Pressable style={[styles.modalContent, !isMobile && styles.modalContentPC]} onPress={(e) => e.stopPropagation()}>
            <Text style={styles.modalTitle}>자산 정보</Text>

            {editHolding && (
              <View style={{ gap: 16 }}>
                <View style={styles.editRow}>
                  <Text style={styles.editLabel}>자산명</Text>
                  <Text style={styles.editValue}>{editHolding.ticker}</Text>
                </View>
                <View style={styles.editRow}>
                  <Text style={styles.editLabel}>명의</Text>
                  <Text style={styles.editValue}>{editHolding.owner}</Text>
                </View>
                <View style={styles.editRow}>
                  <Text style={styles.editLabel}>통화</Text>
                  <Text style={styles.editValue}>{editHolding.currency}</Text>
                </View>
                <View style={styles.editRow}>
                  <Text style={styles.editLabel}>금액</Text>
                  <Text style={[styles.editValue, editHolding.avgCost < 0 && { color: NEGATIVE_COLOR }]}>
                    {editHolding.currency === 'KRW'
                      ? formatKRW(editHolding.avgCost * editHolding.shares)
                      : formatUSD(editHolding.avgCost * editHolding.shares)}
                  </Text>
                </View>
                {editMemo && (
                  <View style={styles.editRow}>
                    <Text style={styles.editLabel}>유형</Text>
                    <Text style={styles.editValue}>{editMemo}</Text>
                  </View>
                )}
              </View>
            )}

            <View style={[styles.modalButtons, { marginTop: 24 }]}>
              <Pressable
                style={[styles.submitBtn, { backgroundColor: NEGATIVE_COLOR }]}
                onPress={handleDeleteOne}
              >
                <Text style={styles.submitBtnText}>삭제</Text>
              </Pressable>
              <Pressable style={styles.cancelBtn} onPress={() => setEditTarget(null)}>
                <Text style={styles.cancelBtnText}>닫기</Text>
              </Pressable>
            </View>
          </Pressable>
        </Pressable>
      </Modal>
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
  headerTitle: { fontFamily: 'Newsreader_500Medium', fontSize: 22, color: COLORS.textPrimary },
  addBtn: { paddingHorizontal: 14, paddingVertical: 7, borderRadius: 8 },
  addBtnText: { fontFamily: 'Inter_600SemiBold', fontSize: 13, color: '#FFF' },
  filterWrapper: { paddingHorizontal: 16, marginBottom: 8 },
  filterWrapperPC: { paddingHorizontal: 24 },
  totalRow: {
    flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center',
    paddingHorizontal: 16, paddingVertical: 12,
    borderBottomWidth: 1, borderBottomColor: COLORS.divider,
  },
  totalRowPC: { paddingHorizontal: 24 },
  totalLabel: { fontFamily: 'JetBrainsMono_600SemiBold', fontSize: 12, color: COLORS.textTertiary, letterSpacing: 1 },
  totalValue: { fontFamily: 'JetBrainsMono_700Bold', fontSize: 16, color: COLORS.textPrimary },
  scroll: { flex: 1 },
  scrollContent: { paddingHorizontal: 16, paddingTop: 8, gap: 8 },
  empty: { paddingVertical: 48, alignItems: 'center' },
  emptyText: { fontFamily: 'Inter_500Medium', fontSize: 14, color: COLORS.textTertiary },
  emptySubText: { fontFamily: 'Inter_400Regular', fontSize: 12, color: COLORS.textMuted, marginTop: 4 },
  card: {
    backgroundColor: COLORS.card, borderRadius: 12, borderWidth: 1, borderColor: COLORS.border,
    padding: 16, flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center',
  },
  cardPC: { marginHorizontal: 8 },
  cardLeft: { flex: 1, marginRight: 12 },
  cardName: { fontFamily: 'JetBrainsMono_600SemiBold', fontSize: 14, color: COLORS.textPrimary, marginBottom: 4 },
  cardMeta: { flexDirection: 'row', alignItems: 'center', gap: 6, marginBottom: 2 },
  ownerBadge: { backgroundColor: COLORS.muted, borderRadius: 4, paddingHorizontal: 5, paddingVertical: 1 },
  ownerText: { fontFamily: 'Inter_500Medium', fontSize: 10, color: COLORS.textTertiary },
  typeBadge: { backgroundColor: '#E8F5E9', borderRadius: 4, paddingHorizontal: 5, paddingVertical: 1 },
  typeText: { fontFamily: 'Inter_500Medium', fontSize: 10, color: POSITIVE_COLOR },
  currencyBadge: { fontFamily: 'JetBrainsMono_500Medium', fontSize: 10, color: COLORS.textMuted },
  cardMemo: { fontFamily: 'Inter_400Regular', fontSize: 11, color: COLORS.textMuted, marginTop: 2 },
  cardRight: { alignItems: 'flex-end' },
  cardAmount: { fontFamily: 'JetBrainsMono_700Bold', fontSize: 16, color: COLORS.textPrimary },
  cardAmountSub: { fontFamily: 'JetBrainsMono_500Medium', fontSize: 11, color: COLORS.textTertiary, marginTop: 2 },
  // Modal
  modalOverlay: { flex: 1, backgroundColor: 'rgba(0,0,0,0.4)', justifyContent: 'center', alignItems: 'center' },
  modalContent: {
    backgroundColor: COLORS.card, borderRadius: 20,
    padding: 24, maxHeight: '80%', width: '90%', maxWidth: 480,
  },
  modalContentPC: { width: 480 },
  modalTitle: { fontFamily: 'Newsreader_500Medium', fontSize: 20, color: COLORS.textPrimary, marginBottom: 20 },
  fieldLabel: { fontFamily: 'Inter_500Medium', fontSize: 13, color: COLORS.textPrimary, marginBottom: 6 },
  input: {
    backgroundColor: '#F8F8F8', borderRadius: 8, paddingHorizontal: 14, paddingVertical: 12,
    fontFamily: 'JetBrainsMono_400Regular', fontSize: 13, color: COLORS.textPrimary,
  },
  modalButtons: { flexDirection: 'row', gap: 12, marginTop: 24 },
  cancelBtn: {
    flex: 1, paddingVertical: 12, borderRadius: 8, alignItems: 'center',
    borderWidth: 1, borderColor: COLORS.border,
  },
  cancelBtnText: { fontFamily: 'Inter_500Medium', fontSize: 14, color: COLORS.textSecondary },
  submitBtn: { flex: 1, paddingVertical: 12, borderRadius: 8, alignItems: 'center' },
  submitBtnText: { fontFamily: 'Inter_600SemiBold', fontSize: 14, color: '#FFF' },
  editRow: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center' },
  editLabel: { fontFamily: 'JetBrainsMono_500Medium', fontSize: 12, color: COLORS.textTertiary },
  editValue: { fontFamily: 'JetBrainsMono_600SemiBold', fontSize: 14, color: COLORS.textPrimary },
});
