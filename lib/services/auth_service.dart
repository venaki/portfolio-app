import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_tokenKey);
      final expiryMs = prefs.getInt(_tokenExpiryKey);
      if (token != null && expiryMs != null) {
        final expiry = DateTime.fromMillisecondsSinceEpoch(expiryMs);
        if (DateTime.now().isBefore(expiry)) {
          _cachedAccessToken = token;
        } else {
          await prefs.remove(_tokenKey);
          await prefs.remove(_tokenExpiryKey);
        }
      }
      return;
    }
    await _googleSignIn.signInSilently();
  }

  /// 웹: 토큰을 localStorage에 저장
  Future<void> _persistToken(String token) async {
    if (!kIsWeb) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    // Google access token 유효기간 3600초, 1분 여유 두고 3540초
    await prefs.setInt(_tokenExpiryKey,
        DateTime.now().add(const Duration(seconds: 3540)).millisecondsSinceEpoch);
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
      final result = await _firebaseAuth.signInWithPopup(provider);
      if (result.credential != null) {
        final oAuth = result.credential as OAuthCredential;
        _cachedAccessToken = oAuth.accessToken;
        if (oAuth.accessToken != null) {
          await _persistToken(oAuth.accessToken!);
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

  Future<void> signOut() async {
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
    // 캐시된 토큰이 유효하면 사용
    if (_cachedAccessToken != null) {
      final prefs = await SharedPreferences.getInstance();
      final expiryMs = prefs.getInt(_tokenExpiryKey);
      if (expiryMs != null && DateTime.now().millisecondsSinceEpoch < expiryMs) {
        return {'Authorization': 'Bearer $_cachedAccessToken'};
      }
      _cachedAccessToken = null;
    }

    // 웹: 팝업 없이 실패 → 호출측에서 처리
    if (kIsWeb) {
      throw Exception('Token expired - re-login required');
    }

    // 네이티브: google_sign_in 사용
    final googleUser = _googleSignIn.currentUser ??
        await _googleSignIn.signInSilently();
    if (googleUser != null) {
      return await googleUser.authHeaders;
    }
    throw Exception('Not signed in');
  }

  /// 토큰 반환 (만료 시 팝업으로 재로그인 포함)
  Future<Map<String, String>> getAuthHeadersInteractive() async {
    try {
      return await getAuthHeaders();
    } catch (_) {
      // 팝업으로 재로그인
      final provider = GoogleAuthProvider();
      for (final scope in _scopes) {
        provider.addScope(scope);
      }
      final result = await _firebaseAuth.signInWithPopup(provider);
      if (result.credential != null) {
        final oAuth = result.credential as OAuthCredential;
        _cachedAccessToken = oAuth.accessToken;
        if (oAuth.accessToken != null) {
          await _persistToken(oAuth.accessToken!);
        }
        return {'Authorization': 'Bearer $_cachedAccessToken'};
      }
      throw Exception('Failed to get auth headers');
    }
  }

  /// Drive 스코프 요청 (웹에서는 이미 로그인 시 포함됨)
  Future<bool> requestDriveScope() async {
    if (kIsWeb) return true;
    return await _googleSignIn.requestScopes([
      'https://www.googleapis.com/auth/drive.readonly',
    ]);
  }
}
