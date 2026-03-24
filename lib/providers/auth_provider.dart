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
      final user = await _authService.restoreSession();
      state = AsyncValue.data(user);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> signIn() async {
    if (_devMode) return;
    state = const AsyncValue.loading();
    try {
      await _authService.signIn();
      // 웹 리다이렉트 방식: 페이지가 이동되므로 여기 이후는 실행되지 않을 수 있음
      // 리다이렉트 복귀 후 restoreSession()에서 상태 복원
      final user = _authService.currentUser;
      state = AsyncValue.data(user);
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
