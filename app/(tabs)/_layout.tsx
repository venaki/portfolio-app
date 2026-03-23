import { Tabs } from 'expo-router';
import { View, StyleSheet } from 'react-native';
import { House, ChartBar, Clock3, Wallet, Settings } from 'lucide-react-native';
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
            <Tabs.Screen name="other-assets" />
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
        paddingTop: 0,
        paddingBottom: 0,
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
        overflow: 'hidden',
      },
      tabBarActiveBackgroundColor: settings.accentColor,
      tabBarLabelStyle: {
        fontFamily: 'Inter_600SemiBold',
        fontSize: 10,
        textTransform: 'uppercase',
        letterSpacing: 0.5,
      },
      tabBarIconStyle: {
        marginBottom: -2,
      },
    }}>
      <Tabs.Screen name="index" options={{
        title: 'Home',
        tabBarIcon: ({ color }) => <House size={18} color={color} />,
      }} />
      <Tabs.Screen name="portfolio" options={{
        title: 'Portfolio',
        tabBarIcon: ({ color }) => <ChartBar size={18} color={color} />,
      }} />
      <Tabs.Screen name="history" options={{
        title: 'History',
        tabBarIcon: ({ color }) => <Clock3 size={18} color={color} />,
      }} />
      <Tabs.Screen name="other-assets" options={{
        title: 'Assets',
        tabBarIcon: ({ color }) => <Wallet size={18} color={color} />,
      }} />
      <Tabs.Screen name="settings" options={{
        title: 'Settings',
        tabBarIcon: ({ color }) => <Settings size={18} color={color} />,
      }} />
    </Tabs>
  );
}

const styles = StyleSheet.create({
  pcLayout: { flex: 1, flexDirection: 'row', backgroundColor: COLORS.background },
  pcContent: { flex: 1 },
});
