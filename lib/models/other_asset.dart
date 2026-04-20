import 'transaction.dart';

enum AssetCategory { savings, bond, loan, other }

class OtherAsset {
  final String id;
  final String account;
  final String name;
  final AssetCategory category;
  final double value; // delta: positive = increase, negative = decrease
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

  /// 방향 라벨 (입금/출금, 매수/매도, 대출/상환, +/-)
  String get directionLabel =>
      value >= 0 ? category.positiveLabel : category.negativeLabel;

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
      case 'cash': return AssetCategory.savings; // backward compat
      default: return AssetCategory.other;
    }
  }

  String get categoryLabel => category.label;
}

extension AssetCategoryExt on AssetCategory {
  String toSheetValue() {
    switch (this) {
      case AssetCategory.savings: return 'savings';
      case AssetCategory.bond: return 'bond';
      case AssetCategory.loan: return 'loan';
      case AssetCategory.other: return 'other';
    }
  }

  String get label {
    switch (this) {
      case AssetCategory.savings: return '예금';
      case AssetCategory.bond: return '채권';
      case AssetCategory.loan: return '대출';
      case AssetCategory.other: return '기타';
    }
  }

  String get positiveLabel {
    switch (this) {
      case AssetCategory.savings: return '입금';
      case AssetCategory.bond: return '매수';
      case AssetCategory.loan: return '대출';
      case AssetCategory.other: return '+';
    }
  }

  String get negativeLabel {
    switch (this) {
      case AssetCategory.savings: return '출금';
      case AssetCategory.bond: return '매도';
      case AssetCategory.loan: return '상환';
      case AssetCategory.other: return '-';
    }
  }
}

/// name + account + category 기준 통합 자산
class ConsolidatedAsset {
  final String name;
  final String account;
  final AssetCategory category;
  final Currency currency;
  final double totalValue;

  const ConsolidatedAsset({
    required this.name,
    required this.account,
    required this.category,
    required this.currency,
    required this.totalValue,
  });

  String get categoryLabel => category.label;
}

/// OtherAsset 리스트를 name+account+category 기준으로 통합
List<ConsolidatedAsset> consolidateOtherAssets(List<OtherAsset> assets) {
  final groups = <String, List<OtherAsset>>{};
  for (final a in assets) {
    final key = '${a.name}|${a.account}|${a.category.toSheetValue()}';
    (groups[key] ??= []).add(a);
  }
  return groups.entries.map((e) {
    final first = e.value.first;
    final total = e.value.fold<double>(0, (sum, a) => sum + a.value);
    return ConsolidatedAsset(
      name: first.name,
      account: first.account,
      category: first.category,
      currency: first.currency,
      totalValue: total,
    );
  }).toList();
}
