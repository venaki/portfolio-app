# Portfolio 인증 Worker

Google OAuth와 종목 검색을 제공하는 Cloudflare Worker입니다. 원격 배포 없이 로컬 검증할 수 있습니다.

## 개발과 검증

Node.js 22 이상에서 이 디렉터리 안에서 실행합니다.

```sh
npm ci
npm run check
npm run build
```

`check`는 TypeScript 검증과 로컬 테스트를 실행합니다. 테스트는 임시 RSA 키, 가짜 Google 응답과 격리된 저장소로 실제 인증 핸들러를 호출합니다. 운영 토큰·Google 계정·Cloudflare 계정은 사용하지 않습니다. `build`는 Wrangler `--dry-run`으로 번들만 만들며 배포하지 않습니다. CI에서도 같은 명령을 사용합니다. 의존성은 `package-lock.json`에 고정되어 있습니다.

실제 로컬 Worker를 실행하려면 Git에서 제외된 `.dev.vars`에 테스트용 OAuth 클라이언트 설정을 넣고 `npm run dev`를 실행합니다. 해당 클라이언트의 redirect URI에 로컬 Worker의 `/auth/callback` 주소가 등록되어 있어야 실제 Google 로그인을 완료할 수 있습니다.

## 인증 흐름

1. 브라우저는 로그인 시도마다 256비트 `state`와 PKCE verifier를 생성합니다. 팝업에는 `state`, SHA-256 challenge, 앱 origin만 전달합니다. verifier는 URL이나 localStorage에 저장하지 않습니다.
2. `/auth/login`은 허용 origin을 확인하고 Durable Object에 10분 TTL의 시도를 생성합니다. Google에는 state, 별도 OIDC nonce, S256 challenge를 전달합니다.
3. `/auth/callback`은 살아 있는 시도만 처리하며, 해당 시도의 앱 origin에 authorization code와 state를 전달합니다. access/refresh/ID token은 팝업 HTML에 포함하지 않습니다. 클라이언트는 Worker origin, 팝업 window, state를 모두 확인합니다.
4. `/auth/exchange`는 앱 origin과 verifier를 확인하고 시도를 원자적으로 점유한 뒤 Google code를 교환합니다. Google ID token의 서명·issuer·audience·만료·nonce 및 승인 scope를 확인합니다. refresh token은 시도 저장소에만 보관하고 access/ID token을 클라이언트에 응답합니다.
5. 클라이언트가 Google credential로 Firebase에 로그인한 뒤 `/auth/complete`에 Firebase ID token과 시도 증명을 보냅니다. Worker는 Firebase JWT를 검증하고 Google subject가 같은지 비교한 뒤 검증된 Firebase UID 아래에 refresh token을 보관합니다. 시도는 한 번만 완료할 수 있습니다.
6. `/auth/refresh`, `/auth/revoke`는 Firebase Bearer ID token으로만 사용자를 식별합니다. 요청 본문의 UID는 사용하지 않습니다. `/auth/migrate`는 존재하지 않습니다.

Durable Object의 storage transaction이 일회성 점유 및 상태 변경을 보장합니다. KV의 최종 일관성에 의존하지 않습니다. 만료된 시도의 비밀 값은 alarm으로 제거됩니다. 교환 중 장애가 나거나 완료 응답이 유실되면 자동으로 임의 재시도하지 않고 새 로그인 시도를 시작합니다. 로그아웃 이후 늦게 완료되는 이전 시도가 저장된 refresh token을 되살리지 못하도록 취소 시각을 저장합니다. 늦은 refresh 실패도 새 로그인 토큰을 삭제하지 못합니다.

클라이언트 Google access token은 UID에 결합된 메모리 캐시만 사용합니다. 새로고침 시 Firebase 세션으로 Worker에 재인증합니다. 로그아웃은 로컬 세션을 즉시 정리하고 서버 토큰 삭제를 요청합니다. 오프라인에서 서버 삭제가 실패해도 로컬 로그아웃은 완료됩니다. 이 API는 Google 계정의 앱 연결 전체를 해제하거나 이미 발급한 access token, Firebase ID token을 원격 폐기하는 API가 아닙니다. Google 앱 연결 해제는 Google 계정 권한 관리에서 별도로 수행합니다.

## 배포 설정

`wrangler.toml`에는 다음 공개 설정이 들어 있습니다.

| 설정 | 의미 |
|---|---|
| `FIREBASE_PROJECT_ID` | Flutter `firebase_options.dart`와 같은 Firebase project ID |
| `ALLOWED_ORIGINS` | 허용 앱 origin의 쉼표 구분 목록. 경로·끝 슬래시 없이 정확한 scheme/host/port 사용 |
| `AUTH_STATE` | `AuthState` Durable Object 바인딩 |
| `v1-auth-state` | SQLite Durable Object 클래스를 만드는 최초 migration |

GitHub Pages, Firebase Hosting의 두 기본 origin, `http://localhost:8080`이 설정되어 있습니다. 실제로 사용하지 않는 origin은 운영 설정에서 제거하고, 다른 주소를 추가할 때는 앱 origin과 Google/Firebase 허용 도메인을 함께 확인합니다. callback은 앱 origin이 아니라 **Worker의 `/auth/callback` URL**이며 Google OAuth 웹 클라이언트의 승인된 redirect URI에 등록해야 합니다.

다음 값은 Wrangler secret으로 설정해야 하며 Git이나 로그에 넣지 않습니다.

- `GOOGLE_CLIENT_ID`: Google OAuth 웹 클라이언트 ID
- `GOOGLE_CLIENT_SECRET`: 같은 클라이언트의 secret

요청 scope는 `openid`, `email`, `profile`, `spreadsheets`, `drive.metadata.readonly`입니다. Drive는 파일 목록 메타데이터만 요청하며 전체 파일 본문 읽기는 요청하지 않습니다. Google Cloud에서 Sheets API와 Drive API, Firebase Google 로그인을 활성화해야 합니다. 허용 origin 외 요청은 거절되며, refresh/revoke를 서버에서 호출하는 경우 Origin이 없어도 유효한 Firebase Bearer token이 필요합니다.

토큰 응답과 callback HTML은 `Cache-Control: no-store`입니다. callback에는 임의 오류 문자열을 반영하지 않고 HTML 문맥을 이스케이프하며 CSP와 정확한 `postMessage` target origin을 설정합니다. JWKS는 고정된 Google 주소에서 받아 서명을 검증합니다. 네트워크 요청에 시간 제한을 두며 외부 응답 원문이나 토큰을 로그로 남기지 않습니다.

## 기존 버전에서 전환

이 변경은 기존 앱과 인증 프로토콜이 호환되지 않습니다. Worker와 Flutter 앱을 함께 반영해야 합니다. 구형 클라이언트는 새 Worker에서 새로 로그인할 수 없으므로 앱 새로고침을 안내해야 합니다.

기존 `AUTH_TOKENS` KV의 `refresh:pending`, `refresh:<uid>`는 출처가 검증되지 않은 매핑이므로 **자동 마이그레이션하거나 읽지 않습니다**. 새 버전 사용자는 한 번 다시 로그인해야 합니다. 브라우저의 기존 `google_access_token`, `google_token_expiry` 키도 재사용하지 않고 제거합니다. 기존 KV namespace는 새 코드에 바인딩되지 않으며, 이전 데이터 삭제나 기존 Google grant 폐기는 별도 운영 작업입니다. 이 코드 변경만으로 운영 Worker 배포나 기존 KV 삭제가 실행되지는 않습니다.

## 참고

- [Firebase ID token 검증](https://firebase.google.com/docs/auth/admin/verify-id-tokens)
- [Google OAuth 웹 서버 흐름과 state](https://developers.google.com/identity/protocols/oauth2/web-server)
- [Google OIDC 검증과 nonce](https://developers.google.com/identity/openid-connect/openid-connect)
- [Google discovery의 S256 지원](https://accounts.google.com/.well-known/openid-configuration)
- [Durable Object 트랜잭션 저장소](https://developers.cloudflare.com/durable-objects/api/sqlite-storage-api/)
- [jose JWKS 서명 검증](https://github.com/panva/jose/blob/main/docs/jwks/remote/functions/createRemoteJWKSet.md)
