# Portfolio reliability refactoring

Status: implementation and local verification complete (2026-09-08). Release v0.1.11 committed, pushed and deployed to Worker and both web hosts (2026-09-09). See the deployment verification record below for remaining checks.

## Scope and constraints

- Keep Flutter, Riverpod, Google Sheets and existing user data formats readable.
- Fix authentication, persistence, financial arithmetic, navigation and historical-data defects before cosmetic cleanup.
- Preserve existing data on failures; explicitly report invalid data rather than treating errors as zero values.
- Do not deploy, commit, rewrite Git history, or mutate production spreadsheets during implementation. The subsequent v0.1.11 release has explicit authorization for commit, push and deployment; production spreadsheet writes remain outside release verification.
- Historical prices use validated CSV/JSON imports without an external account or paid API. The optional source preference received no answer, so the proposed import path was implemented. Existing tracked backups remain unchanged pending confirmation about their contents; future local exports are ignored.
- Cash settlement, dividend/tax accounting and external paid integrations are not silently introduced.

## Work streams

- [x] Authentication: verified user identity, isolated OAuth attempts, safe popup exchange, session cleanup, Worker tests and reproducible tooling.
- [x] Domain: native/KRW cost basis, deterministic transaction replay, input/schema validation, currency-safe consolidation, shared valuation and snapshot engines.
- [x] Persistence: checked HTTP client, immutable spreadsheet sessions, safe CRUD, schema round trips, non-destructive price refresh, consistent mock repository.
- [x] State: user/sheet lifecycle, guarded asynchronous work, mutation serialization, explicit errors and partial quote handling.
- [x] History: supported historical-data ingestion, observation preservation, dirty-range tracking and accurate period/date axes.
- [x] Data management: versioned full backup, validated restoration preview, consistent CSV schema.
- [x] UI: shared forms, input validation, dependable navigation/order editing, useful errors/retries, account integrity, search and connection improvements.
- [x] Delivery: hosting-specific build paths, README and migration instructions, CI, privacy exclusions as authorized.
- [x] Integration: analyzer, unit/service/widget tests, Worker tests/type checking and development-mode browser checks.

## Acceptance checks

- Unauthenticated token access fails; simultaneous users cannot share an OAuth attempt or session.
- HTTP 401/403/429/5xx cannot be reported as a successful save.
- Transaction time, ordering, quantities and KRW basis survive persistence round trips.
- Invalid quotes do not replace valid asset values or historical observations.
- Account/sheet switching invalidates old work before it can affect a new session.
- Backups validate before restoration; legacy rows remain readable.
- Portfolio editing survives or safely exits navigation; mobile navigation remains available.
- Historical charts reflect actual dates, comparison coverage, data source and recalculation status.
- Relevant automated checks pass and no production data is used in integration tests.

## Verification log

- Baseline: 39 Flutter tests pass; analyzer reports 3 warnings and 16 infos.
- Baseline reproductions: 403 save accepted; 15:45 transaction loaded as 00:00; incorrect KRW cost; mixed-currency consolidation; equal-time replay reordering; navigation/edit state loss.


- Final Flutter suite: **138 tests pass** (`flutter test --no-pub`). After replacing the remaining trivial settings/asset tests with production-path tests, the affected **10 tests pass** again; the suite size remains 138.
- Final static analysis: `flutter analyze --no-pub` reports **No issues found**.
- Worker: **12 tests pass**, TypeScript check passes, Wrangler dry-run bundle succeeds. Local workerd verified Durable Object initialization and authentication rejection without production credentials.
- Both release targets build successfully with their expected base href, app bundle and icon fonts: `build/hosting/firebase` and `build/hosting/github`. Wasm compatibility dry runs also succeed; a Wasm deployment was not requested.
- Chrome DEV_MODE: desktop order edit → tab switch → return, 390×844 mobile navigation, settings/backup entry points, and NaN save rejection verified. Release Firebase bundle reaches the login screen with no captured error/warn logs.
- Final consistency review added regression protection for failed/idempotent appends, malformed optional headers, duplicate settings keys, and backup serialization. Today's additions do not mark past history dirty; future-dated assets are excluded from current valuation.
- `git diff --check` passes. Test tabs and temporary web servers were closed. Production Google login, Sheets restoration, Worker deployment and hosting deployment were not executed.

## Transition and remaining limits

- Worker and Flutter authentication protocols must be released together. The new Durable Object binding/migration and existing Google/Firebase origin configuration are documented in `portfolio-cors-proxy/README.md`. Users must sign in and select their spreadsheet again once.
- Existing snapshots are preserved and labeled by calculation version/source. Historical changes mark affected dates; preserved live observations are not silently rewritten by imports.
- Sheets does not provide a conditional row-write transaction across external clients. Local writes are serialized and remote edits are compared before updates, but simultaneous manual/other-client edits remain a documented limitation. Multi-call export consistency also assumes no external writes during export.
- CSV/JSON file parsing, backup round trips, atomic restore request construction and UI confirmation are tested locally. Browser file selection through actual authenticated remote restoration still needs an authorized operating-environment check.
- Existing tracked `_backup/save/*.json` files and the user's untracked `.agents/` are preserved. No Git history cleanup was performed. New local export files are ignored.
- No automatic cash settlement, dividends, taxes, corporate actions, paid market-data integration or cash-flow-adjusted performance accounting was introduced.

See `README.md` for user-facing data formats, calculation definitions and development commands, and `release/deploy.md` for hosting paths and the Firebase predeploy build hook.

## 2026-09-09 인증 설정 후속 확인

Cloudflare 재로그인 후 운영 Worker secret 등록, Firebase provider·도메인·API 활성화 및 Google callback 등록을 확인했다. 자세한 결과와 남은 종단 간 검증은 `docs/auth-readiness.md`에 기록했다. 기존 종목 검색 응답 계약 불일치도 수정해 Worker 검증은 총 19개(인증 12 + 검색 7)로 늘었다. 이후 커밋·배포 승인을 받아 v0.1.11 릴리스를 준비한다.

## 2026-09-09 v0.1.11 배포 확인

- 소스 커밋 `4ea3c7b`를 main에 푸시했다. 버전은 `0.1.11+12`이며 Flutter 분석, 138개 테스트와 두 웹 빌드가 통과했다.
- Worker 버전 `715a4001-b54a-4153-b37b-275b28bac7fd`를 배포했다. 19개 테스트와 타입 검사, 빌드가 통과했다.
- GitHub Pages 배포 커밋은 `7b9c13d`이며 Firebase Hosting도 같은 앱 버전을 배포했다. 두 운영 사이트의 JavaScript 번들 해시가 로컬 산출물과 일치한다.
- 운영 Worker에서 세 웹 origin의 CORS, 미인증 요청 거부, 구형 migrate 제거, Durable Object 인증 시도 생성과 취소 callback, 미국·한국 종목 검색을 확인했다.
- 두 웹의 로그인 화면이 표시되고 브라우저 오류·경고가 없는 것을 확인했다. Firebase 앱의 Google 계정 선택 팝업을 열었으며 실제 사용자 로그인과 시트 연동 확인은 사용자에게 넘겼다. 운영 자산 원장에 테스트 쓰기를 하지 않았다.
- 첫 GitHub CI의 Worker 설치에서 lockfile이 사내 npm 주소를 참조해 E401이 발생했다. 공개 npm 레지스트리를 명시하는 후속 수정으로 검증한다. 이 설정 변경은 배포된 앱 코드를 바꾸지 않는다.
