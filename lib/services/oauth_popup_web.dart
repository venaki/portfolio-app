import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:web/web.dart' as web;

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
      'origin': web.window.location.origin,
      'state': state,
      'challenge': challenge,
    },
  );
  final completer = Completer<Map<String, dynamic>?>();
  JSFunction? messageListener;
  Timer? timeout;
  Timer? closedTimer;
  web.Window? popup;

  void finish(Map<String, dynamic>? value) {
    if (!completer.isCompleted) completer.complete(value);
  }

  void cancel() => finish(null);
  _cancelActive = cancel;
  try {
    // No asynchronous operation precedes window.open: preserve user activation.
    popup = web.window.open(
      loginUrl.toString(),
      'portfolio-auth-$state',
      'width=500,height=650',
    );
    if (popup == null || popup.closed) {
      throw StateError('로그인 팝업을 허용한 후 다시 시도해주세요.');
    }
    messageListener = ((web.MessageEvent event) {
      // dart:html wraps foreign windows in fresh Dart objects, so Dart wrapper
      // equality rejects legitimate callbacks. Compare the native WindowProxy.
      if (event.origin != endpoint.origin ||
          !event.source.strictEquals(popup).toDart) {
        return;
      }
      final raw = event.data.dartify();
      if (raw is! Map) return;
      if (raw['state'] != state) return;
      if (raw['type'] == 'auth-error') {
        finish({'type': 'auth-error', 'error': 'authorization_denied'});
      } else if (raw['type'] == 'auth-code' &&
          raw['code'] is String &&
          (raw['code'] as String).isNotEmpty &&
          (raw['code'] as String).length <= 4096) {
        finish({'state': state, 'verifier': verifier, 'code': raw['code']});
      }
    }).toJS;
    web.window.addEventListener('message', messageListener);
    timeout = Timer(const Duration(minutes: 10), () => finish(null));
    closedTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (popup?.closed == true) finish(null);
    });
    return await completer.future;
  } finally {
    if (messageListener != null) {
      web.window.removeEventListener('message', messageListener);
    }
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
