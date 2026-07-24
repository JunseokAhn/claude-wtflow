# 워크트리 스킬셋 — 작업 규율 · 커밋 컨벤션

## 워크트리 작업 (wt-* 스킬 보완)

### 워크트리 안에서의 행동 정책
- 워크트리 브랜치에서 떠나지 않음 — 다른 브랜치 체크아웃 금지
  (새 브랜치 생성 `git branch <name>` 은 OK)
- 큰 작업 임계: 4단계 이상 또는 1주 이상이면 통합 브랜치 + accumulator + 작업단위(K) 3단계 패턴.
  작은 작업은 develop 으로 직접 PR 1개로 충분

### 커밋 단위 = 태스크 / 분기(K) = 작업 항목
워크트리 작업은 2층이다:
- **이슈 작업 항목 = mirror 분기 K** — 작업 항목(주제)이 바뀔 때만 새 K.
- **태스크(작업 항목 내 하위 단위) = 커밋** — 진행하며 태스크마다 `/wt-commit` 으로
  같은 K 분기에 누적 커밋. ⚠️ 한 작업 항목의 여러 태스크를 커밋 없이 한 덩어리로 진행 금지(가장 흔한 실수).

워크트리 안에서 사용자가 "커밋해", "분기 만들어", "PR-N", "이 작업 마무리" 같은
작업단위 마무리 의도를 보이면 자동 진행 금지, 커밋·작업 항목 전환 시점에 한 번 묻기:

> "`/wt-commit <설명> [-K N]` 으로 처리할까요? 또는 그대로 자연어로?"

- 방식은 세션당 한 번만 (첫 답변 따름). 사용자가 "묶어서 가" 하면 batch OK
- 워크트리 밖에선 적용 안 함

**Why:** 자연어 해석 변동성 + 자동 push 회복 어려움 → 스킬 호출이 contract 보장.
K 모델은 스킬에 있으나 '태스크마다 커밋' 규율이 약해 한 덩어리(batch)로 흐르던 것 보완.

### 워크트리 진입은 wt-plan 경유
- 이슈 작업이면 `/wt-plan <N>` — 슬래시 accumulator 브랜치를 붙인 워크트리를 만들고
  `EnterWorktree` 로 현재 세션을 인플레이스 이동시킨다 (새 세션 spawn 아님)
- **`claude --worktree` 금지** — 브랜치명을 `worktree-…` 로 새로 만들어 미리 만든
  슬래시 accumulator 가 고아가 되고 mirror 분기가 붙을 곳을 잃는다
- 부득이하게 `EnterWorktree` 를 직접 쓸 땐: base_ref=develop 명시(없으면 main fallback)
  + 슬래시 브랜치를 `git worktree add <브랜치>` 로 먼저 붙인 뒤 그 경로로 진입

## 커밋 컨벤션

### Subject — `<type>(<scope>): <한글 요약>`
- **type 은 영어 conventional prefix** (`fix` / `feat` / `refactor` / `chore` / `docs` / `test` / `perf` / `style`)
- **scope 도 영어** (도메인/기능 영역: `auth` / `cart` / `search` / `profile` 등)
- **요약은 한글** — 사용자가 영문 subject 를 즉시 지적함
- 72자 이내, 마침표 없음
- 의심스러우면 작성 직전 `git log --pretty=%s -n 15` 로 다수 언어 확인

### 요약은 "코드 변경" 이 아니라 "기능/동작 변경"
- ✅ `fix(auth): 토큰 만료 시 재로그인 없이 자동 갱신`
- ✅ `fix(cart): 수량 변경 시 합계 즉시 갱신`
- ❌ `fix(auth): useSession 훅에서 token null 처리 추가`
  → 코드가 뭘 했는지 말고, **사용자/시스템 관점에서 뭐가 달라졌는지** 적기
- 예외: **동작 변화가 전혀 없는** 순수 내부 정리(이름변경·파일이동·포맷·dead code 제거)만 코드 변경 자체를 제목으로 (`refactor(store): persist 대상에서 임시 캐시 제거`)
- 단, `refactor` 라도 인증 방식·아키텍처·보안·데이터 흐름 등 **시스템 동작이 바뀌면 동작/결과 관점**으로 작성 (✅ `refactor(auth): API 요청 인증을 쿠키 자동 전송 방식으로 전환` / ❌ `refactor(auth): authApiClient 에서 Authorization 헤더 제거`)

### 본문 (권장, 강제 아님)
필요할 때만 다음 섹션 가볍게 — 한글:
- 1단락 문제 상황 + 수정 내용
- `Why` — 근본 원인 / 맥락
- `변경` — 파일 + 한 줄 영향
- `테스트` — 실행한 검증 (`npx tsc --noEmit`, `npm run lint` 등)

trivial 한 변경은 subject 만으로 충분, body 강요하지 말 것.

### 영문 commit prefix 만은 유지
한글 subject 라도 `fix:` / `feat:` 같은 prefix 는 영어. tooling 호환 + 다수 OSS 컨벤션.
