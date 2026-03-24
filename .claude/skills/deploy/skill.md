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
3. 설정 화면(`lib/screens/settings_screen.dart`)의 버전 표시도 업데이트한다.

### Step 3: 커밋 & 푸쉬

1. 모든 변경사항을 git add한다. (untracked 포함, 단 .gitignore 대상 제외)
2. 커밋 메시지: `v{version}: {패치노트 한줄 요약}`
3. `git push origin main`

### Step 4: 빌드

```bash
flutter build web --release --base-href="/portfolio-app/"
```

빌드 실패 시 중단하고 Director에게 보고한다.

### Step 5: 배포

**GitHub Pages (gh-pages 브랜치):**
```bash
cd /tmp && rm -rf portfolio-deploy
git clone --branch gh-pages --single-branch <repo> portfolio-deploy
rm -rf /tmp/portfolio-deploy/*
cp -r build/web/* /tmp/portfolio-deploy/
cd /tmp/portfolio-deploy && git add -A && git commit -m "Deploy v{version}"
git push origin gh-pages
```
로컬 repo에서도 `git push origin gh-pages` 실행.

**Firebase Hosting:**
```bash
firebase deploy --only hosting --project portfolio-app-venaki-ed7b4
```

### Step 6: 완료 보고

```
🚀 v{version} 배포 완료
- GitHub Pages: https://venaki.github.io/portfolio-app/
- Firebase Hosting: https://portfolio-app-venaki-ed7b4.web.app
```
