import 'dart:async';
import 'dart:js_interop';
import 'package:web/web.dart' as web;
import 'package:portfolio_flutter/services/oauth_popup_web.dart' as oauth;

/// Browser contract checks for the production popup function, using dummy codes.
/// Start with: python3 test/browser/oauth_popup_server.py
void main() {
  final result = web.document.createElement('pre')..id = 'result';
  web.document.body!.append(result);
  var running = false;
  const cases = [
    'valid',
    'wrong-window',
    'wrong-origin',
    'wrong-state',
    'wrong-payload',
    'auth-error',
    'cancel',
    'closed',
  ];
  for (final name in cases) {
    final button = web.HTMLButtonElement()..textContent = 'Run $name';
    void onClick(web.Event _) {
      if (running) return;
      running = true;
      result.textContent = 'Running $name';
      unawaited(() async {
        Timer? cancellation;
        try {
          final operation = oauth.openOAuthPopup('http://127.0.0.1:8768/$name');
          if (name == 'cancel') {
            cancellation = Timer(
              const Duration(milliseconds: 200),
              oauth.cancelActiveOAuthPopup,
            );
          }
          final value = await operation;
          final passed = switch (name) {
            'cancel' || 'closed' => value == null,
            'auth-error' => value?['type'] == 'auth-error',
            _ =>
              value?['code'] == 'local-valid-code' &&
                  value?['verifier'] is String &&
                  (value!['verifier'] as String).length == 43,
          };
          // Never render OAuth state, verifier, or code values.
          result.textContent = '${passed ? 'PASS' : 'FAIL'} $name';
        } catch (_) {
          result.textContent = 'FAIL $name: unexpected exception';
        } finally {
          cancellation?.cancel();
          running = false;
        }
      }());
    }

    button.addEventListener('click', onClick.toJS);
    web.document.body!.append(button);
  }
  result.textContent =
      'Ready: all codes are local fixtures; no Google requests.';
}
