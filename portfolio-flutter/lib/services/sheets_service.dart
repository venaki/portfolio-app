import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/transaction.dart';
import '../models/stock_quote.dart';
import '../models/other_asset.dart';
import '../models/app_settings.dart';

class SheetsService {
  static const _baseUrl = 'https://sheets.googleapis.com/v4/spreadsheets';

  final Future<Map<String, String>> Function() _getAuthHeaders;
  String? _spreadsheetId;

  SheetsService({required Future<Map<String, String>> Function() getAuthHeaders})
      : _getAuthHeaders = getAuthHeaders;

  String? get spreadsheetId => _spreadsheetId;

  void setSpreadsheetId(String id) => _spreadsheetId = id;

  // ─── Spreadsheet 생성 ───

  /// 새 스프레드시트 생성 + 4개 시트 + 헤더 + 환율 행
  Future<String> createSpreadsheet() async {
    final headers = await _getAuthHeaders();
    headers['Content-Type'] = 'application/json';

    // 1. 스프레드시트 생성 (4개 시트)
    final createRes = await http.post(
      Uri.parse(_baseUrl),
      headers: headers,
      body: jsonEncode({
        'properties': {'title': 'Portfolio DB'},
        'sheets': [
          {'properties': {'title': 'Transactions'}},
          {'properties': {'title': 'Prices'}},
          {'properties': {'title': 'OtherAssets'}},
          {'properties': {'title': 'Settings'}},
        ],
      }),
    );
    if (createRes.statusCode != 200) {
      throw Exception('Failed to create spreadsheet: ${createRes.body}');
    }
    final created = jsonDecode(createRes.body);
    final id = created['spreadsheetId'] as String;
    _spreadsheetId = id;

    // 2. 헤더 + 초기 데이터 삽입
    await _batchUpdate(id, headers, [
      _valueRange('Transactions!A1:L1', [
        ['id', 'date', 'account', 'type', 'ticker', 'market', 'name', 'shares', 'price', 'currency', 'exchangeRate', 'memo']
      ]),
      _valueRange('Prices!A1:H1', [
        ['ticker', 'market', 'googlefinance_key', 'price', 'name', 'changepct', 'closeyest', 'currency']
      ]),
      // 환율 행 (수식은 userEnteredValue로 별도 삽입)
      _valueRange('OtherAssets!A1:H1', [
        ['id', 'account', 'name', 'category', 'value', 'currency', 'date', 'memo']
      ]),
      _valueRange('Settings!A1:B5', [
        ['accounts', ''],
        ['base_currency', 'KRW'],
        ['accent_color', '#0D6E6E'],
        ['refresh_interval', '60'],
        ['version', '1'],
      ]),
    ]);

    // 3. Prices 시트에 환율 GOOGLEFINANCE 수식 삽입
    await _insertPriceFormula(id, headers, 'USDKRW', 'FX', 'CURRENCY:USDKRW', 'KRW');

    return id;
  }

  // ─── BatchGet (초기 로드) ───

  /// 4개 시트를 한 번에 읽기
  Future<({
    List<Transaction> transactions,
    List<StockQuote> quotes,
    double exchangeRate,
    List<OtherAsset> otherAssets,
    AppSettings settings,
  })> loadAll() async {
    _ensureId();
    final headers = await _getAuthHeaders();
    final ranges = [
      'Transactions!A2:L',
      'Prices!A2:H',
      'OtherAssets!A2:H',
      'Settings!A1:B',
    ].map(Uri.encodeComponent).join('&ranges=');

    final res = await http.get(
      Uri.parse('$_baseUrl/$_spreadsheetId/values:batchGet?ranges=$ranges'),
      headers: headers,
    );
    if (res.statusCode != 200) throw Exception('batchGet failed: ${res.body}');

    final data = jsonDecode(res.body);
    final valueRanges = data['valueRanges'] as List;

    // Transactions
    final txRows = _getRows(valueRanges[0]);
    final transactions = txRows.map((r) => Transaction.fromSheetRow(_padRow(r, 12))).toList();

    // Prices → quotes + exchangeRate
    final priceRows = _getRows(valueRanges[1]);
    final quotes = <StockQuote>[];
    double exchangeRate = 1450;
    for (final row in priceRows) {
      final padded = _padRow(row, 8);
      if (padded[1] == 'FX') {
        exchangeRate = double.tryParse(padded[3]) ?? 1450;
      } else {
        quotes.add(StockQuote.fromSheetRow(padded));
      }
    }

    // OtherAssets
    final oaRows = _getRows(valueRanges[2]);
    final otherAssets = oaRows.map((r) => OtherAsset.fromSheetRow(_padRow(r, 8))).toList();

    // Settings
    final settingsRows = _getRows(valueRanges[3]);
    final settings = AppSettings.fromSheetRows(settingsRows.map((r) => _padRow(r, 2)).toList());

    return (
      transactions: transactions,
      quotes: quotes,
      exchangeRate: exchangeRate,
      otherAssets: otherAssets,
      settings: settings,
    );
  }

  // ─── Prices 시트 읽기 (시세 갱신용) ───

  Future<({List<StockQuote> quotes, double exchangeRate})> loadPrices() async {
    _ensureId();
    final headers = await _getAuthHeaders();
    final res = await http.get(
      Uri.parse('$_baseUrl/$_spreadsheetId/values/${Uri.encodeComponent("Prices!A2:H")}'),
      headers: headers,
    );
    if (res.statusCode != 200) throw Exception('loadPrices failed: ${res.body}');

    final data = jsonDecode(res.body);
    final rows = _getRows(data);
    final quotes = <StockQuote>[];
    double exchangeRate = 1450;
    for (final row in rows) {
      final padded = _padRow(row, 8);
      if (padded[1] == 'FX') {
        exchangeRate = double.tryParse(padded[3]) ?? 1450;
      } else {
        quotes.add(StockQuote.fromSheetRow(padded));
      }
    }
    return (quotes: quotes, exchangeRate: exchangeRate);
  }

  // ─── Transaction CRUD ───

  Future<void> addTransaction(Transaction tx) async {
    _ensureId();
    final headers = await _getAuthHeaders();
    headers['Content-Type'] = 'application/json';
    await http.post(
      Uri.parse('$_baseUrl/$_spreadsheetId/values/Transactions!A:L:append?valueInputOption=RAW'),
      headers: headers,
      body: jsonEncode({'values': [tx.toSheetRow()]}),
    );
  }

  Future<void> updateTransaction(Transaction tx) async {
    final rowIndex = await findRowById('Transactions', tx.id);
    final headers = await _getAuthHeaders();
    headers['Content-Type'] = 'application/json';
    final range = 'Transactions!A${rowIndex + 2}:L${rowIndex + 2}';
    await http.put(
      Uri.parse('$_baseUrl/$_spreadsheetId/values/${Uri.encodeComponent(range)}?valueInputOption=RAW'),
      headers: headers,
      body: jsonEncode({'values': [tx.toSheetRow()]}),
    );
  }

  Future<void> deleteTransaction(String id) async {
    final rowIndex = await findRowById('Transactions', id);
    final headers = await _getAuthHeaders();
    headers['Content-Type'] = 'application/json';
    final metaRes = await http.get(
      Uri.parse('$_baseUrl/$_spreadsheetId?fields=sheets.properties'),
      headers: headers,
    );
    final meta = jsonDecode(metaRes.body);
    final sheets = meta['sheets'] as List;
    final txSheetId = (sheets.firstWhere(
      (s) => s['properties']['title'] == 'Transactions',
    ))['properties']['sheetId'];
    await http.post(
      Uri.parse('$_baseUrl/$_spreadsheetId:batchUpdate'),
      headers: headers,
      body: jsonEncode({
        'requests': [{
          'deleteDimension': {
            'range': {
              'sheetId': txSheetId,
              'dimension': 'ROWS',
              'startIndex': rowIndex + 1,
              'endIndex': rowIndex + 2,
            }
          }
        }]
      }),
    );
  }

  // ─── OtherAsset CRUD ───

  Future<void> addOtherAsset(OtherAsset asset) async {
    _ensureId();
    final headers = await _getAuthHeaders();
    headers['Content-Type'] = 'application/json';
    await http.post(
      Uri.parse('$_baseUrl/$_spreadsheetId/values/OtherAssets!A:H:append?valueInputOption=RAW'),
      headers: headers,
      body: jsonEncode({'values': [asset.toSheetRow()]}),
    );
  }

  Future<void> updateOtherAsset(OtherAsset asset) async {
    final rowIndex = await findRowById('OtherAssets', asset.id);
    final headers = await _getAuthHeaders();
    headers['Content-Type'] = 'application/json';
    final range = 'OtherAssets!A${rowIndex + 2}:H${rowIndex + 2}';
    await http.put(
      Uri.parse('$_baseUrl/$_spreadsheetId/values/${Uri.encodeComponent(range)}?valueInputOption=RAW'),
      headers: headers,
      body: jsonEncode({'values': [asset.toSheetRow()]}),
    );
  }

  Future<void> deleteOtherAsset(String id) async {
    final rowIndex = await findRowById('OtherAssets', id);
    final headers = await _getAuthHeaders();
    headers['Content-Type'] = 'application/json';
    final metaRes = await http.get(
      Uri.parse('$_baseUrl/$_spreadsheetId?fields=sheets.properties'),
      headers: headers,
    );
    final meta = jsonDecode(metaRes.body);
    final sheets = meta['sheets'] as List;
    final oaSheetId = (sheets.firstWhere(
      (s) => s['properties']['title'] == 'OtherAssets',
    ))['properties']['sheetId'];
    await http.post(
      Uri.parse('$_baseUrl/$_spreadsheetId:batchUpdate'),
      headers: headers,
      body: jsonEncode({
        'requests': [{
          'deleteDimension': {
            'range': {
              'sheetId': oaSheetId,
              'dimension': 'ROWS',
              'startIndex': rowIndex + 1,
              'endIndex': rowIndex + 2,
            }
          }
        }]
      }),
    );
  }

  // ─── Prices 시트에 GOOGLEFINANCE 수식 행 추가 ───

  Future<void> addPriceRow(String ticker, String market, String currency) async {
    _ensureId();
    final headers = await _getAuthHeaders();
    headers['Content-Type'] = 'application/json';

    String gfKey;
    switch (market) {
      case 'KRX': gfKey = 'KRX:$ticker'; break;
      case 'KOSDAQ': gfKey = 'KOSDAQ:$ticker'; break;
      default: gfKey = ticker; break;
    }

    await _insertPriceFormula(_spreadsheetId!, headers, ticker, market, gfKey, currency);
  }

  // ─── Settings 업데이트 ───

  Future<void> saveSettings(AppSettings settings) async {
    _ensureId();
    final headers = await _getAuthHeaders();
    headers['Content-Type'] = 'application/json';
    await http.put(
      Uri.parse('$_baseUrl/$_spreadsheetId/values/${Uri.encodeComponent("Settings!A1:B5")}?valueInputOption=RAW'),
      headers: headers,
      body: jsonEncode({'values': settings.toSheetRows()}),
    );
  }

  /// ID로 시트에서 행 번호 찾기 (0-based data index)
  Future<int> findRowById(String sheetName, String id) async {
    _ensureId();
    final headers = await _getAuthHeaders();
    final range = Uri.encodeComponent('$sheetName!A2:A');
    final res = await http.get(
      Uri.parse('$_baseUrl/$_spreadsheetId/values/$range'),
      headers: headers,
    );
    if (res.statusCode != 200) throw Exception('findRowById failed: ${res.body}');
    final data = jsonDecode(res.body);
    final rows = (data['values'] as List?)?.cast<List<dynamic>>() ?? [];
    for (int i = 0; i < rows.length; i++) {
      if (rows[i].isNotEmpty && rows[i][0].toString() == id) return i;
    }
    throw Exception('Row with id "$id" not found in $sheetName');
  }

  // ─── Private helpers ───

  void _ensureId() {
    if (_spreadsheetId == null) throw Exception('Spreadsheet ID not set');
  }

  Future<void> _insertPriceFormula(
    String ssId, Map<String, String> headers,
    String ticker, String market, String gfKey, String currency,
  ) async {
    // Append row with formulas using USER_ENTERED
    await http.post(
      Uri.parse('$_baseUrl/$ssId/values/Prices!A:H:append?valueInputOption=USER_ENTERED'),
      headers: headers,
      body: jsonEncode({
        'values': [
          [
            ticker,
            market,
            gfKey,
            '=GOOGLEFINANCE("$gfKey","price")',
            '=GOOGLEFINANCE("$gfKey","name")',
            '=GOOGLEFINANCE("$gfKey","changepct")',
            '=GOOGLEFINANCE("$gfKey","closeyest")',
            currency,
          ]
        ]
      }),
    );
  }

  Future<void> _batchUpdate(String ssId, Map<String, String> headers, List<Map<String, dynamic>> data) async {
    await http.post(
      Uri.parse('$_baseUrl/$ssId/values:batchUpdate'),
      headers: headers,
      body: jsonEncode({
        'valueInputOption': 'RAW',
        'data': data,
      }),
    );
  }

  Map<String, dynamic> _valueRange(String range, List<List<String>> values) {
    return {'range': range, 'values': values};
  }

  List<List<dynamic>> _getRows(dynamic valueRange) {
    return (valueRange['values'] as List?)?.cast<List<dynamic>>() ?? [];
  }

  List<String> _padRow(List<dynamic> row, int length) {
    return List.generate(length, (i) => i < row.length ? row[i].toString() : '');
  }
}
