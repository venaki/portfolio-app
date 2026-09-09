/// Shared column order for the sheet repository, backups and model codecs.
abstract final class SheetSchema {
  static const transactions = [
    'id',
    'date',
    'account',
    'type',
    'ticker',
    'market',
    'name',
    'shares',
    'price',
    'currency',
    'exchangeRate',
    'memo',
    'broker',
    'time',
  ];
  static const otherAssets = [
    'id',
    'account',
    'name',
    'category',
    'value',
    'currency',
    'date',
    'memo',
    'time',
  ];
  static const snapshots = [
    'id',
    'date',
    'totalValueKRW',
    'totalCostKRW',
    'profitKRW',
    'profitPct',
    'dailyChangeKRW',
    'dailyChangePct',
    'exchangeRate',
    'source',
    'createdAt',
    'schemaVersion',
  ];
}

String sheetCell(List<String> row, int index, [String fallback = '']) =>
    index < row.length ? row[index] : fallback;

double finiteSheetNumber(String value, String field) {
  final number = double.tryParse(value.trim());
  if (number == null || !number.isFinite) {
    throw FormatException('$field: 유효한 숫자가 아닙니다.');
  }
  return number;
}

String dateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

bool isValidDate(String date) {
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date)) return false;
  final parsed = DateTime.tryParse(date);
  return parsed != null && dateKey(parsed) == date;
}

bool isValidTime(String time) =>
    RegExp(r'^([01]\d|2[0-3]):[0-5]\d(:[0-5]\d)?$').hasMatch(time);

void requireValidRecord(List<String> errors) {
  if (errors.isNotEmpty) throw FormatException(errors.join(' '));
}
