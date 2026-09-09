import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:portfolio_flutter/providers/auth_provider.dart';
import 'package:portfolio_flutter/services/auth_service.dart';

class ProviderUser extends Fake implements User {
  @override
  final String uid;
  ProviderUser(this.uid);
}

class ProviderAuth extends Fake implements AuthService {
  final controller = StreamController<User?>.broadcast(sync: true);
  final restores = <String, Completer<void>>{};
  User? user;
  @override
  Stream<User?> get authStateChanges => controller.stream;
  @override
  User? get currentUser => user;
  @override
  void synchronizeUser(User? user) {
    this.user = user;
  }

  @override
  Future<void> waitForSignIn() async {}
  @override
  Future<void> restoreGoogleToken() =>
      (restores[user!.uid] ??= Completer<void>()).future;
  @override
  Future<void> signIn() async => throw const AuthException('cancelled');
  @override
  Future<void> signOut() async {
    user = null;
    controller.add(null);
  }
}

class TestAuthNotifier extends AuthNotifier {
  TestAuthNotifier(super.service);
  AsyncValue<User?> get value => state;
}

void main() {
  test(
    'late token restoration cannot publish a previous Firebase user',
    () async {
      final service = ProviderAuth();
      final notifier = TestAuthNotifier(service);
      addTearDown(notifier.dispose);
      service.controller.add(ProviderUser('a'));
      await Future<void>.delayed(Duration.zero);
      service.controller.add(ProviderUser('b'));
      await Future<void>.delayed(Duration.zero);
      service.restores['b']!.complete();
      await Future<void>.delayed(Duration.zero);
      expect(notifier.value.value?.uid, 'b');
      service.restores['a']!.complete();
      await Future<void>.delayed(Duration.zero);
      expect(notifier.value.value?.uid, 'b');
    },
  );

  test(
    'cancelled login returns to signed-out state instead of infinite loading',
    () async {
      final service = ProviderAuth();
      final notifier = TestAuthNotifier(service);
      addTearDown(notifier.dispose);
      service.controller.add(null);
      await notifier.signIn();
      expect(notifier.value.isLoading, isFalse);
      expect(notifier.value.hasError, isFalse);
      expect(notifier.value.value, isNull);
    },
  );

  test('auth subscription is cancelled when the notifier is disposed', () {
    final service = ProviderAuth();
    final notifier = AuthNotifier(service);
    expect(service.controller.hasListener, isTrue);
    notifier.dispose();
    expect(service.controller.hasListener, isFalse);
  });
}
