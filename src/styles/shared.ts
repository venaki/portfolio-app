import { StyleSheet } from 'react-native';
import { COLORS } from '../constants';

/** 반복되는 카드 기본 스타일 */
export const CARD_BASE = {
  backgroundColor: COLORS.card,
  borderRadius: 12,
  borderWidth: 1,
  borderColor: COLORS.border,
  padding: 16,
} as const;

/** 소형 배지 (owner, type 등) */
export const BADGE = StyleSheet.create({
  container: {
    backgroundColor: COLORS.muted,
    borderRadius: 4,
    paddingHorizontal: 5,
    paddingVertical: 1,
  },
  text: {
    fontWeight: '500',
    fontSize: 10,
    color: COLORS.textTertiary,
  },
});

/** 섹션 라벨 (ACCOUNTS, APPEARANCE 등) */
export const SECTION = StyleSheet.create({
  label: {
    fontWeight: '600',
    fontSize: 11,
    color: COLORS.textTertiary,
    letterSpacing: 2,
    marginBottom: 10,
  },
});

/** 모달 공통 스타일 */
export const MODAL = StyleSheet.create({
  title: {
    fontWeight: '500',
    fontSize: 20,
    color: COLORS.textPrimary,
    marginBottom: 20,
  },
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 20,
  },
  closeX: {
    fontWeight: '500',
    fontSize: 20,
    color: COLORS.textMuted,
    padding: 4,
  },
  fieldLabel: {
    fontWeight: '500',
    fontSize: 13,
    color: COLORS.textPrimary,
    marginBottom: 6,
  },
  input: {
    backgroundColor: COLORS.inputBg,
    borderRadius: 8,
    paddingHorizontal: 14,
    paddingVertical: 12,
    fontVariant: ['tabular-nums'],
    fontSize: 13,
    color: COLORS.textPrimary,
  },
  buttons: {
    flexDirection: 'row',
    gap: 12,
    marginTop: 24,
  },
  btnPrimary: {
    flex: 1,
    paddingVertical: 12,
    borderRadius: 8,
    alignItems: 'center',
  },
  btnPrimaryText: {
    fontWeight: '600',
    fontSize: 14,
    color: COLORS.white,
  },
  btnSecondary: {
    flex: 1,
    paddingVertical: 12,
    borderRadius: 8,
    alignItems: 'center',
    borderWidth: 1,
    borderColor: COLORS.border,
  },
  btnSecondaryText: {
    fontWeight: '500',
    fontSize: 14,
    color: COLORS.textSecondary,
  },
});

/** 페이지 헤더 타이틀 */
export const PAGE = StyleSheet.create({
  title: {
    fontWeight: '500',
    fontSize: 22,
    color: COLORS.textPrimary,
  },
  addBtn: {
    paddingHorizontal: 14,
    paddingVertical: 7,
    borderRadius: 8,
  },
  addBtnText: {
    fontWeight: '600',
    fontSize: 13,
    color: COLORS.white,
  },
  emptyContainer: {
    paddingVertical: 48,
    alignItems: 'center',
  },
  emptyText: {
    fontSize: 14,
    color: COLORS.textTertiary,
  },
});
