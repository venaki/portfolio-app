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
      _valueRange('Transactions!A1:M1', [
        ['id', 'date', 'account', 'type', 'ticker', 'market', 'name', 'shares', 'price', 'currency', 'exchangeRate', 'memo', 'broker']
      ]),
      _valueRange('Prices!A1:H1', [
        ['ticker', 'market', 'googlefinance_key', 'price', 'name', 'changepct', 'closeyest', 'currency']
      ]),
      // 환율 행 (수식은 userEnteredValue로 별도 삽입)
      _valueRange('OtherAssets!A1:H1', [
        ['id', 'account', 'name', 'category', 'value', 'currency', 'date', 'memo']
      ]),
      _valueRange('Settings!A1:B7', [
        ['accounts', ''],
        ['brokers', ''],
        ['base_currency', 'KRW'],
        ['accent_color', '#0D6E6E'],
        ['refresh_interval', '60'],
        ['version', '1'],
        ['exchange_rate', ''],
      ]),
    ]);

    // 3. Prices 시트에 환율 GOOGLEFINANCE 수식 삽입
    await _insertPriceFormula(id, headers, 'USDKRW', 'FX', 'CURRENCY:USDKRW', 'KRW');

    // 4. Settings 시트에 환율 GOOGLEFINANCE 수식 삽입
    await _insertSettingsExchangeRate(id, headers);

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
      'Transactions!A2:Z',
      'Prices!A2:H',
      'OtherAssets!A2:H',
      'Settings!A1:B',
    ].map(Uri.encodeComponent).join('&ranges=');

    final res = await http.get(
      Uri.parse('$_baseUrl/$_spreadsheetId/values:batchGet?valueRenderOption=UNFORMATTED_VALUE&ranges=$ranges'),
      headers: headers,
    );
    if (res.statusCode != 200) throw Exception('batchGet failed: ${res.body}');

    final data = jsonDecode(res.body);
    final valueRanges = data['valueRanges'] as List;

    // Transactions
    final txRows = _getRows(valueRanges[0]);
    final transactions = txRows.map((r) => Transaction.fromSheetRow(_padRow(r, 13))).toList();

    // Prices → quotes + exchangeRate
    final priceRows = _getRows(valueRanges[1]);
    final quotes = <StockQuote>[];
    double exchangeRate = 1450;
    bool hasFxRow = false;
    for (final row in priceRows) {
      final padded = _padRow(row, 8);
      if (padded[1] == 'FX') {
        hasFxRow = true;
        exchangeRate = double.tryParse(padded[3]) ?? 1450;
      } else {
        quotes.add(StockQuote.fromSheetRow(padded));
      }
    }

    // FX 행이 없으면 자동 삽입
    if (!hasFxRow) {
      final authHeaders = await _getAuthHeaders();
      authHeaders['Content-Type'] = 'application/json';
      await _insertPriceFormula(
        _spreadsheetId!, authHeaders, 'USDKRW', 'FX', 'CURRENCY:USDKRW', 'KRW',
      );
    }

    // OtherAssets
    final oaRows = _getRows(valueRanges[2]);
    final otherAssets = oaRows.map((r) => OtherAsset.fromSheetRow(_padRow(r, 8))).toList();

    // Settings
    final settingsRows = _getRows(valueRanges[3]);
    final settings = AppSettings.fromSheetRows(settingsRows.map((r) => _padRow(r, 2)).toList());

    // Settings의 환율 우선, 없으면 Prices FX 행 fallback
    final finalExchangeRate = settings.exchangeRate ?? exchangeRate;

    // 기존 시트에 Settings exchange_rate가 없으면 자동 추가
    if (settings.exchangeRate == null) {
      final authHeaders = await _getAuthHeaders();
      authHeaders['Content-Type'] = 'application/json';
      await _insertSettingsExchangeRate(_spreadsheetId!, authHeaders);
    }

    return (
      transactions: transactions,
      quotes: quotes,
      exchangeRate: finalExchangeRate,
      otherAssets: otherAssets,
      settings: settings,
    );
  }

  // ─── Prices 시트 읽기 (시세 갱신용) ───

  Future<({List<StockQuote> quotes, double exchangeRate})> loadPrices() async {
    _ensureId();
    final headers = await _getAuthHeaders();
    final ranges = [
      'Prices!A2:H',
      'Settings!A1:B',
    ].map(Uri.encodeComponent).join('&ranges=');

    final res = await http.get(
      Uri.parse('$_baseUrl/$_spreadsheetId/values:batchGet?valueRenderOption=UNFORMATTED_VALUE&ranges=$ranges'),
      headers: headers,
    );
    if (res.statusCode != 200) throw Exception('loadPrices failed: ${res.body}');

    final data = jsonDecode(res.body);
    final valueRanges = data['valueRanges'] as List;

    // Prices → quotes + FX fallback
    final rows = _getRows(valueRanges[0]);
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

    // Settings에서 환율 읽기 (우선)
    final settingsRows = _getRows(valueRanges[1]);
    final settings = AppSettings.fromSheetRows(settingsRows.map((r) => _padRow(r, 2)).toList());
    if (settings.exchangeRate != null) {
      exchangeRate = settings.exchangeRate!;
    }

    return (quotes: quotes, exchangeRate: exchangeRate);
  }

  // ─── 강제 시세 갱신 ───

  /// GOOGLEFINANCE 수식 셀만 변조 → 복원하여 캐시 클리어 시도 (best-effort)
  Future<({List<StockQuote> quotes, double exchangeRate})> forceRefreshPrices({
    int waitSeconds = 3,
  }) async {
    _ensureId();
    final headers = await _getAuthHeaders();
    headers['Content-Type'] = 'application/json';

    // 1. Prices + Settings 수식을 동시 읽기
    final ranges = [
      'Prices!A2:H',
      'Settings!A1:B',
    ].map(Uri.encodeComponent).join('&ranges=');
    final res = await http.get(
      Uri.parse('$_baseUrl/$_spreadsheetId/values:batchGet?valueRenderOption=FORMULA&ranges=$ranges'),
      headers: headers,
    );
    if (res.statusCode != 200) return loadPrices();

    final valueRanges = (jsonDecode(res.body)['valueRanges'] as List);
    final priceRows = _getRows(valueRanges[0]);
    final settingsRows = _getRows(valueRanges[1]);

    // 2. GOOGLEFINANCE 수식 셀만 감지하여 break/restore 데이터 구성
    final breakData = <Map<String, dynamic>>[];
    final restoreData = <Map<String, dynamic>>[];

    // Prices 시트: 수식 셀만 개별 범위로
    for (int i = 0; i < priceRows.length; i++) {
      for (int j = 0; j < priceRows[i].length; j++) {
        final cell = priceRows[i][j].toString();
        if (cell.startsWith('=') && cell.contains('GOOGLEFINANCE')) {
          final col = String.fromCharCode('A'.codeUnitAt(0) + j);
          final range = 'Prices!$col${i + 2}';
          restoreData.add({'range': range, 'values': [[cell]]});
          breakData.add({'range': range, 'values': [[_breakFormula(cell)]]});
        }
      }
    }

    // Settings 시트: exchange_rate 행의 B열
    for (int i = 0; i < settingsRows.length; i++) {
      if (settingsRows[i].isNotEmpty &&
          settingsRows[i][0].toString() == 'exchange_rate' &&
          settingsRows[i].length >= 2) {
        final cell = settingsRows[i][1].toString();
        if (cell.startsWith('=') && cell.contains('GOOGLEFINANCE')) {
          final range = 'Settings!B${i + 1}';
          restoreData.add({'range': range, 'values': [[cell]]});
          breakData.add({'range': range, 'values': [[_breakFormula(cell)]]});
        }
      }
    }

    // 수식 셀이 없으면 바로 loadPrices
    if (breakData.isEmpty) return loadPrices();

    final batchUrl = '$_baseUrl/$_spreadsheetId/values:batchUpdate';

    // 3. 변조된 수식 쓰기
    final breakRes = await http.post(
      Uri.parse(batchUrl),
      headers: headers,
      body: jsonEncode({
        'valueInputOption': 'USER_ENTERED',
        'data': breakData,
      }),
    );
    if (breakRes.statusCode != 200) {
      throw Exception('Force refresh break failed: ${breakRes.statusCode}');
    }

    // 4. 대기 후 원본 수식 복원
    await Future.delayed(Duration(seconds: waitSeconds));
    var restoreRes = await http.post(
      Uri.parse(batchUrl),
      headers: headers,
      body: jsonEncode({
        'valueInputOption': 'USER_ENTERED',
        'data': restoreData,
      }),
    );
    // 복원 실패 시 1회 재시도
    if (restoreRes.statusCode != 200) {
      await Future.delayed(const Duration(seconds: 1));
      restoreRes = await http.post(
        Uri.parse(batchUrl),
        headers: headers,
        body: jsonEncode({
          'valueInputOption': 'USER_ENTERED',
          'data': restoreData,
        }),
      );
      if (restoreRes.statusCode != 200) {
        throw Exception(
          'Force refresh restore failed: ${restoreRes.statusCode}. '
          '수식이 변조된 상태일 수 있습니다.',
        );
      }
    }

    // 5. 재계산 대기 후 값 읽기
    await Future.delayed(Duration(seconds: waitSeconds));
    return loadPrices();
  }

  /// GOOGLEFINANCE 수식의 티커를 1자 잘라서 변조
  String _breakFormula(String formula) {
    return formula.replaceAllMapped(
      RegExp(r'GOOGLEFINANCE\("([^"]{2,})"'),
      (m) {
        final ticker = m.group(1)!;
        return 'GOOGLEFINANCE("${ticker.substring(0, ticker.length - 1)}"';
      },
    );
  }

  // ─── Transaction CRUD ───

  Future<void> addTransaction(Transaction tx) async {
    _ensureId();
    final headers = await _getAuthHeaders();
    headers['Content-Type'] = 'application/json';
    await http.post(
      Uri.parse('$_baseUrl/$_spreadsheetId/values/Transactions!A:Z:append?valueInputOption=RAW'),
      headers: headers,
      body: jsonEncode({'values': [tx.toSheetRow()]}),
    );
  }

  Future<void> updateTransaction(Transaction tx) async {
    final rowIndex = await findRowById('Transactions', tx.id);
    final headers = await _getAuthHeaders();
    headers['Content-Type'] = 'application/json';
    final range = 'Transactions!A${rowIndex + 2}:Z${rowIndex + 2}';
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

    // 한국 주식: 6자리 정규화 + IFERROR로 KRX/KOSDAQ 둘 다 시도
    final isKorean = market == 'KRX' || market == 'KOSDAQ';
    if (isKorean && RegExp(r'^\d+$').hasMatch(ticker) && ticker.length < 6) {
      ticker = ticker.padLeft(6, '0');
    }
    final gfKey = isKorean ? 'KRX:$ticker' : ticker;

    await _insertPriceFormula(_spreadsheetId!, headers, ticker, market, gfKey, currency, isKorean: isKorean);
  }

  // ─── Settings 업데이트 ───

  Future<void> saveSettings(AppSettings settings) async {
    _ensureId();
    final headers = await _getAuthHeaders();
    headers['Content-Type'] = 'application/json';

    // USER_ENTERED로 쓰기 (GOOGLEFINANCE 수식 보존)
    final rows = settings.toSheetRows();
    final endRow = rows.length;
    await http.put(
      Uri.parse('$_baseUrl/$_spreadsheetId/values/${Uri.encodeComponent("Settings!A1:B$endRow")}?valueInputOption=USER_ENTERED'),
      headers: headers,
      body: jsonEncode({'values': rows}),
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
    String ticker, String market, String gfKey, String currency, {
    bool isKorean = false,
  }) async {
    // 한국 주식: IFERROR(KRX, KOSDAQ)로 양쪽 거래소 모두 시도
    String priceFormula, nameFormula, changePctFormula, closeYestFormula;
    if (isKorean) {
      final krx = 'KRX:$ticker';
      final kosdaq = 'KOSDAQ:$ticker';
      priceFormula = '=IFERROR(GOOGLEFINANCE("$krx","price"),GOOGLEFINANCE("$kosdaq","price"))';
      nameFormula = '=IFERROR(GOOGLEFINANCE("$krx","name"),GOOGLEFINANCE("$kosdaq","name"))';
      changePctFormula = '=IFERROR(GOOGLEFINANCE("$krx","changepct"),GOOGLEFINANCE("$kosdaq","changepct"))';
      closeYestFormula = '=IFERROR(GOOGLEFINANCE("$krx","closeyest"),GOOGLEFINANCE("$kosdaq","closeyest"))';
    } else if (market == 'FX') {
      // 환율: 속성 없이 호출해야 정상 작동
      priceFormula = '=GOOGLEFINANCE("$gfKey")';
      nameFormula = '';
      changePctFormula = '';
      closeYestFormula = '';
    } else {
      priceFormula = '=GOOGLEFINANCE("$gfKey","price")';
      nameFormula = '=GOOGLEFINANCE("$gfKey","name")';
      changePctFormula = '=GOOGLEFINANCE("$gfKey","changepct")';
      closeYestFormula = '=GOOGLEFINANCE("$gfKey","closeyest")';
    }

    // 한국 종목코드: 앞자리 0 보존을 위해 텍스트 접두사(') 추가
    final tickerValue = isKorean ? "'$ticker" : ticker;

    await http.post(
      Uri.parse('$_baseUrl/$ssId/values/Prices!A:H:append?valueInputOption=USER_ENTERED'),
      headers: headers,
      body: jsonEncode({
        'values': [
          [tickerValue, market, gfKey, priceFormula, nameFormula, changePctFormula, closeYestFormula, currency]
        ]
      }),
    );
  }

  /// Settings 시트에 환율 GOOGLEFINANCE 수식 삽입 (마이그레이션용)
  Future<void> _insertSettingsExchangeRate(String ssId, Map<String, String> headers) async {
    // Settings에서 기존 행을 읽어 exchange_rate 행 위치를 찾거나 append
    final res = await http.get(
      Uri.parse('$_baseUrl/$ssId/values/${Uri.encodeComponent("Settings!A1:B")}'),
      headers: headers,
    );
    if (res.statusCode != 200) return;

    final data = jsonDecode(res.body);
    final rows = _getRows(data);

    // exchange_rate 행이 이미 있는지 확인
    int existingRow = -1;
    for (int i = 0; i < rows.length; i++) {
      if (rows[i].isNotEmpty && rows[i][0].toString() == 'exchange_rate') {
        existingRow = i;
        break;
      }
    }

    if (existingRow >= 0) {
      // 기존 행에 수식 덮어쓰기
      final row = existingRow + 1; // 1-based
      await http.put(
        Uri.parse('$_baseUrl/$ssId/values/${Uri.encodeComponent("Settings!A$row:B$row")}?valueInputOption=USER_ENTERED'),
        headers: headers,
        body: jsonEncode({'values': [['exchange_rate', '=GOOGLEFINANCE("USDKRW")']]}),
      );
    } else {
      // 새 행 추가
      await http.post(
        Uri.parse('$_baseUrl/$ssId/values/Settings!A:B:append?valueInputOption=USER_ENTERED'),
        headers: headers,
        body: jsonEncode({'values': [['exchange_rate', '=GOOGLEFINANCE("USDKRW")']]}),
      );
    }
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
