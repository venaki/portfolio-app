# Portfolio Manager App — 제품 스펙

## 개요

개인 자산을 실시간으로 관리하는 크로스 플랫폼 앱.
명의별(본석/연지/나은) 포트폴리오를 한눈에 파악하고, 매수/매도 내역을 기록한다.
모바일(iOS)과 PC(웹 브라우저) 모두 지원하며, 각 플랫폼에 최적화된 레이아웃을 제공한다.

## 기술 스택

| 항목 | 선택 |
|------|------|
| 프레임워크 | Expo + React Native |
| 언어 | TypeScript |
| 라우팅 | Expo Router (file-based) |
| 실시간 주가 | Yahoo Finance API (Cloudflare Worker CORS proxy 경유) |
| 환율 | Open Exchange Rates / Yahoo Finance / Frankfurter (다중 폴백) |
| 아이콘 | lucide-react-native |
| 데이터 저장 | 로컬 JSON (웹: localStorage, 네이티브: expo-file-system) |
| CORS Proxy | Cloudflare Workers (portfolio-cors-proxy.venaki.workers.dev) |
| 배포 | GitHub Pages (https://venaki.github.io/portfolio-app) |

## 타겟 플랫폼

- **모바일 (메인)**: iOS (iPhone) — Expo Go / EAS Build
- **PC (웹)**: Mac/Windows 브라우저 — Expo Web
- 반응형 레이아웃으로 모바일/PC 각각 최적화된 UI 제공

---

## 원장 정책

### Source of Truth: `transactions`

- `transactions`(거래내역)이 유일한 진실 원장이다.
- `holdings`(보유현황)은 transactions를 재계산하여 도출하는 **파생 상태**이다.
- 모든 보유 변경은 반드시 transaction을 통해서만 발생한다.

### 거래 유형

| type | 용도 |
|------|------|
| `buy` | 일반 매수 |
| `sell` | 일반 매도 |
| `opening_balance` | 초기 보유 입력 (시드 데이터, 수동 이관) |
| `adjustment` | 수량/단가 보정 (직접 수정 대체) |

### 재계산 규칙

- 앱 시작 시: transactions 로드 → 날짜순 정렬 → replay → holdings 생성
- 거래 추가/수정/삭제 시: 해당 명의+종목 범위 재계산
- holdings 불일치 시: 버리고 재생성

---

## 매도 정산 규칙: 이동평균법 (가중평균법)

한국 증권사와 동일하게 **이동평균법**을 적용한다.

### 계산 방식

- 같은 명의 + 같은 종목의 모든 매수를 합산하여 **가중평균 평단가** 산출
- 매도 시 가중평균 평단가 기준으로 손익 계산
- **로트 구분 없음** — 명의+종목 당 1개 레코드

### 평단가 갱신 공식

```
추가 매수 시:
새 평단가 = (기존수량 × 기존평단가 + 매수수량 × 매수가) / (기존수량 + 매수수량)
새 환율 = (기존수량 × 기존환율 + 매수수량 × 매수환율) / (기존수량 + 매수수량)

매도 시:
평단가 변동 없음 (수량만 차감)
```

### 세금 계산

이동평균법 기준으로 양도소득세를 계산한다.

```
양도차익 = 매도가 × 매도수량 - 이동평균 평단가 × 매도수량
```

---

## 핵심 기능

### 1. 대시보드 (Dashboard)

총 자산 현황을 한눈에 보여주는 메인 화면.

- 총 평가금액 (KRW)
- 총 수익/손실 (KRW, %)
- 일간 변동 (KRW, %)
- 명의별 자산 비중 (본석 / 연지 / 나은)
- 종목별 비중 (파이차트 또는 바차트)
- USD/KRW 환율 표시
- 마지막 업데이트 시각

### 2. 포트폴리오 (Portfolio)

명의별 보유 종목 상세 조회.

- **명의 탭/필터**: 본석 / 연지 / 나은 / 전체
- **종목별 정보 표시**:
  - 종목코드, 종목명
  - 현재가 (USD), 전일대비, 등락률
  - 보유수량, 평단가 (USD) — 이동평균
  - 평가금액 (USD / KRW)
  - 수익률 (USD 기준 / KRW 기준)
  - 수익금 (USD / KRW)
- **종목 추가**: 거래내역 `opening_balance` 또는 `buy` 생성으로 처리
- **종목 수정**: `adjustment` 거래 생성으로 처리
- **종목 삭제**

### 3. 거래내역 (History)

매수/매도 기록을 시간순으로 관리.

- **기록 항목**:
  - 명의 (본석/연지/나은)
  - 종목코드
  - 거래유형 (buy/sell/opening_balance/adjustment)
  - 수량
  - 체결가 (USD)
  - 환율 (KRW/USD)
  - 일시 (ISO datetime)
  - 메모 (선택)
- **필터**: 명의별, 종목별, 거래유형별
- **정렬**: 날짜 최신순 (기본)

### 4. 설정 (Settings)

- **명의(Accounts) 관리**: 추가/삭제
  - 거래내역이 존재하는 명의는 삭제 차단 (모달로 안내)
  - 거래내역이 없는 명의는 확인 모달 후 삭제
- **강조 색상 변경**: 앱 전체 액센트 컬러를 프리셋에서 선택
  - Teal #0D6E6E (기본), Blue #2563EB, Purple #7C3AED, Green #16A34A, Orange #EA580C, Rose #E11D48
  - 선택 시 Tab Bar 활성 상태, 버튼, 수익률(+) 등 전체 accent 색상 반영
  - `settings.accentColor`에 저장
- 자동 새로고침 간격 설정 (기본: 1분)
- 데이터 백업/복원 (JSON 내보내기/가져오기, 마이그레이션 자동 적용)
- 데이터 초기화 (확인 다이얼로그 필수)

---

## 데이터 모델

### Owner (명의)

```
'본석' | '연지' | '나은'
```

### Transaction (거래내역) — Source of Truth

```
{
  id: string                                          // 고유 ID (UUID)
  owner: Owner                                        // 명의
  ticker: string                                      // 종목코드 (예: "TSLA", "035420")
  type: 'buy' | 'sell' | 'opening_balance' | 'adjustment'  // 거래유형
  assetClass: 'us_stock' | 'kr_stock' | 'cash'       // 자산 분류
  currency: 'USD' | 'KRW'                             // 통화
  shares: number                                      // 수량
  price: number                                       // 체결가
  exchangeRate: number                                // 당시 환율 (KRW/USD)
  executedAt: string                                  // 일시 (ISO datetime)
  memo?: string                                       // 메모 (선택)
}
```

### Holding (보유종목) — 파생 상태 (transactions에서 계산)

```
{
  owner: Owner                           // 명의
  ticker: string                         // 종목코드
  assetClass: 'us_stock' | 'kr_stock' | 'cash'  // 자산 분류
  currency: 'USD' | 'KRW'               // 통화
  shares: number                         // 보유 수량
  avgCost: number                        // 이동평균 평단가
  avgExchangeRate: number                // 이동평균 매입환율 (KRW/USD)
}
```

### AppData (저장 구조)

```
{
  schemaVersion: number      // 스키마 버전 (마이그레이션 대비)
  transactions: Transaction[]
  accounts: string[]         // 명의 목록 (예: ["본석", "연지", "나은"])
  settings: {
    refreshInterval: number  // 초 단위 (기본 60 = 1분)
    accentColor: string      // hex 색상 (기본 "#0D6E6E")
  }
}
```

---

## 초기 시드 데이터

시드 데이터는 `opening_balance` 거래로 입력한다.
이동평균법에 따라 같은 명의+종목은 합산된 가중평균으로 기록한다.

### 본석

| 종목 | 수량 | 평단가 (USD) | 매입환율 |
|------|------|-------------|---------|
| TSLA | 500 | $318.01 | ₩1,450.51 |
| TSLL | 2,089 | $16.86 | ₩1,430.00 |
| TQQQ | 1,200 | $25.85 | ₩1,391.50 |

### 연지

| 종목 | 수량 | 평단가 (USD) | 매입환율 |
|------|------|-------------|---------|
| TSLA | 1,053 | $387.85 | ₩1,434.42 |
| TSLL | 7,300 | $29.41 | ₩1,462.41 |
| TQQQ | 406 | $53.18 | ₩1,377.25 |
| TSLY | 1,000 | $8.92 | ₩1,388.65 |
| GOOGL | 4 | $190.88 | ₩1,386.00 |
| SGOV | 200 | $100.51 | ₩1,450.50 |
| NVDA | 14 | $204.71 | ₩1,427.40 |
| NFLX | 5 | $88.74 | ₩1,473.60 |
| MP | 4 | $69.79 | ₩1,473.60 |

### 나은

| 종목 | 수량 | 평단가 (USD) | 매입환율 |
|------|------|-------------|---------|
| TQQQ | 1,037 | $38.10 | ₩1,467.16 |

---

## 실시간 데이터 API

### 주가: Yahoo Finance (Cloudflare Worker proxy)

- **배포 웹**: Cloudflare Worker CORS proxy 경유
  ```
  GET https://portfolio-cors-proxy.venaki.workers.dev/?symbol=TSLA&range=1d&interval=1d
  ```
- **로컬 개발 / 네이티브**: Yahoo Finance 직접 호출
  ```
  GET https://query1.finance.yahoo.com/v8/finance/chart/TSLA?range=1d&interval=1d
  ```
- **한국 주식**: `.KS` (KOSPI) / `.KQ` (KOSDAQ) 접미사 자동 변환
- **무료, API 키 불필요**, Cloudflare Workers 무료 한도: 일 10만 요청

### 환율: 다중 폴백

1. Open Exchange Rates (`open.er-api.com`) — 무료, CORS OK
2. Yahoo Finance (`USDKRW=X`) — proxy 경유
3. Frankfurter (`api.frankfurter.app`) — 무료, CORS OK
4. 폴백 기본값: 1450

### API 운영 정책

- **자동 갱신 기본값**: 1분
- **포그라운드에서만 갱신** (백그라운드 갱신 없음)
- **캐싱**: stale-while-revalidate — 실패 시 마지막 성공 데이터 유지
- **에러 처리**:
  - 네트워크 실패 / 오프라인 → 캐시 데이터 표시 + stale 표시
  - 일부 종목 실패 → 성공한 종목만 갱신

---

## 수익률 계산 공식

### USD 기준 수익률

```
수익률(%) = (현재가 - 이동평균 평단가) / 이동평균 평단가 × 100
수익금($) = (현재가 - 이동평균 평단가) × 수량
```

### KRW 기준 수익률 (환율 반영)

```
매입금액(₩) = 이동평균 평단가 × 수량 × 이동평균 매입환율
평가금액(₩) = 현재가 × 수량 × 현재환율
수익률(%) = (평가금액 - 매입금액) / 매입금액 × 100
수익금(₩) = 평가금액 - 매입금액
```

### 실현손익 (매도 시)

```
실현손익($) = (매도가 - 이동평균 평단가) × 매도수량
실현손익(₩) = 매도가 × 매도수량 × 매도환율 - 이동평균 평단가 × 매도수량 × 이동평균 매입환율
```

---

## 화면 구성

### 네비게이션

| | 모바일 | PC |
|---|---|---|
| 방식 | 하단 Pill Tab Bar | 좌측 사이드바 (240px) |
| 탭 | 대시보드 / 포트폴리오 / 거래내역 / 설정 | 동일 |

### 모바일 레이아웃 (402px)

4개 화면, 세로 스택 구성:
- **대시보드**: 총 자산 카드 → 환율/업데이트 → 명의별 카드 (세로)
- **포트폴리오**: 세그먼트 필터 (전체/본석/연지/나은) → 종목 카드 리스트
- **거래내역**: 필터 칩 (전체/매수/매도) → 월별 거래 카드 리스트
- **설정**: 명의 관리 → 강조 색상 → 새로고침 간격 → 데이터 관리

### PC 레이아웃 (1440px)

사이드바 + 메인 콘텐츠:
- **대시보드**: 총 자산 카드 (가로: 금액 + USD/원금) → 명의별 카드 3열 가로 배치
- **포트폴리오**: 필터 탭 + 추가 버튼 → 테이블 형태 종목 리스트 (종목/명의/현재가/수량/평가금액/수익률)
- **거래내역/설정**: 모바일과 동일 구조, 넓은 폭 활용

### 상태 UX

| 상태 | 표시 |
|------|------|
| 정상 | 실시간 데이터 + 마지막 갱신 시각 |
| Stale | 캐시 데이터 + "마지막 갱신: N분 전" 표시 |
| 오프라인 | 캐시 데이터 + 오프라인 배너 |
| 빈 상태 | 종목 추가 안내 |
| 로딩 | 스켈레톤 UI |

### 디자인 시스템

| 항목 | 값 |
|------|-----|
| 스타일 | Editorial Data Light |
| 제목 폰트 | Newsreader (Medium 500) |
| 숫자/라벨 | JetBrains Mono (Bold/Semibold) |
| 본문/UI | Inter (Regular/Medium) |
| 배경색 | #FAFAFA (페이지) / #FFFFFF (카드) |
| 액센트 (포지티브) | #0D6E6E (Teal) |
| 액센트 (네거티브) | #E07B54 (Orange) |
| 텍스트 | #1A1A1A / #666666 / #888888 / #AAAAAA |
| 카드 | 12px radius, 1px #E5E5E5 stroke |
| 명의 색상 | 본석: #0D6E6E / 연지: #E07B54 / 나은: #5B7FD6 |

### 디자인 파일

- `financial-app-design.pen` — Pencil 디자인 파일
- 모바일 4개 화면 + PC 2개 화면 (Dashboard, Portfolio)

---

## 비포함 (Out of Scope)

- 대출 인생 계산기 / 시뮬레이션
- Google Sheets 실시간 연동 (초기 데이터만 시딩)
- 코인 관리
- 푸시 알림
- iCloud 동기화 (추후 별도 구현)
- 복수 로트 관리 (이동평균법으로 합산)
