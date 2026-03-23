import 'package:flutter_test/flutter_test.dart';
import 'package:portfolio_flutter/models/other_asset.dart';
import 'package:portfolio_flutter/models/transaction.dart';

void main() {
  final assets = [
    OtherAsset(
      id: '1',
      account: '본석',
      name: '예금',
      category: AssetCategory.savings,
      value: 50000000,
      currency: Currency.krw,
      date: '2026-01-01',
    ),
    OtherAsset(
      id: '2',
      account: '연지',
      name: '채권',
      category: AssetCategory.bond,
      value: 20000000,
      currency: Currency.krw,
      date: '2026-01-01',
    ),
    OtherAsset(
      id: '3',
      account: '본석',
      name: '대출',
      category: AssetCategory.loan,
      value: 15000000,
      currency: Currency.krw,
      date: '2026-01-01',
    ),
  ];

  double calcTotal(List<OtherAsset> list, String filter) {
    return list
        .where((a) => filter == '전체' || a.account == filter)
        .fold(0.0, (sum, a) {
      final value =
          a.category == AssetCategory.loan && a.value > 0 ? -a.value : a.value;
      return sum + value;
    });
  }

  test('전체 합계: 예금 + 채권 - 대출', () {
    expect(calcTotal(assets, '전체'), 55000000);
  });

  test('본석 합계: 예금 - 대출', () {
    expect(calcTotal(assets, '본석'), 35000000);
  });

  test('연지 합계: 채권만', () {
    expect(calcTotal(assets, '연지'), 20000000);
  });

  test('categoryLabel returns Korean labels', () {
    expect(assets[0].categoryLabel, '예금');
    expect(assets[1].categoryLabel, '채권');
    expect(assets[2].categoryLabel, '대출');
  });

  test('toSheetRow produces correct format', () {
    final row = assets[0].toSheetRow();
    expect(row[0], '1');
    expect(row[1], '본석');
    expect(row[2], '예금');
    expect(row[3], 'savings');
    expect(row[5], 'KRW');
  });

  test('fromSheetRow round-trips correctly', () {
    final row = assets[0].toSheetRow();
    final parsed = OtherAsset.fromSheetRow(row);
    expect(parsed.id, assets[0].id);
    expect(parsed.name, assets[0].name);
    expect(parsed.category, assets[0].category);
    expect(parsed.value, assets[0].value);
  });
}
