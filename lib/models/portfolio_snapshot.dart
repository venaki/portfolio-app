class PortfolioSnapshot {
  final String id;
  final String date;
  final double totalValueKRW;
  final double totalCostKRW;
  final double profitKRW;
  final double profitPct;
  final double dailyChangeKRW;
  final double dailyChangePct;
  final double exchangeRate;
  final String source;
  final String createdAt;
  final int schemaVersion;

  const PortfolioSnapshot({
    required this.id,
    required this.date,
    required this.totalValueKRW,
    required this.totalCostKRW,
    required this.profitKRW,
    required this.profitPct,
    required this.dailyChangeKRW,
    required this.dailyChangePct,
    required this.exchangeRate,
    required this.source,
    required this.createdAt,
    this.schemaVersion = 1,
  });

  factory PortfolioSnapshot.fromSheetRow(List<String> row) {
    return PortfolioSnapshot(
      id: row[0],
      date: row[1],
      totalValueKRW: double.tryParse(row[2]) ?? 0,
      totalCostKRW: double.tryParse(row[3]) ?? 0,
      profitKRW: double.tryParse(row[4]) ?? 0,
      profitPct: double.tryParse(row[5]) ?? 0,
      dailyChangeKRW: double.tryParse(row[6]) ?? 0,
      dailyChangePct: double.tryParse(row[7]) ?? 0,
      exchangeRate: double.tryParse(row[8]) ?? 0,
      source: row[9],
      createdAt: row[10],
      schemaVersion: int.tryParse(row[11]) ?? 1,
    );
  }

  List<String> toSheetRow() {
    return [
      id,
      date,
      totalValueKRW.toString(),
      totalCostKRW.toString(),
      profitKRW.toString(),
      profitPct.toString(),
      dailyChangeKRW.toString(),
      dailyChangePct.toString(),
      exchangeRate.toString(),
      source,
      createdAt,
      schemaVersion.toString(),
    ];
  }
}
