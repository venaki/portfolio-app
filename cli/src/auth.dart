import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

class LocalState {
  final Directory directory;
  LocalState(String path) : directory = Directory(path);
  Future<void> prepare() async {
    await directory.create(recursive: true);
    if (!Platform.isWindows) {
      final result = await Process.run('chmod', ['700', directory.path]);
      if (result.exitCode != 0) throw StateError('설정 디렉터리 권한 설정 실패');
    }
  }

  File file(String name) => File('${directory.path}/$name.json');
  Future<Map<String, dynamic>> read(String name) async =>
      await file(name).exists()
      ? Map<String, dynamic>.from(
          jsonDecode(await file(name).readAsString()) as Map,
        )
      : {};
  Future<void> write(String name, Object value) async {
    await prepare();
    final temp = File('${file(name).path}.${randomString()}.tmp');
    await temp.writeAsString(jsonEncode(value), flush: true);
    if (!Platform.isWindows) {
      final result = await Process.run('chmod', ['600', temp.path]);
      if (result.exitCode != 0) throw StateError('설정 파일 권한 설정 실패');
    }
    await temp.rename(file(name).path);
  }
}

String randomString() => base64Url
    .encode(List.generate(32, (_) => Random.secure().nextInt(256)))
    .replaceAll('=', '');

class GoogleAuth {
  final LocalState state;
  GoogleAuth(this.state);
  static const scope = 'https://www.googleapis.com/auth/spreadsheets';
  Future<Map<String, dynamic>> _token(Map<String, String> fields) async {
    final response = await http
        .post(Uri.parse('https://oauth2.googleapis.com/token'), body: fields)
        .timeout(const Duration(seconds: 30));
    if (response.statusCode != 200)
      throw StateError(
        'Google 인증 실패 (${response.statusCode}). auth login을 다시 실행하세요.',
      );
    final data = Map<String, dynamic>.from(jsonDecode(response.body) as Map);
    if (data['access_token'] is! String) throw StateError('잘못된 인증 응답');
    data['expires_at'] =
        DateTime.now().millisecondsSinceEpoch +
        ((data['expires_in'] as num?)?.toInt() ?? 3600) * 1000;
    return data;
  }

  Future<void> login(String clientFile) async {
    final source = jsonDecode(await File(clientFile).readAsString()) as Map;
    if (source['installed'] is! Map)
      throw FormatException('Google Desktop app OAuth 클라이언트 JSON이 필요합니다.');
    final client = Map<String, dynamic>.from(source['installed'] as Map);
    final clientId = client['client_id'] as String;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final redirect = 'http://127.0.0.1:${server.port}/callback';
    final nonce = randomString(), verifier = randomString();
    final challenge = base64Url
        .encode(sha256.convert(utf8.encode(verifier)).bytes)
        .replaceAll('=', '');
    final url = Uri.https('accounts.google.com', '/o/oauth2/v2/auth', {
      'client_id': clientId,
      'redirect_uri': redirect,
      'response_type': 'code',
      'scope': scope,
      'access_type': 'offline',
      'prompt': 'consent',
      'state': nonce,
      'code_challenge': challenge,
      'code_challenge_method': 'S256',
    });
    stderr.writeln('브라우저에서 아래 URL을 열고 Google 로그인을 완료하세요:\n$url');
    final result = Completer<String>();
    final subscription = server.listen((request) async {
      final q = request.uri.queryParameters;
      if (request.uri.path != '/callback' || q['state'] != nonce) {
        request.response.statusCode = 400;
        request.response.write('Invalid callback');
      } else if (q['error'] != null) {
        request.response.write('Authorization declined.');
        if (!result.isCompleted)
          result.completeError(StateError('Google 인증이 거절되었습니다.'));
      } else if (q['code'] != null) {
        request.response.write(
          'Authorization received. You can close this window.',
        );
        if (!result.isCompleted) result.complete(q['code']!);
      } else {
        request.response.statusCode = 400;
      }
      await request.response.close();
    });
    try {
      final code = await result.future.timeout(const Duration(minutes: 5));
      final tokens = await _token({
        'client_id': clientId,
        if (client['client_secret'] is String)
          'client_secret': client['client_secret'] as String,
        'code': code,
        'code_verifier': verifier,
        'redirect_uri': redirect,
        'grant_type': 'authorization_code',
      });
      if (tokens['refresh_token'] is! String)
        throw StateError('장기 인증이 발급되지 않았습니다. 다시 인증하세요.');
      await state.write('auth', {
        'client_id': clientId,
        'client_secret': client['client_secret'],
        ...tokens,
      });
    } finally {
      await subscription.cancel();
      await server.close(force: true);
    }
  }

  Future<Map<String, String>> headers() async {
    // Optional short-lived token injection for automation; never stored or printed.
    final injected = Platform.environment['PORTFOLIO_ACCESS_TOKEN'];
    if (injected != null && injected.isNotEmpty)
      return {'Authorization': 'Bearer $injected'};
    var auth = await state.read('auth');
    if (auth['refresh_token'] is! String)
      throw StateError(
        'CLI 인증이 필요합니다: auth login --client <desktop-client.json>',
      );
    if ((auth['expires_at'] as num? ?? 0) <
        DateTime.now().millisecondsSinceEpoch + 60000) {
      final tokens = await _token({
        'client_id': auth['client_id'] as String,
        if (auth['client_secret'] is String)
          'client_secret': auth['client_secret'] as String,
        'refresh_token': auth['refresh_token'] as String,
        'grant_type': 'refresh_token',
      });
      auth = {...auth, ...tokens};
      await state.write('auth', auth);
    }
    return {'Authorization': 'Bearer ${auth['access_token']}'};
  }
}
