# 인증 배포 준비 확인

배포 전 확인일: 2026-09-09 (KST). 아래 표는 관리 API와 콘솔을 조회한 당시의 기록이다. 이후 승인된 v0.1.11 배포 결과는 `docs/refactoring-plan.md`의 배포 확인 절에 기록했다.

| 항목 | 결과 |
|---|---|
| Cloudflare CLI 로그인 | 정상. 대상 Worker 계정 접근과 Workers 쓰기 권한 확인 |
| Worker OAuth secret | `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET` 등록 확인. secret 값은 조회하지 않음 |
| 현재 운영 Worker | 2026-03-27 배포 버전. 기존 `AUTH_TOKENS` KV 바인딩 사용 |
| Firebase 프로젝트 | `portfolio-app-venaki-ed7b4` 활성 상태, 관리 API 접근 정상 |
| Firebase Google 로그인 | 활성화 확인 |
| OAuth 클라이언트 ID | 운영 Worker의 로그인 리디렉션과 Firebase Google provider의 ID가 일치 |
| Firebase 승인 도메인 | `localhost`, `venaki.github.io`, 프로젝트의 `.web.app`과 `.firebaseapp.com` 모두 등록 |
| Google 승인 리디렉션 URI | 콘솔에서 `https://portfolio-cors-proxy.venaki.workers.dev/auth/callback` 등록 확인 |
| OAuth 앱 게시 상태 | 외부 사용자용 프로덕션 상태 확인. 콘솔 표시 사용자 한도 100명 중 3명 |
| Google API | Sheets, Drive, Identity Toolkit 모두 ENABLED |

## 배포에 포함할 변경

현재 운영 Worker의 `ALLOWED_ORIGINS`는 GitHub Pages와 localhost만 포함한다. 새 `wrangler.toml`은 Firebase Hosting의 두 도메인도 포함하며, `FIREBASE_PROJECT_ID`와 `AUTH_STATE` Durable Object 바인딩 및 최초 migration을 함께 반영한다.

기존 Worker와 새 Flutter 앱은 인증 프로토콜이 다르므로 둘을 한 릴리스로 배포해야 한다. 기존 KV의 토큰은 자동 이관하지 않는다. 배포 후 사용자는 새로 로그인하고 자신의 시트를 다시 선택한다. callback 등록 주소는 기존 운영 Worker 주소를 그대로 유지한다.

설정 조회 성공은 실제 Google code 교환·새 Durable Object 저장·Sheets 저장 성공까지 입증하지 않는다. 새 인증의 종단 간 검증은 아직 수행하지 않았다. 배포 시 로그인 → 앱 새로고침 → 테스트용 시트 조회·저장 → 로그아웃을 확인한다. 운영 배포 전에 별도 환경에서 검증하려면 해당 환경의 OAuth callback과 Worker/앱 주소를 별도로 구성해야 한다.

## 함께 보완한 검색 응답

Worker가 Yahoo의 객체 응답을 그대로 반환하고 Flutter가 배열을 기대하는 기존 불일치를 수정했다. 미국·한국 종목을 `{ticker,name,exchange}[]`로 변환하고 한국 종목의 선행 0 및 KRX/KOSDAQ을 유지한다. Worker 테스트는 인증 12개 + 검색 7개, 총 19개가 통과했다. TypeScript 검사와 Wrangler dry-run 빌드도 통과했다.

## 관리 CLI 조회 주의사항

Firebase CLI `login:list --json`은 계정 정보와 함께 토큰을 반환한다. 계정 정보를 확인할 때 JSON 원문을 로그나 도구 출력에 전달하지 않고 필요한 공개 항목만 선택한다. 토큰과 client secret은 문서·소스·커밋에 기록하지 않는다.
