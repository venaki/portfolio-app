import { Tabs } from 'expo-router';
import { View, StyleSheet } from 'react-native';
import { useResponsive } from '../../src/hooks/useResponsive';
import { useApp } from '../../src/context/AppContext';
import { Sidebar } from '../../src/components/Sidebar';
import { COLORS } from '../../src/constants';

export default function TabsLayout() {
  const { isMobile } = useResponsive();
  const { settings } = useApp();

  if (!isMobile) {
    return (
      <View style={styles.pcLayout}>
        <Sidebar />
        <View style={styles.pcContent}>
          <Tabs screenOptions={{
            headerShown: false,
            tabBarStyle: { display: 'none' },
          }}>
            <Tabs.Screen name="index" />
            <Tabs.Screen name="portfolio" />
            <Tabs.Screen name="history" />
            <Tabs.Screen name="assets" />
            <Tabs.Screen name="settings" />
          </Tabs>
        </View>
      </View>
    );
  }

  return (
    <Tabs screenOptions={{
      headerShown: false,
      tabBarActiveTintColor: '#FFFFFF',
      tabBarInactiveTintColor: COLORS.textMuted,
      tabBarStyle: {
        position: 'absolute',
        backgroundColor: COLORS.card,
        borderTopWidth: 0,
        borderRadius: 36,
        marginHorizontal: 21,
        marginBottom: 21,
        height: 62,
        elevation: 8,
        shadowColor: '#000',
        shadowOpacity: 0.08,
        shadowRadius: 12,
        shadowOffset: { width: 0, height: 2 },
        borderWidth: 1,
        borderColor: COLORS.border,
      },
      tabBarItemStyle: {
        borderRadius: 26,
        margin: 4,
      },
      tabBarActiveBackgroundColor: settings.accentColor,
      tabBarLabelStyle: {
        fontFamily: 'Inter_600SemiBold',
        fontSize: 10,
        textTransform: 'uppercase',
        letterSpacing: 0.5,
      },
    }}>
      <Tabs.Screen name="index" options={{ title: 'Home' }} />
      <Tabs.Screen name="portfolio" options={{ title: 'Portfolio' }} />
      <Tabs.Screen name="history" options={{ title: 'History' }} />
      <Tabs.Screen name="assets" options={{ title: 'Assets' }} />
      <Tabs.Screen name="settings" options={{ title: 'Settings' }} />
    </Tabs>
  );
}

const styles = StyleSheet.create({
  pcLayout: { flex: 1, flexDirection: 'row', backgroundColor: COLORS.background },
  pcContent: { flex: 1 },
});
