# Phase 2 Design Spec — Flutter Portfolio App

## Overview

Phase 1에서 완성된 대시보드/포트폴리오 화면 위에, 거래내역/기타자산/설정 화면과 PC 반응형 레이아웃을 추가한다.

## Scope

- 화면 3개: 거래내역(History), 기타자산(Assets), 설정(Settings)
- 모달 4개: 거래 추가(개선), 거래 편집, 자산 추가, 자산 편집
- 확인 모달 3개: 계정 삭제 (차단/확인), 거래 삭제 확인
- PC 반응형 레이아웃 (breakpoint 768px)
- 종목 검색 자동완성 위젯
- 포트폴리오 화면 +추가 버튼 제거
- 필터 디자인 세그먼트 컨트롤로 통일
- ID 기반 CRUD (rowIndex 폐기)

## Out of Scope

- Google Picker API (Phase 3)
- 다크 모드
- i18n/다국어

---

## 0. ID-Based CRUD (기술 부채 해소)

### 배경

Phase 1의 Transaction/OtherAsset CRUD는 로컬 리스트의 rowIndex에 의존한다. 필터 적용 시 index 불일치, 연속 삭제 시 index 밀림 등의 문제가 잠재되어 있다.

### 변경

- `updateTransaction(Transaction tx, int rowIndex)` → `updateTransaction(Transaction tx)`
- `deleteTransaction(int rowIndex)` → `deleteTransaction(String id)`
- OtherAsset CRUD도 동일하게 ID 기반으로 설계
- **구현 방식**: 수정/삭제 전 Sheets에서 전체 행을 읽어 ID로 대상 행을 찾은 뒤 작업 수행
- 또는 loadAll 후 로컬 리스트에서 ID로 index를 역산하여 Sheets API 호출

### 영향 범위

- `SheetsService`: update/delete 메서드 시그니처 변경
- `PortfolioNotifier`: 동일 변경
- 거래 편집/삭제 모달: Transaction.id 전달
- 자산 편집/삭제 모달: OtherAsset.id 전달

---

## 1. Responsive Shell

### 구조

- **< 768px (모바일)**: 기존 `CustomTabBar` (하단 pill 탭) + `IndexedStack`
- **>= 768px (PC)**: 좌측 사이드바 (240px) + Content 영역, 탭바 숨김

### 사이드바 (PC)

- 배경: #FFFFFF, 우측 border 1px #E5E5E5
- 상단: Portfolio 로고 + 아이콘
- 네비게이션: 대시보드 / 포트폴리오 / 거래내역 / 기타 자산 / 설정
- 활성 항목: #0D6E6E 배경 + 흰 텍스트
- pen 디자인 노드 참조: `ANSBN/LXHNQ` (PC - History 사이드바)

### 상태 공유

- `ResponsiveShell`은 `currentIndex`를 관리하고 callback으로 사이드바/탭바에 전달
- 기존 `MainApp`의 `_currentIndex` 로직을 `ResponsiveShell`로 이동

### 파일

- `lib/widgets/responsive_shell.dart` — breakpoint 판별 + 사이드바/탭바 분기
- `lib/widgets/sidebar.dart` — PC 사이드바 위젯
- `lib/app.dart` 수정 — `ResponsiveShell`로 감싸기

---

## 2. History Screen (거래내역)

### pen 디자인 참조

- 모바일: `RC3oh`, PC: `ANSBN`
- 거래 추가 모달: `JSPW8`, 거래 편집 모달: `AF52o`

### 레이아웃

- **Header**: "거래내역" 타이틀 (Newsreader, 40px) + [추가] 버튼 (teal pill)
- **3단 필터** (세그먼트 컨트롤, #F0F0F0 배경, cornerRadius 8):
  - 자산클래스: 전체 / 미국 / 한국
  - 명의: 전체 / {settings.accounts}
  - 유형: 전체 / 매수 / 매도
- **월별 그룹**: 날짜 역순 정렬, "YYYY년 MM월" 라벨 (JetBrains Mono, 11px, #888, letterSpacing 2)
- **TransactionCard**: 거래 타입 태그 + 종목명 + 시장태그 / 수량·단가·환율 / 날짜 + 총액

### 필터 로직

- 자산클래스: 미국 → Market.us, 한국 → Market.krx + Market.kosdaq
- 명의: account 필드 매칭
- 유형: 매수 → buy + openingBalance + adjustment, 매도 → sell
- AND 조합

### 상태 처리

- **로딩**: `isLoading && transactions.isEmpty` → 중앙 스피너 (DashboardScreen 패턴)
- **빈 상태**: 필터 결과 0건 → "거래내역이 없습니다" 메시지
- **에러**: `error != null` → 에러 메시지 + 재시도 버튼

### 인터랙션

- TransactionCard 탭 → 거래 편집 모달 (Transaction.id 전달)
- [추가] 탭 → 거래 추가 모달

### 거래 추가 모달 (기존 AddTransactionModal 리팩토링)

- pen 디자인 `JSPW8` 기준
- `BaseModal` 래퍼 적용
- 필드 순서 (pen 디자인 기준): 자산유형(미국/한국) → 명의 → 종목코드(자동완성) → 거래유형(매수/매도) → 수량 → 체결가 → 환율 → 날짜 → 메모
- 종목 검색 자동완성 위젯 통합
- 하단: [거래 추가] 버튼 (teal, full-width)

### 거래 편집 모달

- pen 디자인 `AF52o` 기준
- `BaseModal` 래퍼 적용
- 기존 데이터 프리필 (종목명도 표시)
- 필드: 종목코드+종목명(readonly) → 거래유형 → 명의 → 수량 → 가격 → 환율 → 날짜 → 메모
- 하단: [삭제] 버튼 (#E07B54 계열) + [저장] 버튼 (teal)
- **삭제 시**: 확인 모달 표시 ("이 거래를 삭제하시겠습니까?") → 확인 후 ID 기반 삭제

### 파일

- `lib/screens/history_screen.dart`
- `lib/widgets/transaction_card.dart` (신규)
- `lib/widgets/add_transaction_modal.dart` (기존 리팩토링, BaseModal 적용)
- `lib/widgets/edit_transaction_modal.dart` (신규)
- `lib/widgets/transaction_delete_modal.dart` (신규)

---

## 3. Assets Screen (기타자산)

### pen 디자인 참조

- 모바일: `Gw4xU`, PC: `0Ywgs`
- 자산 추가 모달: `oe2p6`, 자산 편집 모달: `RqIs8`

### 레이아웃

- **Header**: "기타 자산" 타이틀 (Newsreader, 40px) + [추가] 버튼 (teal pill)
- **필터** (세그먼트 컨트롤): 전체 / {settings.accounts}
- **합계 행**: "합계" + 필터된 총액 (대출은 음수 합산)
- **AssetCard 리스트**: 자산명 / 명의·카테고리·통화 태그 / 금액

### AssetCard

- 자산명 (볼드)
- 태그 행: 명의(teal) + 카테고리(예금/채권/대출/기타) + 통화(KRW/USD)
- 우측: 금액 표시, 대출(loan)은 빨간색 음수
- 탭 → 자산 편집 모달 (OtherAsset.id 전달)

### 상태 처리

- **로딩**: `isLoading && otherAssets.isEmpty` → 중앙 스피너
- **빈 상태**: 필터 결과 0건 → "기타 자산이 없습니다" 메시지
- **에러**: 에러 메시지 + 재시도 버튼

### 자산 추가 모달

- pen 디자인 `oe2p6` 기준
- `BaseModal` 래퍼 적용
- 필드: 명의 chip → 자산유형 chip (예금/채권/대출/기타) → 자산명 → 금액(KRW) → 통화(KRW/USD) → 메모
- 카테고리 매핑: 예금→savings, 채권→bond, 대출→loan, 기타→other (cash는 other에 통합)
- 하단: [추가] 버튼 (teal, full-width)

### 자산 편집 모달

- pen 디자인 `RqIs8` 기준
- `BaseModal` 래퍼 적용
- 기존 데이터 프리필
- 하단: [삭제] + [저장]
- 삭제 시 즉시 삭제 (거래와 달리 연쇄 영향 없음)

### Sheets 연동

- `PortfolioNotifier`에 추가:
  - `addOtherAsset(asset)` → SheetsService.addOtherAsset + 로컬 상태 업데이트
  - `updateOtherAsset(asset)` → ID로 행 찾기 → 수정 + 로컬 업데이트
  - `deleteOtherAsset(id)` → ID로 행 찾기 → 삭제 + 로컬 업데이트
- `SheetsService`에 OtherAssets CRUD 메서드 추가 (ID 기반)

### 파일

- `lib/screens/assets_screen.dart`
- `lib/widgets/asset_card.dart` (신규)
- `lib/widgets/add_asset_modal.dart` (신규, BaseModal 적용)
- `lib/widgets/edit_asset_modal.dart` (신규, BaseModal 적용)

---

## 4. Settings Screen (설정)

### pen 디자인 참조

- 모바일: `RiACv`, PC: `AOXtJ`
- 계정 삭제 모달: `dI6Ak` (차단), `pCN2B` (확인)

### 레이아웃

- **타이틀**: "설정" (Newsreader, 40px)
- **ACCOUNT 섹션**: Google 프로필 (아바타 + 이메일 + 연결 상태) + 로그아웃 링크
- **ACCOUNTS 섹션**: 명의 목록 (편집 아이콘) + 새 명의 입력 + [추가] 버튼
- **APPEARANCE 섹션**: 강조 색상 6개 프리셋 원형 버튼
- **DATA REFRESH 섹션**: 자동 새로고침 간격 드롭다운 (5분/10분/15분/30분/60분)
- **DATA & SHEETS 섹션** (모바일+PC 모두):
  - CSV 내보내기 버튼
  - 연결된 시트 표시 + [변경] 버튼

### 섹션 스타일

- 섹션 라벨: 대문자 영문, JetBrains Mono, 11px, #888, letterSpacing 2
- 카드: 흰 배경 #FFFFFF, cornerRadius 12, border 1px #E5E5E5
- 섹션 간 gap: 32px

### 명의 관리 로직

- **추가**: 입력 필드 + [추가] 버튼 → settings.accounts에 append → Sheets 저장
- **삭제**: 명의 탭 시:
  - 해당 명의의 거래내역 존재 여부 확인
  - 있으면 → 차단 모달 (`dI6Ak`): "N건의 거래내역이 있어 삭제할 수 없습니다"
  - 없으면 → 확인 모달 (`pCN2B`): "삭제하시겠습니까?" + [취소]/[삭제] 버튼

### 강조 색상

- 프리셋: #0D6E6E(Teal), #2563EB(Blue), #7C3AED(Purple), #059669(Green), #EA580C(Orange), #E11D48(Rose)
- 선택 시 `settings.accentColor` 업데이트 → 앱 전체 반영 → Sheets 저장
- **반영 메커니즘**: `app.dart`의 `PortfolioApp`이 `portfolioProvider.settings.accentColor`를 watch → `ThemeData`의 primary color에 동적 주입

### 자동 새로고침

- 드롭다운 값: 5분/10분/15분/30분/60분 (UI 표시)
- 저장 단위: 초 (300/600/900/1800/3600) — 기존 `AppSettings.refreshInterval` 단위 유지
- 변경 시 `PortfolioNotifier._startRefreshTimer()` 재호출하여 Timer 재시작

### updateSettings 구현

- `PortfolioNotifier.updateSettings(AppSettings)`:
  1. `state.settings` 업데이트 (로컬)
  2. `SheetsService.saveSettings()` 호출 (원격)
  3. `refreshInterval` 변경 시 → Timer 재시작
  4. `accentColor` 변경 시 → state 업데이트만 (app.dart에서 watch)

### 시트 변경

- [변경] 탭 → `SheetConnectScreen`으로 네비게이션 (기존 화면 재활용)
- 연결 완료 시 spreadsheetId 교체 → 로딩 인디케이터 표시 → 전체 데이터 리로드 → 완료 후 설정 화면 복귀

### CSV 내보내기

- **대상**: Transaction 전체 필드 (id, date, account, type, ticker, market, name, shares, price, currency, exchangeRate, memo)
- **인코딩**: UTF-8 BOM (한글 종목명 호환)
- **파일명**: `portfolio_YYYYMMDD.csv`
- **구현**: Flutter Web — Blob + URL.createObjectURL로 다운로드 트리거

### 파일

- `lib/screens/settings_screen.dart`
- `lib/widgets/account_delete_modal.dart` (신규)

---

## 5. Ticker Search Autocomplete (종목 검색 자동완성)

### 위젯

- 독립 위젯 `TickerSearch`
- 텍스트 입력 필드 + 드롭다운 오버레이

### 동작

1. 2글자 이상 입력 시 300ms debounce
2. CORS 프록시 `GET /search?q={query}` 호출
3. 결과 리스트: ticker / name / exchange
4. 항목 선택 시 콜백: `onSelected(ticker, name, market, currency)`

### 적용

- 거래 추가 모달: 종목코드 필드 교체
- 거래 편집 모달: 종목코드 필드 (readonly이므로 자동완성 비활성)

### 에러 처리

- 네트워크 실패 시: 자동완성 드롭다운 숨김, 수동 입력 가능 상태 유지
- CORS 프록시 타임아웃: 3초 후 자동 취소

### 파일

- `lib/widgets/ticker_search.dart`

---

## 6. Shared Widgets (공통 위젯)

### SegmentedFilter (기존 FilterTabs 리네이밍 + 통합)

- 기존 `lib/widgets/filter_tabs.dart` → `lib/widgets/segmented_filter.dart`로 리네이밍
- Props: `items: List<String>`, `selected: String`, `onChanged: Function`
- 스타일: 배경 #F0F0F0, cornerRadius 8, padding 4, gap 4
- 활성: #FFFFFF 배경 + shadow, 비활성: transparent
- 기존 PortfolioScreen 사용처도 함께 업데이트

### BaseModal

- 모달 공통 래퍼 — 모든 모달에 적용
- 배경 딤 + 흰 카드 (cornerRadius 20, padding 24)
- Header: 타이틀 + X 닫기 버튼
- 기존 `AddTransactionModal` 리팩토링 시 BaseModal 적용

### 파일

- `lib/widgets/segmented_filter.dart` (FilterTabs 리네이밍)
- `lib/widgets/base_modal.dart` (신규)

---

## 7. Provider / Service Changes

### PortfolioNotifier 추가 메서드

```
addOtherAsset(OtherAsset) → void
updateOtherAsset(OtherAsset) → void        // ID 기반
deleteOtherAsset(String id) → void          // ID 기반
updateSettings(AppSettings) → void          // Timer 재시작 포함
```

### PortfolioNotifier 기존 메서드 변경

```
updateTransaction(Transaction tx) → void    // ID 기반 (rowIndex 제거)
deleteTransaction(String id) → void         // ID 기반 (rowIndex 제거)
```

### SheetsService 추가 메서드

```
addOtherAsset(OtherAsset) → void
updateOtherAsset(OtherAsset) → void         // ID로 행 찾기
deleteOtherAsset(String id) → void          // ID로 행 찾기
findRowById(String sheetName, String id) → int  // 공통: ID로 행 번호 조회
```

### SheetsService 기존 메서드 변경

```
updateTransaction(Transaction tx) → void    // ID 기반
deleteTransaction(String id) → void         // ID 기반
```

### 에러 처리 패턴

- API 호출 성공 후 로컬 상태 업데이트 (기존 패턴 유지)
- API 실패 시: 모달 유지 + SnackBar로 에러 메시지 표시
- 전 화면 동일 패턴 적용

---

## 8. File Structure (신규/변경)

```
lib/
├── app.dart                          ← 수정: ResponsiveShell 적용, 동적 theme
├── widgets/
│   ├── responsive_shell.dart         ← 신규
│   ├── sidebar.dart                  ← 신규
│   ├── base_modal.dart               ← 신규
│   ├── segmented_filter.dart         ← FilterTabs 리네이밍
│   ├── ticker_search.dart            ← 신규
│   ├── transaction_card.dart         ← 신규
│   ├── asset_card.dart               ← 신규
│   ├── add_transaction_modal.dart    ← 리팩토링 (BaseModal 적용)
│   ├── edit_transaction_modal.dart   ← 신규
│   ├── transaction_delete_modal.dart ← 신규
│   ├── add_asset_modal.dart          ← 신규
│   ├── edit_asset_modal.dart         ← 신규
│   ├── account_delete_modal.dart     ← 신규
│   ├── filter_tabs.dart              ← 삭제 (segmented_filter로 대체)
│   └── (기존 위젯 유지)
├── screens/
│   ├── history_screen.dart           ← 신규
│   ├── assets_screen.dart            ← 신규
│   ├── settings_screen.dart          ← 신규
│   └── portfolio_screen.dart         ← 수정: +추가 버튼 제거, SegmentedFilter 적용
├── providers/
│   └── portfolio_provider.dart       ← 수정: OtherAsset CRUD, updateSettings, ID 기반 CRUD
├── services/
│   └── sheets_service.dart           ← 수정: OtherAsset CRUD, findRowById, ID 기반 CRUD
```

---

## 9. Implementation Order

1. **공통 기반**: ResponsiveShell, Sidebar, BaseModal, SegmentedFilter(리네이밍), ID 기반 CRUD 전환 + 테스트
2. **거래내역 + 자동완성**: HistoryScreen + TransactionCard + TickerSearch + AddTransactionModal(리팩토링) + EditTransactionModal + TransactionDeleteModal + 테스트
3. **기타자산**: AssetsScreen + AssetCard + AddAssetModal + EditAssetModal + SheetsService OtherAsset CRUD + 테스트
4. **설정**: SettingsScreen + AccountDeleteModal + updateSettings + 동적 theme + CSV 내보내기 + 시트 변경 + 테스트

---

## 10. Testing Strategy

- 계산 엔진: 기존 22개 테스트 유지
- ID 기반 CRUD: findRowById, update/delete by ID 테스트
- 필터 로직: 거래내역 3단 필터 조합 테스트 (자산클래스/명의/유형)
- OtherAsset CRUD: 추가/수정/삭제 + 합계 계산
- 설정: 명의 추가/삭제 로직, 삭제 차단 조건, refreshInterval 변환
- 자동완성: debounce, 검색 결과 파싱, 네트워크 실패 시 fallback
- 위젯 테스트: 각 화면 렌더링 + 인터랙션
