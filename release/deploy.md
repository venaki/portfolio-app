# 웹 빌드와 배포

Flutter 3.41.5 / Dart 3.11.3, Worker 검증에는 Node.js 22.19.0을 사용한다. CI는 분석·테스트·빌드만 실행하며 배포 권한이나 운영 비밀값을 사용하지 않는다.

## 검증과 빌드

프로젝트 루트에서 실행한다.

```bash
flutter pub get --enforce-lockfile
flutter analyze
flutter test --no-pub
bash scripts/build_web.sh
```

`scripts/build_web.sh`는 운영 모드(`DEV_MODE=false`)로 다음 두 산출물을 각각 생성하고 HTML의 기준 경로를 검사한다. `firebase` 또는 `github` 인자를 주면 하나만 빌드한다.

| 호스팅 | 기준 경로 | 업로드할 디렉터리 |
| --- | --- | --- |
| Firebase Hosting | `/` | `build/hosting/firebase/` |
| GitHub Pages | `/portfolio-app/` | `build/hosting/github/` |

두 호스팅의 산출물을 서로 바꾸어 사용하면 정적 파일 경로가 깨진다. `firebase.json`의 `hosting.public`은 Firebase 산출물에 맞춰져 있다. Worker 검증은 `portfolio-cors-proxy/`에서 `npm ci`, `npm run typecheck`, `npm test`를 실행한다.

## 이번 인증 전환의 배포 순서

이 릴리스는 구형 Worker와 새 앱의 인증 프로토콜이 호환되지 않는다. 위 빌드·검증을 먼저 마친 뒤, Worker와 두 웹 호스팅을 한 릴리스로 연속 반영한다. 전환 중에는 구형 페이지의 로그인이 실패할 수 있으므로 사용자는 앱을 새로고침하고 다시 로그인해야 한다.

명시적인 배포 요청을 받은 경우 Worker 디렉터리에서 실행한다.

```bash
cd portfolio-cors-proxy
npm run check
npm run build
npx wrangler secret list
npx wrangler deployments list
npx wrangler deploy
cd ..
```

`npm run build`는 dry-run이고 `wrangler deploy`가 실제 배포다. 배포 전에 기존 버전 ID와 이전 앱 산출물을 기록한다. 배포에는 `wrangler.toml`의 Firebase 도메인, Firebase 프로젝트 ID, Durable Object binding 및 migration이 포함돼야 한다. Google callback 주소는 기존 운영 Worker 주소를 유지한다. 배포 오류가 나면 웹 앱 반영을 중단하고 오류·현재 버전을 확인한다. 구형 인증은 보안 결함과 새 저장소 비호환성이 있으므로 웹 앱만 임의로 되돌리는 것을 기본 복구 방식으로 삼지 않는다.

Worker가 정상 반영되면 아래 순서로 두 호스팅을 배포하고 로그인 → 새로고침 → 테스트 시트 조회·저장 → 로그아웃을 확인한다. 실제 사용자 원장은 테스트 대상으로 자동 선택하지 않는다. 설정 조회 결과는 `docs/auth-readiness.md`를 참고한다.

## GitHub Pages

주소: <https://venaki.github.io/portfolio-app/>

저장소의 Pages 소스는 `gh-pages` 브랜치의 루트이다. 검증한 산출물을 별도 임시 체크아웃에 준비한다.

```bash
project_root="$(git rev-parse --show-toplevel)"
deploy_dir="$(mktemp -d "${TMPDIR:-/tmp}/portfolio-pages.XXXXXX")"
git clone --branch gh-pages --single-branch git@github.com:venaki/portfolio-app.git "$deploy_dir/site"
rsync -a --delete --exclude=.git "$project_root/build/hosting/github/" "$deploy_dir/site/"
git -C "$deploy_dir/site" status --short
```

배포 요청 범위와 변경 결과를 확인한 뒤 그 체크아웃에서 커밋·푸시한다. 소스 작업 디렉터리의 변경은 이 절차로 커밋하지 않는다.

```bash
git -C "$deploy_dir/site" add --all
git -C "$deploy_dir/site" commit -m "Deploy reviewed web build"
git -C "$deploy_dir/site" push origin HEAD:gh-pages
```

빌드가 생성한 `.nojekyll`을 함께 업로드한다. 이미 동일한 산출물이 게시되어 변경이 없다면 새 커밋은 필요 없다.

## Firebase Hosting

주소: <https://portfolio-app-venaki-ed7b4.web.app/>

배포가 요청된 경우에만 프로젝트 루트에서 실행한다.

```bash
firebase deploy --only hosting --project portfolio-app-venaki-ed7b4
```

배포 후 두 주소의 첫 화면, 새로고침, 로그인 팝업, 실제 연결할 Google Sheets 권한을 각각 확인한다. OAuth 리디렉션은 Worker의 콜백 경로를 사용하며, 허용 앱 origin과 Firebase 인증 도메인은 두 호스팅에 맞게 설정해야 한다. 운영 설정 변경은 승인된 범위에서만 수행하며, 이번 릴리스에는 위 Worker 전환 절차를 함께 적용한다.

Firebase Hosting의 `predeploy`는 `scripts/build_web.sh firebase`를 실행해 현재 소스로 루트 경로 번들을 다시 만듭니다. 이전 배포 명령을 사용하더라도 오래된 `build/web` 결과를 Firebase에 재사용하지 않습니다. [Firebase CLI hooks](https://firebase.google.com/docs/cli#hooks) 규약을 따릅니다.
