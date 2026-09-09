import 'package:flutter_test/flutter_test.dart';
import 'package:portfolio_flutter/services/historical_prices.dart';

void main() {
  test('CSV preserves Korean ticker leading zero and quoted FX comma', () {
    final data = HistoricalPriceImport.fromText(
      '\uFEFFdate,ticker,price\r\n2026-01-02,005930,70000\r\n2026-01-02,USDKRW,"1,450.5"\r\n',
    );
    expect(data.pricesByTicker['005930']!['2026-01-02'], 70000);
    expect(data.exchangeRates['2026-01-02'], 1450.5);
    expect(
      HistoricalPriceImport.fromRows(data.toRows()).toRows(),
      data.toRows(),
    );
  });
  test(
    'JSON import accepts explicit observations and rejects conflicting duplicates',
    () {
      final data = HistoricalPriceImport.fromText(
        '{"prices":[{"date":"2026-01-02","ticker":"xyz","price":100}]}',
      );
      expect(data.pricesByTicker.keys, ['XYZ']);
      expect(
        () => HistoricalPriceImport.fromRows([
          ['2026-01-02', 'XYZ', '100'],
          ['2026-01-02', 'XYZ', '200'],
        ]),
        throwsFormatException,
      );
    },
  );
  for (final row in [
    ['2026-02-30', 'XYZ', '100'],
    ['2026-01-02', 'XYZ', 'NaN'],
    ['2026-01-02', 'XYZ', 'Infinity'],
    ['2026-01-02', 'XYZ', '0'],
    ['2026-01-02', '=FORMULA', '1'],
    ['2026-01-02', 'XYZ'],
  ]) {
    test('invalid observation rejected: $row', () {
      expect(
        () => HistoricalPriceImport.fromRows([row]),
        throwsFormatException,
      );
    });
  }
  test(
    'merging a correction preserves unrelated observations without mutating source',
    () {
      final original = HistoricalPriceImport.fromRows([
        ['2026-01-01', 'XYZ', '100'],
        ['2026-01-02', 'XYZ', '110'],
      ]);
      final merged = original.merge(
        HistoricalPriceImport.fromRows([
          ['2026-01-02', 'XYZ', '120'],
        ]),
      );
      expect(merged.pricesByTicker['XYZ'], {
        '2026-01-01': 100,
        '2026-01-02': 120,
      });
      expect(original.pricesByTicker['XYZ']!['2026-01-02'], 110);
    },
  );
}
