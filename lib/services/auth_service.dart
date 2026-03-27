import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';
import 'oauth_popup_stub.dart' if (dart.library.html) 'oauth_popup_web.dart'
    as oauth_popup;

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
        if (DateTime.now().millisecondsSinceEpoch < expiryMs) {
          _cachedAccessToken = token;
          return;
        }
      }
      // 2. localStorage 만료/없음 → Workers refresh 시도
      final uid = _firebaseAuth.currentUser?.uid;
      if (uid != null) {
        await _refreshViaWorker(uid);
      }
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

  Future<void> _persistToken(String token, {int? expiresIn}) async {
    if (!kIsWeb) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    final duration = Duration(seconds: (expiresIn ?? 3600) - 60);
    await prefs.setInt(_tokenExpiryKey,
        DateTime.now().add(duration).millisecondsSinceEpoch);
  }

  Future<void> _clearPersistedToken() async {
    if (!kIsWeb) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_tokenExpiryKey);
  }

  /// 로그인
  Future<void> signIn() async {
    if (kIsWeb) {
      await _signInViaWorkers();
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

  /// 웹: Workers OAuth 팝업으로 로그인
  Future<void> _signInViaWorkers() async {
    // Firebase uid가 아직 없으므로 임시 uid 사용 후, Firebase 로그인 완료 후 재매핑
    // → 간단하게: 먼저 Firebase signInWithPopup 없이 Workers로 직접 OAuth
    // → callback에서 id_token을 받아 Firebase에 credential로 등록

    final uid = _firebaseAuth.currentUser?.uid ?? 'pending';
    final loginUrl = '$corsProxyBase/auth/login?uid=$uid';

    final result = await oauth_popup.openOAuthPopup(loginUrl);
    if (result == null) throw Exception('OAuth cancelled');

    final accessToken = result['access_token'] as String?;
    final idToken = result['id_token'] as String?;
    final expiresIn = result['expires_in'] as int?;

    if (accessToken == null) throw Exception('No access token');

    // access token 캐싱
    _cachedAccessToken = accessToken;
    await _persistToken(accessToken, expiresIn: expiresIn);

    // Firebase Auth에 Google credential로 세션 등록
    if (idToken != null) {
      await _firebaseAuth.setPersistence(Persistence.LOCAL);
      final credential = GoogleAuthProvider.credential(
        accessToken: accessToken,
        idToken: idToken,
      );
      final userCred = await _firebaseAuth.signInWithCredential(credential);

      // Firebase uid가 확정되면 Workers KV의 키를 pending → 실제 uid로 이동
      final firebaseUid = userCred.user?.uid;
      if (firebaseUid != null && uid == 'pending') {
        try {
          await http.post(
            Uri.parse('$corsProxyBase/auth/migrate'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'from_uid': 'pending', 'to_uid': firebaseUid}),
          );
        } catch (_) {}
      }
    }
  }

  Future<void> signOut() async {
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

  /// 토큰 반환 (팝업 없이, 실패 시 에러)
  Future<Map<String, String>> getAuthHeaders() async {
    if (_cachedAccessToken != null) {
      final prefs = await SharedPreferences.getInstance();
      final expiryMs = prefs.getInt(_tokenExpiryKey);
      if (expiryMs != null && DateTime.now().millisecondsSinceEpoch < expiryMs) {
        return {'Authorization': 'Bearer $_cachedAccessToken'};
      }
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
      throw Exception('Token expired - re-login required');
    }

    // 네이티브
    final googleUser = _googleSignIn.currentUser ??
        await _googleSignIn.signInSilently();
    if (googleUser != null) {
      return await googleUser.authHeaders;
    }
    throw Exception('Not signed in');
  }

  /// 토큰 반환 (만료 시 Workers 팝업으로 재로그인 포함)
  Future<Map<String, String>> getAuthHeadersInteractive() async {
    try {
      return await getAuthHeaders();
    } catch (_) {
      if (kIsWeb) {
        await _signInViaWorkers();
        if (_cachedAccessToken != null) {
          return {'Authorization': 'Bearer $_cachedAccessToken'};
        }
      }
      throw Exception('Failed to get auth headers');
    }
  }

  Future<bool> requestDriveScope() async {
    if (kIsWeb) return true;
    return await _googleSignIn.requestScopes([
      'https://www.googleapis.com/auth/drive.readonly',
    ]);
  }
}
