# Portfolio CLI

웹앱과 동일한 Google Sheets 원장을 관리하는 로컬 CLI입니다. Flutter UI나 Worker 배포 없이 실행하며, 앱의 모델·거래 재생·SheetsService를 직접 재사용합니다. Dart 3.11.3 이상으로 빌드합니다. 저장 명령은 기본적으로 **조회와 검증만 수행**하고 `--apply`가 있어야 씁니다. 출력은 JSON, 오류는 stderr와 종료 코드 1입니다.

## 설치

```sh
bash scripts/install_cli.sh
~/.local/bin/portfolio --help
```

Dart가 PATH에 없다면 `DART_BIN=/path/to/dart bash scripts/install_cli.sh`를 사용합니다. 설치된 실행 파일은 Dart/Flutter 없이 실행됩니다. 개발 중에는 `cd cli && dart pub get && dart run bin/portfolio.dart ...`로 실행합니다. 소스의 `src/`는 상위 앱 코드에 상대 경로로 의존하므로 CLI 디렉터리만 별도로 배포하지 마세요. 배포 단위는 컴파일된 실행 파일 또는 전체 저장소입니다.

## 최초 연결

1. 기존 Google Cloud 프로젝트에서 OAuth **Desktop app** 클라이언트를 만들고 JSON을 저장소 **밖에** 내려받습니다. Sheets API가 활성화되어 있어야 합니다. 웹앱의 Web client JSON은 사용할 수 없습니다.
2. 다음 명령이 출력하는 URL을 일반 브라우저에서 열어 **원장 소유 계정**으로 인증합니다. loopback callback은 127.0.0.1에만 열리고 5분 후 만료되며 PKCE와 state 검증을 사용합니다.
3. 앱에서 쓰는 스프레드시트 URL의 `/d/`와 `/edit` 사이 ID를 설정합니다.

```sh
portfolio auth login --client /private/path/desktop-client.json
portfolio configure --sheet YOUR_SPREADSHEET_ID
portfolio auth status
portfolio settings
portfolio trade list
```

[Google Desktop OAuth 지침](https://developers.google.com/identity/protocols/oauth2/native-app)을 따릅니다. 최초 동의는 사용자가 진행해야 합니다. 브라우저 로그인 쿠키나 기존 Worker 토큰을 가져오지 않습니다. `spreadsheets` 범위는 계정이 접근 가능한 스프레드시트에 접근할 수 있는 권한이며 특정 원장만으로 제한된 OAuth 범위는 아닙니다. CLI는 설정한 ID에만 요청합니다. Drive 검색 권한은 요청하지 않습니다.

설정·갱신 토큰·변경 전 원장 기록은 기본 `~/.config/portfolio-cli/`에 저장됩니다. macOS/Linux에서 디렉터리 0700, 파일 0600이며 **암호화 저장은 아닙니다**. 저장소에 넣거나 공유하지 마세요. `--state-dir /private/path`로 격리할 수 있습니다. `auth logout`은 로컬 인증 파일만 지우며 Google의 권한 철회는 계정 설정에서 진행합니다. `auth status`는 로컬 인증 존재 여부만 표시합니다. 운영 자동화에서는 단기 토큰을 `PORTFOLIO_ACCESS_TOKEN` 환경변수로 공급할 수도 있습니다(출력·저장하지 않음).

## 거래 관리

이 예시는 이미 등록된 거래입니다. **다시 추가할 필요는 없습니다.** 기본 미리보기에서 기존 거래와 내용이 같으면 `already_present`를 반환합니다.

```sh
portfolio trade add --owner 본석 --broker 토스증권 \
  --ticker SPCX --market US --side buy --quantity 1 \
  --price 145.86 --fx 1360 --date 2026-09-29 --time 12:38
```

저장하려면 동일 명령에 `--apply`를 붙입니다. 날짜·시간은 앱과 같은 현지 벽시계 값이며 자동 추정하지 않습니다. 수수료·세금·현금 자동 정산은 앱과 마찬가지로 지원하지 않습니다.

- 필수: `--owner --broker --ticker --market --side --quantity --price --date --time`; 미국 거래에는 `--fx` 추가.
- 시장: `US`, `KRX`, `KOSDAQ`. 한국 거래 통화/환율은 KRW/1. 종목 코드는 `005930`처럼 선행 0 유지.
- 유형: `buy`, `sell`, `opening_balance`, `adjustment`(앱의 양수 수량 조정 의미).
- 선택: `--name`, `--memo`, `--id`(증권사 주문 ID 등 안정적인 식별자 권장).
- 명의와 증권사는 기존 앱 설정에 등록되어 있어야 합니다. CLI는 설정을 임의로 생성하지 않습니다.
- 자동 ID는 정규화된 입력의 해시입니다. 명시적 ID가 없으면 같은 날짜·시간·명의·증권사·종목·거래유형·수량·가격·환율의 기존 기록을 중복으로 판단합니다. 메모·종목명 차이로 중복 생성하지 않습니다. 실제로 같은 체결이 두 건이면 각기 다른 `--id`를 명시하세요. 알 수 없는 응답 후에는 새 ID를 만들지 말고 기존 ID를 조회하세요.

```sh
portfolio trade list --owner 본석 --ticker SPCX
portfolio trade update --id RECORD_ID --price 146
# 위 미리보기의 revision을 전달해야 적용됩니다.
portfolio trade update --id RECORD_ID --price 146 --expect REVISION --apply
portfolio trade delete --id RECORD_ID
portfolio trade delete --id RECORD_ID --expect REVISION --apply
portfolio holdings
```

수정은 지정한 필드만 변경합니다. 삭제는 행을 밀지 않는 빈 행 처리입니다. 보유 수량보다 큰 매도, 필요한 선행 매수 삭제, 잘못된 날짜·숫자, 기존 원장의 오류가 있으면 쓰기를 거절합니다. `holdings`는 실행 컴퓨터의 오늘까지 거래를 재생한 **수량과 매입 원가**이며 실시간 평가액이 아닙니다.

## 기타 자산

```sh
portfolio asset list --owner 본석
portfolio asset add --owner 본석 --name 적금 --category savings \
  --value 100000 --currency KRW --date 2026-09-29 --time 12:38
portfolio asset update --id RECORD_ID --value 200000
portfolio asset delete --id RECORD_ID
```

분류: `savings`, `bond`, `loan`, `other`. 금액은 잔액이 아닌 **증감액**입니다. 대출은 양수 발생/음수 상환이며 원금을 초과하는 상환은 거절합니다. 거래와 동일하게 `--apply`, 수정·삭제 시 `--expect`가 필요합니다.

## 저장 확인과 복구

저장 전 `change-*.json`에 대상 시트, 변경 전후 행, 거래·기타자산 원장 사본을 남기고 저장 후 다시 읽어 검증합니다. 성공 시 `status: saved`와 기록 경로를 반환합니다. 이 사본은 **전체 웹앱 백업이 아니며** 시세·설정·스냅샷은 포함하지 않습니다. 전체 백업은 웹앱 설정에서 받으세요.

실패가 나면 자동으로 쓰기를 재시도하지 않습니다. 먼저 `trade list --id ID` 또는 `asset list --id ID`로 실제 반영 여부를 확인하세요. `pending` 기록은 실패를 뜻하지 않고 결과 미확정을 뜻합니다. 복구는 기록의 `before` 값을 확인하여 update/add 명령으로 미리보기 후 적용합니다. 자동 undo는 이 버전에 포함하지 않습니다.

변경은 과거 평가 기록에 재계산 필요일을 표시하고 새 종목의 시세 행을 추가합니다. 평가 스냅샷을 CLI에서 생성하지는 않습니다. 웹앱에서 새로고침하고 필요한 경우 과거 추이 복원을 실행하세요. 부수적인 시세 행/재계산 표시는 원장 저장 전에 기록되므로 실패 후 남을 수 있습니다.

동일 설정 디렉터리의 CLI 실행은 파일 잠금으로 직렬화합니다. 다른 컴퓨터·웹앱·Sheets 직접 편집과의 완전한 잠금은 지원되지 않습니다. 저장 직전 원장 revision, 수정·삭제 시 원본 행을 비교하지만 마지막 확인과 쓰기 사이 경쟁은 Sheets API의 한계로 남습니다. 같은 원장을 동시에 편집하지 마세요.

## 검증

```sh
cd cli
dart pub get --enforce-lockfile
dart analyze
dart test
dart compile exe bin/portfolio.dart -o ../build/portfolio
```

테스트는 메모리 원장과 가짜 HTTP 응답만 사용하며 실제 Google Sheets를 변경하지 않습니다. 실제 연결은 최초 인증 후 조회 → 테스트 시트에서 미리보기/적용/재조회 순으로 별도 확인하세요.
