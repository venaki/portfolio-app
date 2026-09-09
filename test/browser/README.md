# OAuth 팝업 브라우저 계약 테스트

`python3 test/browser/oauth_popup_server.py`를 실행하고 Chrome에서
`http://127.0.0.1:8767`을 엽니다. 모든 `Run …` 버튼을 눌렀을 때
해당 시나리오의 `PASS`가 표시되어야 합니다. 터미널에서 Ctrl-C로 종료합니다.

실제 `openOAuthPopup` 함수를 dart2js로 컴파일하며, 8768의 로컬 팝업이
가짜 코드만 전달합니다. Google 로그인, 계정, 토큰, Worker가 필요 없습니다.
결과에는 state/verifier/code를 출력하지 않습니다.

- `valid`: 다른 origin 팝업의 정상 코드 수신과 verifier 보존
- `wrong-window`: origin/state가 맞아도 다른 iframe의 코드는 거절
- `wrong-origin`: 같은 팝업 창이 다른 origin에서 보낸 코드는 거절
- `wrong-state`: 같은 origin/팝업이어도 다른 state는 거절
- `wrong-payload`: 문자열, 숫자·빈·과대 코드, 알 수 없는 type은 거절
- `auth-error`: 해당 시도의 오류 메시지 처리
- `cancel`: `cancelActiveOAuthPopup()`이 null로 완료하고 창 정리
- `closed`: 코드 없이 팝업을 닫으면 null로 완료

거절 시나리오는 잘못된 메시지를 먼저 보내고 정상 메시지를 나중에 보냅니다.
잘못된 메시지를 수락하면 결과가 `FAIL`이 됩니다. `valid`는 dart:html의
새 Window wrapper끼리 비교해 정상 메시지까지 거절하던 회귀를 검출합니다.
