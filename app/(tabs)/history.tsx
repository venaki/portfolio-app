import { View, Text, StyleSheet } from 'react-native';
import { COLORS } from '../../src/constants';

export default function History() {
  return (
    <View style={styles.container}>
      <Text style={styles.text}>거래내역</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, justifyContent: 'center', alignItems: 'center', backgroundColor: COLORS.background },
  text: { fontFamily: 'Newsreader_500Medium', fontSize: 24, color: COLORS.textPrimary },
});
