"""Serve an OAuth browser contract harness on two local origins only."""
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from threading import Event, Thread
from urllib.parse import urlsplit
import subprocess

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / '.dart_tool' / 'oauth_popup_contract'

SCRIPT = r'''
const q = new URLSearchParams(location.search);
const origin = q.get('origin');
const state = q.get('state');
const path = location.pathname;
const send = (code = 'local-valid-code', nextState = state, recipient = window.opener) =>
  recipient.postMessage({type:'auth-code',state:nextState,code},origin);
const valid = () => { send(); window.close(); };
if (path === '/valid') valid();
else if (path === '/wrong-window') {
  const frame = document.createElement('iframe');
  frame.src = '/frame' + location.search;
  frame.onload = () => setTimeout(valid, 100);
  document.body.append(frame);
} else if (path === '/frame') {
  send('local-invalid-window-code', state, window.parent.opener);
} else if (path === '/wrong-origin') {
  location.replace('http://127.0.0.1:8767/origin-step' + location.search);
} else if (path === '/origin-step') {
  send('local-invalid-origin-code');
  setTimeout(() => location.replace('http://127.0.0.1:8768/valid' + location.search), 100);
} else if (path === '/wrong-state') {
  send('local-invalid-state-code', 'unrelated-state');
  setTimeout(valid, 100);
} else if (path === '/wrong-payload') {
  window.opener.postMessage('not-an-object', origin);
  window.opener.postMessage({type:'auth-code',state,code:123}, origin);
  window.opener.postMessage({type:'auth-code',state,code:''}, origin);
  window.opener.postMessage({type:'auth-code',state,code:'x'.repeat(4097)}, origin);
  window.opener.postMessage({type:'unsupported',state,code:'invalid'}, origin);
  setTimeout(valid, 100);
} else if (path === '/auth-error') {
  window.opener.postMessage({type:'auth-error',state},origin);
  window.close();
} else if (path === '/closed') window.close();
'''


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *_):
        pass  # Do not log even fixture state/challenge query strings.

    def do_GET(self):
        path = urlsplit(self.path).path
        if path == '/':
            body = b'<!doctype html><meta charset="utf-8"><title>OAuth popup contract tests</title><body><script defer src="/harness.js"></script></body>'
            content_type = 'text/html; charset=utf-8'
        elif path == '/harness.js':
            body = (OUT / 'harness.js').read_bytes()
            content_type = 'text/javascript'
        else:
            body = ('<!doctype html><meta charset="utf-8"><title>Local fake callback</title><body><script>' + SCRIPT + '</script></body>').encode()
            content_type = 'text/html; charset=utf-8'
        self.send_response(200)
        self.send_header('Content-Type', content_type)
        self.send_header('Cache-Control', 'no-store')
        self.end_headers()
        self.wfile.write(body)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    subprocess.run(['dart', 'compile', 'js', '-O2', '-o', str(OUT / 'harness.js'),
                    str(ROOT / 'test/browser/oauth_popup_harness.dart')], cwd=ROOT, check=True)
    servers = [ThreadingHTTPServer(('127.0.0.1', port), Handler) for port in (8767, 8768)]
    try:
        for server in servers:
            Thread(target=server.serve_forever, daemon=True).start()
        print('Open http://127.0.0.1:8767 and run each test. Ctrl-C stops both servers.', flush=True)
        Event().wait()
    except KeyboardInterrupt:
        pass
    finally:
        for server in servers:
            server.shutdown()
            server.server_close()


if __name__ == '__main__':
    main()
