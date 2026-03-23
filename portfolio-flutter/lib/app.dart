import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/auth_provider.dart';
import 'providers/portfolio_provider.dart';
import 'screens/login_screen.dart';
import 'screens/sheet_connect_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/portfolio_screen.dart';
import 'widgets/custom_tab_bar.dart';

class PortfolioApp extends ConsumerWidget {
  const PortfolioApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return MaterialApp(
      title: 'Portfolio',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFFAFAFA),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0D6E6E),
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
      home: authState.when(
        loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (_, __) => const LoginScreen(),
        data: (user) {
          if (user == null) return const LoginScreen();
          return const SheetConnectGate();
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
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, __) => const SheetConnectScreen(),
      data: (id) {
        if (id == null || id.isEmpty) return const SheetConnectScreen();
        return const MainApp();
      },
    );
  }
}

/// 메인 앱 (탭 네비게이션) — Phase 1에서는 대시보드와 포트폴리오만
class MainApp extends ConsumerStatefulWidget {
  const MainApp({super.key});

  @override
  ConsumerState<MainApp> createState() => _MainAppState();
}

class _MainAppState extends ConsumerState<MainApp> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    final ssId = await ref.read(spreadsheetIdProvider.future);
    if (ssId != null) {
      await ref.read(portfolioProvider.notifier).connect(ssId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      const DashboardScreen(),
      const PortfolioScreen(),
      const Placeholder(), // History — Phase 2
      const Placeholder(), // Other Assets — Phase 2
      const Placeholder(), // Settings — Phase 2
    ];

    return Scaffold(
      body: Column(
        children: [
          Expanded(child: screens[_currentIndex]),
          CustomTabBar(
            currentIndex: _currentIndex,
            onTap: (i) => setState(() => _currentIndex = i),
          ),
        ],
      ),
    );
  }
}
