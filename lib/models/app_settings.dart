import 'dart:convert';

import 'holding.dart';
import 'sheet_schema.dart';

class AppSettings {
  static const currentSchemaVersion = 2;
  final List<String> accounts;
  final List<String> brokers;
  final String baseCurrency;
  final String accentColor;
  final int refreshInterval;
  final int version;
  final double? exchangeRate;
  final int forceRefreshWait;
  final List<String> holdingOrder;
  final int schemaVersion;

  const AppSettings({
    this.accounts = const [],
    this.brokers = const [],
    this.baseCurrency = 'KRW',
    this.accentColor = '#0D6E6E',
    this.refreshInterval = 60,
    this.version = 1,
    this.exchangeRate,
    this.forceRefreshWait = 3,
    this.holdingOrder = const [],
    this.schemaVersion = currentSchemaVersion,
  });

  /// Holding 고유 키 생성: ticker|account|broker
  static String holdingKey(String ticker, String account, String broker) =>
      '$ticker|$account|$broker';

  /// Canonical identity includes market and currency and escapes account names.
  static String holdingKeyFor(Holding holding) => jsonEncode([
    holding.ticker,
    holding.account,
    holding.broker,
    holding.market.name,
    holding.currency.name,
  ]);

  /// Preserve existing order preferences until the next save migrates the keys.
  int holdingOrderIndex(Holding holding) {
    final canonical = holdingOrder.indexOf(holdingKeyFor(holding));
    return canonical >= 0
        ? canonical
        : holdingOrder.indexOf(
            holdingKey(holding.ticker, holding.account, holding.broker),
          );
  }

  List<String> get validationErrors => [
    if (refreshInterval < 30 || refreshInterval > 86400)
      '자동 갱신 간격은 30초 이상 24시간 이하여야 합니다.',
    if (forceRefreshWait < 1 || forceRefreshWait > 120)
      '강제 갱신 대기는 1초 이상 120초 이하여야 합니다.',
    if (!RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(accentColor))
      '강조색 형식이 올바르지 않습니다.',
    if (baseCurrency != 'KRW' && baseCurrency != 'USD')
      '기준 통화는 KRW 또는 USD여야 합니다.',
    if (accounts.any((a) => a.trim().isEmpty) ||
        accounts.toSet().length != accounts.length)
      '계좌 이름은 비어 있거나 중복될 수 없습니다.',
    if (brokers.any((b) => b.trim().isEmpty) ||
        brokers.toSet().length != brokers.length)
      '증권사 이름은 비어 있거나 중복될 수 없습니다.',
  ];

  static List<String> _parseList(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const [];
    if (raw.trimLeft().startsWith('[')) {
      final decoded = jsonDecode(raw);
      if (decoded is! List || decoded.any((item) => item is! String)) {
        throw const FormatException('설정 목록은 문자열 배열이어야 합니다.');
      }
      return List<String>.from(decoded);
    }
    return raw
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  static int _integer(Map<String, String> map, String key, int fallback) {
    final raw = map[key];
    if (raw == null || raw.isEmpty) return fallback;
    final value = int.tryParse(raw);
    if (value == null) throw FormatException('$key: 정수가 필요합니다.');
    return value;
  }

  factory AppSettings.fromSheetRows(List<List<String>> rows) {
    final map = <String, String>{};
    final keys = <String>{};
    for (final row in rows) {
      if (row.isEmpty || row.first.trim().isEmpty) continue;
      if (!keys.add(row.first)) {
        throw FormatException('설정 키가 중복되었습니다: ${row.first}');
      }
      if (row.length >= 2) map[row[0]] = row[1];
    }
    final fx = double.tryParse(map['exchange_rate'] ?? '');
    final settings = AppSettings(
      accounts: _parseList(map['accounts']),
      brokers: _parseList(map['brokers']),
      baseCurrency: map['base_currency'] ?? 'KRW',
      accentColor: map['accent_color'] ?? '#0D6E6E',
      refreshInterval: _integer(map, 'refresh_interval', 60),
      version: _integer(map, 'version', 1),
      exchangeRate: fx != null && fx.isFinite && fx > 0 ? fx : null,
      forceRefreshWait: _integer(map, 'force_refresh_wait', 3),
      holdingOrder: _parseList(map['holding_order']),
      schemaVersion: _integer(map, 'settings_schema_version', 1),
    );
    requireValidRecord(settings.validationErrors);
    return settings;
  }

  List<List<String>> toSheetRows() {
    return [
      ['accounts', jsonEncode(accounts)],
      ['brokers', jsonEncode(brokers)],
      ['base_currency', baseCurrency],
      ['accent_color', accentColor],
      ['refresh_interval', refreshInterval.toString()],
      ['version', version.toString()],
      ['exchange_rate', '=GOOGLEFINANCE("USDKRW")'],
      ['force_refresh_wait', forceRefreshWait.toString()],
      ['holding_order', jsonEncode(holdingOrder)],
      ['settings_schema_version', currentSchemaVersion.toString()],
    ];
  }

  AppSettings copyWith({
    List<String>? accounts,
    List<String>? brokers,
    String? baseCurrency,
    String? accentColor,
    int? refreshInterval,
    int? version,
    double? exchangeRate,
    int? forceRefreshWait,
    List<String>? holdingOrder,
    int? schemaVersion,
  }) {
    return AppSettings(
      accounts: accounts ?? this.accounts,
      brokers: brokers ?? this.brokers,
      baseCurrency: baseCurrency ?? this.baseCurrency,
      accentColor: accentColor ?? this.accentColor,
      refreshInterval: refreshInterval ?? this.refreshInterval,
      version: version ?? this.version,
      exchangeRate: exchangeRate ?? this.exchangeRate,
      forceRefreshWait: forceRefreshWait ?? this.forceRefreshWait,
      holdingOrder: holdingOrder ?? this.holdingOrder,
      schemaVersion: schemaVersion ?? this.schemaVersion,
    );
  }
}
