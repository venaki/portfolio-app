import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../providers/portfolio_provider.dart';
import '../models/app_settings.dart';
import '../utils/constants.dart';
import '../widgets/account_delete_modal.dart';
import '../screens/sheet_connect_screen.dart';

// Conditional import for dart:html (web only)
import 'csv_export_stub.dart' if (dart.library.html) 'csv_export_web.dart'
    as csv_export;

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _accountController = TextEditingController();

  @override
  void dispose() {
    _accountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final portfolio = ref.watch(portfolioProvider);
    final authState = ref.watch(authStateProvider);
    final settings = portfolio.settings;
    final isWide = MediaQuery.of(context).size.width >= 768;
    final hPadding = isWide ? 40.0 : 24.0;

    return ListView(
      padding: EdgeInsets.fromLTRB(hPadding, 0, hPadding, 40),
      children: [
        // Title
        const Padding(
          padding: EdgeInsets.only(top: 16, bottom: 24),
          child: Text(
            '설정',
            style: TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.w500,
              color: Color(0xFF1A1A1A),
            ),
          ),
        ),

        // 1. ACCOUNT
        _sectionLabel('ACCOUNT'),
        _card(
          child: Column(
            children: [
              authState.when(
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
                data: (user) {
                  if (user == null) return const SizedBox.shrink();
                  return Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundImage: user.photoUrl != null
                            ? NetworkImage(user.photoUrl!)
                            : null,
                        child: user.photoUrl == null
                            ? const Icon(Icons.person, size: 20)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.email,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF1A1A1A),
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Google 계정 연결됨',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF888888),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              Center(
                child: GestureDetector(
                  onTap: _signOut,
                  child: const Text(
                    '로그아웃',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF0D6E6E),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),

        // 2. ACCOUNTS
        _sectionLabel('ACCOUNTS'),
        _card(
          child: Column(
            children: [
              ...settings.accounts.asMap().entries.map((entry) {
                final idx = entry.key;
                final name = entry.value;
                return Column(
                  children: [
                    if (idx > 0)
                      const Divider(height: 1, color: Color(0xFFE5E5E5)),
                    GestureDetector(
                      onTap: () => _onAccountTap(name),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                name,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF1A1A1A),
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.close,
                              size: 16,
                              color: Color(0xFFAAAAAA),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              }),
              if (settings.accounts.isNotEmpty)
                const Divider(height: 1, color: Color(0xFFE5E5E5)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _accountController,
                      decoration: InputDecoration(
                        hintText: '명의 이름',
                        hintStyle: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFFAAAAAA),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              const BorderSide(color: Color(0xFFE5E5E5)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              const BorderSide(color: Color(0xFFE5E5E5)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              const BorderSide(color: Color(0xFF0D6E6E)),
                        ),
                        isDense: true,
                      ),
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _addAccount,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D6E6E),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        '추가',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),

        // 3. APPEARANCE
        _sectionLabel('APPEARANCE'),
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '강조 색상',
                style: TextStyle(fontSize: 14, color: Color(0xFF1A1A1A)),
              ),
              const SizedBox(height: 12),
              Row(
                children: accentPresets.map((preset) {
                  final isSelected = '#${preset.color.value.toRadixString(16).substring(2).toUpperCase()}' ==
                          settings.accentColor.toUpperCase() ||
                      hexToColor(settings.accentColor) == preset.color;
                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: GestureDetector(
                      onTap: () => _setAccentColor(preset.color),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: preset.color,
                          shape: BoxShape.circle,
                          border: isSelected
                              ? Border.all(color: const Color(0xFF1A1A1A), width: 2)
                              : null,
                        ),
                        child: isSelected
                            ? const Icon(Icons.check, size: 16, color: Colors.white)
                            : null,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),

        // 4. DATA REFRESH
        _sectionLabel('DATA REFRESH'),
        _card(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '자동 새로고침 간격',
                style: TextStyle(fontSize: 14, color: Color(0xFF1A1A1A)),
              ),
              PopupMenuButton<int>(
                onSelected: _setRefreshInterval,
                itemBuilder: (_) => _refreshOptions.entries
                    .map((e) => PopupMenuItem(
                          value: e.key,
                          child: Text(e.value),
                        ))
                    .toList(),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE5E5E5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _refreshLabel(settings.refreshInterval),
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.keyboard_arrow_down,
                        size: 18,
                        color: Color(0xFF888888),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),

        // 5. DATA & SHEETS
        _sectionLabel('DATA & SHEETS'),
        _card(
          child: Column(
            children: [
              GestureDetector(
                onTap: () => _exportCsv(),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'CSV 내보내기',
                        style: TextStyle(fontSize: 14, color: Color(0xFF1A1A1A)),
                      ),
                      Icon(
                        Icons.download,
                        size: 18,
                        color: Color(0xFF888888),
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1, color: Color(0xFFE5E5E5)),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '연결된 시트',
                      style: TextStyle(fontSize: 14, color: Color(0xFF1A1A1A)),
                    ),
                    GestureDetector(
                      onTap: _changeSheet,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFE5E5E5)),
                        ),
                        child: const Text(
                          '변경',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF666666),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- Section label ---
  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: 'JetBrains Mono',
          fontSize: 11,
          letterSpacing: 2,
          color: Color(0xFF888888),
        ),
      ),
    );
  }

  // --- Card wrapper ---
  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E5E5)),
      ),
      child: child,
    );
  }

  // --- Refresh interval options (seconds → label) ---
  static const _refreshOptions = <int, String>{
    300: '5분',
    600: '10분',
    900: '15분',
    1800: '30분',
    3600: '60분',
  };

  String _refreshLabel(int seconds) {
    return _refreshOptions[seconds] ?? '${seconds ~/ 60}분';
  }

  // --- Actions ---

  Future<void> _signOut() async {
    await ref.read(authStateProvider.notifier).signOut();
  }

  void _addAccount() {
    final name = _accountController.text.trim();
    if (name.isEmpty) return;
    final settings = ref.read(portfolioProvider).settings;
    if (settings.accounts.contains(name)) return;
    final newSettings =
        settings.copyWith(accounts: [...settings.accounts, name]);
    ref.read(portfolioProvider.notifier).updateSettings(newSettings);
    _accountController.clear();
  }

  void _onAccountTap(String name) {
    final txs = ref.read(portfolioProvider).transactions;
    final count = txs.where((t) => t.account == name).length;
    final blocked = count > 0;

    showDialog(
      context: context,
      builder: (_) => AccountDeleteModal(
        accountName: name,
        isBlocked: blocked,
        transactionCount: count,
        onConfirm: blocked
            ? null
            : () {
                final settings = ref.read(portfolioProvider).settings;
                final newAccounts =
                    settings.accounts.where((a) => a != name).toList();
                ref.read(portfolioProvider.notifier).updateSettings(
                      settings.copyWith(accounts: newAccounts),
                    );
              },
      ),
    );
  }

  void _setAccentColor(Color color) {
    final hex =
        '#${color.value.toRadixString(16).substring(2).toUpperCase()}';
    final settings = ref.read(portfolioProvider).settings;
    ref
        .read(portfolioProvider.notifier)
        .updateSettings(settings.copyWith(accentColor: hex));
  }

  void _setRefreshInterval(int seconds) {
    final settings = ref.read(portfolioProvider).settings;
    ref
        .read(portfolioProvider.notifier)
        .updateSettings(settings.copyWith(refreshInterval: seconds));
  }

  void _exportCsv() {
    final txs = ref.read(portfolioProvider).transactions;
    csv_export.downloadCsv(txs);
  }

  void _changeSheet() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SheetConnectScreen()),
    );
  }
}
