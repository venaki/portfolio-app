import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/auth_provider.dart';
import 'providers/portfolio_provider.dart';
import 'screens/login_screen.dart';
import 'screens/sheet_connect_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/portfolio_screen.dart';
import 'screens/history_screen.dart';
import 'screens/assets_screen.dart';
import 'screens/settings_screen.dart';
import 'widgets/responsive_shell.dart';
import 'widgets/portfolio_status_banner.dart';
import 'utils/constants.dart';

const _devMode = bool.fromEnvironment('DEV_MODE');

class PortfolioApp extends ConsumerWidget {
  const PortfolioApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final portfolio = ref.watch(portfolioProvider);
    final accentColor = hexToColor(portfolio.settings.accentColor);

    return MaterialApp(
      title: 'Portfolio',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFFAFAFA),
        colorScheme: const ColorScheme.light().copyWith(
          primary: accentColor,
          onPrimary: Colors.white,
          surface: const Color(0xFFFFFFFF),
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFFFFFFFF),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFFE5E5E5)),
          ),
        ),
      ),
      home: _devMode
          ? const MainApp()
          : authState.when(
              loading: () => const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              ),
              error: (_, __) => const LoginScreen(),
              data: (user) {
                if (user == null) return const LoginScreen();
                return SheetConnectGate(key: ValueKey(user.uid));
              },
            ),
    );
  }
}

/// 스프레드시트 연결 확인 게이트
class SheetConnectGate extends ConsumerWidget {
  const SheetConnectGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ssId = ref.watch(spreadsheetIdProvider);
    return ssId.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, __) => const SheetConnectScreen(),
      data: (id) {
        if (id == null || id.isEmpty) return const SheetConnectScreen();
        return MainApp(key: ValueKey(id));
      },
    );
  }
}

/// 연결된 사용자/시트 수명에 맞춘 탭 화면.
class MainApp extends ConsumerStatefulWidget {
  const MainApp({super.key});

  @override
  ConsumerState<MainApp> createState() => _MainAppState();
}

class _MainAppState extends ConsumerState<MainApp> with WidgetsBindingObserver {
  int _currentIndex = 0;
  bool _editingPortfolio = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initData();
  }

  Future<void> _initData() async {
    if (_devMode) return; // 이미 PortfolioNotifier 생성자에서 로드됨
    try {
      final ssId = await ref.read(spreadsheetIdProvider.future);
      if (!mounted) return;
      if (ssId != null && ref.read(portfolioProvider).spreadsheetId != ssId) {
        await ref.read(portfolioProvider.notifier).connect(ssId);
      }
    } catch (_) {
      // The connection gate or PortfolioStatusBanner provides retry controls.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    ref
        .read(portfolioProvider.notifier)
        .setForeground(state == AppLifecycleState.resumed);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      const DashboardScreen(),
      PortfolioScreen(
        onEditModeChanged: (value) => setState(() => _editingPortfolio = value),
      ),
      const HistoryScreen(),
      const AssetsScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1280),
          child: ResponsiveShell(
            currentIndex: _currentIndex,
            isEditingPortfolio: _editingPortfolio,
            onTap: (i) => setState(() {
              if (i != _currentIndex) _editingPortfolio = false;
              _currentIndex = i;
            }),
            child: Column(
              children: [
                const PortfolioStatusBanner(),
                Expanded(child: screens[_currentIndex]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
