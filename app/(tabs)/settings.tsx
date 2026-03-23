import React, { useCallback, useRef, useState } from 'react';
import {
  View,
  Text,
  ScrollView,
  TextInput,
  Pressable,
  Alert,
  Modal,
  Platform,
  StyleSheet,
} from 'react-native';
import { useApp } from '../../src/context/AppContext';
import { ACCENT_PRESETS, COLORS } from '../../src/constants';
import { useResponsive } from '../../src/hooks/useResponsive';
import { ColorPicker } from '../../src/components/ColorPicker';

const INTERVAL_OPTIONS: { label: string; value: number }[] = [
  { label: '30초', value: 30 },
  { label: '1분', value: 60 },
  { label: '5분', value: 300 },
  { label: '15분', value: 900 },
];

function getIntervalLabel(value: number): string {
  return INTERVAL_OPTIONS.find((o) => o.value === value)?.label ?? `${value}초`;
}

function nextInterval(current: number): number {
  const idx = INTERVAL_OPTIONS.findIndex((o) => o.value === current);
  const next = (idx + 1) % INTERVAL_OPTIONS.length;
  return INTERVAL_OPTIONS[next].value;
}

export default function Settings() {
  const { settings, updateSettings, resetData, getAppDataJson, importData, market, accounts, addAccount, removeAccount, transactions } = useApp();
  const { isMobile, isPC } = useResponsive();
  const [newAccountName, setNewAccountName] = useState('');
  const [removeModal, setRemoveModal] = useState<{ visible: boolean; name: string; blocked: boolean; count: number }>({ visible: false, name: '', blocked: false, count: 0 });

  const handleAccentColor = useCallback(
    async (color: string) => {
      await updateSettings({ accentColor: color });
    },
    [updateSettings],
  );

  const handleCycleInterval = useCallback(async () => {
    await updateSettings({ refreshInterval: nextInterval(settings.refreshInterval) });
  }, [settings.refreshInterval, updateSettings]);

  const fileInputRef = useRef<HTMLInputElement | null>(null);

  const handleBackup = useCallback(async () => {
    try {
      const json = await getAppDataJson();
      if (Platform.OS === 'web') {
        const blob = new Blob([json], { type: 'application/json' });
        const fileName = `portfolio-backup-${new Date().toISOString().slice(0, 10)}.json`;

        // Try File System Access API (shows save dialog)
        if ('showSaveFilePicker' in window) {
          try {
            const handle = await (window as any).showSaveFilePicker({
              suggestedName: fileName,
              types: [{ description: 'JSON', accept: { 'application/json': ['.json'] } }],
            });
            const writable = await handle.createWritable();
            await writable.write(blob);
            await writable.close();
            return;
          } catch (e: any) {
            if (e.name === 'AbortError') return; // User cancelled
          }
        }

        // Fallback: direct download
        const url = URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = fileName;
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
        URL.revokeObjectURL(url);
      } else {
        const { Share } = require('react-native');
        await Share.share({ message: json, title: 'portfolio-backup.json' });
      }
    } catch {
      Alert.alert('오류', '데이터를 내보내는 중 오류가 발생했습니다.');
    }
  }, [getAppDataJson]);

  const handleRestore = useCallback(() => {
    if (Platform.OS === 'web') {
      fileInputRef.current?.click();
    } else {
      Alert.alert('알림', '모바일에서는 expo-document-picker 설치 후 지원됩니다.');
    }
  }, []);

  const handleFileSelected = useCallback(async (event: any) => {
    const file = event.target?.files?.[0];
    if (!file) return;
    try {
      const text = await file.text();
      const data = JSON.parse(text);
      if (!data.transactions || !data.settings) {
        window.alert('올바른 백업 파일이 아닙니다.');
        return;
      }
      if (window.confirm('현재 데이터를 백업 파일로 교체하시겠습니까?')) {
        await importData(text);
        window.alert('데이터가 복원되었습니다.');
      }
    } catch {
      window.alert('JSON 파일을 읽는 중 오류가 발생했습니다.');
    }
    // Reset input so same file can be selected again
    if (fileInputRef.current) fileInputRef.current.value = '';
  }, [importData]);

  const handleReset = useCallback(async () => {
    if (Platform.OS === 'web') {
      if (window.confirm('모든 거래 내역과 설정이 삭제됩니다. 계속하시겠습니까?')) {
        await resetData();
      }
    } else {
      Alert.alert('데이터 초기화', '모든 거래 내역과 설정이 삭제됩니다. 계속하시겠습니까?', [
        { text: '취소', style: 'cancel' },
        { text: '초기화', style: 'destructive', onPress: () => resetData() },
      ]);
    }
  }, [resetData]);

  const handleAddAccount = useCallback(async () => {
    const name = newAccountName.trim();
    if (!name) return;
    if (accounts.includes(name)) {
      Alert.alert('알림', '이미 존재하는 명의입니다.');
      return;
    }
    await addAccount(name);
    setNewAccountName('');
  }, [newAccountName, accounts, addAccount]);

  const handleRemoveAccount = useCallback((name: string) => {
    const count = transactions.filter(t => t.owner === name).length;
    if (count > 0) {
      setRemoveModal({ visible: true, name, blocked: true, count });
    } else {
      setRemoveModal({ visible: true, name, blocked: false, count: 0 });
    }
  }, [transactions]);

  const confirmRemoveAccount = useCallback(async () => {
    await removeAccount(removeModal.name);
    setRemoveModal({ visible: false, name: '', blocked: false, count: 0 });
  }, [removeAccount, removeModal.name]);

  const accentColor = settings.accentColor;

  return (
    <>
    <ScrollView
      style={styles.container}
      contentContainerStyle={[
        styles.content,
        isMobile ? styles.contentMobile : styles.contentPC,
      ]}
      showsVerticalScrollIndicator={false}
    >
      {/* Title */}
      <Text style={[styles.title, isPC && styles.titlePC]}>설정</Text>

      {/* ── SECTION 0: ACCOUNTS ── */}
      <View style={styles.section}>
        <Text style={styles.sectionLabel}>ACCOUNTS</Text>
        <View style={styles.card}>
          {accounts.map((account, idx) => (
            <View key={account}>
              {idx > 0 && <View style={styles.divider} />}
              <View style={styles.accountRow}>
                <Text style={styles.fieldLabel}>{account}</Text>
                <Pressable onPress={() => handleRemoveAccount(account)} hitSlop={8}>
                  <Text style={styles.accountRemoveBtn}>✕</Text>
                </Pressable>
              </View>
            </View>
          ))}
          {accounts.length > 0 && <View style={styles.divider} />}
          <View style={styles.accountAddRow}>
            <TextInput
              style={styles.accountInput}
              value={newAccountName}
              onChangeText={setNewAccountName}
              placeholder="새 명의 입력"
              placeholderTextColor={COLORS.textMuted}
              onSubmitEditing={handleAddAccount}
            />
            <Pressable
              style={[styles.accountAddBtn, { backgroundColor: accentColor }]}
              onPress={handleAddAccount}
            >
              <Text style={styles.accountAddBtnText}>추가</Text>
            </Pressable>
          </View>
        </View>
      </View>

      {/* ── SECTION 1: APPEARANCE ── */}
      <View style={styles.section}>
        <Text style={styles.sectionLabel}>APPEARANCE</Text>
        <View style={styles.card}>
          <Text style={styles.fieldLabel}>강조 색상</Text>
          <View style={styles.pickerWrapper}>
            <ColorPicker
              colors={ACCENT_PRESETS}
              selected={accentColor}
              onSelect={handleAccentColor}
            />
          </View>
        </View>
      </View>

      {/* ── SECTION 2: DATA REFRESH ── */}
      <View style={styles.section}>
        <Text style={styles.sectionLabel}>DATA REFRESH</Text>
        <View style={styles.card}>
          {/* Interval row */}
          <View style={styles.row}>
            <Text style={styles.fieldLabel}>자동 새로고침 간격</Text>
            <Pressable onPress={handleCycleInterval} style={styles.intervalBadge}>
              <Text style={[styles.intervalText, { color: accentColor }]}>
                {getIntervalLabel(settings.refreshInterval)}
              </Text>
            </Pressable>
          </View>
        </View>
      </View>

      {/* ── SECTION 4: DATA MANAGEMENT ── */}
      <View style={styles.section}>
        <Text style={styles.sectionLabel}>DATA MANAGEMENT</Text>
        <View style={styles.card}>
          {/* Backup */}
          <Pressable style={styles.mgmtRow} onPress={handleBackup}>
            <Text style={styles.fieldLabel}>데이터 백업 (JSON 내보내기)</Text>
            <Text style={styles.mgmtIcon}>↑</Text>
          </Pressable>
          <View style={styles.divider} />
          {/* Restore */}
          <Pressable style={styles.mgmtRow} onPress={handleRestore}>
            <Text style={styles.fieldLabel}>데이터 복원 (JSON 가져오기)</Text>
            <Text style={styles.mgmtIcon}>↓</Text>
          </Pressable>
          <View style={styles.divider} />
          {/* Reset */}
          <Pressable style={styles.mgmtRow} onPress={handleReset}>
            <Text style={[styles.fieldLabel, styles.resetText]}>데이터 초기화</Text>
            <Text style={[styles.mgmtIcon, styles.resetText]}>⌫</Text>
          </Pressable>
        </View>
      </View>
    </ScrollView>
    {Platform.OS === 'web' && (
      <input
        ref={fileInputRef as any}
        type="file"
        accept=".json"
        style={{ display: 'none' }}
        onChange={handleFileSelected}
      />
    )}
    <Modal visible={removeModal.visible} transparent animationType="fade">
      <Pressable style={styles.modalOverlay} onPress={() => setRemoveModal(prev => ({ ...prev, visible: false }))}>
        <View style={styles.modalCard} onStartShouldSetResponder={() => true}>
          <Text style={styles.modalTitle}>명의 삭제</Text>
          {removeModal.blocked ? (
            <>
              <Text style={styles.modalMessage}>
                "{removeModal.name}" 명의에 {removeModal.count}건의 거래내역이 있어 삭제할 수 없습니다.
              </Text>
              <Text style={styles.modalHint}>거래내역을 먼저 삭제해주세요.</Text>
              <Pressable
                style={[styles.modalBtn, { backgroundColor: accentColor }]}
                onPress={() => setRemoveModal(prev => ({ ...prev, visible: false }))}
              >
                <Text style={styles.modalBtnText}>확인</Text>
              </Pressable>
            </>
          ) : (
            <>
              <Text style={styles.modalMessage}>
                "{removeModal.name}" 명의를 삭제하시겠습니까?
              </Text>
              <View style={styles.modalBtnRow}>
                <Pressable
                  style={[styles.modalBtn, styles.modalBtnCancel]}
                  onPress={() => setRemoveModal(prev => ({ ...prev, visible: false }))}
                >
                  <Text style={styles.modalBtnCancelText}>취소</Text>
                </Pressable>
                <Pressable
                  style={[styles.modalBtn, styles.modalBtnDestructive]}
                  onPress={confirmRemoveAccount}
                >
                  <Text style={styles.modalBtnText}>삭제</Text>
                </Pressable>
              </View>
            </>
          )}
        </View>
      </Pressable>
    </Modal>
    </>
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
  contentMobile: {
    paddingTop: 0,
    paddingHorizontal: 24,
    paddingBottom: 100,
  },
  contentPC: {
    paddingTop: 32,
    paddingHorizontal: 40,
    paddingBottom: 32,
  },
  title: {
    fontFamily: 'Newsreader_500Medium',
    fontSize: 40,
    color: COLORS.textPrimary,
    marginTop: 24,
    marginBottom: 32,
  },
  titlePC: {
    marginTop: 0,
  },
  section: {
    marginBottom: 32,
  },
  sectionLabel: {
    fontFamily: 'JetBrainsMono_600SemiBold',
    fontSize: 11,
    color: COLORS.textTertiary,
    letterSpacing: 2,
    marginBottom: 10,
  },
  card: {
    backgroundColor: COLORS.card,
    borderRadius: 12,
    borderWidth: 1,
    borderColor: COLORS.border,
    padding: 16,
  },
  fieldLabel: {
    fontFamily: 'Inter_500Medium',
    fontSize: 13,
    color: COLORS.textPrimary,
  },
  pickerWrapper: {
    marginTop: 12,
  },
  apiKeyRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 10,
  },
  savedBadge: {
    fontFamily: 'Inter_500Medium',
    fontSize: 12,
  },
  textInput: {
    backgroundColor: '#F8F8F8',
    borderRadius: 8,
    padding: 12,
    fontFamily: 'JetBrainsMono_400Regular',
    fontSize: 13,
    color: COLORS.textPrimary,
  },
  fieldDesc: {
    fontFamily: 'Inter_400Regular',
    fontSize: 12,
    color: COLORS.textTertiary,
    lineHeight: 12 * 1.4,
    marginTop: 8,
  },
  row: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingVertical: 4,
  },
  divider: {
    height: 1,
    backgroundColor: COLORS.divider,
    marginVertical: 12,
  },
  intervalBadge: {
    paddingHorizontal: 10,
    paddingVertical: 4,
    borderRadius: 6,
    backgroundColor: COLORS.muted,
  },
  intervalText: {
    fontFamily: 'JetBrainsMono_500Medium',
    fontSize: 12,
  },
  usageText: {
    fontFamily: 'JetBrainsMono_400Regular',
    fontSize: 13,
    color: COLORS.textSecondary,
  },
  mgmtRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingVertical: 4,
  },
  mgmtIcon: {
    fontFamily: 'Inter_400Regular',
    fontSize: 16,
    color: COLORS.textSecondary,
  },
  resetText: {
    color: '#E07B54',
  },
  accountRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingVertical: 4,
  },
  accountRemoveBtn: {
    fontFamily: 'Inter_500Medium',
    fontSize: 14,
    color: COLORS.textTertiary,
    paddingHorizontal: 4,
  },
  accountAddRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
    paddingVertical: 4,
  },
  accountInput: {
    flex: 1,
    backgroundColor: '#F8F8F8',
    borderRadius: 8,
    paddingHorizontal: 12,
    paddingVertical: 8,
    fontFamily: 'Inter_400Regular',
    fontSize: 13,
    color: COLORS.textPrimary,
  },
  accountAddBtn: {
    paddingHorizontal: 14,
    paddingVertical: 8,
    borderRadius: 8,
  },
  accountAddBtnText: {
    fontFamily: 'Inter_600SemiBold',
    fontSize: 13,
    color: '#FFFFFF',
  },
  modalOverlay: {
    flex: 1,
    backgroundColor: 'rgba(0,0,0,0.4)',
    justifyContent: 'center',
    alignItems: 'center',
  },
  modalCard: {
    backgroundColor: COLORS.card,
    borderRadius: 16,
    padding: 24,
    width: 320,
    maxWidth: '90%' as any,
  },
  modalTitle: {
    fontFamily: 'Inter_600SemiBold',
    fontSize: 16,
    color: COLORS.textPrimary,
    marginBottom: 12,
  },
  modalMessage: {
    fontFamily: 'Inter_400Regular',
    fontSize: 14,
    color: COLORS.textSecondary,
    lineHeight: 20,
    marginBottom: 8,
  },
  modalHint: {
    fontFamily: 'Inter_400Regular',
    fontSize: 13,
    color: COLORS.textTertiary,
    marginBottom: 20,
  },
  modalBtnRow: {
    flexDirection: 'row' as const,
    gap: 8,
    marginTop: 12,
  },
  modalBtn: {
    flex: 1,
    paddingVertical: 10,
    borderRadius: 8,
    alignItems: 'center' as const,
  },
  modalBtnCancel: {
    backgroundColor: COLORS.muted,
  },
  modalBtnCancelText: {
    fontFamily: 'Inter_500Medium',
    fontSize: 14,
    color: COLORS.textSecondary,
  },
  modalBtnDestructive: {
    backgroundColor: '#E07B54',
  },
  modalBtnText: {
    fontFamily: 'Inter_500Medium',
    fontSize: 14,
    color: '#FFFFFF',
  },
});
