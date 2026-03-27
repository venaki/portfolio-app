import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';

class AuthService {
  static const _scopes = [
    'https://www.googleapis.com/auth/spreadsheets',
    'https://www.googleapis.com/auth/drive.readonly',
  ];

  static const _tokenKey = 'google_access_token';
  static const _tokenExpiryKey = 'google_token_expiry';

  // 네이티브 전용
  final _googleSignIn = GoogleSignIn(scopes: _scopes);

  FirebaseAuth get _firebaseAuth => FirebaseAuth.instance;

  String? _cachedAccessToken;

  User? get currentUser => _firebaseAuth.currentUser;
  bool get isSignedIn => _firebaseAuth.currentUser != null;

  /// 앱 시작 시 토큰 복원
  Future<void> restoreGoogleToken() async {
    if (kIsWeb) {
      // 1. localStorage에서 캐시된 토큰 확인
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_tokenKey);
      final expiryMs = prefs.getInt(_tokenExpiryKey);
      if (token != null && expiryMs != null) {
        final expiry = DateTime.fromMillisecondsSinceEpoch(expiryMs);
        if (DateTime.now().isBefore(expiry)) {
          _cachedAccessToken = token;
          return;
        }
      }
      // 2. 캐시 만료/없음 → Workers로 refresh 시도
      final uid = _firebaseAuth.currentUser?.uid;
      if (uid != null) {
        final refreshed = await _refreshViaWorker(uid);
        if (refreshed) return;
      }
      // 3. refresh도 실패 → getAuthHeaders에서 팝업 유도
      return;
    }
    await _googleSignIn.signInSilently();
  }

  /// Workers /auth/refresh로 토큰 갱신
  Future<bool> _refreshViaWorker(String uid) async {
    try {
      final res = await http.post(
        Uri.parse('$corsProxyBase/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'uid': uid}),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final token = data['access_token'] as String?;
        final expiresIn = data['expires_in'] as int?;
        if (token != null) {
          _cachedAccessToken = token;
          await _persistToken(token, expiresIn: expiresIn);
          return true;
        }
      }
    } catch (_) {}
    return false;
  }

  /// 웹: 토큰을 localStorage에 저장
  Future<void> _persistToken(String token, {int? expiresIn}) async {
    if (!kIsWeb) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    final duration = Duration(seconds: (expiresIn ?? 3600) - 60);
    await prefs.setInt(_tokenExpiryKey,
        DateTime.now().add(duration).millisecondsSinceEpoch);
  }

  /// 웹: localStorage에서 토큰 제거
  Future<void> _clearPersistedToken() async {
    if (!kIsWeb) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_tokenExpiryKey);
  }

  Future<void> signIn() async {
    if (kIsWeb) {
      await _firebaseAuth.setPersistence(Persistence.LOCAL);
      final provider = GoogleAuthProvider();
      for (final scope in _scopes) {
        provider.addScope(scope);
      }
      // offline access를 위해 access_type=offline, prompt=consent 추가
      provider.setCustomParameters({
        'access_type': 'offline',
        'prompt': 'consent',
      });
      final result = await _firebaseAuth.signInWithPopup(provider);
      if (result.credential != null) {
        final oAuth = result.credential as OAuthCredential;
        _cachedAccessToken = oAuth.accessToken;
        if (oAuth.accessToken != null) {
          await _persistToken(oAuth.accessToken!);
        }

        // authorization code가 있으면 Workers로 exchange하여 refresh token 저장
        if (oAuth.accessToken != null && _firebaseAuth.currentUser != null) {
          await _exchangeForRefreshToken(result);
        }
      }
    } else {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return;

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await _firebaseAuth.signInWithCredential(credential);
    }
  }

  /// Firebase signInWithPopup 결과에서 serverAuthCode 추출 시도
  /// Firebase Web SDK는 authorization code를 직접 노출하지 않으므로,
  /// google_sign_in 패키지를 통해 serverAuthCode를 받아 exchange
  Future<void> _exchangeForRefreshToken(UserCredential result) async {
    try {
      // google_sign_in으로 serverAuthCode 획득 시도
      final googleUser = await _googleSignIn.signInSilently();
      if (googleUser == null) {
        // signInSilently 실패 시 interactive sign-in
        final interactive = await _googleSignIn.signIn();
        if (interactive == null) return;
        await _doExchange(interactive);
      } else {
        await _doExchange(googleUser);
      }
    } catch (_) {
      // exchange 실패해도 access token은 이미 있으므로 계속 진행
    }
  }

  Future<void> _doExchange(GoogleSignInAccount account) async {
    final serverAuthCode = account.serverAuthCode;
    if (serverAuthCode == null) return;
    final uid = _firebaseAuth.currentUser?.uid;
    if (uid == null) return;

    try {
      await http.post(
        Uri.parse('$corsProxyBase/auth/exchange'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'code': serverAuthCode,
          'redirect_uri': '',
          'uid': uid,
        }),
      );
    } catch (_) {}
  }

  Future<void> signOut() async {
    // Workers에서 refresh token 삭제
    final uid = _firebaseAuth.currentUser?.uid;
    if (uid != null && kIsWeb) {
      try {
        await http.post(
          Uri.parse('$corsProxyBase/auth/revoke'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'uid': uid}),
        );
      } catch (_) {}
    }

    _cachedAccessToken = null;
    await _clearPersistedToken();
    if (kIsWeb) {
      await _firebaseAuth.signOut();
    } else {
      await Future.wait([
        _firebaseAuth.signOut(),
        _googleSignIn.signOut(),
      ]);
    }
  }

  Future<Map<String, String>> getAuthHeaders() async {
    // 캐시된 토큰이 유효하면 사용
    if (_cachedAccessToken != null) {
      // 만료 확인
      final prefs = await SharedPreferences.getInstance();
      final expiryMs = prefs.getInt(_tokenExpiryKey);
      if (expiryMs != null && DateTime.now().millisecondsSinceEpoch < expiryMs) {
        return {'Authorization': 'Bearer $_cachedAccessToken'};
      }
      // 만료됨 → refresh 시도
      _cachedAccessToken = null;
    }

    // 웹: Workers refresh 시도
    if (kIsWeb) {
      final uid = _firebaseAuth.currentUser?.uid;
      if (uid != null) {
        final refreshed = await _refreshViaWorker(uid);
        if (refreshed) {
          return {'Authorization': 'Bearer $_cachedAccessToken'};
        }
      }

      // refresh 실패 → 팝업으로 재로그인
      final provider = GoogleAuthProvider();
      for (final scope in _scopes) {
        provider.addScope(scope);
      }
      provider.setCustomParameters({
        'access_type': 'offline',
        'prompt': 'consent',
      });
      final result = await _firebaseAuth.signInWithPopup(provider);
      if (result.credential != null) {
        final oAuth = result.credential as OAuthCredential;
        _cachedAccessToken = oAuth.accessToken;
        if (oAuth.accessToken != null) {
          await _persistToken(oAuth.accessToken!);
          if (_firebaseAuth.currentUser != null) {
            await _exchangeForRefreshToken(result);
          }
        }
        return {'Authorization': 'Bearer $_cachedAccessToken'};
      }
      throw Exception('Failed to get auth headers');
    }

    // 네이티브: google_sign_in 사용
    final googleUser = _googleSignIn.currentUser ??
        await _googleSignIn.signInSilently();
    if (googleUser != null) {
      return await googleUser.authHeaders;
    }
    throw Exception('Not signed in');
  }

  /// Drive 스코프 요청 (웹에서는 이미 로그인 시 포함됨)
  Future<bool> requestDriveScope() async {
    if (kIsWeb) return true;
    return await _googleSignIn.requestScopes([
      'https://www.googleapis.com/auth/drive.readonly',
    ]);
  }
}
