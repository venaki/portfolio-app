import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../providers/auth_provider.dart';
import '../providers/portfolio_provider.dart';
import '../models/app_settings.dart';
import '../utils/constants.dart';
import '../widgets/form_fields.dart';
import '../services/portfolio_backup.dart';
import '../services/file_transfer.dart';
import '../services/historical_prices.dart';
import 'sheet_connect_screen.dart';
import 'csv_export_stub.dart'
    if (dart.library.html) 'csv_export_web.dart'
    as csv_export;

bool accountHasRecords(PortfolioState state, String account) =>
    state.transactions.any((tx) => tx.account == account) ||
    state.otherAssets.any((asset) => asset.account == account);

String? validateSettingsName(String value) {
  if (value.trim().isEmpty) return '이름을 입력해주세요';
  if (value.trim() == '전체') return '전체는 필터에서 사용하는 이름입니다';
  if (RegExp(r'[,|:]').hasMatch(value)) return '이름에 쉼표, |, :를 사용할 수 없습니다';
  return null;
}

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});
  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _account = TextEditingController(), _broker = TextEditingController();
  late final _packageInfo = PackageInfo.fromPlatform();
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    _account.dispose();
    _broker.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (error) {
      if (mounted) setState(() => _error = '작업 실패: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save(AppSettings settings) =>
      _run(() => ref.read(portfolioProvider.notifier).updateSettings(settings));

  Future<void> _add(bool account) async {
    final controller = account ? _account : _broker;
    final name = controller.text.trim();
    final error = validateSettingsName(name);
    final settings = ref.read(portfolioProvider).settings;
    final names = account ? settings.accounts : settings.brokers;
    if (error != null || names.contains(name)) {
      setState(() => _error = error ?? '이미 등록된 이름입니다');
      return;
    }
    await _run(() async {
      await ref
          .read(portfolioProvider.notifier)
          .updateSettings(
            account
                ? settings.copyWith(accounts: [...names, name])
                : settings.copyWith(brokers: [...names, name]),
          );
      controller.clear();
    });
  }

  Future<void> _remove(String name, bool account) async {
    final state = ref.read(portfolioProvider);
    final used = account
        ? accountHasRecords(state, name)
        : state.transactions.any((tx) => tx.broker == name);
    if (used) {
      setState(
        () =>
            _error = '연결된 주식 또는 기타자산 내역이 있어 삭제할 수 없습니다. 내역의 명의·증권사를 먼저 변경해주세요.',
      );
      return;
    }
    if (!await confirmDelete(context, '$name 삭제') || !mounted) return;
    final settings = ref.read(portfolioProvider).settings;
    await _save(
      account
          ? settings.copyWith(
              accounts: settings.accounts
                  .where((value) => value != name)
                  .toList(),
            )
          : settings.copyWith(
              brokers: settings.brokers
                  .where((value) => value != name)
                  .toList(),
            ),
    );
  }

  Future<void> _exportBackup() => _run(() async {
    final backup = await ref.read(portfolioProvider.notifier).createBackup();
    downloadText(
      text: backup.toJsonText(),
      fileName:
          'portfolio-backup-${DateTime.now().toIso8601String().substring(0, 10)}.json',
    );
  });

  Future<void> _importBackup() => _run(() async {
    final text = await pickTextFile();
    if (text == null || !mounted) return;
    final backup = PortfolioBackup.fromJsonText(text);
    backup.validate();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('백업 복원 미리보기'),
        content: SingleChildScrollView(
          child: Text(
            '${backup.summary}\n\n현재 연결된 시트의 데이터를 이 백업으로 대체합니다. 복원 전에 현재 백업을 내려받아 보관해주세요.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('데이터 대체 및 복원'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await ref.read(portfolioProvider.notifier).restoreBackup(backup);
    }
  });

  Future<void> _importPrices() => _run(() async {
    final text = await pickTextFile(accept: '.csv,.json');
    if (text == null || !mounted) return;
    final prices = HistoricalPriceImport.fromText(text);
    final rows = prices.toRows();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('과거 가격 가져오기'),
        content: Text(
          '${prices.summary}\n${rows.isEmpty ? '' : '${rows.first[0]} ~ ${rows.last[0]}'}\n같은 날짜·종목 가격은 파일의 값으로 반영합니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('가격 기록 반영'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await ref.read(portfolioProvider.notifier).importHistoricalPrices(prices);
    }
  });

  @override
  Widget build(BuildContext context) {
    final portfolio = ref.watch(portfolioProvider);
    final authState = ref.watch(authStateProvider);
    final disabled =
        _busy ||
        portfolio.isLoading ||
        portfolio.isSaving ||
        portfolio.isBackfilling;
    final writeDisabled = disabled || !portfolio.canWrite;
    final settings = portfolio.settings;
    final accentColor = Theme.of(context).colorScheme.primary;
    final isWide = MediaQuery.of(context).size.width >= 1024;
    final hPadding = isWide ? 40.0 : 24.0;

    return ListView(
      padding: EdgeInsets.fromLTRB(hPadding, 0, hPadding, 40),
      children: [
        const SizedBox(height: 16),
        if (_busy) const LinearProgressIndicator(),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              _error!,
              style: const TextStyle(fontSize: 13, color: Color(0xFFD32F2F)),
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
                        backgroundImage: user.photoURL != null
                            ? NetworkImage(user.photoURL!)
                            : null,
                        child: user.photoURL == null
                            ? const Icon(Icons.person, size: 20)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.email ?? '',
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
              Center(
                child: GestureDetector(
                  onTap: disabled
                      ? null
                      : () => _run(
                          () => ref.read(authStateProvider.notifier).signOut(),
                        ),
                  child: Text(
                    '로그아웃',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: accentColor,
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
              if (settings.accounts.isNotEmpty)
                ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  buildDefaultDragHandles: false,
                  itemCount: settings.accounts.length,
                  proxyDecorator: (child, index, animation) {
                    return Material(
                      elevation: 2,
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      child: child,
                    );
                  },
                  onReorder: (oldIndex, newIndex) {
                    if (!writeDisabled) _reorderAccounts(oldIndex, newIndex);
                  },
                  itemBuilder: (context, idx) {
                    final name = settings.accounts[idx];
                    return Column(
                      key: ValueKey(name),
                      children: [
                        if (idx > 0)
                          const Divider(height: 1, color: Color(0xFFE5E5E5)),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Row(
                            children: [
                              ReorderableDragStartListener(
                                index: idx,
                                child: const Padding(
                                  padding: EdgeInsets.only(right: 12),
                                  child: Icon(
                                    Icons.drag_handle,
                                    size: 18,
                                    color: Color(0xFFCCCCCC),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  name,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF1A1A1A),
                                  ),
                                ),
                              ),
                              GestureDetector(
                                onTap: writeDisabled
                                    ? null
                                    : () => _remove(name, true),
                                child: const Icon(
                                  Icons.close,
                                  size: 16,
                                  color: Color(0xFFAAAAAA),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              if (settings.accounts.isNotEmpty)
                const Divider(height: 1, color: Color(0xFFE5E5E5)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _account,
                      enabled: !writeDisabled,
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
                          borderSide: const BorderSide(
                            color: Color(0xFFE5E5E5),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: Color(0xFFE5E5E5),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: accentColor),
                        ),
                        isDense: true,
                      ),
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: writeDisabled ? null : () => _add(true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: accentColor,
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

        // 3. INVESTMENT BANKS
        _sectionLabel('INVESTMENT BANKS'),
        _card(
          child: Column(
            children: [
              ...settings.brokers.asMap().entries.map((entry) {
                final idx = entry.key;
                final name = entry.value;
                return Column(
                  children: [
                    if (idx > 0)
                      const Divider(height: 1, color: Color(0xFFE5E5E5)),
                    GestureDetector(
                      onTap: writeDisabled ? null : () => _remove(name, false),
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
              if (settings.brokers.isNotEmpty)
                const Divider(height: 1, color: Color(0xFFE5E5E5)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _broker,
                      enabled: !writeDisabled,
                      decoration: InputDecoration(
                        hintText: '증권사',
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
                          borderSide: const BorderSide(
                            color: Color(0xFFE5E5E5),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: Color(0xFFE5E5E5),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: accentColor),
                        ),
                        isDense: true,
                      ),
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: writeDisabled ? null : () => _add(false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: accentColor,
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

        // 4. APPEARANCE
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
                  final isSelected =
                      '#${preset.color.toARGB32().toRadixString(16).substring(2).toUpperCase()}' ==
                          settings.accentColor.toUpperCase() ||
                      hexToColor(settings.accentColor) == preset.color;
                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: GestureDetector(
                      onTap: writeDisabled
                          ? null
                          : () => _save(
                              settings.copyWith(
                                accentColor:
                                    '#${preset.color.toARGB32().toRadixString(16).substring(2)}',
                              ),
                            ),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: preset.color,
                          shape: BoxShape.circle,
                          border: isSelected
                              ? Border.all(
                                  color: const Color(0xFF1A1A1A),
                                  width: 2,
                                )
                              : null,
                        ),
                        child: isSelected
                            ? const Icon(
                                Icons.check,
                                size: 16,
                                color: Colors.white,
                              )
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
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '자동 새로고침 간격',
                    style: TextStyle(fontSize: 14, color: Color(0xFF1A1A1A)),
                  ),
                  PopupMenuButton<int>(
                    enabled: !writeDisabled,
                    onSelected: (value) =>
                        _save(settings.copyWith(refreshInterval: value)),
                    itemBuilder: (_) => _refreshOptions.entries
                        .map(
                          (e) =>
                              PopupMenuItem(value: e.key, child: Text(e.value)),
                        )
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
              const Divider(height: 24, color: Color(0xFFE5E5E5)),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '강제 새로고침 대기',
                    style: TextStyle(fontSize: 14, color: Color(0xFF1A1A1A)),
                  ),
                  PopupMenuButton<int>(
                    enabled: !writeDisabled,
                    onSelected: (value) =>
                        _save(settings.copyWith(forceRefreshWait: value)),
                    itemBuilder: (_) => _forceRefreshWaitOptions.entries
                        .map(
                          (e) =>
                              PopupMenuItem(value: e.key, child: Text(e.value)),
                        )
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
                            _forceRefreshWaitLabel(settings.forceRefreshWait),
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
                onTap: disabled
                    ? null
                    : () => _run(
                        () async =>
                            csv_export.downloadCsv(portfolio.transactions),
                      ),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'CSV 내보내기',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      Icon(Icons.download, size: 18, color: Color(0xFF888888)),
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
                      onTap: disabled
                          ? null
                          : () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const SheetConnectScreen(),
                              ),
                            ),
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
              if (portfolio.spreadsheetId != null) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    portfolio.spreadsheetName ?? portfolio.spreadsheetId!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF888888),
                    ),
                  ),
                ),
                _dataAction('시트 URL 복사', Icons.copy, () async {
                  await Clipboard.setData(
                    ClipboardData(
                      text:
                          'https://docs.google.com/spreadsheets/d/${portfolio.spreadsheetId}/edit',
                    ),
                  );
                }),
              ],
              _dataAction(
                '전체 데이터 다시 불러오기',
                Icons.sync,
                disabled
                    ? null
                    : () => _run(
                        () => ref.read(portfolioProvider.notifier).loadAll(),
                      ),
              ),
              _dataAction(
                '과거 가격 CSV 가져오기',
                Icons.upload_file,
                writeDisabled ? null : _importPrices,
              ),
              _dataAction(
                '전체 백업 내보내기',
                Icons.download,
                disabled ? null : _exportBackup,
              ),
              _dataAction(
                '백업 파일 복원',
                Icons.upload_file,
                disabled ? null : _importBackup,
              ),
            ],
          ),
        ),
        const SizedBox(height: 40),

        // Version
        FutureBuilder<PackageInfo>(
          future: _packageInfo,
          builder: (context, snapshot) {
            final version = snapshot.data?.version ?? '';
            return Center(
              child: Text(
                'v$version',
                style: const TextStyle(fontSize: 11, color: Color(0xFFAAAAAA)),
              ),
            );
          },
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

  // --- Force refresh wait options (seconds → label) ---
  static const _forceRefreshWaitOptions = <int, String>{
    1: '1초',
    3: '3초',
    5: '5초',
    10: '10초',
  };

  String _forceRefreshWaitLabel(int seconds) {
    return _forceRefreshWaitOptions[seconds] ?? '$seconds초';
  }

  // --- Actions ---

  void _reorderAccounts(int oldIndex, int newIndex) {
    final settings = ref.read(portfolioProvider).settings;
    final accounts = [...settings.accounts];
    if (newIndex > oldIndex) newIndex--;
    final value = accounts.removeAt(oldIndex);
    accounts.insert(newIndex, value);
    _save(settings.copyWith(accounts: accounts));
  }

  Widget _dataAction(String title, IconData icon, VoidCallback? onTap) =>
      Column(
        children: [
          const Divider(height: 1, color: Color(0xFFE5E5E5)),
          InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                  ),
                  Icon(icon, size: 18, color: const Color(0xFF888888)),
                ],
              ),
            ),
          ),
        ],
      );
}
