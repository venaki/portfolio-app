import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auth_service.dart';

const _devMode = bool.fromEnvironment('DEV_MODE');

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

final authStateProvider = StateNotifierProvider<AuthNotifier, AsyncValue<User?>>((ref) {
  return AuthNotifier(ref.read(authServiceProvider));
});

class AuthNotifier extends StateNotifier<AsyncValue<User?>> {
  final AuthService _authService;

  AuthNotifier(this._authService) : super(const AsyncValue.loading()) {
    _init();
  }

  Future<void> _init() async {
    if (_devMode) {
      state = const AsyncValue.data(null);
      return;
    }
    try {
      // Firebase Auth 상태 변화를 리슨 (리다이렉트 복귀 포함)
      FirebaseAuth.instance.authStateChanges().listen((user) {
        if (!mounted) return;
        state = AsyncValue.data(user);
        // Google API 토큰 복원
        if (user != null) {
          _authService.restoreGoogleToken();
        }
      });
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> signIn() async {
    if (_devMode) return;
    state = const AsyncValue.loading();
    try {
      await _authService.signIn();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> signOut() async {
    if (_devMode) return;
    await _authService.signOut();
    state = const AsyncValue.data(null);
  }
}
