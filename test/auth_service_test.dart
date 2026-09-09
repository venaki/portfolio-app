import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:portfolio_flutter/services/auth_service.dart';

class TestUser extends Fake implements User {
  @override
  final String uid;
  TestUser(this.uid);
  @override
  Future<String?> getIdToken([bool forceRefresh = false]) async =>
      'firebase-$uid';
}

class TestCredential extends Fake implements UserCredential {
  @override
  final User user;
  TestCredential(this.user);
}

class TestAuth extends Fake implements FirebaseAuth {
  User? user;
  User? loginUser;
  final events = StreamController<User?>.broadcast(sync: true);
  TestAuth(this.user);
  @override
  User? get currentUser => user;
  @override
  Stream<User?> authStateChanges() => events.stream;
  @override
  Future<void> setPersistence(Persistence persistence) async {}
  @override
  Future<UserCredential> signInWithCredential(AuthCredential credential) async {
    user = loginUser ?? TestUser('signed-in');
    events.add(user);
    return TestCredential(user!);
  }

  @override
  Future<void> signOut() async {
    user = null;
    events.add(null);
  }
}

http.Response tokenResponse(String token) =>
    http.Response(jsonEncode({'access_token': token, 'expires_in': 3600}), 200);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'concurrent refreshes share one request with a Firebase bearer, not a body uid',
    () async {
      final auth = TestAuth(TestUser('a'));
      final response = Completer<http.Response>();
      var requests = 0;
      final service = AuthService(
        firebaseAuth: auth,
        isWeb: true,
        client: MockClient((request) {
          requests++;
          expect(request.headers['Authorization'], 'Bearer firebase-a');
          expect(jsonDecode(request.body), isEmpty);
          return response.future;
        }),
      );
      addTearDown(service.dispose);
      final one = service.getAuthHeaders();
      final two = service.getAuthHeaders();
      await Future<void>.delayed(Duration.zero);
      expect(requests, 1);
      response.complete(tokenResponse('google-a'));
      expect(await one, {'Authorization': 'Bearer google-a'});
      expect(await two, {'Authorization': 'Bearer google-a'});
      expect(await service.getAuthHeaders(), {
        'Authorization': 'Bearer google-a',
      });
      expect(requests, 1);
    },
  );

  test(
    'a late response from a previous uid is discarded and cannot replace the new cache',
    () async {
      final auth = TestAuth(TestUser('a'));
      final oldResponse = Completer<http.Response>();
      final service = AuthService(
        firebaseAuth: auth,
        isWeb: true,
        client: MockClient((request) {
          if (request.headers['Authorization'] == 'Bearer firebase-a') {
            return oldResponse.future;
          }
          return Future.value(tokenResponse('google-b'));
        }),
      );
      addTearDown(service.dispose);
      final old = service.getAuthHeaders();
      final rejected = expectLater(
        old,
        throwsA(
          isA<AuthException>().having((e) => e.code, 'code', 'session_changed'),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      auth.user = TestUser('b');
      service.synchronizeUser(auth.user);
      expect(await service.getAuthHeaders(), {
        'Authorization': 'Bearer google-b',
      });
      oldResponse.complete(tokenResponse('google-a'));
      await rejected;
      expect(await service.getAuthHeaders(), {
        'Authorization': 'Bearer google-b',
      });
    },
  );

  test(
    'logout is local immediately and an ongoing refresh cannot restore the session',
    () async {
      final auth = TestAuth(TestUser('a'));
      final oldResponse = Completer<http.Response>();
      final revokeResponse = Completer<http.Response>();
      final service = AuthService(
        firebaseAuth: auth,
        isWeb: true,
        client: MockClient((request) {
          return request.url.path.endsWith('/revoke')
              ? revokeResponse.future
              : oldResponse.future;
        }),
      );
      addTearDown(service.dispose);
      final headers = service.getAuthHeaders();
      final rejected = expectLater(headers, throwsA(isA<AuthException>()));
      await Future<void>.delayed(Duration.zero);
      final logout = service.signOut();
      await Future<void>.delayed(Duration.zero);
      expect(auth.currentUser, isNull);
      oldResponse.complete(tokenResponse('must-not-cache'));
      await rejected;
      revokeResponse.complete(
        http.Response('{"error":"upstream_unavailable"}', 502),
      );
      await logout;
      await expectLater(
        service.getAuthHeaders(),
        throwsA(isA<AuthException>()),
      );
    },
  );

  test(
    'legacy browser tokens are deleted and never trusted during restoration',
    () async {
      SharedPreferences.setMockInitialValues({
        'google_access_token': 'legacy-token',
        'google_token_expiry': DateTime.now()
            .add(const Duration(hours: 1))
            .millisecondsSinceEpoch,
      });
      final service = AuthService(
        firebaseAuth: TestAuth(TestUser('a')),
        isWeb: true,
        client: MockClient((_) async => tokenResponse('verified-token')),
      );
      addTearDown(service.dispose);
      await service.restoreGoogleToken();
      expect(await service.getAuthHeaders(), {
        'Authorization': 'Bearer verified-token',
      });
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('google_access_token'), isFalse);
      expect(prefs.containsKey('google_token_expiry'), isFalse);
    },
  );

  test(
    'authorization failures propagate without caching a token or logging secrets',
    () async {
      final service = AuthService(
        firebaseAuth: TestAuth(TestUser('a')),
        isWeb: true,
        client: MockClient(
          (_) async => http.Response('{"error":"relogin_required"}', 401),
        ),
      );
      addTearDown(service.dispose);
      await expectLater(
        service.getAuthHeaders(),
        throwsA(
          isA<AuthException>().having(
            (e) => e.requiresReauthentication,
            'reauth',
            isTrue,
          ),
        ),
      );
    },
  );

  test(
    'partial login is signed out when authenticated completion fails',
    () async {
      final auth = TestAuth(null);
      final service = AuthService(
        firebaseAuth: auth,
        isWeb: true,
        openPopup: (_) async => {
          'state': 'state',
          'verifier': 'verifier',
          'code': 'code',
        },
        client: MockClient((request) async {
          if (request.url.path.endsWith('/exchange')) {
            return http.Response(
              '{"access_token":"test-access","id_token":"test-google-id","expires_in":3600}',
              200,
            );
          }
          expect(request.url.path, '/auth/complete');
          expect(request.headers['Authorization'], 'Bearer firebase-signed-in');
          expect(jsonDecode(request.body), {
            'state': 'state',
            'verifier': 'verifier',
          });
          return http.Response('{"error":"identity_mismatch"}', 403);
        }),
      );
      addTearDown(service.dispose);
      await expectLater(service.signIn(), throwsA(isA<AuthException>()));
      expect(auth.currentUser, isNull);
      await expectLater(
        service.getAuthHeaders(),
        throwsA(isA<AuthException>()),
      );
    },
  );

  test(
    'popup cancellation completes signIn and permits a later retry',
    () async {
      var attempts = 0;
      final service = AuthService(
        firebaseAuth: TestAuth(null),
        isWeb: true,
        openPopup: (_) async {
          attempts++;
          return null;
        },
        client: MockClient((_) async => throw StateError('unexpected HTTP')),
      );
      addTearDown(service.dispose);
      for (var i = 0; i < 2; i++) {
        await expectLater(
          service.signIn(),
          throwsA(
            isA<AuthException>().having((e) => e.code, 'code', 'cancelled'),
          ),
        );
        expect(service.isSigningIn, isFalse);
      }
      expect(attempts, 2);
    },
  );

  test(
    'invalidating an early-revoked Google token performs a fresh authenticated refresh',
    () async {
      var requests = 0;
      final service = AuthService(
        firebaseAuth: TestAuth(TestUser('a')),
        isWeb: true,
        client: MockClient((_) async => tokenResponse('token-${++requests}')),
      );
      addTearDown(service.dispose);
      expect(await service.getAuthHeaders(), {
        'Authorization': 'Bearer token-1',
      });
      service.invalidateGoogleToken();
      expect(await service.getAuthHeaders(), {
        'Authorization': 'Bearer token-2',
      });
      expect(requests, 2);
    },
  );
}
