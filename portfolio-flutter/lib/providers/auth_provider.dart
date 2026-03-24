import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../services/auth_service.dart';

const _devMode = bool.fromEnvironment('DEV_MODE');

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

final authStateProvider = StateNotifierProvider<AuthNotifier, AsyncValue<GoogleSignInAccount?>>((ref) {
  return AuthNotifier(ref.read(authServiceProvider));
});

class AuthNotifier extends StateNotifier<AsyncValue<GoogleSignInAccount?>> {
  final AuthService _authService;

  AuthNotifier(this._authService) : super(const AsyncValue.loading()) {
    _init();
  }

  Future<void> _init() async {
    if (_devMode) {
      // Dev 모드: SSO 스킵, 가짜 로그인 상태
      state = const AsyncValue.data(null);
      return;
    }
    try {
      final user = await _authService.signInSilently();
      state = AsyncValue.data(user);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> signIn() async {
    if (_devMode) return;
    state = const AsyncValue.loading();
    try {
      final user = await _authService.signIn();
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
