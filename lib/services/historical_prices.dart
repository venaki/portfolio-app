import 'dart:convert';
import '../models/sheet_schema.dart';

class BackfillPriceRequest {
  final String ticker;
  final String market;
  const BackfillPriceRequest({required this.ticker, required this.market});
}

class BackfillPriceData {
  final Map<String, Map<String, double>> pricesByTicker;
  final Map<String, double> exchangeRates;
  final List<String> failedSymbols;
  const BackfillPriceData({
    required this.pricesByTicker,
    required this.exchangeRates,
    required this.failedSymbols,
  });
}

/// Explicit imported prices. No values are fabricated from today's quotes.
class HistoricalPriceImport {
  final Map<String, Map<String, double>> pricesByTicker;
  final Map<String, double> exchangeRates;
  const HistoricalPriceImport({
    this.pricesByTicker = const {},
    this.exchangeRates = const {},
  });
  int get count =>
      exchangeRates.length +
      pricesByTicker.values.fold<int>(0, (n, s) => n + s.length);
  String get summary => '과거 가격·환율 $count건';

  factory HistoricalPriceImport.fromRows(List<List<String>> rows) {
    final prices = <String, Map<String, double>>{}, rates = <String, double>{};
    if (rows.length > 100000) {
      throw const FormatException('한 번에 최대 100,000개의 가격을 가져올 수 있습니다.');
    }
    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      if (row.every((c) => c.trim().isEmpty)) continue;
      if (row.length != 3) {
        throw FormatException('가격 ${i + 1}행: date,ticker,price 3개 열이 필요합니다.');
      }
      final date = row[0].trim(), ticker = row[1].trim().toUpperCase();
      final price = double.tryParse(row[2].trim().replaceAll(',', ''));
      if (!isValidDate(date) ||
          !RegExp(r'^[A-Z0-9][A-Z0-9._:^=-]{0,29}$').hasMatch(ticker) ||
          price == null ||
          !price.isFinite ||
          price <= 0) {
        throw FormatException('가격 ${i + 1}행: 날짜·종목 코드·양수 가격을 확인해 주세요.');
      }
      final series = ticker == 'USDKRW'
          ? rates
          : (prices[ticker] ??= <String, double>{});
      if (series.containsKey(date) && series[date] != price) {
        throw FormatException('$ticker $date에 서로 다른 가격이 있습니다.');
      }
      series[date] = price;
    }
    return HistoricalPriceImport(pricesByTicker: prices, exchangeRates: rates);
  }
  factory HistoricalPriceImport.fromText(String text) {
    if (text.length > 20 * 1024 * 1024) {
      throw const FormatException('가격 파일은 20MB 이하여야 합니다.');
    }
    final clean = text.replaceFirst('\uFEFF', '').trim();
    if (clean.startsWith('[') || clean.startsWith('{')) {
      final decoded = jsonDecode(clean);
      final rows = decoded is Map ? decoded['prices'] : decoded;
      if (rows is! List) {
        throw const FormatException('가격 JSON은 prices 배열이 필요합니다.');
      }
      return HistoricalPriceImport.fromRows(
        rows.map((row) {
          if (row is Map) {
            return [
              '${row['date'] ?? ''}',
              '${row['ticker'] ?? ''}',
              '${row['price'] ?? ''}',
            ];
          }
          if (row is List) return row.map((v) => v.toString()).toList();
          throw const FormatException('가격 행 형식이 올바르지 않습니다.');
        }).toList(),
      );
    }
    final rows = _csv(clean);
    if (rows.isEmpty ||
        rows.first.map((c) => c.trim().toLowerCase()).join(',') !=
            'date,ticker,price') {
      throw const FormatException(
        'CSV 첫 행은 date,ticker,price여야 합니다. 환율 ticker는 USDKRW입니다.',
      );
    }
    return HistoricalPriceImport.fromRows(rows.skip(1).toList());
  }
  List<List<String>> toRows() {
    final rows = <List<String>>[
      for (final entry in pricesByTicker.entries)
        for (final value in entry.value.entries)
          [value.key, entry.key, value.value.toString()],
      for (final entry in exchangeRates.entries)
        [entry.key, 'USDKRW', entry.value.toString()],
    ];
    rows.sort((a, b) {
      final date = a[0].compareTo(b[0]);
      return date != 0 ? date : a[1].compareTo(b[1]);
    });
    return rows;
  }

  HistoricalPriceImport merge(HistoricalPriceImport other) {
    final prices = {
      for (final e in pricesByTicker.entries)
        e.key: Map<String, double>.from(e.value),
    };
    for (final e in other.pricesByTicker.entries) {
      (prices[e.key] ??= {}).addAll(e.value);
    }
    return HistoricalPriceImport(
      pricesByTicker: prices,
      exchangeRates: {...exchangeRates, ...other.exchangeRates},
    );
  }

  BackfillPriceData toBackfillData(List<BackfillPriceRequest> requests) =>
      BackfillPriceData(
        pricesByTicker: pricesByTicker,
        exchangeRates: exchangeRates,
        failedSymbols: [
          for (final r in requests)
            if (pricesByTicker[r.ticker]?.isNotEmpty != true) r.ticker,
        ],
      );

  static List<List<String>> _csv(String source) {
    final rows = <List<String>>[], row = <String>[];
    var cell = StringBuffer();
    var quoted = false;
    for (var i = 0; i < source.length; i++) {
      final c = source[i];
      if (c == '"') {
        if (quoted && i + 1 < source.length && source[i + 1] == '"') {
          cell.write('"');
          i++;
        } else {
          quoted = !quoted;
        }
      } else if (!quoted && (c == ',' || c == '\n' || c == '\r')) {
        row.add(cell.toString());
        cell = StringBuffer();
        if (c != ',') {
          rows.add([...row]);
          row.clear();
          if (c == '\r' && i + 1 < source.length && source[i + 1] == '\n') i++;
        }
      } else {
        cell.write(c);
      }
    }
    if (quoted) throw const FormatException('CSV 따옴표가 닫히지 않았습니다.');
    if (cell.isNotEmpty || row.isNotEmpty) {
      row.add(cell.toString());
      rows.add(row);
    }
    return rows;
  }
}
