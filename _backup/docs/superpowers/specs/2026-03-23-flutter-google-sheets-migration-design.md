# Portfolio App: Flutter + Google Sheets Migration Design

## Overview

기존 Expo/React Native 포트폴리오 앱을 Flutter Web으로 전환하고, 데이터 저장소를 로컬 스토리지에서 Google Sheets API로 교체한다. Google Sign-In으로 인증하고, GOOGLEFINANCE 수식으로 실시간 시세를 가져온다.

**목표:**
- 기존 앱의 모든 기능을 100% 유지
- 백엔드 없는 정적 배포 유지 (GitHub Pages)
- CORS 프록시 역할 축소 (시세 조회 제거, 종목 검색만 유지)
- Google Sheets 공유로 멀티유저 지원

---

## 1. Architecture

```
┌──────────────────────────────────────────┐
│        Flutter Web App (PWA)             │
│        GitHub Pages 정적 배포             │
└──────┬──────────┬──────────┬─────────────┘
       │          │          │
       ▼          ▼          ▼
  Google SSO   Sheets API   CORS Proxy
  (OAuth 2.0)  (v4)         (Cloudflare Worker)
       │          │          │
       │          ▼          ▼
       │     Google Sheets   Yahoo Finance
       │     (4개 시트)      Search API
       │          │
       └──────────┘
         Access Token
```

### 핵심 원칙
- **서버리스**: 백엔드 없음. 모든 API 호출은 클라이언트에서 직접
- **Google Sheets = Database**: 하나의 스프레드시트가 모든 데이터 저장
- **GOOGLEFINANCE = 시세 피드**: Yahoo Finance API + CORS 프록시 대체
- **CORS 프록시**: 종목 검색 기능 하나만 담당 (기존 인프라 재활용)

### 기술 스택
| 영역 | 기술 |
|------|------|
| Framework | Flutter Web (PWA) |
| Language | Dart |
| Auth | `google_sign_in` 패키지 |
| Sheets API | `googleapis` 패키지 (SheetsApi v4) |
| File Picker | Google Picker API (스프레드시트 선택) |
| State | Riverpod |
| UI | Material Design 3 |
| Deploy | GitHub Pages (정적) |
| CORS Proxy | Cloudflare Worker (기존 재활용) |

---

## 2. Authentication

### Google Sign-In Flow
```
앱 시작 → 로그인 화면 → Google Sign-In
  → OAuth 2.0 (scope: spreadsheets)
  → Access Token 획득
  → 스프레드시트 연결/생성 화면
  → 메인 앱
```

### Scopes
- `https://www.googleapis.com/auth/spreadsheets` — Sheets 읽기/쓰기 (편집 권한 있는 모든 시트 접근 가능)

> Note: Google Picker API는 별도 scope 없이 OAuth 토큰 + API Key로 동작하므로, Drive 내 모든 스프레드시트를 선택할 수 있다.

### Session
- 토큰은 메모리에 유지, 만료 시 자동 갱신 (google_sign_in 패키지 처리)
- 로그아웃 시: OAuth 세션 해제, 로그인 화면으로 이동
- 스프레드시트 ID는 브라우저 localStorage에 유지 (재로그인 시 자동 연결)

---

## 3. Google Sheets Data Structure

하나의 스프레드시트, 4개 시트:

### 3.1 `Transactions` 시트

매수/매도 거래 기록. 한 행 = 한 거래.

| Column | Field | Type | Description |
|--------|-------|------|-------------|
| A | id | string | UUID |
| B | date | string | ISO 8601 (executedAt) |
| C | account | string | 계좌 명의 |
| D | type | string | `buy`, `sell`, `opening_balance`, `adjustment` |
| E | ticker | string | 종목코드 (TSLA, 005930) |
| F | market | string | `US`, `KRX`, `KOSDAQ` |
| G | name | string | 종목명 (검색 시 자동 입력, 시세 로딩 전 표시용) |
| H | shares | number | 수량 |
| I | price | number | 단가 (해당 통화 기준) |
| J | currency | string | `USD`, `KRW` |
| K | exchangeRate | number | 매입 시 USD/KRW 환율 |
| L | memo | string | 메모 |

### 3.2 `Prices` 시트

GOOGLEFINANCE 수식으로 실시간 시세 자동 갱신. 앱은 읽기 전용 (새 종목 추가 시 수식 행 삽입만).

| Column | Field | Type | Description |
|--------|-------|------|-------------|
| A | ticker | string | 종목코드 |
| B | market | string | `US`, `KRX`, `KOSDAQ`, `FX` |
| C | googlefinance_key | string | GOOGLEFINANCE 조회 키 (예: `KRX:005930`) |
| D | price | formula | `=GOOGLEFINANCE(C2,"price")` |
| E | name | formula | `=GOOGLEFINANCE(C2,"name")` |
| F | changepct | formula | `=GOOGLEFINANCE(C2,"changepct")` |
| G | closeyest | formula | `=GOOGLEFINANCE(C2,"closeyest")` |
| H | currency | string | `USD`, `KRW` |

**수식 생성 규칙:**
| 시장 | googlefinance_key | 예시 |
|------|-------------------|------|
| US | `{ticker}` | `AAPL` |
| KRX | `KRX:{ticker}` | `KRX:005930` |
| KOSDAQ | `KOSDAQ:{ticker}` | `KOSDAQ:096530` |
| FX (환율) | `CURRENCY:USDKRW` | `CURRENCY:USDKRW` |

**GOOGLEFINANCE 캐시 주의:**
- GOOGLEFINANCE 수식은 스프레드시트가 브라우저에서 열려 있을 때 자동 갱신됨
- 아무도 시트를 열지 않은 상태에서 API로 읽으면 마지막 캐시된 값이 반환될 수 있음
- 앱에서 시세 갱신 시 값의 freshness를 판단하기 어려우므로, "마지막 API 호출 시간"을 UI에 표시

**GOOGLEFINANCE 실패 대응:**
- D열 값이 `#N/A` 또는 에러인 경우 앱에서 감지
- 해당 종목의 포트폴리오/대시보드에 "시세 없음" 표시 + 수동 가격 입력 링크
- 수동 입력 시 D열에 직접 값 기록 (수식 덮어쓰기)
- 수식 복구: 설정 화면에서 "시세 수식 재생성" 버튼 제공

**환율 fallback:**
- Prices 시트의 `CURRENCY:USDKRW` 행이 에러인 경우
- 하드코딩 fallback 환율 사용 (1,450원)
- UI에 "환율 정보 없음 — 기본값 사용 중" 경고 표시

### 3.3 `OtherAssets` 시트

비주식 자산 (예금, 채권, 대출, 현금 등). 한 행 = 한 자산.

| Column | Field | Type | Description |
|--------|-------|------|-------------|
| A | id | string | UUID |
| B | account | string | 계좌 명의 |
| C | name | string | 자산명 (예: 청약저축) |
| D | category | string | `savings`, `bond`, `loan`, `cash`, `other` |
| E | value | number | 금액 (대출은 음수) |
| F | currency | string | `USD`, `KRW` |
| G | date | string | 등록/갱신 일자 |
| H | memo | string | 메모 |

**카테고리 표시 매핑:**
| 시트 값 (영어) | UI 표시 (한국어) |
|---------------|-----------------|
| savings | 예금 |
| bond | 채권 |
| loan | 대출 |
| cash | 현금 |
| other | 기타 |

### 3.4 `Settings` 시트

앱 설정. Key-Value 구조.

| Key | Value (예시) | Description |
|-----|-------------|-------------|
| accounts | 본석,연지,나은 | 쉼표 구분 계좌 목록 |
| base_currency | KRW | 기준 통화 |
| accent_color | #0D6E6E | 테마 강조색 |
| refresh_interval | 60 | 자동 새로고침 간격 (초) |
| version | 1 | 스키마 버전 |

---

## 4. Stock Search (종목 검색)

### Flow
```
사용자 입력: "삼성" 또는 "TES"
  → CORS 프록시 경유 Yahoo Finance Search API 호출
  → 검색 결과 드롭다운 표시
  → 선택 시 자동 입력:
      - ticker: 005930
      - market: KRX
      - name: Samsung Electronics Co Ltd
```

미국/한국 주식 모두 동일한 자동완성 UX:
```
[종목 검색: "tes"]
  ┌────────────────────────────────────────┐
  │ TSLA    Tesla Inc              NASDAQ  │
  │ TSLL    Direxion TSLA Bull 2X  NASDAQ  │
  └────────────────────────────────────────┘

[종목 검색: "삼성"]
  ┌────────────────────────────────────────┐
  │ 005930  Samsung Electronics     KRX    │
  │ 006400  Samsung SDI             KRX    │
  └────────────────────────────────────────┘
```

### Yahoo Finance Search API
```
GET https://portfolio-cors-proxy.venaki.workers.dev/search?q={query}
  → Proxy → https://query2.finance.yahoo.com/v1/finance/search?q={query}
```

### 거래소 매핑
| Yahoo suffix | market |
|-------------|--------|
| (없음) | US |
| .KS | KRX |
| .KQ | KOSDAQ |

### CORS 프록시 변경사항
기존 `portfolio-cors-proxy` Cloudflare Worker에 `/search` 엔드포인트 추가.
시세 조회 엔드포인트는 유지하되 앱에서 더 이상 사용하지 않음.

---

## 5. Spreadsheet Management

### 최초 실행 (Onboarding)
```
┌──────────────────────────────┐
│  Portfolio App               │
│                              │
│  📄 새 스프레드시트 생성       │  → Sheets API로 자동 생성
│  📂 기존 스프레드시트 연결     │  → Google Picker로 Drive에서 선택
└──────────────────────────────┘
```

**새로 생성 시:**
1. Sheets API로 빈 스프레드시트 생성 (제목: "Portfolio DB")
2. 4개 시트 생성 + 컬럼 헤더 삽입
3. `Prices` 시트에 환율 행 추가: `CURRENCY:USDKRW`
4. 스프레드시트 ID를 localStorage에 저장

**기존 연결 시:**
1. Google Picker API로 Drive 파일 선택 UI 표시 (내 드라이브 + 공유 드라이브 모두 표시)
2. 편집 권한 있는 스프레드시트만 선택 가능
3. 시트 구조 검증 (4개 시트 + 헤더 확인)
4. 스프레드시트 ID를 localStorage에 저장

### 공유 (멀티유저)
- Director가 Google Sheets에서 와이프에게 "편집자" 권한 공유
- 와이프: 앱 로그인 → "기존 스프레드시트 연결" → Google Picker에서 공유받은 시트 선택
- Google Sheets 동시 편집 지원으로 충돌 없음
- 편집/삭제 시 동시 수정은 last-write-wins (Google Sheets 기본 동작)

### 데이터 내보내기/불러오기
| 기능 | 동작 |
|------|------|
| CSV 내보내기 | Sheets 데이터를 CSV 파일로 다운로드 (백업용) |
| 스프레드시트 연결 변경 | Google Picker로 다른 스프레드시트 선택 → DB 전환 |

---

## 6. Calculation Engine

현재 앱의 계산 로직을 Dart로 1:1 재구현.

### 6.1 Holdings Replay

Transactions 시트의 거래 목록에서 현재 보유자산 계산:
1. 거래를 `date` 기준 오름차순 정렬
2. `Map<"account::ticker", Holding>` 유지
3. 각 거래 처리:
   - `buy` / `opening_balance` / `adjustment`: 주식 추가, 가중평균 매입가/환율 재계산
   - `sell`: 주식 감소, 0 이하면 제거
4. 최종 Holding 리스트 반환

> Note: OtherAssets는 Holdings Replay에 포함하지 않음. 별도 시트에서 직접 읽기.

### 6.2 수익 계산

```dart
// USD 기준 수익
profitUSD = (currentPrice - avgCost) * shares
profitPercentUSD = ((currentPrice - avgCost) / avgCost) * 100

// KRW 기준 평가금액
totalValueKRW:
  - KRW 자산: currentPrice * shares
  - USD 자산: currentPrice * shares * currentExchangeRate

// KRW 기준 매입가
costKRW:
  - KRW 자산: avgCost * shares
  - USD 자산: avgCost * shares * avgExchangeRate

// KRW 기준 수익
profitKRW = totalValueKRW - costKRW
profitPercentKRW = (profitKRW / costKRW) * 100

// 일간 변동 (Prices 시트의 closeyest 열 사용)
dailyChangeKRW = (currentPrice - closeyest) * shares * (KRW ? 1 : currentRate)
```

### 6.3 데이터 흐름

```
Transactions 시트 (읽기)
  → Holdings Replay (계산)
  → Holding 리스트 (주식 자산)

OtherAssets 시트 (읽기)
  → OtherAsset 리스트 (비주식 자산)

Prices 시트 (읽기)
  → GOOGLEFINANCE 값 (현재가, 전일종가, 변동률, 환율)

Holdings + OtherAssets + Prices + 환율
  → 수익/수익률/평가금액 계산
  → 총자산 = 주식 평가금액 합계 + 기타 자산 합계
  → UI 렌더링
```

---

## 7. App Screens

### 7.1 Screen Flow

```
[로그인] → [스프레드시트 연결/생성] → [메인 탭]

메인 탭 (BottomNavigationBar):
  ├── 대시보드     (계좌별 총자산, 수익률 요약)
  ├── 포트폴리오    (종목별 보유 현황, 실시간 시세)
  ├── 거래 내역    (매수/매도 기록, 추가/수정/삭제)
  ├── 기타 자산    (비주식 자산 관리)
  └── 설정        (계정, 데이터, 테마, 계좌)
```

### 7.2 로그인 화면
- Google Sign-In 버튼
- 앱 로고/타이틀

### 7.3 스프레드시트 연결 화면
- "새 스프레드시트 생성" 버튼
- "기존 스프레드시트 연결" 버튼 (Google Picker 실행)
- 이미 localStorage에 ID가 있으면 자동 스킵

### 7.4 대시보드
**상단: Total Asset Card**
- 전체 평가금액 (KRW, USD) — 주식 + 기타 자산 합계
- 전체 매입가 (KRW)
- 전체 수익 (KRW), 수익률 (%)
- 일간 변동액 (KRW), 변동률 (%)

**메타 정보**
- 현재 환율 (1 USD = ₩XXXXX)
- 마지막 업데이트 시간

**BY ACCOUNT 섹션**
- 각 계좌별 카드: 계좌명, 평가금액, 수익, 수익률
- 자산분류별 breakdown (미국/한국/기타)

### 7.5 포트폴리오
**필터**: 계좌 (전체/개별), 자산분류 (전체/미국/한국/기타)

**모바일**: 종목별 카드 (종목명, 현재가, 수익, 평단가, 수량, 평가금액, 매입환율)
**PC**: 테이블 레이아웃

### 7.6 거래 내역
**필터**: 자산분류, 계좌, 거래유형 (전체/매수/매도)

- 월별 그룹화
- 각 거래 카드 (종목명, 유형, 수량, 가격, 날짜)
- 매도 시: 당시 평단가/실현수익 표시

**거래 추가 모달**:
- 종목 검색 (자동완성 → Yahoo Search API → 종목코드/거래소/종목명 자동 입력)
- 거래유형 (매수/매도)
- 계좌 선택
- 수량, 가격, 환율, 날짜, 메모
- Sheets API로 Transactions 시트에 행 추가
- 새 종목이면 Prices 시트에 GOOGLEFINANCE 수식 행 자동 추가 (거래 추가 직후)

**거래 편집 모달**:
- 기존 거래 수정/삭제
- Sheets API로 해당 행 업데이트/삭제

**Prices 시트 종목 관리**:
- 새 종목 판별: Prices 시트에 해당 ticker가 없으면 수식 행 자동 추가
- 종목 삭제(모든 보유량 매도 완료) 시: Prices 행은 유지 (재매수 시 재활용, 시트 용량 무시 가능)

### 7.7 기타 자산
**필터**: 계좌 (전체/개별)

- 합계 (KRW)
- 자산별 카드 (자산명, 카테고리 배지, 통화, 금액)
- 대출은 음수 표시

**추가/편집 모달**:
- 계좌, 유형 (예금/채권/대출/현금/기타), 자산명, 통화, 금액, 메모

### 7.8 설정
```
👤 계정
   user@gmail.com (Google 프로필)
   🚪 로그아웃

📊 데이터
   연결된 시트: Portfolio DB ✅
   📥 CSV 내보내기
   📂 다른 스프레드시트 연결

🔧 시세
   시세 수식 재생성 (GOOGLEFINANCE 수식 복구)

🎨 테마
   강조색 선택 (6개 프리셋: Teal, Blue, Purple, Green, Orange, Rose)

🔄 새로고침
   자동 새로고침 간격 (30초, 1분, 5분, 15분)

👥 계좌 관리
   계좌 추가/제거
```

---

## 8. Data Sync & Loading

### 앱 시작 시 로딩 순서
1. Google Sign-In 확인 (토큰 유효성)
2. localStorage에서 스프레드시트 ID 로드
3. `spreadsheets.values.batchGet`으로 4개 시트 한 번에 읽기 (API 호출 1회)
   - `Transactions!A:L`
   - `Prices!A:H`
   - `OtherAssets!A:H`
   - `Settings!A:B`
4. Holdings Replay 실행
5. UI 렌더링

### 데이터 변경 시
- 거래 추가/수정/삭제 → Sheets API 즉시 호출 → 로컬 상태 갱신
- 별도 "저장" 버튼 없음 (자동 저장)

### 시세 갱신
- Settings의 refresh_interval 간격으로 Prices 시트 폴링 (Prices 시트만 읽기)
- Pull-to-refresh로 수동 갱신
- GOOGLEFINANCE가 시트 내에서 자동 갱신하므로, 앱은 읽기만 하면 됨

### 로딩 상태
- 초기 로딩: 전체 화면 스피너
- 시세 갱신: 인라인 로딩 표시
- API 실패: 에러 메시지 + 재시도 버튼

---

## 9. UI Design System

### Material Design 3 기반
- Flutter 기본 Material 위젯 최대 활용
- 커스텀 스타일링 최소화

### Color System
```dart
// 강조색 (Settings 시트에서 로드, 기본값 Teal)
accentColor: #0D6E6E

// 프리셋
Teal: #0D6E6E
Blue: #2563EB
Purple: #7C3AED
Green: #16A34A
Orange: #EA580C
Rose: #E11D48

// 수익/손실
positive: #16A34A (green)
negative: #E07B54 (red-orange)

// 계좌 색상 (동적 배열, 순환)
accountColors: [#0D6E6E, #E07B54, #5B7FD6, #9333EA, #DC2626, #CA8A04]
```

### Responsive
- 모바일 (<640px): 카드 레이아웃, 하단 탭
- PC (>=640px): 테이블 레이아웃, 넓은 카드

---

## 10. Project Structure

```
portfolio-flutter/                    # 새 Flutter 프로젝트
├── lib/
│   ├── main.dart                    # 앱 엔트리포인트
│   ├── app.dart                     # MaterialApp, 라우팅, 테마
│   │
│   ├── models/                      # 데이터 모델
│   │   ├── transaction.dart
│   │   ├── holding.dart
│   │   ├── stock_quote.dart
│   │   ├── other_asset.dart
│   │   └── settings.dart
│   │
│   ├── services/                    # 외부 서비스 통신
│   │   ├── auth_service.dart        # Google Sign-In
│   │   ├── sheets_service.dart      # Google Sheets API CRUD (batchGet/update)
│   │   ├── picker_service.dart      # Google Picker API (스프레드시트 선택)
│   │   ├── search_service.dart      # 종목 검색 (CORS 프록시)
│   │   └── price_service.dart       # Prices 시트 읽기 + 수식 행 관리
│   │
│   ├── engine/                      # 계산 엔진
│   │   ├── holdings_engine.dart     # 거래 → 보유자산 계산
│   │   └── calculations.dart        # 수익/수익률/평가금액
│   │
│   ├── providers/                   # 상태 관리 (Riverpod)
│   │   ├── auth_provider.dart
│   │   ├── portfolio_provider.dart  # transactions, holdings, quotes
│   │   └── settings_provider.dart
│   │
│   ├── screens/                     # 화면
│   │   ├── login_screen.dart
│   │   ├── sheet_connect_screen.dart
│   │   ├── dashboard_screen.dart
│   │   ├── portfolio_screen.dart
│   │   ├── history_screen.dart
│   │   ├── other_assets_screen.dart
│   │   └── settings_screen.dart
│   │
│   ├── widgets/                     # 재사용 컴포넌트
│   │   ├── total_asset_card.dart
│   │   ├── account_card.dart
│   │   ├── holding_card.dart
│   │   ├── holding_row.dart
│   │   ├── transaction_card.dart
│   │   ├── filter_tabs.dart
│   │   ├── filter_chips.dart
│   │   ├── stock_search_field.dart  # 종목 검색 자동완성
│   │   ├── add_transaction_modal.dart
│   │   ├── add_other_asset_modal.dart
│   │   ├── color_picker.dart
│   │   └── account_manager.dart
│   │
│   └── utils/
│       ├── format.dart              # KRW/USD/날짜 포맷
│       └── constants.dart           # 색상, 기본값
│
├── web/
│   ├── index.html                   # PWA 설정
│   ├── manifest.json                # PWA manifest
│   └── favicon.png
│
├── test/                            # 테스트
│   ├── engine/
│   │   ├── holdings_engine_test.dart
│   │   └── calculations_test.dart
│   └── services/
│       └── sheets_service_test.dart
│
├── pubspec.yaml
└── README.md
```

---

## 11. CORS Proxy Changes

기존 `portfolio-cors-proxy` Cloudflare Worker에 검색 엔드포인트 추가:

```
기존: /quote?symbols=TSLA,AAPL    → Yahoo Finance Quote (앱에서 더 이상 미사용)
추가: /search?q={query}           → Yahoo Finance Search API
```

시세 조회 엔드포인트는 제거하지 않고 유지 (하위 호환).

---

## 12. Migration Strategy

### 기존 앱 데이터 → Google Sheets

기존 JSON 데이터를 가진 사용자를 위한 마이그레이션:
1. 기존 앱에서 JSON 내보내기
2. 새 Flutter 앱에서 "기존 데이터 가져오기" 기능 (1회성)
3. JSON 파싱:
   - `assetClass === 'cash'`인 transactions → OtherAssets 시트로 이전
   - 나머지 transactions → Transactions 시트에 행 삽입
4. Prices 시트에 GOOGLEFINANCE 수식 자동 생성

### 구현 우선순위

**Phase 1: Core**
- 프로젝트 세팅 (Flutter Web + PWA)
- Google Sign-In
- Sheets 연결/생성 (Google Picker API 포함)
- Transactions CRUD
- Holdings 계산 엔진
- Prices 시트 (GOOGLEFINANCE)
- 대시보드, 포트폴리오 화면

**Phase 2: Full Feature**
- 거래 내역 화면 (필터, 월별 그룹)
- 기타 자산 화면
- 종목 검색 자동완성 (CORS 프록시)
- 설정 화면 (테마, 계좌 관리, CSV 내보내기)

**Phase 3: Polish**
- PWA 최적화 (오프라인, 아이콘)
- 반응형 레이아웃 (PC/모바일)
- JSON 마이그레이션 도구
- GitHub Pages 배포 설정

---

## 13. Constraints & Risks

| Risk | Mitigation |
|------|-----------|
| GOOGLEFINANCE 한국 주식 불안정 | 에러 감지 → "시세 없음" 표시 + 수동 가격 입력 fallback |
| GOOGLEFINANCE 캐시 (시트 미열람 시) | UI에 "마지막 API 호출 시간" 표시, 수동 갱신 버튼 |
| Sheets API 할당량 (분당 60요청) | 개인 사용이므로 충분. batchGet으로 요청 최소화 (초기 로드 1회) |
| Yahoo Search API 변경 | CORS 프록시 수정으로 대응 (드묾) |
| Google OAuth 토큰 만료 | google_sign_in 패키지 자동 갱신 |
| 동시 편집 충돌 | 행 추가는 충돌 없음. 편집/삭제는 last-write-wins (Google Sheets 기본 동작) |
| 환율 GOOGLEFINANCE 실패 | 하드코딩 fallback 1,450원 + UI 경고 |

---

## 14. Out of Scope

- iOS/Android 네이티브 빌드 (추후 확장 가능)
- 실시간 알림/푸시
- 자동 거래 연동 (증권사 API)
- 차트/그래프 (추후 확장 가능)
- 다크 모드 (추후 확장 가능)
