# 배포 가이드 (GitHub Pages)

## 배포 URL
https://venaki.github.io/portfolio-app/

## 배포 절차
1. `flutter build web --base-href "/portfolio-app/" --release`
2. `gh-pages` 브랜치에 `build/web/` 결과물 복사
3. 커밋 & 푸시 → 자동 배포

## 주의사항
- `--base-href "/portfolio-app/"` 누락 시 경로 깨짐
- OAuth redirect URI에 `https://venaki.github.io/portfolio-app` 등록 필요 (Google Cloud Console → 사용자 인증 정보 → OAuth 2.0 클라이언트)
- GitHub Pages 소스: `gh-pages` 브랜치 `/` (루트)
