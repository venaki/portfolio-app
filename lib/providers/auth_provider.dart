import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auth_service.dart';

const _devMode = bool.fromEnvironment('DEV_MODE');

final authServiceProvider = Provider<AuthService>((ref) {
  final service = AuthService();
  ref.onDispose(service.dispose);
  return service;
});

final authStateProvider =
    StateNotifierProvider<AuthNotifier, AsyncValue<User?>>((ref) {
      return AuthNotifier(ref.read(authServiceProvider));
    });

class AuthNotifier extends StateNotifier<AsyncValue<User?>> {
  final AuthService _authService;
  StreamSubscription<User?>? _subscription;
  int _event = 0;
  int _action = 0;

  AuthNotifier(this._authService) : super(const AsyncValue.loading()) {
    if (_devMode) {
      state = const AsyncValue.data(null);
    } else {
      _subscription = _authService.authStateChanges.listen(
        _onAuthChanged,
        onError: (Object error, StackTrace stack) {
          if (mounted) state = AsyncValue.error(error, stack);
        },
      );
    }
  }

  Future<void> _onAuthChanged(User? user) async {
    final event = ++_event;
    _authService.synchronizeUser(user);
    if (!mounted) return;
    if (user == null) {
      state = const AsyncValue.data(null);
      return;
    }
    state = const AsyncValue.loading();
    try {
      await _authService.waitForSignIn();
      if (!mounted || event != _event) return;
      await _authService.restoreGoogleToken();
      if (mounted && event == _event) state = AsyncValue.data(user);
    } catch (error, stack) {
      if (mounted && event == _event) state = AsyncValue.error(error, stack);
    }
  }

  Future<void> signIn() async {
    if (_devMode) return;
    final action = ++_action;
    final previous = state;
    ++_event;
    state = const AsyncValue.loading();
    try {
      await _authService.signIn();
      if (mounted && action == _action) {
        state = AsyncValue.data(_authService.currentUser);
      }
    } on AuthException catch (error, stack) {
      if (!mounted || action != _action) return;
      state = error.code == 'cancelled'
          ? (previous.isLoading ? const AsyncValue.data(null) : previous)
          : AsyncValue.error(error, stack);
    } catch (error, stack) {
      if (mounted && action == _action) state = AsyncValue.error(error, stack);
    }
  }

  Future<void> signOut() async {
    if (_devMode) return;
    final action = ++_action;
    ++_event;
    // Consumers immediately dispose user-scoped portfolio state and ongoing operations.
    state = const AsyncValue.data(null);
    try {
      await _authService.signOut();
    } finally {
      if (mounted && action == _action) {
        state = AsyncValue.data(_authService.currentUser);
      }
    }
  }

  @override
  void dispose() {
    ++_event;
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}
