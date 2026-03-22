# Portfolio Manager

개인 자산관리 앱 — 미국/한국 주식 + 기타 자산을 명의별로 관리

**Live**: https://venaki.github.io/portfolio-app

## 기술 스택

- Expo + React Native + TypeScript
- Expo Router (file-based routing)
- Yahoo Finance API (주가) + er-api.com (환율)
- localStorage (웹) / expo-file-system (네이티브)

## 로컬 개발

```bash
cd portfolio-app
npm install
npx expo start --web
```

http://localhost:8081 에서 확인

## 배포 (GitHub Pages)

```bash
./deploy.sh
```

이 스크립트가 하는 일:
1. `npx expo export --platform web` — 웹 빌드
2. `dist/index.html`에 Google Fonts CDN 링크 패치
3. `dist/assets/node_modules` 제거 (@ 경로 호스팅 문제 우회)
4. `npx gh-pages -d dist` — GitHub Pages 배포

## 주의사항

### 빌드할 때마다 index.html이 덮어씌워짐

`npx expo export`는 매번 `dist/index.html`을 새로 생성합니다. Google Fonts CDN `<link>` 태그가 사라지므로 **반드시 `deploy.sh`를 통해 배포**해야 합니다. 수동으로 `npx expo export` 후 바로 배포하면 폰트가 깨집니다.

### @ 경로 문제

Expo가 폰트를 `assets/node_modules/@expo-google-fonts/...` 경로로 번들링합니다. GitHub Pages와 Vercel 모두 `@` 문자가 포함된 경로를 제대로 서빙하지 못합니다. 해결 방법:
- 웹: `useFonts`를 스킵하고 Google Fonts CDN으로 로드 (`app/_layout.tsx`에서 `Platform.OS === 'web'` 분기)
- 네이티브: 기존 `useFonts` 사용

### app.json baseUrl

```json
"experiments": {
  "baseUrl": "/portfolio-app"
}
```

GitHub Pages가 `venaki.github.io/portfolio-app/` 서브경로에서 서빙하므로 이 설정이 필수입니다. 다른 호스팅(루트 경로)으로 이전 시 제거해야 합니다.

### 웹에서 Alert.alert 제한

React Native의 `Alert.alert`는 웹에서 버튼 배열(확인/취소)이 동작하지 않습니다. 삭제 등 확인이 필요한 곳에서 `window.confirm`으로 대체되어 있습니다.

### 데이터 저장 위치

| 플랫폼 | 저장소 | 위치 |
|--------|--------|------|
| 웹 | localStorage | `portfolio-data` 키 |
| iOS | expo-file-system | `documentDirectory/portfolio-data.json` |

**브라우저 데이터를 삭제하면 포트폴리오 데이터도 삭제됩니다.** 설정 > 데이터 백업으로 JSON 파일을 내보내 두세요.

### 주가 API (Yahoo Finance)

- 비공식 API — 언제든 변경/차단 가능
- 웹에서는 CORS proxy(`corsproxy.io`) 경유
- 네이티브에서는 직접 호출
- proxy 서버 장애 시 주가 로딩 실패 가능 → 캐시 데이터 유지

### 환율 API

우선순위: er-api.com → Yahoo Finance → frankfurter.app → fallback 1450원

## 프로젝트 구조

```
portfolio-app/
├── app/                    # Expo Router 화면
│   ├── _layout.tsx         # 루트 레이아웃 (폰트, AppProvider)
│   └── (tabs)/             # 탭 화면들
│       ├── _layout.tsx     # 반응형 탭/사이드바
│       ├── index.tsx       # 대시보드
│       ├── portfolio.tsx   # 포트폴리오
│       ├── history.tsx     # 거래내역
│       ├── other-assets.tsx # 기타 자산
│       └── settings.tsx    # 설정
├── src/
│   ├── types.ts            # 타입 정의
│   ├── constants.ts        # 색상, 상수
│   ├── seed.ts             # 초기 시드 데이터
│   ├── engine/             # 비즈니스 로직
│   │   ├── holdings.ts     # 거래 → 보유 계산 (이동평균법)
│   │   └── calculations.ts # 수익률, 손익 계산
│   ├── storage/            # 데이터 영속성
│   ├── api/fmp.ts          # Yahoo Finance + 환율 API
│   ├── context/            # React Context (전역 상태)
│   ├── hooks/              # useMarketData, useResponsive
│   └── components/         # UI 컴포넌트
├── __tests__/              # 테스트 (Jest)
├── deploy.sh               # 배포 스크립트
└── app.json                # Expo 설정
```
