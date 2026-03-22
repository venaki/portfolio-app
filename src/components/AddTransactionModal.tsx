import { useState } from 'react';
import {
  Modal,
  View,
  Text,
  TextInput,
  TouchableOpacity,
  ScrollView,
  StyleSheet,
  KeyboardAvoidingView,
  Platform,
  Alert,
} from 'react-native';
import { Owner, TransactionType } from '../types';
import { COLORS } from '../constants';
import { useApp } from '../context/AppContext';
import { FilterTabs } from './FilterTabs';

interface Props {
  visible: boolean;
  onClose: () => void;
}

const OWNERS: Owner[] = ['본석', '연지', '나은'];
const TX_TYPES: { label: string; value: TransactionType }[] = [
  { label: '매수', value: 'buy' },
  { label: '매도', value: 'sell' },
  { label: '최초잔고', value: 'opening_balance' },
];

const today = new Date().toISOString().slice(0, 10);

export function AddTransactionModal({ visible, onClose }: Props) {
  const { addTransaction } = useApp();

  const [owner, setOwner] = useState<Owner>('본석');
  const [ticker, setTicker] = useState('');
  const [txType, setTxType] = useState<TransactionType>('buy');
  const [shares, setShares] = useState('');
  const [price, setPrice] = useState('');
  const [exchangeRate, setExchangeRate] = useState('');
  const [executedAt, setExecutedAt] = useState(today);
  const [memo, setMemo] = useState('');
  const [submitting, setSubmitting] = useState(false);

  const txTypeLabels = TX_TYPES.map((t) => t.label);
  const selectedTxLabel = TX_TYPES.find((t) => t.value === txType)?.label ?? '매수';

  function reset() {
    setOwner('본석');
    setTicker('');
    setTxType('buy');
    setShares('');
    setPrice('');
    setExchangeRate('');
    setExecutedAt(today);
    setMemo('');
  }

  async function handleSubmit() {
    const tickerTrimmed = ticker.trim().toUpperCase();
    const sharesNum = parseFloat(shares);
    const priceNum = parseFloat(price);
    const rateNum = parseFloat(exchangeRate);

    if (!tickerTrimmed) return Alert.alert('오류', '종목코드를 입력해주세요.');
    if (isNaN(sharesNum) || sharesNum <= 0) return Alert.alert('오류', '수량을 올바르게 입력해주세요.');
    if (isNaN(priceNum) || priceNum <= 0) return Alert.alert('오류', '체결가를 올바르게 입력해주세요.');
    if (isNaN(rateNum) || rateNum <= 0) return Alert.alert('오류', '환율을 올바르게 입력해주세요.');

    setSubmitting(true);
    try {
      await addTransaction({
        owner,
        ticker: tickerTrimmed,
        type: txType,
        shares: sharesNum,
        price: priceNum,
        exchangeRate: rateNum,
        executedAt,
        memo: memo.trim() || undefined,
      });
      reset();
      onClose();
    } catch (e) {
      Alert.alert('오류', '거래 추가에 실패했습니다.');
    } finally {
      setSubmitting(false);
    }
  }

  function handleClose() {
    reset();
    onClose();
  }

  return (
    <Modal visible={visible} animationType="slide" transparent onRequestClose={handleClose}>
      <KeyboardAvoidingView
        style={styles.overlay}
        behavior={Platform.OS === 'ios' ? 'padding' : undefined}
      >
        <View style={styles.backdrop} />
        <View style={styles.sheet}>
          {/* Header */}
          <View style={styles.header}>
            <Text style={styles.title}>종목 추가</Text>
            <TouchableOpacity onPress={handleClose} hitSlop={{ top: 8, bottom: 8, left: 8, right: 8 }}>
              <Text style={styles.closeBtn}>✕</Text>
            </TouchableOpacity>
          </View>

          <ScrollView showsVerticalScrollIndicator={false} keyboardShouldPersistTaps="handled">
            {/* 명의 */}
            <Text style={styles.label}>명의</Text>
            <FilterTabs
              options={OWNERS}
              selected={owner}
              onSelect={(v) => setOwner(v as Owner)}
            />

            {/* 종목코드 */}
            <Text style={styles.label}>종목코드</Text>
            <TextInput
              style={styles.input}
              value={ticker}
              onChangeText={setTicker}
              placeholder="예: TSLA"
              placeholderTextColor={COLORS.textDisabled}
              autoCapitalize="characters"
            />

            {/* 거래유형 */}
            <Text style={styles.label}>거래유형</Text>
            <FilterTabs
              options={txTypeLabels}
              selected={selectedTxLabel}
              onSelect={(label) => {
                const found = TX_TYPES.find((t) => t.label === label);
                if (found) setTxType(found.value);
              }}
            />

            {/* 수량 */}
            <Text style={styles.label}>수량</Text>
            <TextInput
              style={styles.input}
              value={shares}
              onChangeText={setShares}
              placeholder="0"
              placeholderTextColor={COLORS.textDisabled}
              keyboardType="decimal-pad"
            />

            {/* 체결가 */}
            <Text style={styles.label}>체결가 (USD)</Text>
            <TextInput
              style={styles.input}
              value={price}
              onChangeText={setPrice}
              placeholder="0.00"
              placeholderTextColor={COLORS.textDisabled}
              keyboardType="decimal-pad"
            />

            {/* 환율 */}
            <Text style={styles.label}>환율 (KRW/USD)</Text>
            <TextInput
              style={styles.input}
              value={exchangeRate}
              onChangeText={setExchangeRate}
              placeholder="1350"
              placeholderTextColor={COLORS.textDisabled}
              keyboardType="decimal-pad"
            />

            {/* 날짜 */}
            <Text style={styles.label}>날짜</Text>
            <TextInput
              style={styles.input}
              value={executedAt}
              onChangeText={setExecutedAt}
              placeholder="YYYY-MM-DD"
              placeholderTextColor={COLORS.textDisabled}
            />

            {/* 메모 */}
            <Text style={styles.label}>메모 (선택)</Text>
            <TextInput
              style={[styles.input, styles.memoInput]}
              value={memo}
              onChangeText={setMemo}
              placeholder="메모를 입력하세요"
              placeholderTextColor={COLORS.textDisabled}
              multiline
            />

            {/* Submit */}
            <TouchableOpacity
              style={[styles.submitBtn, submitting && styles.submitBtnDisabled]}
              onPress={handleSubmit}
              disabled={submitting}
              activeOpacity={0.8}
            >
              <Text style={styles.submitText}>{submitting ? '추가 중...' : '거래 추가'}</Text>
            </TouchableOpacity>

            <View style={{ height: 32 }} />
          </ScrollView>
        </View>
      </KeyboardAvoidingView>
    </Modal>
  );
}

const styles = StyleSheet.create({
  overlay: {
    flex: 1,
    justifyContent: 'flex-end',
  },
  backdrop: {
    ...StyleSheet.absoluteFillObject,
    backgroundColor: 'rgba(0,0,0,0.4)',
  },
  sheet: {
    backgroundColor: '#FFFFFF',
    borderTopLeftRadius: 20,
    borderTopRightRadius: 20,
    padding: 24,
    maxHeight: '90%',
  },
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 20,
  },
  title: {
    fontFamily: 'Newsreader_500Medium',
    fontSize: 20,
    color: COLORS.textPrimary,
  },
  closeBtn: {
    fontFamily: 'Inter_500Medium',
    fontSize: 16,
    color: COLORS.textTertiary,
  },
  label: {
    fontFamily: 'Inter_600SemiBold',
    fontSize: 13,
    color: COLORS.textSecondary,
    marginTop: 16,
    marginBottom: 6,
  },
  input: {
    backgroundColor: '#F8F8F8',
    borderRadius: 8,
    paddingHorizontal: 14,
    paddingVertical: 12,
    fontFamily: 'JetBrainsMono_500Medium',
    fontSize: 14,
    color: COLORS.textPrimary,
  },
  memoInput: {
    minHeight: 64,
    textAlignVertical: 'top',
  },
  submitBtn: {
    backgroundColor: '#16A34A',
    borderRadius: 10,
    paddingVertical: 15,
    alignItems: 'center',
    marginTop: 24,
  },
  submitBtnDisabled: {
    opacity: 0.6,
  },
  submitText: {
    fontFamily: 'Inter_600SemiBold',
    fontSize: 15,
    color: '#FFFFFF',
  },
});
