import 'dart:convert';
import 'package:portfolio_flutter/screens/settings_screen.dart';
import 'package:portfolio_flutter/providers/portfolio_provider.dart';
import 'package:portfolio_flutter/models/other_asset.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portfolio_flutter/widgets/form_fields.dart';
import 'package:portfolio_flutter/widgets/transaction_form.dart';
import 'package:portfolio_flutter/screens/csv_export.dart';
import 'package:portfolio_flutter/screens/sheet_connect_screen.dart';
import 'package:portfolio_flutter/models/transaction.dart';
import 'package:portfolio_flutter/models/sheet_schema.dart';

void main() {
  test('account deletion protects accounts with only other assets', () {
    const state = PortfolioState(
      otherAssets: [
        OtherAsset(
          id: 'a',
          date: '2026-01-01',
          account: '예금계좌',
          name: '예금',
          category: AssetCategory.savings,
          value: 100,
          currency: Currency.krw,
        ),
      ],
    );
    expect(accountHasRecords(state, '예금계좌'), isTrue);
    expect(accountHasRecords(state, '빈 계좌'), isFalse);
  });
  test('amount validation rejects nonfinite, zero, negative and text', () {
    for (final value in ['NaN', 'Infinity', '-1', '0', 'abc', ' ']) {
      expect(validateAmount(value), isNotNull, reason: value);
    }
    expect(validateAmount('1,234.5'), isNull);
    expect(parseAmount('1,234.5'), 1234.5);
  });
  test('ticker validation rejects Korean names and mismatched markets', () {
    expect(validateTicker('삼성전자', Market.krx), isNotNull);
    expect(validateTicker('AAPL', Market.krx), isNotNull);
    expect(validateTicker('005930', Market.us), isNotNull);
    expect(validateTicker('005930', Market.krx), isNull);
    expect(validateTicker('BRK.B', Market.us), isNull);
  });
  test('sheet URL validation requires Google Sheets host or standalone id', () {
    const id = 'abcdefghijklmnopqrstuv';
    expect(
      extractSpreadsheetId('https://docs.google.com/spreadsheets/d/$id/edit'),
      id,
    );
    expect(
      extractSpreadsheetId('https://example.com/spreadsheets/d/$id'),
      isNull,
    );
    expect(extractSpreadsheetId(id), id);
  });
  test('CSV uses complete schema and neutralizes formula cells', () {
    final tx = Transaction(
      id: '1',
      date: '2026-01-02',
      account: '=SUM(1,2)',
      type: TransactionType.buy,
      ticker: 'AAPL',
      market: Market.us,
      name: 'Apple',
      shares: 1,
      price: 100,
      currency: Currency.usd,
      exchangeRate: 1300,
      broker: 'B',
      time: '13:00',
      memo: 'line\nbreak',
    );
    final csv = encodeTransactionCsv([tx]);
    final firstLine = const LineSplitter()
        .convert(csv)
        .first
        .replaceFirst('\uFEFF', '');
    expect(firstLine.split(','), SheetSchema.transactions);
    expect(csv, contains('"\'=SUM(1,2)"'));
    expect(csv, contains('"B","13:00"'));
    expect(csv, contains('"line\nbreak"'));
  });
}
