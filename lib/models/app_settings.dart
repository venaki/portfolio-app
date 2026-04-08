class AppSettings {
  final List<String> accounts;
  final List<String> brokers;
  final String baseCurrency;
  final String accentColor;
  final int refreshInterval;
  final int version;
  final double? exchangeRate;
  final int forceRefreshWait;
  final List<String> holdingOrder;

  const AppSettings({
    this.accounts = const [], this.brokers = const [], this.baseCurrency = 'KRW',
    this.accentColor = '#0D6E6E', this.refreshInterval = 60, this.version = 1,
    this.exchangeRate, this.forceRefreshWait = 3, this.holdingOrder = const [],
  });

  /// Holding 고유 키 생성: ticker|account|broker
  static String holdingKey(String ticker, String account, String broker) =>
      '$ticker|$account|$broker';

  factory AppSettings.fromSheetRows(List<List<String>> rows) {
    final map = <String, String>{};
    for (final row in rows) {
      if (row.length >= 2) map[row[0]] = row[1];
    }
    return AppSettings(
      accounts: (map['accounts'] ?? '').split(',').where((s) => s.isNotEmpty).toList(),
      brokers: (map['brokers'] ?? '').split(',').where((s) => s.isNotEmpty).toList(),
      baseCurrency: map['base_currency'] ?? 'KRW',
      accentColor: map['accent_color'] ?? '#0D6E6E',
      refreshInterval: int.tryParse(map['refresh_interval'] ?? '60') ?? 60,
      version: int.tryParse(map['version'] ?? '1') ?? 1,
      exchangeRate: double.tryParse(map['exchange_rate'] ?? ''),
      forceRefreshWait: int.tryParse(map['force_refresh_wait'] ?? '3') ?? 3,
      holdingOrder: (map['holding_order'] ?? '').split(',').where((s) => s.isNotEmpty).toList(),
    );
  }

  List<List<String>> toSheetRows() {
    return [
      ['accounts', accounts.join(',')],
      ['brokers', brokers.join(',')],
      ['base_currency', baseCurrency],
      ['accent_color', accentColor],
      ['refresh_interval', refreshInterval.toString()],
      ['version', version.toString()],
      ['exchange_rate', '=GOOGLEFINANCE("USDKRW")'],
      ['force_refresh_wait', forceRefreshWait.toString()],
      ['holding_order', holdingOrder.join(',')],
    ];
  }

  AppSettings copyWith({
    List<String>? accounts, List<String>? brokers, String? baseCurrency,
    String? accentColor, int? refreshInterval, int? version, double? exchangeRate,
    int? forceRefreshWait, List<String>? holdingOrder,
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
    );
  }
}
