import 'dart:async';
import 'dart:html' as html;

/// Workers OAuth 팝업을 열고 postMessage로 결과를 수신
Future<Map<String, dynamic>?> openOAuthPopup(String url) async {
  final completer = Completer<Map<String, dynamic>?>();

  final popup = html.window.open(url, 'google-auth', 'width=500,height=600');

  late final StreamSubscription sub;
  Timer? timeout;

  sub = html.window.onMessage.listen((event) {
    if (event.data is Map) {
      final data = Map<String, dynamic>.from(event.data as Map);
      final type = data['type'];
      if (type == 'auth-success' || type == 'auth-error') {
        sub.cancel();
        timeout?.cancel();
        if (!completer.isCompleted) {
          completer.complete(type == 'auth-success' ? data : null);
        }
      }
    }
  });

  // 타임아웃 60초
  timeout = Timer(const Duration(seconds: 60), () {
    sub.cancel();
    if (!completer.isCompleted) completer.complete(null);
  });

  // 팝업이 닫혔는지 폴링
  Timer.periodic(const Duration(milliseconds: 500), (timer) {
    if (popup.closed == true) {
      timer.cancel();
      sub.cancel();
      timeout?.cancel();
      if (!completer.isCompleted) completer.complete(null);
    }
  });

  return completer.future;
}
