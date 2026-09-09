import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';
import 'oauth_popup_stub.dart'
    if (dart.library.html) 'oauth_popup_web.dart'
    as oauth_popup;

class AuthException implements Exception {
  final String code;
  const AuthException(this.code);

  bool get requiresReauthentication => const {
    'relogin_required',
    'invalid_identity_token',
    'identity_token_required',
    'consent_required',
    'session_changed',
  }.contains(code);

  @override
  String toString() => switch (code) {
    'cancelled' => '로그인을 취소했습니다.',
    'session_changed' => '로그인 계정이 변경되었습니다. 다시 시도해주세요.',
    'network_error' ||
    'upstream_unavailable' => '인증 서버에 연결할 수 없습니다. 잠시 후 다시 시도해주세요.',
    'consent_required' => '스프레드시트와 파일 목록 접근 권한을 허용해주세요.',
    'origin_not_allowed' => '이 주소에서는 로그인을 사용할 수 없습니다.',
    _ => '로그인이 만료되었거나 완료되지 않았습니다. 다시 로그인해주세요.',
  };
}

class AuthService {
  static const _scopes = [
    'https://www.googleapis.com/auth/spreadsheets',
    'https://www.googleapis.com/auth/drive.metadata.readonly',
  ];
  static const _timeout = Duration(seconds: 20);

  final FirebaseAuth? _providedAuth;
  GoogleSignIn? _google;
  final http.Client _client;
  final bool _isWeb;
  final Future<Map<String, dynamic>?> Function(String) _openPopup;
  bool _disposed = false;
  String? _sessionUid;
  int _generation = 0;
  int _loginCancellation = 0;
  String? _cachedAccessToken;
  DateTime? _tokenExpiry;
  Future<void>? _loginFuture;
  Future<void>? _refreshFuture;
  String? _refreshUid;
  int? _refreshGeneration;

  AuthService({
    FirebaseAuth? firebaseAuth,
    GoogleSignIn? googleSignIn,
    http.Client? client,
    bool? isWeb,
    Future<Map<String, dynamic>?> Function(String)? openPopup,
  }) : _providedAuth = firebaseAuth,
       _google = googleSignIn,
       _client = client ?? http.Client(),
       _isWeb = isWeb ?? kIsWeb,
       _openPopup = openPopup ?? oauth_popup.openOAuthPopup;

  FirebaseAuth get _firebaseAuth => _providedAuth ?? FirebaseAuth.instance;
  GoogleSignIn get _googleSignIn => _google ??= GoogleSignIn(scopes: _scopes);
  User? get currentUser => _firebaseAuth.currentUser;
  bool get isSignedIn => currentUser != null;
  bool get isSigningIn => _loginFuture != null;
  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  Future<void> waitForSignIn() async {
    final pending = _loginFuture;
    if (pending != null) await pending;
  }

  /// Called before exposing a Firebase user to portfolio providers.
  void synchronizeUser(User? user) {
    if (_sessionUid == user?.uid) return;
    _sessionUid = user?.uid;
    _generation++;
    _clearMemoryToken();
  }

  void _checkSession(String? uid, int generation) {
    if (_disposed || currentUser?.uid != uid || _generation != generation) {
      throw const AuthException('session_changed');
    }
  }

  void _clearMemoryToken() {
    _cachedAccessToken = null;
    _tokenExpiry = null;
  }

  /// A Google API 401 may invalidate an access token before its advertised expiry.
  void invalidateGoogleToken() {
    _generation++;
    _clearMemoryToken();
  }

  /// Legacy unbound localStorage tokens are never reused. New tokens stay in memory.
  Future<void> _removeLegacyTokens() async {
    if (!_isWeb) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('google_access_token');
    await prefs.remove('google_token_expiry');
  }

  Future<void> restoreGoogleToken() async {
    await _removeLegacyTokens();
    await getAuthHeaders();
  }

  Future<void> signIn() {
    if (_disposed) return Future.error(const AuthException('session_changed'));
    final running = _loginFuture;
    if (running != null) return running;
    late final Future<void> operation;
    operation = _signIn().whenComplete(() {
      if (identical(_loginFuture, operation)) _loginFuture = null;
    });
    _loginFuture = operation;
    return operation;
  }

  Future<void> _signIn() async {
    synchronizeUser(currentUser);
    final startUid = _sessionUid;
    final startGeneration = _generation;
    final cancellation = _loginCancellation;
    if (_isWeb) {
      final result = await _openPopup('$corsProxyBase/auth/login');
      if (result == null || result['type'] == 'auth-error') {
        throw const AuthException('cancelled');
      }
      _checkSession(startUid, startGeneration);
      if (cancellation != _loginCancellation) {
        throw const AuthException('cancelled');
      }
      final state = result['state'];
      final verifier = result['verifier'];
      final code = result['code'];
      if (state is! String || verifier is! String || code is! String) {
        throw const AuthException('invalid_response');
      }
      final tokens = await _post('/auth/exchange', {
        'state': state,
        'verifier': verifier,
        'code': code,
      });
      _checkSession(startUid, startGeneration);
      if (cancellation != _loginCancellation) {
        throw const AuthException('cancelled');
      }
      final accessToken = tokens['access_token'];
      final idToken = tokens['id_token'];
      if (accessToken is! String || idToken is! String) {
        throw const AuthException('invalid_response');
      }
      await _firebaseAuth.setPersistence(Persistence.LOCAL);
      _checkSession(startUid, startGeneration);
      final credential = GoogleAuthProvider.credential(
        accessToken: accessToken,
        idToken: idToken,
      );
      final userCredential = await _firebaseAuth.signInWithCredential(
        credential,
      );
      final user = userCredential.user;
      if (user == null) throw const AuthException('invalid_response');
      if (cancellation != _loginCancellation || _disposed) {
        if (currentUser?.uid == user.uid) await _firebaseAuth.signOut();
        throw const AuthException('cancelled');
      }
      synchronizeUser(currentUser);
      final generation = _generation;
      try {
        _checkSession(user.uid, generation);
        final firebaseToken = await _firebaseToken(user);
        _checkSession(user.uid, generation);
        await _post('/auth/complete', {
          'state': state,
          'verifier': verifier,
        }, firebaseToken: firebaseToken);
        _checkSession(user.uid, generation);
        _cacheTokens(tokens);
        await _removeLegacyTokens();
      } catch (_) {
        _clearMemoryToken();
        // Do not expose a half-completed login or sign out a newer account.
        if (currentUser?.uid == user.uid && _generation == generation) {
          await _firebaseAuth.signOut();
        }
        rethrow;
      }
    } else {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) throw const AuthException('cancelled');
      final googleAuth = await googleUser.authentication;
      if (cancellation != _loginCancellation) {
        throw const AuthException('cancelled');
      }
      await _firebaseAuth.signInWithCredential(
        GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        ),
      );
      synchronizeUser(currentUser);
    }
  }

  Future<void> signOut() async {
    final user = currentUser;
    _loginCancellation++;
    _generation++;
    _clearMemoryToken();
    oauth_popup.cancelActiveOAuthPopup();
    // Start remote cleanup with the captured user, but clear the local session immediately.
    final revoke = _isWeb && user != null
        ? _revokeUser(user)
        : Future<void>.value();
    await _firebaseAuth.signOut();
    synchronizeUser(null);
    if (!_isWeb) await _googleSignIn.signOut();
    await _removeLegacyTokens();
    await revoke;
  }

  Future<void> _revokeUser(User user) async {
    try {
      final token = await _firebaseToken(user);
      await _post('/auth/revoke', {}, firebaseToken: token);
    } catch (_) {
      // Offline logout still clears the local session. No API response can restore it.
    }
  }

  Future<Map<String, String>> getAuthHeaders() async {
    final login = _loginFuture;
    if (login != null) await login;
    synchronizeUser(currentUser);
    final uid = _sessionUid;
    final generation = _generation;
    if (uid == null) throw const AuthException('relogin_required');
    _checkSession(uid, generation);
    if (!_isWeb) {
      final user =
          _googleSignIn.currentUser ?? await _googleSignIn.signInSilently();
      _checkSession(uid, generation);
      if (user == null) throw const AuthException('relogin_required');
      final headers = await user.authHeaders;
      _checkSession(uid, generation);
      return headers;
    }
    if (_cachedAccessToken == null ||
        _tokenExpiry == null ||
        !DateTime.now().isBefore(_tokenExpiry!)) {
      if (_refreshFuture != null &&
          _refreshUid == uid &&
          _refreshGeneration == generation) {
        await _refreshFuture;
      } else {
        final operation = _refresh(uid, generation);
        _refreshFuture = operation;
        _refreshUid = uid;
        _refreshGeneration = generation;
        try {
          await operation;
        } finally {
          if (identical(_refreshFuture, operation)) _refreshFuture = null;
        }
      }
    }
    _checkSession(uid, generation);
    if (_cachedAccessToken == null) {
      throw const AuthException('relogin_required');
    }
    return {'Authorization': 'Bearer $_cachedAccessToken'};
  }

  Future<void> _refresh(String uid, int generation) async {
    final user = currentUser;
    if (user == null) throw const AuthException('relogin_required');
    final token = await _firebaseToken(user);
    _checkSession(uid, generation);
    final data = await _post('/auth/refresh', {}, firebaseToken: token);
    _checkSession(uid, generation);
    _cacheTokens(data);
  }

  void _cacheTokens(Map<String, dynamic> data) {
    final accessToken = data['access_token'];
    final expiresIn = data['expires_in'];
    if (accessToken is! String ||
        accessToken.isEmpty ||
        expiresIn is! num ||
        !expiresIn.isFinite ||
        expiresIn <= 60) {
      throw const AuthException('invalid_response');
    }
    _cachedAccessToken = accessToken;
    _tokenExpiry = DateTime.now().add(
      Duration(seconds: expiresIn.toInt() - 60),
    );
  }

  Future<String> _firebaseToken(User user) async {
    try {
      final token = await user.getIdToken().timeout(_timeout);
      if (token == null || token.isEmpty) {
        throw const AuthException('invalid_identity_token');
      }
      return token;
    } on TimeoutException {
      throw const AuthException('network_error');
    } on FirebaseAuthException catch (error) {
      throw AuthException(
        error.code == 'network-request-failed'
            ? 'network_error'
            : 'invalid_identity_token',
      );
    }
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body, {
    String? firebaseToken,
  }) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$corsProxyBase$path'),
            headers: {
              'Content-Type': 'application/json',
              if (firebaseToken != null)
                'Authorization': 'Bearer $firebaseToken',
            },
            body: jsonEncode(body),
          )
          .timeout(_timeout);
      Map<String, dynamic> data;
      try {
        data = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (_) {
        throw const AuthException('invalid_response');
      }
      if (response.statusCode != 200) {
        throw AuthException(
          data['error'] is String
              ? data['error'] as String
              : 'upstream_unavailable',
        );
      }
      return data;
    } on TimeoutException {
      throw const AuthException('network_error');
    } on http.ClientException {
      throw const AuthException('network_error');
    }
  }

  Future<Map<String, String>> getAuthHeadersInteractive() async {
    try {
      return await getAuthHeaders();
    } on AuthException catch (error) {
      if (!_isWeb || !error.requiresReauthentication) rethrow;
      await signIn();
      return getAuthHeaders();
    }
  }

  Future<bool> requestDriveScope() async {
    // The Worker checks the granted scope before completing every web login.
    if (_isWeb) return true;
    return _googleSignIn.requestScopes([_scopes[1]]);
  }

  void dispose() {
    _disposed = true;
    _loginCancellation++;
    _generation++;
    _clearMemoryToken();
    oauth_popup.cancelActiveOAuthPopup();
    _client.close();
  }
}
