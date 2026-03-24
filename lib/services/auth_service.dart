import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  static const _scopes = [
    'https://www.googleapis.com/auth/spreadsheets',
  ];

  final _googleSignIn = GoogleSignIn(
    scopes: _scopes,
  );

  FirebaseAuth get _firebaseAuth => FirebaseAuth.instance;

  /// Firebase Auth의 현재 사용자
  User? get currentUser => _firebaseAuth.currentUser;
  bool get isSignedIn => _firebaseAuth.currentUser != null;

  /// 앱 시작 시 세션 복원 시도
  /// Firebase Auth는 세션을 IndexedDB에 저장하므로 새로고침 후에도 유지됨
  Future<User?> restoreSession() async {
    final firebaseUser = _firebaseAuth.currentUser;
    if (firebaseUser == null) return null;

    // Firebase 세션은 있지만, Google API 호출을 위해 Google Sign-In도 복원
    await _googleSignIn.signInSilently();
    return firebaseUser;
  }

  Future<User?> signIn() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return null;

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final userCredential =
        await _firebaseAuth.signInWithCredential(credential);
    return userCredential.user;
  }

  Future<void> signOut() async {
    await Future.wait([
      _firebaseAuth.signOut(),
      _googleSignIn.signOut(),
    ]);
  }

  Future<Map<String, String>> getAuthHeaders() async {
    // Google Sign-In 세션에서 auth headers 가져오기
    final googleUser = _googleSignIn.currentUser ??
        await _googleSignIn.signInSilently();
    if (googleUser == null) throw Exception('Not signed in');
    return await googleUser.authHeaders;
  }

  /// Drive 스코프를 추가 요청 (시트 선택 시 사용)
  Future<bool> requestDriveScope() async {
    return await _googleSignIn.requestScopes([
      'https://www.googleapis.com/auth/drive.readonly',
    ]);
  }
}
