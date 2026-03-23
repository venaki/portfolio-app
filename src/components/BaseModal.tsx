import { Modal, Pressable, View, StyleSheet, ViewStyle } from 'react-native';
import { COLORS } from '../constants';

interface Props {
  visible: boolean;
  onClose: () => void;
  children: React.ReactNode;
  cardStyle?: ViewStyle;
}

export function BaseModal({ visible, onClose, children, cardStyle }: Props) {
  return (
    <Modal visible={visible} transparent animationType="fade" onRequestClose={onClose}>
      <Pressable style={styles.overlay} onPress={onClose}>
        <View style={[styles.card, cardStyle]} onStartShouldSetResponder={() => true}>
          {children}
        </View>
      </Pressable>
    </Modal>
  );
}

const styles = StyleSheet.create({
  overlay: {
    flex: 1,
    backgroundColor: 'rgba(0,0,0,0.4)',
    justifyContent: 'center',
    alignItems: 'center',
  },
  card: {
    backgroundColor: COLORS.card,
    borderRadius: 16,
    padding: 24,
    width: 320,
    maxWidth: '90%' as any,
  },
});
