import 'dart:convert';
import '../engine/holdings_engine.dart';
import '../models/app_settings.dart';
import '../models/other_asset.dart';
import '../models/portfolio_snapshot.dart';
import '../models/transaction.dart';
import 'historical_prices.dart';

class PortfolioBackup {
  static const format = 'portfolio-backup';
  static const version = 1;
  final List<Transaction> transactions;
  final List<OtherAsset> otherAssets;
  final AppSettings settings;
  final List<PortfolioSnapshot> snapshots;
  final HistoricalPriceImport historicalPrices;
  final String exportedAt;
  final Map<String, String> extraSettings;
  final String exchangeRateSource;

  PortfolioBackup({
    required this.transactions,
    required this.otherAssets,
    required this.settings,
    this.snapshots = const [],
    this.historicalPrices = const HistoricalPriceImport(),
    String? exportedAt,
    this.extraSettings = const {},
    this.exchangeRateSource = '=GOOGLEFINANCE("CURRENCY:USDKRW")',
  }) : exportedAt = exportedAt ?? DateTime.now().toUtc().toIso8601String();
  String get summary =>
      '주식 거래 ${transactions.length}건 · 기타자산 ${otherAssets.length}건 · 명의 ${settings.accounts.length}개 · 스냅샷 ${snapshots.length}건 · ${historicalPrices.summary}';

  void validate() {
    final errors = <String>[
      ...settings.validationErrors,
      ...replayPortfolio(transactions).issues.map((i) => i.toString()),
      ...validateOtherAssetLedger(otherAssets).map((i) => i.toString()),
    ];
    final knownKeys = settings.toSheetRows().map((r) => r.first).toSet();
    if (extraSettings.keys.any(
      (key) => key.isEmpty || knownKeys.contains(key),
    )) {
      errors.add('추가 설정의 키가 비어 있거나 기본 설정과 중복됩니다.');
    }
    final rate = double.tryParse(exchangeRateSource);
    if (!(rate != null && rate.isFinite && rate > 0) &&
        !const {
          '=GOOGLEFINANCE("USDKRW")',
          '=GOOGLEFINANCE("CURRENCY:USDKRW")',
        }.contains(exchangeRateSource)) {
      errors.add(
        '환율 설정은 양수 또는 기본 GOOGLEFINANCE 환율 수식이어야 합니다. 사용자 지정 수식은 시트 원본으로 백업해 주세요.',
      );
    }
    final dirty = extraSettings['history_dirty_from'];
    if (dirty != null && dirty.isNotEmpty) {
      HistoricalPriceImport.fromRows([
        [dirty, 'USDKRW', '1'],
      ]);
    }
    for (final tx in transactions) {
      if (!settings.accounts.contains(tx.account)) {
        errors.add('등록되지 않은 명의: ${tx.account}');
      }
      if (tx.broker.isNotEmpty && !settings.brokers.contains(tx.broker)) {
        errors.add('등록되지 않은 증권사: ${tx.broker}');
      }
    }
    for (final asset in otherAssets) {
      if (!settings.accounts.contains(asset.account)) {
        errors.add('등록되지 않은 명의: ${asset.account}');
      }
    }
    final dates = <String>{};
    for (final snapshot in snapshots) {
      PortfolioSnapshot.fromSheetRow(snapshot.toSheetRow());
      if (!dates.add(snapshot.date)) errors.add('스냅샷 날짜 중복: ${snapshot.date}');
    }
    HistoricalPriceImport.fromRows(historicalPrices.toRows());
    if (errors.isNotEmpty) throw FormatException(errors.take(10).join('\n'));
  }

  String toJsonText() {
    validate();
    return const JsonEncoder.withIndent('  ').convert({
      'format': format,
      'version': version,
      'exportedAt': exportedAt,
      'extraSettings': extraSettings,
      'exchangeRateSource': exchangeRateSource,
      'transactions': transactions.map((t) => t.toSheetRow()).toList(),
      'otherAssets': otherAssets.map((a) => a.toSheetRow()).toList(),
      'settings': settings.toSheetRows(),
      'snapshots': snapshots.map((s) => s.toSheetRow()).toList(),
      'historicalPrices': historicalPrices.toRows(),
    });
  }

  factory PortfolioBackup.fromJsonText(String text) {
    if (text.length > 20 * 1024 * 1024) {
      throw const FormatException('백업 파일은 20MB 이하여야 합니다.');
    }
    final decoded = jsonDecode(text.replaceFirst('\uFEFF', ''));
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('올바른 백업 JSON이 아닙니다.');
    }
    final PortfolioBackup backup;
    if (decoded['format'] == format) {
      if (decoded['version'] != version) {
        throw const FormatException('지원하지 않는 백업 버전입니다.');
      }
      backup = PortfolioBackup(
        transactions: _rows(
          decoded,
          'transactions',
        ).map(Transaction.fromSheetRow).toList(),
        otherAssets: _rows(
          decoded,
          'otherAssets',
        ).map(OtherAsset.fromSheetRow).toList(),
        settings: AppSettings.fromSheetRows(_rows(decoded, 'settings')),
        snapshots: _rows(
          decoded,
          'snapshots',
        ).map(PortfolioSnapshot.fromSheetRow).toList(),
        historicalPrices: HistoricalPriceImport.fromRows(
          _rows(decoded, 'historicalPrices'),
        ),
        exportedAt: decoded['exportedAt'] as String?,
        extraSettings: _stringMap(decoded['extraSettings']),
        exchangeRateSource:
            decoded['exchangeRateSource'] as String? ??
            '=GOOGLEFINANCE("CURRENCY:USDKRW")',
      );
    } else if (decoded.containsKey('schemaVersion') &&
        decoded['transactions'] is List) {
      backup = _legacy(decoded);
    } else {
      throw const FormatException('Portfolio 백업 파일을 선택해 주세요.');
    }
    backup.validate();
    return backup;
  }
  List<List<String>> get settingsRows => [
    for (final row in settings.toSheetRows())
      row.first == 'exchange_rate' ? [row.first, exchangeRateSource] : row,
    for (final entry in extraSettings.entries) [entry.key, entry.value],
  ];

  static Map<String, String> _stringMap(dynamic value) {
    if (value == null) return {};
    if (value is! Map ||
        value.length > 1000 ||
        value.entries.any((e) => e.key is! String || e.value is! String)) {
      throw const FormatException('추가 설정은 문자열 키와 값이어야 합니다.');
    }
    return Map<String, String>.from(value);
  }

  static List<List<String>> _rows(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! List || value.length > 100000) {
      throw FormatException('$key 목록이 없거나 너무 큽니다.');
    }
    return value.map((row) {
      if (row is! List || row.any((c) => c is! String)) {
        throw FormatException('$key 행의 열 형식이 올바르지 않습니다.');
      }
      return List<String>.from(row);
    }).toList();
  }

  static PortfolioBackup _legacy(Map<String, dynamic> data) {
    if (data['schemaVersion'] != 1 ||
        data.keys.any(
          (key) => !const {
            'schemaVersion',
            'transactions',
            'accounts',
            'settings',
          }.contains(key),
        )) {
      throw const FormatException(
        '이전 백업에 지원하지 않는 버전 또는 데이터가 있습니다. 데이터 누락을 방지하기 위해 가져오기를 중단했습니다.',
      );
    }
    final transactions = <Transaction>[];
    for (final item in data['transactions'] as List) {
      if (item is! Map) throw const FormatException('이전 버전 거래 형식이 올바르지 않습니다.');
      final stamp = (item['executedAt'] ?? item['date'] ?? '').toString();
      if (item['assetClass'] == 'cash') {
        throw const FormatException('이전 버전 현금 거래는 기타자산으로 이관한 후 가져와 주세요.');
      }
      final currency = (item['currency'] ?? 'USD').toString();
      transactions.add(
        Transaction.fromSheetRow([
          '${item['id'] ?? ''}',
          stamp.length >= 10 ? stamp.substring(0, 10) : stamp,
          '${item['account'] ?? item['owner'] ?? ''}',
          '${item['type'] ?? ''}',
          '${item['ticker'] ?? ''}',
          '${item['market'] ?? (currency == 'KRW' ? 'KRX' : 'US')}',
          '${item['name'] ?? item['ticker'] ?? ''}',
          '${item['shares'] ?? ''}',
          '${item['price'] ?? ''}',
          currency,
          '${item['exchangeRate'] ?? ''}',
          '${item['memo'] ?? ''}',
          '${item['broker'] ?? ''}',
          '${item['time'] ?? (stamp.length >= 16 ? stamp.substring(11, 16) : '00:00')}',
        ]),
      );
    }
    final settings = data['settings'] as Map? ?? {};
    final accounts = data['accounts'] is List
        ? List<String>.from(data['accounts'])
        : transactions.map((t) => t.account).toSet().toList();
    return PortfolioBackup(
      transactions: transactions,
      otherAssets: const [],
      settings: AppSettings(
        accounts: accounts,
        brokers: transactions
            .map((t) => t.broker)
            .where((b) => b.isNotEmpty)
            .toSet()
            .toList(),
        refreshInterval: (settings['refreshInterval'] as num?)?.toInt() ?? 60,
        accentColor: settings['accentColor'] as String? ?? '#0D6E6E',
      ),
    );
  }
}
