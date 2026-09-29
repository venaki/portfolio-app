import 'dart:convert';
import 'dart:io';
import 'package:args/args.dart';
import '../../lib/engine/holdings_engine.dart';
import '../../lib/models/other_asset.dart';
import '../../lib/models/transaction.dart';
import '../../lib/services/sheets_service.dart';
import '../src/auth.dart';
import '../src/ledger.dart';

void output(Object value) =>
    stdout.writeln(const JsonEncoder.withIndent('  ').convert(value));
ArgParser parser() {
  final p = ArgParser()
    ..addOption('sheet')
    ..addOption('state-dir')
    ..addFlag('help', negatable: false);
  p.addCommand('configure', ArgParser()..addOption('sheet', mandatory: true));
  p.addCommand(
    'auth',
    ArgParser()
      ..addCommand('login', ArgParser()..addOption('client', mandatory: true))
      ..addCommand('status')
      ..addCommand('logout'),
  );
  p.addCommand('holdings');
  p.addCommand('settings');
  for (final collection in ['trade', 'asset']) {
    final c = ArgParser();
    c.addCommand(
      'list',
      ArgParser()
        ..addOption('id')
        ..addOption('owner')
        ..addOption('ticker'),
    );
    for (final action in ['add', 'update', 'delete']) {
      final a = ArgParser()
        ..addFlag('apply', negatable: false)
        ..addOption('expect');
      final fields = action == 'delete'
          ? ['id']
          : [
              'id',
              'owner',
              'date',
              'time',
              'memo',
              if (collection == 'trade') ...[
                'broker',
                'ticker',
                'market',
                'name',
                'side',
                'quantity',
                'price',
                'fx',
              ] else ...[
                'name',
                'category',
                'value',
                'currency',
              ],
            ];
      for (final key in fields) {
        a.addOption(key);
      }
      c.addCommand(action, a);
    }
    p.addCommand(collection, c);
  }
  return p;
}

Future<void> main(List<String> arguments) async {
  SheetsService? repo;
  RandomAccessFile? lock;
  try {
    final p = parser(), args = p.parse(arguments);
    if (args['help'] == true || args.command == null) {
      stdout.writeln(
        'Portfolio CLI — JSON output; writes preview unless --apply\n'
        'configure --sheet ID | auth login --client FILE | auth status | auth logout\n'
        'trade|asset list|add|update|delete | holdings | settings\n'
        'See cli/README.md for fields and examples.\n${p.usage}',
      );
      return;
    }
    for (ArgResults? part = args; part != null; part = part.command) {
      if (part.rest.isNotEmpty)
        throw FormatException('알 수 없는 인자: ${part.rest}');
    }
    final home =
        Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
    if (home == null && args['state-dir'] == null)
      throw StateError('--state-dir가 필요합니다.');
    final state = LocalState(
      args['state-dir'] as String? ?? '$home/.config/portfolio-cli',
    );
    final command = args.command!;
    await state.prepare();
    // All CLI invocations serialize token refreshes and writes on this machine.
    lock = await File(
      '${state.directory.path}/session.lock',
    ).open(mode: FileMode.append);
    await lock.lock(FileLock.blockingExclusive);
    if (command.name == 'configure') {
      final sheet = command['sheet'] as String;
      if (!RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(sheet))
        throw FormatException('시트 ID 형식 오류');
      await state.write('config', {'sheet': sheet});
      output({'configured': true, 'sheet': sheet});
      return;
    }
    if (command.name == 'auth') {
      final sub = command.command;
      if (sub == null) throw FormatException('auth login|status|logout');
      if (sub.name == 'login') {
        await GoogleAuth(state).login(sub['client'] as String);
        output({'authenticated': true});
      } else if (sub.name == 'logout') {
        if (await state.file('auth').exists())
          await state.file('auth').delete();
        output({'local_credentials_removed': true});
      } else {
        output({
          'credentials_present':
              (await state.read('auth'))['refresh_token'] != null,
        });
      }
      return;
    }
    final config = await state.read('config');
    final sheet = args['sheet'] as String? ?? config['sheet'] as String?;
    if (sheet == null) throw StateError('configure --sheet ID를 먼저 실행하세요.');
    repo = SheetsService(getAuthHeaders: GoogleAuth(state).headers);
    repo.setSpreadsheetId(sheet);
    final data = await repo.loadAll();
    final issues = [
      ...repo.dataIssues,
      ...replayPortfolio(data.transactions).issues.map((e) => '$e'),
      ...validateOtherAssetLedger(data.otherAssets).map((e) => '$e'),
    ];
    if (issues.isNotEmpty) throw FormatException(issues.join('\n'));
    if (command.name == 'settings') {
      output({
        'accounts': data.settings.accounts,
        'brokers': data.settings.brokers,
      });
      return;
    }
    if (command.name == 'holdings') {
      final today = DateTime.now().toIso8601String().substring(0, 10);
      output({
        'asOf': today,
        'holdings': [
          for (final h in replayPortfolio(
            data.transactions,
            throughDate: today,
          ).holdings)
            {
              'ticker': h.ticker,
              'owner': h.account,
              'broker': h.broker,
              'shares': h.shares,
              'currency': h.currency.name.toUpperCase(),
              'costNative': h.costNative,
              'costKRW': h.costKRW,
            },
        ],
        'assets': [
          for (final a in consolidateOtherAssets(
            data.otherAssets
                .where((a) => a.date.compareTo(today) <= 0)
                .toList(),
          ))
            {
              'name': a.name,
              'owner': a.account,
              'category': a.category.name,
              'currency': a.currency.name.toUpperCase(),
              'value': a.totalValue,
            },
        ],
      });
      return;
    }
    final sub = command.command;
    if (sub == null || sub.rest.isNotEmpty)
      throw FormatException('하위 명령을 확인하세요.');
    final trade = command.name == 'trade';
    if (sub.name == 'list') {
      final rows = trade
          ? data.transactions.map(
              (x) => record(Transaction.sheetHeaders, x.toSheetRow()),
            )
          : data.otherAssets.map(
              (x) => record(OtherAsset.sheetHeaders, x.toSheetRow()),
            );
      output({
        'revision': revisionOf(data),
        'records': rows
            .where(
              (r) =>
                  (sub['id'] == null || r['id'] == sub['id']) &&
                  (sub['owner'] == null || r['account'] == sub['owner']) &&
                  (sub['ticker'] == null || r['ticker'] == sub['ticker']),
            )
            .toList(),
      });
      return;
    }
    final fields = <String, String>{};
    const aliases = {
      'owner': 'account',
      'side': 'type',
      'quantity': 'shares',
      'fx': 'exchangeRate',
    };
    for (final name in sub.options.where(
      (k) => k != 'apply' && k != 'expect',
    )) {
      if (sub[name] != null)
        fields[aliases[name] ?? name] = sub[name] as String;
    }
    final change = plan(data, command.name!, sub.name!, fields);
    if (sub['apply'] != true || change.action == 'noop') {
      output({
        'status': change.action == 'noop' ? 'already_present' : 'preview',
        'sheet': sheet,
        ...change.toJson(),
      });
      return;
    }
    if (sub.name != 'add' && sub['expect'] != change.revision)
      throw StateError('수정·삭제에는 미리보기 revision을 --expect로 전달하세요.');
    final journal =
        'change-${DateTime.now().microsecondsSinceEpoch}-${randomString()}';
    final entry = {
      'sheet': sheet,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      ...change.toJson(),
      'ledgerBefore': {
        'transactions': data.transactions.map((x) => x.toSheetRow()).toList(),
        'otherAssets': data.otherAssets.map((x) => x.toSheetRow()).toList(),
      },
    };
    await state.write(journal, {'status': 'pending', ...entry});
    try {
      await applyChange(repo, change);
    } catch (_) {
      stderr.writeln(
        '저장 결과가 불확실할 수 있습니다. 중복 추가하지 말고 ID ${change.id}로 조회하세요. 변경 전 기록: ${state.file(journal).path}',
      );
      rethrow;
    }
    await state.write(journal, {'status': 'verified', ...entry});
    output({
      'status': 'saved',
      'sheet': sheet,
      'id': change.id,
      'journal': state.file(journal).path,
    });
  } catch (e) {
    stderr.writeln(
      jsonEncode({
        'error': e is FormatException
            ? e.message
            : e is StateError
            ? e.message
            : '작업 실패 (${e.runtimeType}). 설정과 연결을 확인하세요.',
      }),
    );
    exitCode = 1;
  } finally {
    repo?.close();
    await lock?.close();
  }
}
