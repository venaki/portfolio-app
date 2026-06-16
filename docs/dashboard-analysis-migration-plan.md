# Dashboard Analysis Tabs Migration Plan

## Goal

대시보드 상단에 `현황 / 추이 / 비중` 탭을 추가한다.

- `현황`: 현재 대시보드 화면을 유지한다.
- `추이`: 총자산, 원금, 수익 추이를 선 그래프로 보여준다.
- `비중`: 종목별, 유형별, 계좌별 비중을 도넛 그래프로 보여준다.

추이 데이터는 `Snapshots` 시트를 기준으로 표시한다. 기존 과거 데이터가 없는 경우에는 거래내역과 과거 시세 조회를 이용해 최초 백필을 수행하고, 이후부터는 현재 자산 상태를 스냅샷으로 누적한다.

## Current State

현재 앱 데이터 구조:

- `Transactions`: 주식 거래내역
- `Prices`: 현재 시세와 환율
- `OtherAssets`: 예금, 채권, 대출, 기타 자산 내역
- `Settings`: 계좌, 증권사, 테마, 환율 등 설정

현재 대시보드 계산 방식:

- `DashboardScreen`에서 `PortfolioState`의 현재 거래내역, 보유 종목, 현재 시세, 기타 자산을 즉석 집계한다.
- 계좌별/유형별 집계는 현재 상태 기준으로만 계산한다.
- 과거 일별 평가금액 저장소는 없다.

따라서 `비중`은 현재 데이터만으로 바로 구현 가능하지만, `추이`는 새 저장 구조가 필요하다.

## UX Structure

### Dashboard Top-Level Tabs

대시보드 화면 최상단에 3개 탭을 둔다.

```text
[ 현황 ] [ 추이 ] [ 비중 ]
```

### Status Tab

기존 대시보드 화면을 그대로 유지한다.

구성:

- 새로고침 버튼
- 총 자산 카드
- 환율/업데이트 시간
- `By Account / By Type` 세그먼트
- 계좌별 카드 또는 유형별 카드

### Trend Tab

참고 이미지의 `추이` 화면을 앱 톤에 맞춰 적용한다.

구성:

- 총 투자 자산
- 선택 기간 대비 증가/감소 문장
- 원금
- 자산/원금 선 그래프
- 기간 필터

기간 필터:

```text
[ 올해 ] [ 1개월 ] [ 3개월 ] [ 6개월 ] [ 1년 ] [ 전체 ]
```

데이터가 부족한 경우:

```text
추이 데이터가 아직 부족해요.
지금부터 자동으로 기록을 시작합니다.
과거 거래내역을 기준으로 최근 1년 추이를 복원할 수 있어요.

[최근 1년 추이 복원]
```

### Allocation Tab

참고 이미지의 `비중` 화면을 앱 톤에 맞춰 적용한다.

구성:

- `종목별 / 유형별 / 계좌별` 세그먼트
- 선택된 대표 항목명
- 대표 항목 비중
- 대표 항목 평가액
- 도넛 그래프
- 비중 리스트

세그먼트:

```text
[ 종목별 ] [ 유형별 ] [ 계좌별 ]
```

비중 계산 정책:

- 기본 분모는 양수 자산 총액으로 한다.
- 대출은 음수 자산이므로 도넛 비중에서 제외한다.
- 대출은 별도 `부채` 섹션으로 표시한다.
- 1% 미만 항목은 MVP에서는 그대로 표시하고, 추후 `기타` 묶기 옵션을 검토한다.

## Sheet Migration

### New Sheet: Snapshots

추이 차트의 단일 조회원이다.

Header:

```text
id
date
totalValueKRW
totalCostKRW
profitKRW
profitPct
dailyChangeKRW
dailyChangePct
exchangeRate
source
createdAt
schemaVersion
```

Field policy:

- `id`: `snapshot-{date}` 또는 UUID
- `date`: `YYYY-MM-DD`
- `totalValueKRW`: 해당 날짜의 총 평가액
- `totalCostKRW`: 해당 날짜의 원금
- `profitKRW`: 평가액 - 원금
- `profitPct`: 원금 대비 수익률
- `dailyChangeKRW`: 전일 대비 변동액
- `dailyChangePct`: 전일 대비 변동률
- `exchangeRate`: 해당 계산에 사용한 원달러 환율
- `source`: `live`, `backfill`, `manual`
- `createdAt`: 생성 시각 ISO 문자열
- `schemaVersion`: 현재는 `1`

Unique key:

- `date + source`가 아니라 `date`를 기본 유니크 키로 본다.
- 같은 날짜의 스냅샷이 이미 있으면 최신 계산값으로 덮어쓴다.

### New Sheet: HistoricalPrices

백필 계산 캐시다. 추이 화면은 직접 이 시트를 읽지 않는다.

Header:

```text
date
ticker
market
currency
close
exchangeRate
source
createdAt
schemaVersion
```

Field policy:

- `date`: `YYYY-MM-DD`
- `ticker`: 앱 내부 티커
- `market`: `US`, `KRX`, `KOSDAQ`, `FX`
- `currency`: `USD` 또는 `KRW`
- `close`: 해당 날짜 종가
- `exchangeRate`: USD 종목의 KRW 환산에 사용할 환율
- `source`: `googlefinance`, `manual`, `cached`
- `createdAt`: 생성 시각 ISO 문자열
- `schemaVersion`: 현재는 `1`

Unique key:

- `date + ticker + market`

### Settings Migration

`Settings` 시트에 아래 키를 추가한다.

```text
snapshot_schema_version | 1
historical_price_schema_version | 1
last_snapshot_date |
last_backfill_at |
backfill_range |
```

정책:

- 기존 `Settings` 구조는 key-value 형태이므로 하위 호환성이 좋다.
- 없는 키는 앱 로드시 자동 추가한다.
- 기존 사용자의 시트는 `loadAll()` 시점에 마이그레이션한다.

## Data Calculation Policy

### Current Snapshot Calculation

현재 스냅샷은 기존 대시보드 총액 계산과 동일한 기준을 사용한다.

포함:

- 현재 보유 주식 평가액
- 기타 자산 평가액
- 예금, 채권, 기타 양수 자산
- 대출은 순자산에서 차감

원금:

- 주식은 `calcCostKRW()`
- 기타 자산은 현재 대시보드와 동일하게 평가액을 원금으로 본다.
- 대출은 음수로 반영한다.

### Backfill Calculation

백필은 날짜별로 거래내역을 재생해서 과거 보유 상태를 만든다.

절차:

1. 백필 대상 날짜 목록을 만든다.
2. 각 날짜까지의 `Transactions`를 재생해 보유 종목과 원금을 계산한다.
3. 각 날짜까지의 `OtherAssets`를 누적해 기타 자산을 계산한다.
4. 필요한 `ticker/date` 과거 종가를 `HistoricalPrices`에서 먼저 찾는다.
5. 캐시에 없으면 GoogleFinance 기반 조회로 채운다.
6. 날짜별 총 평가액, 원금, 수익을 계산한다.
7. `Snapshots`에 저장한다.

MVP 백필 범위:

- 최초는 최근 1년
- 샘플링은 주 1회 또는 월 1회부터 시작 가능
- 안정화 후 일별 백필로 확장한다.

### Exchange Rate Policy

USD 종목의 과거 평가액은 해당 날짜의 환율로 KRW 환산한다.

우선순위:

1. `HistoricalPrices`의 `FX/USDKRW` 캐시
2. GoogleFinance 과거 환율 조회
3. 실패 시 현재 환율 사용, 단 `source`나 경고 상태에 표시

## Implementation Order

### Phase 0: Preparation

- [ ] 차트 라이브러리 결정
- [ ] `fl_chart` 의존성 추가 여부 확정
- [ ] 기존 대시보드 계산 로직을 재사용 가능한 유틸/모델로 분리할 범위 확정

권장:

- `fl_chart`를 사용한다.
- 직접 `CustomPainter`로 차트를 그리는 것은 MVP 이후로 미룬다.

### Phase 1: Refactor Dashboard Aggregation

- [ ] 현재 `DashboardScreen` 안의 총액 계산을 별도 계산 유틸로 분리한다.
- [ ] 계좌별 집계 계산을 별도 함수로 분리한다.
- [ ] 유형별 집계 계산을 별도 함수로 분리한다.
- [ ] 비중 계산에서 재사용할 `AllocationItem` 모델을 만든다.
- [ ] 기존 `현황` 화면이 동일하게 보이는지 확인한다.

DoD:

- 기존 대시보드 수치가 변경되지 않는다.
- 기존 `By Account / By Type` 동작이 유지된다.

### Phase 2: Add Dashboard Inner Tabs

- [ ] `dashboardAnalysisTabProvider`를 추가한다.
- [ ] `현황 / 추이 / 비중` 세그먼트를 대시보드 상단에 추가한다.
- [ ] 기존 대시보드 본문을 `Status` 뷰로 감싼다.
- [ ] `Trend`와 `Allocation`은 임시 빈 상태로 연결한다.

DoD:

- 탭 전환이 가능하다.
- `현황` 탭에서 기존 화면이 유지된다.
- 모바일/데스크톱 레이아웃이 깨지지 않는다.

### Phase 3: Implement Allocation Tab

- [ ] 종목별 비중 데이터 생성
- [ ] 유형별 비중 데이터 생성
- [ ] 계좌별 비중 데이터 생성
- [ ] 도넛 차트 구현
- [ ] 비중 리스트 구현
- [ ] 리스트 항목 선택 시 차트/상단 대표 항목 동기화
- [ ] 대출은 부채 섹션으로 분리

DoD:

- 현재 데이터만으로 비중 탭이 정상 표시된다.
- 종목별/유형별/계좌별 전환이 가능하다.
- 음수 자산이 도넛 비중을 왜곡하지 않는다.
- 항목 합계가 100%에 근접한다.

### Phase 4: Add Snapshot Models and Service API

- [ ] `PortfolioSnapshot` 모델 추가
- [ ] `HistoricalPrice` 모델 추가
- [ ] `SheetsService.loadSnapshots()` 추가
- [ ] `SheetsService.upsertSnapshot()` 추가
- [ ] `SheetsService.loadHistoricalPrices()` 추가
- [ ] `SheetsService.upsertHistoricalPrices()` 추가
- [ ] 기존 시트에 `Snapshots`, `HistoricalPrices`가 없으면 생성하는 마이그레이션 추가
- [ ] `Settings` 마이그레이션 추가

DoD:

- 신규 사용자는 새 시트 구조로 생성된다.
- 기존 사용자는 앱 로드시 자동 마이그레이션된다.
- 마이그레이션은 중복 실행해도 안전하다.

### Phase 5: Current Snapshot Recording

- [ ] 현재 대시보드 계산 결과로 오늘 스냅샷을 생성한다.
- [ ] `loadAll()` 또는 `refreshPrices()` 이후 오늘 스냅샷을 upsert한다.
- [ ] 같은 날짜는 중복 append하지 않고 덮어쓴다.
- [ ] `last_snapshot_date`를 업데이트한다.

DoD:

- 앱 새로고침 후 `Snapshots`에 오늘 행이 생긴다.
- 하루 여러 번 새로고침해도 같은 날짜 행이 중복되지 않는다.
- 추이 탭이 `Snapshots`를 읽을 수 있다.

### Phase 6: Implement Trend Tab with Snapshots

- [ ] `Snapshots` 기반 선 그래프 구현
- [ ] 자산/원금 두 라인 표시
- [ ] 기간 필터 구현
- [ ] 선택 기간 시작점 대비 증가/감소 문장 표시
- [ ] 스냅샷 부족 상태 UI 구현

DoD:

- 스냅샷이 2개 이상이면 선 그래프가 표시된다.
- 스냅샷이 부족하면 백필 안내가 표시된다.
- 기간 필터에 따라 그래프와 요약 문구가 바뀐다.

### Phase 7: Historical Backfill MVP

- [ ] 최근 1년 백필 버튼 추가
- [ ] 백필 대상 날짜 생성
- [ ] 날짜별 거래내역 재생 로직 구현
- [ ] 날짜별 기타자산 누적 로직 구현
- [ ] 과거 시세 캐시 조회 구현
- [ ] 캐시 누락분 조회 구현
- [ ] `HistoricalPrices`에 캐시 저장
- [ ] 계산된 과거 스냅샷을 `Snapshots`에 저장
- [ ] 진행 중/성공/실패 상태 표시

DoD:

- 과거 스냅샷을 생성할 수 있다.
- 실패한 티커/날짜가 있으면 사용자에게 명확히 표시된다.
- 백필 후 추이 차트가 즉시 갱신된다.

### Phase 8: Hardening

- [ ] 거래내역 수정/삭제 후 백필 재생성 필요 상태 표시
- [ ] 백필 재실행 버튼 추가
- [ ] 과거 시세 조회 실패 fallback 정책 정리
- [ ] 대량 티커/장기간 데이터에서 성능 점검
- [ ] 모바일 차트 터치 영역 점검
- [ ] 데스크톱 폭에서 차트 최대 너비 점검

DoD:

- 데이터 수정 후 사용자가 추이 데이터 갱신 필요성을 알 수 있다.
- 네트워크/GoogleFinance 실패가 앱 전체 장애로 번지지 않는다.
- 작은 화면에서 텍스트와 차트가 겹치지 않는다.

## Technical Risks

### GoogleFinance Historical Data Reliability

GoogleFinance는 종목/시장/날짜에 따라 과거 데이터가 누락될 수 있다.

대응:

- `HistoricalPrices` 캐시를 둔다.
- 실패 항목을 명시적으로 기록한다.
- 백필은 수동 트리거로 시작한다.
- 최초 MVP는 최근 1년으로 제한한다.

### Korean Stock Historical Data

한국 주식은 `KRX:`와 `KOSDAQ:` 조회가 종목별로 다를 수 있다.

대응:

- 현재 `Prices` 시트의 한국 종목 처리 방식과 동일하게 `KRX` 우선, 실패 시 `KOSDAQ`을 시도한다.
- 실패한 티커는 백필 결과에 표시한다.

### Transaction Replay Accuracy

매도, 조정, 기초잔고 처리가 현재 `replayTransactions()`와 일치해야 한다.

대응:

- 백필도 동일한 엔진을 날짜별 subset에 적용한다.
- 별도 계산 로직을 만들지 않는다.

### Sheet Migration Safety

기존 사용자 시트를 깨면 안 된다.

대응:

- 새 시트는 없을 때만 생성한다.
- 기존 시트의 기존 열은 변경하지 않는다.
- `Settings`는 key-value append 방식으로만 확장한다.
- 마이그레이션 함수는 idempotent하게 작성한다.

## Recommended MVP Cut

한 번에 전부 구현하지 않는다.

권장 순서:

1. `현황 / 추이 / 비중` 탭 구조 추가
2. `비중` 탭 완성
3. `Snapshots` 시트 마이그레이션
4. 현재 스냅샷 저장
5. 스냅샷 기반 `추이` 탭 완성
6. 최근 1년 백필 추가

이 순서가 좋은 이유:

- `비중`은 현재 데이터만으로 정확히 구현 가능하다.
- `추이` 저장 구조를 먼저 안정화한 뒤 백필을 붙이면 복잡도를 나눌 수 있다.
- 백필 실패가 있어도 앱의 핵심 대시보드와 비중 기능은 먼저 제공된다.

## Acceptance Criteria

- 대시보드 상단에서 `현황 / 추이 / 비중`을 전환할 수 있다.
- `현황`은 기존 수치와 레이아웃을 유지한다.
- `비중`은 종목별/유형별/계좌별 도넛 그래프와 리스트를 제공한다.
- `Snapshots` 시트가 없는 기존 사용자도 자동 마이그레이션된다.
- 오늘 스냅샷이 중복 없이 저장된다.
- 스냅샷이 2개 이상이면 추이 그래프가 표시된다.
- 과거 데이터가 부족하면 백필 CTA가 표시된다.
- 최근 1년 백필 실행 후 추이 그래프가 과거 데이터로 채워진다.
- 백필 실패 항목은 숨기지 않고 사용자에게 표시한다.

