import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  static const _scopes = [
    'https://www.googleapis.com/auth/spreadsheets',
    'https://www.googleapis.com/auth/drive.readonly',
  ];

  // 네이티브 전용
  final _googleSignIn = GoogleSignIn(scopes: _scopes);

  FirebaseAuth get _firebaseAuth => FirebaseAuth.instance;

  String? _cachedAccessToken;

  User? get currentUser => _firebaseAuth.currentUser;
  bool get isSignedIn => _firebaseAuth.currentUser != null;

  /// 앱 시작 시 토큰 복원
  Future<void> restoreGoogleToken() async {
    if (kIsWeb) {
      // 웹: 세션 복원 시 재로그인으로 토큰 갱신 필요
      // cachedAccessToken이 없으면 getAuthHeaders에서 재로그인 유도
      return;
    }
    await _googleSignIn.signInSilently();
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
    // 웹: 캐시된 토큰 사용
    if (_cachedAccessToken != null) {
      return {'Authorization': 'Bearer $_cachedAccessToken'};
    }

    // 웹: 토큰 없으면 재로그인으로 갱신
    if (kIsWeb) {
      final provider = GoogleAuthProvider();
      for (final scope in _scopes) {
        provider.addScope(scope);
      }
      final result = await _firebaseAuth.signInWithPopup(provider);
      if (result.credential != null) {
        final oAuth = result.credential as OAuthCredential;
        _cachedAccessToken = oAuth.accessToken;
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
    if (kIsWeb) return true; // 이미 signIn에서 포함
    return await _googleSignIn.requestScopes([
      'https://www.googleapis.com/auth/drive.readonly',
    ]);
  }
}
