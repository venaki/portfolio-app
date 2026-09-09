import 'dart:convert';

import 'data_issue.dart';
import 'sheet_schema.dart';
import 'transaction.dart';

enum AssetCategory { savings, bond, loan, other }

class OtherAsset {
  static const sheetHeaders = SheetSchema.otherAssets;
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
    required this.id,
    required this.account,
    required this.name,
    required this.category,
    required this.value,
    required this.currency,
    required this.date,
    this.memo = '',
    this.time = '00:00',
  });

  /// date + time 조합 정렬키 (e.g. "2024-03-15 14:30")
  String get sortKey => '$date $time';

  String get groupKey =>
      jsonEncode([name, account, category.name, currency.name]);

  List<String> get validationErrors => [
    if (id.trim().isEmpty) '자산 ID가 없습니다.',
    if (account.trim().isEmpty) '계좌가 없습니다.',
    if (name.trim().isEmpty) '자산명이 없습니다.',
    if (!value.isFinite || value == 0) '금액은 0이 아닌 유한한 숫자여야 합니다.',
    if (!isValidDate(date)) '날짜 형식이 올바르지 않습니다.',
    if (!isValidTime(time)) '시간 형식이 올바르지 않습니다.',
  ];

  /// 방향 라벨 (입금/출금, 매수/매도, 대출/상환, +/-)
  String get directionLabel =>
      value >= 0 ? category.positiveLabel : category.negativeLabel;

  factory OtherAsset.fromSheetRow(List<String> row) {
    final rawTime = sheetCell(row, 8).trim();
    final asset = OtherAsset(
      id: sheetCell(row, 0).trim(),
      account: sheetCell(row, 1).trim(),
      name: sheetCell(row, 2).trim(),
      category: _parseCategory(sheetCell(row, 3)),
      value: finiteSheetNumber(sheetCell(row, 4), '금액'),
      currency: parseCurrency(sheetCell(row, 5)),
      date: sheetCell(row, 6).trim(),
      memo: sheetCell(row, 7),
      time: rawTime.isEmpty ? '00:00' : rawTime,
    );
    requireValidRecord(asset.validationErrors);
    return asset;
  }

  List<String> toSheetRow() {
    return [
      id,
      account,
      name,
      category.toSheetValue(),
      value.toString(),
      currency == Currency.krw ? 'KRW' : 'USD',
      date,
      memo,
      time,
    ];
  }

  static AssetCategory _parseCategory(String value) {
    switch (value) {
      case 'savings':
        return AssetCategory.savings;
      case 'bond':
        return AssetCategory.bond;
      case 'loan':
        return AssetCategory.loan;
      case 'cash':
        return AssetCategory.savings; // backward compat
      case 'other':
        return AssetCategory.other;
      default:
        throw FormatException('알 수 없는 자산 분류: $value');
    }
  }

  String get categoryLabel => category.label;
}

extension AssetCategoryExt on AssetCategory {
  String toSheetValue() {
    switch (this) {
      case AssetCategory.savings:
        return 'savings';
      case AssetCategory.bond:
        return 'bond';
      case AssetCategory.loan:
        return 'loan';
      case AssetCategory.other:
        return 'other';
    }
  }

  String get label {
    switch (this) {
      case AssetCategory.savings:
        return '예금';
      case AssetCategory.bond:
        return '채권';
      case AssetCategory.loan:
        return '대출';
      case AssetCategory.other:
        return '기타';
    }
  }

  String get positiveLabel {
    switch (this) {
      case AssetCategory.savings:
        return '입금';
      case AssetCategory.bond:
        return '매수';
      case AssetCategory.loan:
        return '대출';
      case AssetCategory.other:
        return '+';
    }
  }

  String get negativeLabel {
    switch (this) {
      case AssetCategory.savings:
        return '출금';
      case AssetCategory.bond:
        return '매도';
      case AssetCategory.loan:
        return '상환';
      case AssetCategory.other:
        return '-';
    }
  }
}

/// 통화가 다른 자산은 합산하지 않는다.
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
  String get key => jsonEncode([name, account, category.name, currency.name]);
  double get signedValue =>
      category == AssetCategory.loan ? -totalValue : totalValue;
}

/// 원통화 단위로만 합산한다. 환산은 평가 엔진의 책임이다.
List<ConsolidatedAsset> consolidateOtherAssets(List<OtherAsset> assets) {
  final groups = <String, List<OtherAsset>>{};
  for (final a in assets) {
    final key = a.groupKey;
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

/// Validate the entire ledger when adding, editing or deleting an asset entry.
/// The input position is the deterministic order for equal timestamps.
List<DataIssue> validateOtherAssetLedger(List<OtherAsset> assets) {
  final ordered = assets.indexed.toList()
    ..sort((a, b) {
      final byTime = a.$2.sortKey.compareTo(b.$2.sortKey);
      return byTime != 0 ? byTime : a.$1.compareTo(b.$1);
    });
  final balances = <String, double>{};
  final seenIds = <String>{};
  final issues = <DataIssue>[];
  for (final (_, asset) in ordered) {
    final errors = [...asset.validationErrors];
    if (!seenIds.add(asset.id)) errors.add('중복된 자산 ID입니다.');
    if (errors.isNotEmpty) {
      issues.add(DataIssue(recordId: asset.id, message: errors.join(' ')));
      continue;
    }
    final balance = (balances[asset.groupKey] ?? 0) + asset.value;
    if (!balance.isFinite) {
      issues.add(
        DataIssue(recordId: asset.id, message: '자산 잔액이 계산 범위를 초과합니다.'),
      );
      continue;
    }
    if (asset.category == AssetCategory.loan && balance < -0.00000001) {
      issues.add(DataIssue(recordId: asset.id, message: '상환액이 대출 잔액을 초과합니다.'));
      continue;
    }
    balances[asset.groupKey] = balance;
  }
  return issues;
}
