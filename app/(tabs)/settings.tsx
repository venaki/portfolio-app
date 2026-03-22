import React, { useCallback } from 'react';
import {
  View,
  Text,
  ScrollView,
  TextInput,
  Pressable,
  Alert,
  Share,
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
  const { settings, updateSettings, resetData, getAppDataJson, importData, market } = useApp();
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

  const handleBackup = useCallback(async () => {
    try {
      const json = await getAppDataJson();
      await Share.share({ message: json, title: 'portfolio-backup.json' });
    } catch {
      Alert.alert('오류', '데이터를 내보내는 중 오류가 발생했습니다.');
    }
  }, [getAppDataJson]);

  const handleRestore = useCallback(() => {
    Alert.alert(
      '데이터 복원',
      'JSON 가져오기는 expo-document-picker 설치 후 지원됩니다.\n현재 버전에서는 사용할 수 없습니다.',
      [{ text: '확인' }],
    );
  }, []);

  const handleReset = useCallback(() => {
    Alert.alert(
      '데이터 초기화',
      '모든 거래 내역과 설정이 삭제됩니다. 계속하시겠습니까?',
      [
        { text: '취소', style: 'cancel' },
        {
          text: '초기화',
          style: 'destructive',
          onPress: async () => {
            await resetData();
          },
        },
      ],
    );
  }, [resetData]);

  const accentColor = settings.accentColor;

  return (
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
});
