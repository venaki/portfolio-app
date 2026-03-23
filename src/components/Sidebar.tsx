import { View, Text, Pressable, StyleSheet } from 'react-native';
import { usePathname, router } from 'expo-router';
import { useApp } from '../context/AppContext';
import { COLORS } from '../constants';

const NAV_ITEMS = [
  { label: '대시보드', path: '/' },
  { label: '포트폴리오', path: '/portfolio' },
  { label: '거래내역', path: '/history' },
  { label: '기타 자산', path: '/other-assets' },
  { label: '설정', path: '/settings' },
];

export function Sidebar() {
  const pathname = usePathname();
  const { settings } = useApp();

  return (
    <View style={styles.container}>
      <View style={styles.logo}>
        <Text style={styles.logoText}>Portfolio</Text>
      </View>
      <View style={styles.nav}>
        {NAV_ITEMS.map(item => {
          const isActive = pathname === item.path || (item.path === '/' && (pathname === '' || pathname === '/'));
          return (
            <Pressable
              key={item.path}
              style={[styles.navItem, isActive && { backgroundColor: settings.accentColor }]}
              onPress={() => router.push(item.path as any)}
            >
              <Text style={[styles.navLabel, isActive && styles.navLabelActive]}>
                {item.label}
              </Text>
            </Pressable>
          );
        })}
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    width: 240,
    backgroundColor: COLORS.card,
    borderRightWidth: 1,
    borderRightColor: COLORS.border,
    paddingVertical: 32,
    paddingHorizontal: 20,
    gap: 32,
  },
  logo: { flexDirection: 'row', alignItems: 'center', gap: 10 },
  logoText: { fontWeight: '500', fontSize: 22, color: COLORS.textPrimary },
  nav: { gap: 4 },
  navItem: { flexDirection: 'row', alignItems: 'center', paddingVertical: 10, paddingHorizontal: 14, borderRadius: 8, gap: 10 },
  navLabel: { fontWeight: '500', fontSize: 14, color: COLORS.textSecondary },
  navLabelActive: { fontWeight: '600', color: COLORS.white },
});
