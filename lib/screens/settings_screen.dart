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
    final state = ref.watch(portfolioProvider);
    final settings = state.settings;
    final user = ref.watch(authStateProvider).asData?.value;
    final disabled =
        _busy || state.isLoading || state.isSaving || state.isBackfilling;
    final writeDisabled = disabled || !state.canWrite;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        if (_busy) const LinearProgressIndicator(),
        if (_error != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ),
        _section('계정', [
          if (user != null)
            ListTile(
              leading: const Icon(Icons.person),
              title: Text(user.email ?? ''),
              subtitle: const Text('Google 계정 연결됨'),
            ),
          TextButton(
            onPressed: disabled
                ? null
                : () => _run(
                    () => ref.read(authStateProvider.notifier).signOut(),
                  ),
            child: const Text('로그아웃'),
          ),
        ]),
        _section('명의', [
          if (settings.accounts.isEmpty)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('거래와 자산을 추가하려면 명의를 먼저 등록해주세요.'),
            ),
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: settings.accounts.length,
            onReorder: (oldIndex, newIndex) async {
              if (writeDisabled) return;
              final accounts = [...settings.accounts];
              if (newIndex > oldIndex) newIndex--;
              accounts.insert(newIndex, accounts.removeAt(oldIndex));
              await _save(settings.copyWith(accounts: accounts));
            },
            itemBuilder: (_, index) {
              final name = settings.accounts[index];
              return ListTile(
                key: ValueKey(name),
                title: Text(name),
                trailing: Padding(
                  padding: const EdgeInsets.only(right: 28),
                  child: IconButton(
                    tooltip: '$name 삭제',
                    onPressed: writeDisabled ? null : () => _remove(name, true),
                    icon: const Icon(Icons.close),
                  ),
                ),
              );
            },
          ),
          _nameInput(_account, '명의 이름', writeDisabled, () => _add(true)),
        ]),
        _section('증권사', [
          for (final broker in settings.brokers)
            ListTile(
              title: Text(broker),
              trailing: IconButton(
                tooltip: '$broker 삭제',
                onPressed: writeDisabled ? null : () => _remove(broker, false),
                icon: const Icon(Icons.close),
              ),
            ),
          _nameInput(_broker, '증권사 이름', writeDisabled, () => _add(false)),
        ]),
        _section('화면', [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: accentPresets
                  .map(
                    (preset) => IconButton(
                      tooltip:
                          '강조 색상 ${preset.color.toARGB32().toRadixString(16)}',
                      style: IconButton.styleFrom(
                        backgroundColor: preset.color,
                      ),
                      onPressed: writeDisabled
                          ? null
                          : () => _save(
                              settings.copyWith(
                                accentColor:
                                    '#${preset.color.toARGB32().toRadixString(16).substring(2)}',
                              ),
                            ),
                      icon: Icon(
                        hexToColor(settings.accentColor) == preset.color
                            ? Icons.check
                            : Icons.circle,
                        color: Colors.white,
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ]),
        _section('데이터 새로고침', [
          ListTile(
            title: const Text('시세 자동 새로고침'),
            trailing: DropdownButton<int>(
              value: settings.refreshInterval,
              onChanged: writeDisabled
                  ? null
                  : (value) {
                      if (value != null) {
                        _save(settings.copyWith(refreshInterval: value));
                      }
                    },
              items:
                  {
                        ...[60, 300, 600, 900, 1800, 3600],
                        settings.refreshInterval,
                      }
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text('${value ~/ 60}분'),
                        ),
                      )
                      .toList(),
            ),
          ),
          ListTile(
            title: const Text('강제 시세 갱신 대기'),
            trailing: DropdownButton<int>(
              value: settings.forceRefreshWait,
              onChanged: writeDisabled
                  ? null
                  : (value) {
                      if (value != null) {
                        _save(settings.copyWith(forceRefreshWait: value));
                      }
                    },
              items:
                  {
                        ...[1, 3, 5, 10],
                        settings.forceRefreshWait,
                      }
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text('$value초'),
                        ),
                      )
                      .toList(),
            ),
          ),
          ListTile(
            title: const Text('전체 데이터 다시 불러오기'),
            subtitle: const Text('시트에서 직접 수정한 거래와 자산도 반영합니다.'),
            trailing: const Icon(Icons.sync),
            onTap: disabled
                ? null
                : () => _run(
                    () => ref.read(portfolioProvider.notifier).loadAll(),
                  ),
          ),
        ]),
        _section('시트와 백업', [
          ListTile(
            title: Text(state.spreadsheetName ?? '연결된 시트'),
            subtitle: Text(state.spreadsheetId ?? '시트를 연결해주세요'),
            trailing: const Icon(Icons.chevron_right),
            onTap: disabled
                ? null
                : () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SheetConnectScreen(),
                    ),
                  ),
          ),
          if (state.spreadsheetId != null)
            ListTile(
              title: const Text('시트 URL 복사'),
              trailing: const Icon(Icons.copy),
              onTap: () async {
                await Clipboard.setData(
                  ClipboardData(
                    text:
                        'https://docs.google.com/spreadsheets/d/${state.spreadsheetId}/edit',
                  ),
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('시트 URL을 복사했습니다.')),
                  );
                }
              },
            ),
          ListTile(
            title: const Text('과거 가격 CSV 가져오기'),
            subtitle: const Text('date,ticker,price · USDKRW는 원/달러 환율'),
            trailing: const Icon(Icons.upload_file),
            onTap: writeDisabled ? null : _importPrices,
          ),
          ListTile(
            title: const Text('주식 거래 CSV 내보내기'),
            subtitle: const Text('주식 거래 14개 필드 · 전체 백업은 아래 JSON을 사용하세요.'),
            trailing: const Icon(Icons.download),
            onTap: disabled
                ? null
                : () => _run(
                    () async => csv_export.downloadCsv(state.transactions),
                  ),
          ),
          ListTile(
            title: const Text('전체 백업 내보내기'),
            subtitle: const Text('거래, 기타자산, 설정, 스냅샷과 과거 가격'),
            trailing: const Icon(Icons.download),
            onTap: disabled ? null : _exportBackup,
          ),
          ListTile(
            title: const Text('백업 파일 복원'),
            subtitle: const Text('파일 검증 및 미리보기 후 현재 데이터를 대체합니다.'),
            trailing: const Icon(Icons.upload_file),
            onTap: disabled ? null : _importBackup,
          ),
        ]),
        FutureBuilder<PackageInfo>(
          future: _packageInfo,
          builder: (_, snapshot) =>
              Center(child: Text('v${snapshot.data?.version ?? ''}')),
        ),
      ],
    );
  }

  Widget _section(String title, List<Widget> children) => Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Card(child: Column(children: children)),
      ],
    ),
  );
  Widget _nameInput(
    TextEditingController controller,
    String label,
    bool disabled,
    VoidCallback onAdd,
  ) => Padding(
    padding: const EdgeInsets.all(12),
    child: Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            enabled: !disabled,
            onSubmitted: (_) => onAdd(),
            decoration: InputDecoration(
              labelText: label,
              border: const OutlineInputBorder(),
            ),
          ),
        ),
        const SizedBox(width: 8),
        FilledButton(
          onPressed: disabled ? null : onAdd,
          child: const Text('추가'),
        ),
      ],
    ),
  );
}
