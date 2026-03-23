import { useCallback, useState } from 'react';
import { View, Text, TextInput, Pressable, Alert, StyleSheet } from 'react-native';
import { useApp } from '../context/AppContext';
import { COLORS } from '../constants';
import { BaseModal } from './BaseModal';

interface Props {
  accentColor: string;
}

export function AccountManager({ accentColor }: Props) {
  const { accounts, addAccount, removeAccount, transactions } = useApp();
  const [newAccountName, setNewAccountName] = useState('');
  const [removeModal, setRemoveModal] = useState<{ visible: boolean; name: string; blocked: boolean; count: number }>({ visible: false, name: '', blocked: false, count: 0 });

  const handleAdd = useCallback(async () => {
    const name = newAccountName.trim();
    if (!name) return;
    if (accounts.includes(name)) {
      Alert.alert('알림', '이미 존재하는 명의입니다.');
      return;
    }
    await addAccount(name);
    setNewAccountName('');
  }, [newAccountName, accounts, addAccount]);

  const handleRemove = useCallback((name: string) => {
    const count = transactions.filter(t => t.owner === name).length;
    if (count > 0) {
      setRemoveModal({ visible: true, name, blocked: true, count });
    } else {
      setRemoveModal({ visible: true, name, blocked: false, count: 0 });
    }
  }, [transactions]);

  const confirmRemove = useCallback(async () => {
    await removeAccount(removeModal.name);
    setRemoveModal({ visible: false, name: '', blocked: false, count: 0 });
  }, [removeAccount, removeModal.name]);

  const closeModal = () => setRemoveModal(prev => ({ ...prev, visible: false }));

  return (
    <>
      <View style={styles.section}>
        <Text style={styles.sectionLabel}>ACCOUNTS</Text>
        <View style={styles.card}>
          {accounts.map((account, idx) => (
            <View key={account}>
              {idx > 0 && <View style={styles.divider} />}
              <View style={styles.accountRow}>
                <Text style={styles.fieldLabel}>{account}</Text>
                <Pressable onPress={() => handleRemove(account)} hitSlop={8}>
                  <Text style={styles.removeBtn}>✕</Text>
                </Pressable>
              </View>
            </View>
          ))}
          {accounts.length > 0 && <View style={styles.divider} />}
          <View style={styles.addRow}>
            <TextInput
              style={styles.input}
              value={newAccountName}
              onChangeText={setNewAccountName}
              placeholder="새 명의 입력"
              placeholderTextColor={COLORS.textMuted}
              onSubmitEditing={handleAdd}
            />
            <Pressable
              style={[styles.addBtn, { backgroundColor: accentColor }]}
              onPress={handleAdd}
            >
              <Text style={styles.addBtnText}>추가</Text>
            </Pressable>
          </View>
        </View>
      </View>

      <BaseModal visible={removeModal.visible} onClose={closeModal}>
        <Text style={styles.modalTitle}>명의 삭제</Text>
        {removeModal.blocked ? (
          <>
            <Text style={styles.modalMessage}>
              "{removeModal.name}" 명의에 {removeModal.count}건의 거래내역이 있어 삭제할 수 없습니다.
            </Text>
            <Text style={styles.modalHint}>거래내역을 먼저 삭제해주세요.</Text>
            <Pressable
              style={[styles.modalBtn, { backgroundColor: accentColor }]}
              onPress={closeModal}
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
              <Pressable style={[styles.modalBtn, styles.modalBtnCancel]} onPress={closeModal}>
                <Text style={styles.modalBtnCancelText}>취소</Text>
              </Pressable>
              <Pressable style={[styles.modalBtn, styles.modalBtnDestructive]} onPress={confirmRemove}>
                <Text style={styles.modalBtnText}>삭제</Text>
              </Pressable>
            </View>
          </>
        )}
      </BaseModal>
    </>
  );
}

const styles = StyleSheet.create({
  section: { marginBottom: 32 },
  sectionLabel: {
    fontWeight: '600',
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
    fontWeight: '500',
    fontSize: 13,
    color: COLORS.textPrimary,
  },
  divider: {
    height: 1,
    backgroundColor: COLORS.divider,
    marginVertical: 12,
  },
  accountRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingVertical: 4,
  },
  removeBtn: {
    fontWeight: '500',
    fontSize: 14,
    color: COLORS.textTertiary,
    paddingHorizontal: 4,
  },
  addRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
    paddingVertical: 4,
  },
  input: {
    flex: 1,
    backgroundColor: COLORS.inputBg,
    borderRadius: 8,
    paddingHorizontal: 12,
    paddingVertical: 8,
    fontSize: 13,
    color: COLORS.textPrimary,
  },
  addBtn: {
    paddingHorizontal: 14,
    paddingVertical: 8,
    borderRadius: 8,
  },
  addBtnText: {
    fontWeight: '600',
    fontSize: 13,
    color: COLORS.white,
  },
  modalTitle: {
    fontWeight: '600',
    fontSize: 16,
    color: COLORS.textPrimary,
    marginBottom: 12,
  },
  modalMessage: {
    fontSize: 14,
    color: COLORS.textSecondary,
    lineHeight: 20,
    marginBottom: 8,
  },
  modalHint: {
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
    fontWeight: '500',
    fontSize: 14,
    color: COLORS.textSecondary,
  },
  modalBtnDestructive: {
    backgroundColor: '#E07B54',
  },
  modalBtnText: {
    fontWeight: '500',
    fontSize: 14,
    color: COLORS.white,
  },
});
