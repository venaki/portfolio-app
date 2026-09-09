---
name: deploy
description: 패치노트 생성 → 버전 업 → 커밋/푸쉬 → 빌드 → GitHub Pages + Firebase Hosting 배포를 일괄 실행한다.
---

# 배포

패치노트 생성부터 빌드, 배포까지 일괄 실행한다.

## 실행 절차

### Step 1: 패치노트 생성

`/patch-note` 스킬을 실행하여 패치노트를 생성한다.

### Step 2: 버전 업

1. 생성된 패치노트의 버전 번호를 확인한다.
2. `pubspec.yaml`의 `version` 필드를 업데이트한다.
   - 버전: 패치노트 버전과 동일 (예: `0.1.2`)
   - 빌드 번호: 기존 빌드 번호 +1 (예: `+3` → `+4`)
3. 설정 화면은 패키지 버전을 읽으므로 하드코딩한 별도 버전은 추가하지 않는다.

### Step 3: 빌드

```bash
flutter pub get --enforce-lockfile
flutter analyze
flutter test --no-pub
bash scripts/build_web.sh
```

검증 또는 빌드 실패 시 중단하고 Director에게 보고한다. Firebase용 `build/hosting/firebase/`는 `/`, GitHub Pages용 `build/hosting/github/`는 `/portfolio-app/` 기준으로 각각 생성된다.

### Step 4: 커밋 & 푸쉬

1. `git status`와 변경 내용을 검토하고 이번 릴리스에 승인된 파일만 명시적으로 스테이징한다. 사용자의 다른 변경이나 untracked 파일은 자동 포함하지 않는다.
2. 커밋 메시지: `v{version}: {패치노트 한줄 요약}`
3. `git push origin main`

### Step 5: 배포

이번 릴리스는 Worker와 앱의 인증 프로토콜이 함께 변경된다. `release/deploy.md`의 인증 전환 확인 후 **Worker → GitHub Pages → Firebase Hosting** 순서로 연속 반영한다. 구형 클라이언트의 새 로그인은 전환 중 실패할 수 있다.

**Cloudflare Worker:**
```bash
cd portfolio-cors-proxy
npm run check
npm run build
npx wrangler secret list
npx wrangler deployments list
npx wrangler deploy
cd ..
```
배포 전 기존 버전을 기록하고, `AUTH_STATE` Durable Object migration 및 Firebase 허용 주소 반영을 확인한다. Worker 배포 실패 시 웹 앱 배포를 중단한다.

**GitHub Pages (gh-pages 브랜치):**
```bash
project_root="$(git rev-parse --show-toplevel)"
deploy_dir="$(mktemp -d "${TMPDIR:-/tmp}/portfolio-pages.XXXXXX")"
git clone --branch gh-pages --single-branch git@github.com:venaki/portfolio-app.git "$deploy_dir/site"
rsync -a --delete --exclude=.git "$project_root/build/hosting/github/" "$deploy_dir/site/"
git -C "$deploy_dir/site" status --short
git -C "$deploy_dir/site" add --all
git -C "$deploy_dir/site" commit -m "Deploy v{version}"
git -C "$deploy_dir/site" push origin HEAD:gh-pages
```
소스 작업 디렉터리에서 `gh-pages`를 다시 푸시하지 않는다. 변경이 없는 경우 커밋을 생략한다.

**Firebase Hosting:**
`firebase.json`의 `hosting.public`이 `build/hosting/firebase`인지 확인한다.
```bash
firebase deploy --only hosting --project portfolio-app-venaki-ed7b4
```

### Step 6: 완료 보고

```
🚀 v{version} 배포 완료
- GitHub Pages: https://venaki.github.io/portfolio-app/
- Firebase Hosting: https://portfolio-app-venaki-ed7b4.web.app
```
