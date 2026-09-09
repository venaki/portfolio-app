import 'sheet_schema.dart';

class PortfolioSnapshot {
  static const sheetHeaders = SheetSchema.snapshots;
  static const currentSchemaVersion = 2;
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
    this.schemaVersion = currentSchemaVersion,
  });

  bool get needsRebuild => schemaVersion < currentSchemaVersion;

  List<String> get validationErrors => [
    if (id.isEmpty) '스냅샷 ID가 없습니다.',
    if (!isValidDate(date)) '스냅샷 날짜가 올바르지 않습니다.',
    if (![
      totalValueKRW,
      totalCostKRW,
      profitKRW,
      profitPct,
      dailyChangeKRW,
      dailyChangePct,
      exchangeRate,
    ].every((v) => v.isFinite))
      '스냅샷에는 유한한 숫자만 저장할 수 있습니다.',
    if (exchangeRate <= 0) '스냅샷 환율이 올바르지 않습니다.',
    if (DateTime.tryParse(createdAt) == null) '스냅샷 생성 시각이 올바르지 않습니다.',
    if (schemaVersion < 1) '스냅샷 버전이 올바르지 않습니다.',
  ];

  factory PortfolioSnapshot.fromSheetRow(List<String> row) {
    final snapshot = PortfolioSnapshot(
      id: sheetCell(row, 0),
      date: sheetCell(row, 1),
      totalValueKRW: finiteSheetNumber(sheetCell(row, 2), '평가액'),
      totalCostKRW: finiteSheetNumber(sheetCell(row, 3), '원가'),
      profitKRW: finiteSheetNumber(sheetCell(row, 4), '평가손익'),
      profitPct: finiteSheetNumber(sheetCell(row, 5), '평가수익률'),
      dailyChangeKRW: finiteSheetNumber(sheetCell(row, 6), '일간변동'),
      dailyChangePct: finiteSheetNumber(sheetCell(row, 7), '일간변동률'),
      exchangeRate: finiteSheetNumber(sheetCell(row, 8), '환율'),
      source: sheetCell(row, 9),
      createdAt: sheetCell(row, 10),
      schemaVersion: int.tryParse(sheetCell(row, 11)) ?? 1,
    );
    requireValidRecord(snapshot.validationErrors);
    return snapshot;
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
