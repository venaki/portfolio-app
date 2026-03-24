---
name: patch-note
description: 현재 버전 이후 변경사항을 요약하여 release/patch-note/ 폴더에 새 버전 패치노트 MD 파일을 생성한다.
---

# Patch Note 생성

현재 버전 이후 추가된 변경사항을 요약하여 패치노트를 생성한다.

## 실행 절차

### Step 1: 현재 버전 확인

`release/patch-note/` 폴더에서 가장 최신 패치노트 파일을 찾아 현재 버전을 파악한다.
버전 형식: `x.y.z`

### Step 2: 새 버전 번호 결정

현재 버전의 마지막 숫자(patch)에 +1을 한다.
예: `0.1.1` → `0.1.2`

Director가 별도로 버전을 지정하면 그것을 사용한다.

### Step 3: 변경사항 수집

마지막 패치노트 이후의 변경사항을 수집한다:
1. `git log`로 마지막 패치노트 이후 커밋 확인
2. 현재 세션의 대화 컨텍스트에서 작업 내역 파악
3. 변경된 파일 diff 확인

### Step 4: 패치노트 작성

기존 패치노트 스타일을 따라 작성한다:
- 파일: `release/patch-note/{version}.md`
- 형식:
```markdown
# v{version} - {한줄 요약}

## {카테고리}
- 변경사항 1
- 변경사항 2
```

카테고리 예시: 기능 추가, UI 개선, 버그 수정, 데이터 호환성, 배포 등

### Step 5: 완료 보고

```
📋 패치노트 생성: release/patch-note/{version}.md
```
