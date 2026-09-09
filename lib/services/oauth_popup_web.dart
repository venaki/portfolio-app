// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:math';
import 'package:crypto/crypto.dart';

void Function()? _cancelActive;

void cancelActiveOAuthPopup() => _cancelActive?.call();

/// Only the popup opened for this attempt may return an authorization code.
/// The verifier never leaves this page until it is posted to the exchange API.
Future<Map<String, dynamic>?> openOAuthPopup(String url) async {
  cancelActiveOAuthPopup();
  final random = Random.secure();
  String secret() => base64Url
      .encode(List.generate(32, (_) => random.nextInt(256)))
      .replaceAll('=', '');
  final state = secret();
  final verifier = secret();
  final challenge = base64Url
      .encode(sha256.convert(ascii.encode(verifier)).bytes)
      .replaceAll('=', '');
  final endpoint = Uri.parse(url);
  final loginUrl = endpoint.replace(
    queryParameters: {
      'origin': html.window.location.origin,
      'state': state,
      'challenge': challenge,
    },
  );
  final completer = Completer<Map<String, dynamic>?>();
  StreamSubscription<html.MessageEvent>? subscription;
  Timer? timeout;
  Timer? closedTimer;
  html.WindowBase? popup;

  void finish(Map<String, dynamic>? value) {
    if (!completer.isCompleted) completer.complete(value);
  }

  void cancel() => finish(null);
  _cancelActive = cancel;
  try {
    // No asynchronous operation precedes window.open: preserve user activation.
    popup = html.window.open(
      loginUrl.toString(),
      'portfolio-auth-$state',
      'width=500,height=650',
    );
    if (popup.closed == true) throw StateError('로그인 팝업을 허용한 후 다시 시도해주세요.');
    subscription = html.window.onMessage.listen((event) {
      if (event.origin != endpoint.origin ||
          event.source != popup ||
          event.data is! Map) {
        return;
      }
      final raw = event.data as Map;
      if (raw['state'] != state) return;
      if (raw['type'] == 'auth-error') {
        finish({'type': 'auth-error', 'error': 'authorization_denied'});
      } else if (raw['type'] == 'auth-code' &&
          raw['code'] is String &&
          (raw['code'] as String).isNotEmpty &&
          (raw['code'] as String).length <= 4096) {
        finish({'state': state, 'verifier': verifier, 'code': raw['code']});
      }
    });
    timeout = Timer(const Duration(minutes: 10), () => finish(null));
    closedTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (popup?.closed == true) finish(null);
    });
    return await completer.future;
  } finally {
    await subscription?.cancel();
    timeout?.cancel();
    closedTimer?.cancel();
    if (identical(_cancelActive, cancel)) _cancelActive = null;
    try {
      popup?.close();
    } catch (_) {
      /* A browser may already have closed it. */
    }
  }
}
