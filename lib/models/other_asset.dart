import 'transaction.dart';

enum AssetCategory { savings, bond, loan, cash, other }

class OtherAsset {
  final String id;
  final String account;
  final String name;
  final AssetCategory category;
  final double value;
  final Currency currency;
  final String date;
  final String memo;
  final String time; // "HH:mm" format

  const OtherAsset({
    required this.id, required this.account, required this.name,
    required this.category, required this.value, required this.currency,
    required this.date, this.memo = '', this.time = '00:00',
  });

  /// date + time 조합 정렬키 (e.g. "2024-03-15 14:30")
  String get sortKey => '$date $time';

  factory OtherAsset.fromSheetRow(List<String> row) {
    return OtherAsset(
      id: row[0], account: row[1], name: row[2],
      category: _parseCategory(row[3]),
      value: double.tryParse(row[4]) ?? 0,
      currency: row[5] == 'KRW' ? Currency.krw : Currency.usd,
      date: row[6], memo: row.length > 7 ? row[7] : '',
      time: row.length > 8 ? row[8] : '00:00',
    );
  }

  List<String> toSheetRow() {
    return [id, account, name, category.toSheetValue(), value.toString(),
            currency == Currency.krw ? 'KRW' : 'USD', date, memo, time];
  }

  static AssetCategory _parseCategory(String value) {
    switch (value) {
      case 'savings': return AssetCategory.savings;
      case 'bond': return AssetCategory.bond;
      case 'loan': return AssetCategory.loan;
      case 'cash': return AssetCategory.cash;
      default: return AssetCategory.other;
    }
  }

  String get categoryLabel {
    switch (category) {
      case AssetCategory.savings: return '예금';
      case AssetCategory.bond: return '채권';
      case AssetCategory.loan: return '대출';
      case AssetCategory.cash: return '현금';
      case AssetCategory.other: return '기타';
    }
  }
}

extension AssetCategoryExt on AssetCategory {
  String toSheetValue() {
    switch (this) {
      case AssetCategory.savings: return 'savings';
      case AssetCategory.bond: return 'bond';
      case AssetCategory.loan: return 'loan';
      case AssetCategory.cash: return 'cash';
      case AssetCategory.other: return 'other';
    }
  }
}
