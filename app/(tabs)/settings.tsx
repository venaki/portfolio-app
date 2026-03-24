import { useCallback, useRef } from 'react';
import {
  View,
  Text,
  ScrollView,
  Pressable,
  Alert,
  Platform,
  StyleSheet,
} from 'react-native';
import { useApp } from '../../src/context/AppContext';
import { ACCENT_PRESETS, COLORS } from '../../src/constants';
import { CARD_BASE, SECTION, MODAL } from '../../src/styles/shared';
import { useResponsive } from '../../src/hooks/useResponsive';
import { ColorPicker } from '../../src/components/ColorPicker';
import { AccountManager } from '../../src/components/AccountManager';

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
  const { settings, updateSettings, resetData, getAppDataJson, importData } = useApp();
  const { isMobile, isPC } = useResponsive();

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
            if (e.name === 'AbortError') return;
          }
        }

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
      <Text style={[styles.title, isPC && styles.titlePC]}>설정</Text>

      <AccountManager accentColor={accentColor} />

      {/* ── APPEARANCE ── */}
      <View style={styles.section}>
        <Text style={SECTION.label}>APPEARANCE</Text>
        <View style={styles.card}>
          <Text style={MODAL.fieldLabel}>강조 색상</Text>
          <View style={styles.pickerWrapper}>
            <ColorPicker
              colors={ACCENT_PRESETS}
              selected={accentColor}
              onSelect={handleAccentColor}
            />
          </View>
        </View>
      </View>

      {/* ── DATA REFRESH ── */}
      <View style={styles.section}>
        <Text style={SECTION.label}>DATA REFRESH</Text>
        <View style={styles.card}>
          <View style={styles.row}>
            <Text style={MODAL.fieldLabel}>자동 새로고침 간격</Text>
            <Pressable onPress={handleCycleInterval} style={styles.intervalBadge}>
              <Text style={[styles.intervalText, { color: accentColor }]}>
                {getIntervalLabel(settings.refreshInterval)}
              </Text>
            </Pressable>
          </View>
        </View>
      </View>

      {/* ── DATA MANAGEMENT ── */}
      <View style={styles.section}>
        <Text style={SECTION.label}>DATA MANAGEMENT</Text>
        <View style={styles.card}>
          <Pressable style={styles.mgmtRow} onPress={handleBackup}>
            <Text style={MODAL.fieldLabel}>데이터 백업 (JSON 내보내기)</Text>
            <Text style={styles.mgmtIcon}>↑</Text>
          </Pressable>
          <View style={styles.divider} />
          <Pressable style={styles.mgmtRow} onPress={handleRestore}>
            <Text style={MODAL.fieldLabel}>데이터 복원 (JSON 가져오기)</Text>
            <Text style={styles.mgmtIcon}>↓</Text>
          </Pressable>
          <View style={styles.divider} />
          <Pressable style={styles.mgmtRow} onPress={handleReset}>
            <Text style={[MODAL.fieldLabel, styles.resetText]}>데이터 초기화</Text>
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
    </>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: COLORS.background },
  content: { paddingBottom: 24 },
  contentMobile: { paddingTop: 0, paddingHorizontal: 24, paddingBottom: 100 },
  contentPC: { paddingTop: 32, paddingHorizontal: 40, paddingBottom: 32 },
  title: {
    fontWeight: '500',
    fontSize: 40,
    color: COLORS.textPrimary,
    marginTop: 24,
    marginBottom: 32,
  },
  titlePC: { marginTop: 0 },
  section: { marginBottom: 32 },
  card: {
    ...CARD_BASE,
  },
  pickerWrapper: { marginTop: 12 },
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
    fontWeight: '500',
    fontSize: 12,
    fontVariant: ['tabular-nums'],
  },
  mgmtRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingVertical: 4,
  },
  mgmtIcon: {
    fontSize: 16,
    color: COLORS.textSecondary,
  },
  resetText: { color: '#E07B54' },
});
