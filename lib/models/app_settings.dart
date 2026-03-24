class AppSettings {
  final List<String> accounts;
  final List<String> brokers;
  final String baseCurrency;
  final String accentColor;
  final int refreshInterval;
  final int version;

  const AppSettings({
    this.accounts = const [], this.brokers = const [], this.baseCurrency = 'KRW',
    this.accentColor = '#0D6E6E', this.refreshInterval = 60, this.version = 1,
  });

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
    ];
  }

  AppSettings copyWith({
    List<String>? accounts, List<String>? brokers, String? baseCurrency,
    String? accentColor, int? refreshInterval, int? version,
  }) {
    return AppSettings(
      accounts: accounts ?? this.accounts,
      brokers: brokers ?? this.brokers,
      baseCurrency: baseCurrency ?? this.baseCurrency,
      accentColor: accentColor ?? this.accentColor,
      refreshInterval: refreshInterval ?? this.refreshInterval,
      version: version ?? this.version,
    );
  }
}
