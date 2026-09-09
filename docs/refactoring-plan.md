# Portfolio reliability refactoring

Status: implementation and local verification complete (2026-09-08). Release v0.1.11 authorized and being prepared (2026-09-09).

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
