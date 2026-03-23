# UI Overhaul: pen 디자인 기반 Flutter UI 재구현

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** pen 파일의 디자인을 Flutter에 **그대로** 재현한다. Material 3 기본 위젯을 제거하고 커스텀 UI로 교체.

**Design reference:** `portfolio-app/financial-app-design.pen`

**폰트:** 시스템 기본 (커스텀 폰트 없음). pen 파일의 Newsreader/JetBrains Mono/Inter는 무시.

---

## 디자인 시스템 핵심 (pen 파일 기준)

### 색상
- Background: `#FAFAFA`
- Card: `#FFFFFF`, border `#E5E5E5`, cornerRadius 12
- Text primary: `#1A1A1A`
- Text secondary: `#888888`
- Text muted: `#AAAAAA`
- Divider: `#F0F0F0`
- Accent (teal): `#0D6E6E`
- Positive: `#0D6E6E` (수익), badge background `#E8F5E9`
- Negative: `#E07B54` (손실)
- Input background: `#F8F8F8`

### 탭바 (모든 화면 공통)
- Pill 스타일: 흰색 배경, cornerRadius 36, border #E5E5E5, shadow
- 활성 탭: teal 배경(#0D6E6E), 흰색 아이콘/텍스트, cornerRadius 26
- 비활성 탭: 아이콘/텍스트 #AAAAAA
- 탭: HOME, PORTFOLIO, HISTORY, ASSETS, SETTINGS
- 아이콘: lucide (house, chart-bar, clock-3, wallet, settings)
- 폰트 크기 10, letterSpacing 0.5

### 헤더
- 타이틀: fontSize 40, fontWeight 500 (큰 서체)
- 우측 아이콘/버튼

### 필터 (포트폴리오 화면)
- 세그먼트 스타일: 배경 #F0F0F0, cornerRadius 8, padding 4
- 활성 탭: 흰색 배경, shadow, fontWeight 600
- 비활성: fontWeight 500, 색상 #888888

### 필터 (거래내역 화면)
- Chip 스타일: cornerRadius 20, padding [6,14]
- 활성: teal 배경(#0D6E6E), 흰색 텍스트
- 비활성: #F0F0F0 배경, #666666 텍스트

### 카드 공통
- 배경 #FFFFFF, cornerRadius 12, padding 16, border #E5E5E5

### 섹션 라벨
- fontSize 11, fontWeight 600, letterSpacing 2, 색상 #888888, 대문자

---

### Task 1: 앱 테마 + 커스텀 탭바

**Files:**
- Modify: `lib/app.dart`
- Create: `lib/widgets/custom_tab_bar.dart`

- [ ] **Step 1: custom_tab_bar.dart 작성**

커스텀 pill 스타일 탭바. pen 디자인 그대로:
- 외곽: 흰색, cornerRadius 36, border #E5E5E5, shadow (blur 12, color #00000014, offset y:2)
- 내부 padding 4
- 5개 탭 (HOME/PORTFOLIO/HISTORY/ASSETS/SETTINGS)
- 활성: teal 배경, cornerRadius 26, 아이콘+텍스트 흰색
- 비활성: 투명, 아이콘+텍스트 #AAAAAA
- 아이콘 크기 18, 텍스트 크기 10, letterSpacing 0.5

lucide 아이콘은 Flutter Icons로 대체:
- house → Icons.home_outlined
- chart-bar → Icons.bar_chart
- clock-3 → Icons.schedule
- wallet → Icons.account_balance_wallet_outlined
- settings → Icons.settings_outlined

- [ ] **Step 2: app.dart 테마 + NavigationBar 교체**

MaterialApp 테마를 pen 디자인 색상으로:
- scaffoldBackgroundColor: #FAFAFA
- cardTheme: color #FFFFFF, elevation 0, shape cornerRadius 12 + border #E5E5E5

MainApp에서 NavigationBar를 CustomTabBar로 교체.

- [ ] **Step 3: 빌드 확인 + 커밋**

---

### Task 2: 대시보드 화면 재디자인

**Files:**
- Modify: `lib/screens/dashboard_screen.dart`
- Modify: `lib/widgets/total_asset_card.dart`
- Modify: `lib/widgets/account_card.dart`

- [ ] **Step 1: total_asset_card.dart 재작성**

pen 디자인 기준:
- "TOTAL ASSETS" 라벨: fontSize 11, fontWeight 600, letterSpacing 2, color #888888
- 총자산 금액: fontSize 32, fontWeight 700, color #1A1A1A
- 수익 배지: 초록 배경(#E8F5E9), cornerRadius 4, padding [4,8], 아이콘(trending-up) + 금액
- 수익률: fontSize 12, fontWeight 600, color #0D6E6E or #E07B54
- 카드: cornerRadius 12, padding 20, border #E5E5E5

- [ ] **Step 2: account_card.dart 재작성**

pen 디자인 기준:
- 상단: 좌측 (컬러닷 + 계좌명), 우측 (수익률)
- 하단: 좌측 (원화 금액, fontSize 18, fontWeight 700), 우측 (달러 금액, fontSize 12, #888888)
- 카드: cornerRadius 12, padding 16, border #E5E5E5

- [ ] **Step 3: dashboard_screen.dart 헤더 재작성**

pen 디자인 기준:
- 타이틀 "자산 현황": fontSize 40, fontWeight 500
- 새로고침 아이콘: Icons.refresh, color #888888, size 22
- Meta Row: 환율 아이콘(Icons.attach_money) + "USD/KRW ₩1,505.32" / "12:34 업데이트"
- "BY ACCOUNT" 섹션 라벨: fontSize 11, fontWeight 600, letterSpacing 2, color #888888
- Content padding: [0, 24, 24, 24], gap 32

- [ ] **Step 4: 빌드 확인 + 커밋**

---

### Task 3: 포트폴리오 화면 재디자인

**Files:**
- Modify: `lib/screens/portfolio_screen.dart`
- Modify: `lib/widgets/holding_card.dart`
- Modify: `lib/widgets/filter_tabs.dart`

- [ ] **Step 1: filter_tabs.dart 재작성**

pen 디자인의 세그먼트 스타일:
- 컨테이너: 배경 #F0F0F0, cornerRadius 8, padding 4
- 활성 탭: 흰색 배경, cornerRadius 6, shadow (blur 2, color #00000010, offset y:1), fontWeight 600, color #1A1A1A
- 비활성: 투명, fontWeight 500, color #888888
- 각 탭 padding [8, 0], 균등 너비

- [ ] **Step 2: holding_card.dart 재작성**

pen 디자인 기준 (좌/우 분리 레이아웃):
- 좌측 상단: 티커(fontWeight 700) + 명의 배지(cornerRadius 4, teal 배경, 흰색 텍스트, fontSize 10)
- 좌측 중간: 종목명 (fontSize 12, color #888888)
- 좌측 하단: "500주 · 평단 $318.01" (fontSize 10, color #AAAAAA)
- 우측 상단: 현재가 (fontSize 16, fontWeight 700)
- 우측 중간: 변동률 (fontSize 12, fontWeight 600, color에 따라 #0D6E6E or #E07B54)
- 우측 하단: 원화 평가금액 (fontSize 10, color #888888)
- 카드: cornerRadius 12, padding 16, border #E5E5E5

- [ ] **Step 3: portfolio_screen.dart 헤더 재작성**

- 타이틀 "포트폴리오": fontSize 40, fontWeight 500
- "+추가" 버튼: teal 배경, cornerRadius 8, padding [7,14], 흰색 텍스트
- FAB 제거 → 헤더에 추가 버튼으로 변경

- [ ] **Step 4: 빌드 확인 + 커밋**

---

### Task 4: 거래 추가 모달 재디자인

**Files:**
- Modify: `lib/widgets/add_transaction_modal.dart`

- [ ] **Step 1: 모달 재작성**

pen 디자인 기준:
- 상단: "종목 추가" 타이틀(fontSize 20, fontWeight 500) + "✕" 닫기 버튼
- 필드 라벨: fontSize 12, fontWeight 600, color #1A1A1A
- 자산유형 필터: chip 스타일 (cornerRadius 20, teal 활성, #F0F0F0 비활성)
- 명의 필터: chip 스타일
- 입력 필드: cornerRadius 8, border #E5E5E5, padding [12, 14], placeholder color #AAAAAA
- 거래유형: chip 스타일 (매수: teal, 매도: #F0F0F0)
- "거래 추가" 버튼: cornerRadius 10, fill #16A34A (green), padding 15, 흰색 텍스트
- 전체: Dialog 스타일 (cornerRadius 20, padding 24, maxWidth 560)

- [ ] **Step 2: 빌드 확인 + 커밋**

---

### Task 5: 빌드 검증

- [ ] **Step 1: flutter analyze**
- [ ] **Step 2: flutter test**
- [ ] **Step 3: flutter build web**
- [ ] **Step 4: 커밋**
