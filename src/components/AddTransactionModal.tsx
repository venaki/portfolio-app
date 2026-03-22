import { useState } from 'react';
import {
  Modal,
  View,
  Text,
  TextInput,
  TouchableOpacity,
  Pressable,
  ScrollView,
  StyleSheet,
  KeyboardAvoidingView,
  Platform,
  Alert,
} from 'react-native';
import { Owner, TransactionType, AssetClass, Currency } from '../types';
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
];

const ASSET_CLASS_TABS = ['미국', '한국'];
const ASSET_CLASS_MAP: Record<string, AssetClass> = {
  '미국': 'us_stock',
  '한국': 'kr_stock',
};
const CURRENCY_OPTIONS = ['KRW', 'USD'];

const today = new Date().toISOString().slice(0, 10);

export function AddTransactionModal({ visible, onClose }: Props) {
  const { addTransaction } = useApp();

  const [owner, setOwner] = useState<Owner>('본석');
  const [assetClassLabel, setAssetClassLabel] = useState('미국');
  const [ticker, setTicker] = useState('');
  const [txType, setTxType] = useState<TransactionType>('buy');
  const [shares, setShares] = useState('');
  const [price, setPrice] = useState('');
  const [exchangeRate, setExchangeRate] = useState('');
  const [executedAt, setExecutedAt] = useState(today);
  const [memo, setMemo] = useState('');
  const [cashCurrency, setCashCurrency] = useState<Currency>('KRW');
  const [submitting, setSubmitting] = useState(false);

  const assetClass = ASSET_CLASS_MAP[assetClassLabel];
  const isKR = assetClass === 'kr_stock';
  const isCash = assetClass === 'cash';
  const isUS = assetClass === 'us_stock';

  const txTypeLabels = TX_TYPES.map((t) => t.label);
  const selectedTxLabel = TX_TYPES.find((t) => t.value === txType)?.label ?? '매수';

  function reset() {
    setOwner('본석');
    setAssetClassLabel('미국');
    setTicker('');
    setTxType('buy');
    setShares('');
    setPrice('');
    setExchangeRate('');
    setExecutedAt(today);
    setMemo('');
    setCashCurrency('KRW');
  }

  async function handleSubmit() {
    const tickerTrimmed = isCash ? ticker.trim() : ticker.trim().toUpperCase();
    const priceNum = parseFloat(price);

    if (!tickerTrimmed) {
      return Alert.alert('오류', isCash ? '자산명을 입력해주세요.' : '종목코드를 입력해주세요.');
    }
    if (isNaN(priceNum) || priceNum <= 0) {
      return Alert.alert('오류', isCash ? '금액을 올바르게 입력해주세요.' : '체결가를 올바르게 입력해주세요.');
    }

    let sharesNum: number;
    let rateNum: number;
    let currency: Currency;

    if (isCash) {
      sharesNum = 1;
      currency = cashCurrency;
      rateNum = currency === 'KRW' ? 1 : parseFloat(exchangeRate);
      if (currency === 'USD' && (isNaN(rateNum) || rateNum <= 0)) {
        return Alert.alert('오류', '환율을 올바르게 입력해주세요.');
      }
    } else if (isKR) {
      sharesNum = parseFloat(shares);
      if (isNaN(sharesNum) || sharesNum <= 0) return Alert.alert('오류', '수량을 올바르게 입력해주세요.');
      rateNum = 1;
      currency = 'KRW';
    } else {
      // US stock
      sharesNum = parseFloat(shares);
      rateNum = parseFloat(exchangeRate);
      if (isNaN(sharesNum) || sharesNum <= 0) return Alert.alert('오류', '수량을 올바르게 입력해주세요.');
      if (isNaN(rateNum) || rateNum <= 0) return Alert.alert('오류', '환율을 올바르게 입력해주세요.');
      currency = 'USD';
    }

    setSubmitting(true);
    try {
      await addTransaction({
        owner,
        ticker: tickerTrimmed,
        type: txType,
        assetClass,
        currency,
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
    <Modal visible={visible} animationType="none" transparent onRequestClose={handleClose}>
      <KeyboardAvoidingView
        style={styles.overlay}
        behavior={Platform.OS === 'ios' ? 'padding' : undefined}
      >
        <Pressable style={styles.backdrop} onPress={handleClose} />
        <Pressable style={styles.sheet} onPress={(e) => e.stopPropagation()}>
          {/* Header */}
          <View style={styles.header}>
            <Text style={styles.title}>종목 추가</Text>
            <TouchableOpacity onPress={handleClose} hitSlop={{ top: 8, bottom: 8, left: 8, right: 8 }}>
              <Text style={styles.closeBtn}>✕</Text>
            </TouchableOpacity>
          </View>

          <ScrollView showsVerticalScrollIndicator={false} keyboardShouldPersistTaps="handled">
            {/* 자산유형 */}
            <Text style={styles.label}>자산유형</Text>
            <FilterTabs
              options={ASSET_CLASS_TABS}
              selected={assetClassLabel}
              onSelect={setAssetClassLabel}
            />

            {/* 명의 */}
            <Text style={styles.label}>명의</Text>
            <FilterTabs
              options={OWNERS}
              selected={owner}
              onSelect={(v) => setOwner(v as Owner)}
            />

            {/* 종목코드 / 자산명 */}
            <Text style={styles.label}>{isCash ? '자산명' : '종목코드'}</Text>
            <TextInput
              style={styles.input}
              value={ticker}
              onChangeText={setTicker}
              placeholder={isCash ? '예: 신한은행 예금' : isKR ? '예: 035420' : '예: TSLA'}
              placeholderTextColor={COLORS.textDisabled}
              autoCapitalize={isCash ? 'none' : 'characters'}
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

            {/* 수량 (hidden for cash) */}
            {!isCash && (
              <>
                <Text style={styles.label}>수량</Text>
                <TextInput
                  style={styles.input}
                  value={shares}
                  onChangeText={setShares}
                  placeholder="0"
                  placeholderTextColor={COLORS.textDisabled}
                  keyboardType="decimal-pad"
                />
              </>
            )}

            {/* 체결가 / 금액 */}
            <Text style={styles.label}>
              {isCash ? `금액 (${cashCurrency})` : isKR ? '체결가 (KRW)' : '체결가 (USD)'}
            </Text>
            <TextInput
              style={styles.input}
              value={price}
              onChangeText={setPrice}
              placeholder={isKR || isCash ? '0' : '0.00'}
              placeholderTextColor={COLORS.textDisabled}
              keyboardType="decimal-pad"
            />

            {/* Cash: currency selector */}
            {isCash && (
              <>
                <Text style={styles.label}>통화</Text>
                <FilterTabs
                  options={CURRENCY_OPTIONS}
                  selected={cashCurrency}
                  onSelect={(v) => setCashCurrency(v as Currency)}
                />
              </>
            )}

            {/* 환율 (US stocks always, cash USD only) */}
            {(isUS || (isCash && cashCurrency === 'USD')) && (
              <>
                <Text style={styles.label}>환율 (KRW/USD)</Text>
                <TextInput
                  style={styles.input}
                  value={exchangeRate}
                  onChangeText={setExchangeRate}
                  placeholder="1350"
                  placeholderTextColor={COLORS.textDisabled}
                  keyboardType="decimal-pad"
                />
              </>
            )}

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
        </Pressable>
      </KeyboardAvoidingView>
    </Modal>
  );
}

const styles = StyleSheet.create({
  overlay: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: 'rgba(0,0,0,0.4)',
  },
  backdrop: {
    ...StyleSheet.absoluteFillObject,
  },
  sheet: {
    backgroundColor: '#FFFFFF',
    borderRadius: 20,
    padding: 24,
    maxHeight: '90%',
    width: '90%',
    maxWidth: 560,
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
