import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// A failed HTTP response must never be confused with a successful write.
class SheetsApiException implements Exception {
  final int? statusCode;
  final String message;

  const SheetsApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class SheetsApiClient {
  final Future<Map<String, String>> Function() getAuthHeaders;
  final http.Client _client;
  final Duration timeout;
  final void Function()? onUnauthorized;

  SheetsApiClient({
    required this.getAuthHeaders,
    http.Client? client,
    this.timeout = const Duration(seconds: 25),
    this.onUnauthorized,
  }) : _client = client ?? http.Client();

  Future<Map<String, dynamic>> request(
    String method,
    Uri uri, {
    Map<String, dynamic>? body,
  }) async {
    try {
      final headers = Map<String, String>.from(
        await getAuthHeaders().timeout(timeout),
      )..['Content-Type'] = 'application/json';
      final request = http.Request(method, uri)..headers.addAll(headers);
      if (body != null) request.body = jsonEncode(body);
      final response = await _client
          .send(request)
          .then(http.Response.fromStream)
          .timeout(timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        if (response.statusCode == 401) onUnauthorized?.call();
        final message = switch (response.statusCode) {
          401 => '로그인이 만료되었습니다. 다시 로그인해 주세요.',
          403 => '이 스프레드시트에 필요한 권한이 없습니다. 편집 권한을 확인해 주세요.',
          404 => '스프레드시트 또는 시트를 찾을 수 없습니다.',
          409 => '다른 작업과 충돌했습니다. 다시 불러온 뒤 시도해 주세요.',
          429 => 'Google Sheets 요청 한도에 도달했습니다. 잠시 후 다시 시도해 주세요.',
          >= 500 => 'Google Sheets에 일시적인 문제가 있습니다. 잠시 후 다시 시도해 주세요.',
          _ => 'Google Sheets 요청이 실패했습니다 (${response.statusCode}).',
        };
        throw SheetsApiException(message, statusCode: response.statusCode);
      }
      if (response.body.isEmpty) return {};
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic> || decoded.containsKey('error')) {
        throw const SheetsApiException('Google Sheets 응답 형식이 올바르지 않습니다.');
      }
      return decoded;
    } on SheetsApiException {
      rethrow;
    } on TimeoutException {
      // A timed-out mutation may have reached Google. Do not blindly append again.
      throw const SheetsApiException(
        '요청 시간이 초과되었습니다. 저장 여부를 다시 불러와 확인한 뒤 재시도해 주세요.',
      );
    } on http.ClientException {
      throw const SheetsApiException('연결이 끊겼습니다. 네트워크를 확인하고 다시 불러와 주세요.');
    } on FormatException {
      throw const SheetsApiException('Google Sheets 응답을 읽을 수 없습니다.');
    }
  }

  void close() => _client.close();
}
