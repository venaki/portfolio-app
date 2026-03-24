import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  static const _scopes = [
    'https://www.googleapis.com/auth/spreadsheets',
  ];

  final _googleSignIn = GoogleSignIn(
    scopes: _scopes,
  );

  FirebaseAuth get _firebaseAuth => FirebaseAuth.instance;

  /// 리다이렉트 후 받은 access token 캐시
  String? _cachedAccessToken;

  User? get currentUser => _firebaseAuth.currentUser;
  bool get isSignedIn => _firebaseAuth.currentUser != null;

  /// 앱 시작 시 세션 복원
  Future<User?> restoreSession() async {
    // 리다이렉트 결과 확인 (로그인 후 돌아온 경우)
    if (kIsWeb) {
      try {
        final result = await _firebaseAuth.getRedirectResult();
        if (result.credential != null) {
          final oAuth = result.credential as OAuthCredential;
          _cachedAccessToken = oAuth.accessToken;
          return result.user;
        }
      } catch (_) {}
    }

    final firebaseUser = _firebaseAuth.currentUser;
    if (firebaseUser == null) return null;

    // 기존 세션: Google Sign-In silent로 API 토큰 복원
    await _googleSignIn.signInSilently();
    return firebaseUser;
  }

  Future<void> signIn() async {
    if (kIsWeb) {
      // 웹: 리다이렉트 방식 (COOP 우회)
      final provider = GoogleAuthProvider();
      for (final scope in _scopes) {
        provider.addScope(scope);
      }
      await _firebaseAuth.signInWithRedirect(provider);
      // 리다이렉트되므로 여기 이후는 실행되지 않음
    } else {
      // 네이티브: 기존 google_sign_in 방식
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
    await Future.wait([
      _firebaseAuth.signOut(),
      _googleSignIn.signOut(),
    ]);
  }

  Future<Map<String, String>> getAuthHeaders() async {
    // 1. 리다이렉트에서 받은 캐시 토큰
    if (_cachedAccessToken != null) {
      return {'Authorization': 'Bearer $_cachedAccessToken'};
    }

    // 2. Google Sign-In silent로 토큰 획득
    final googleUser = _googleSignIn.currentUser ??
        await _googleSignIn.signInSilently();
    if (googleUser != null) {
      return await googleUser.authHeaders;
    }

    throw Exception('Not signed in');
  }

  /// Drive 스코프를 추가 요청 (시트 선택 시 사용)
  Future<bool> requestDriveScope() async {
    return await _googleSignIn.requestScopes([
      'https://www.googleapis.com/auth/drive.readonly',
    ]);
  }
}
