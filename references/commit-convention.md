# 커밋 컨벤션

> **이 문서는 기본값이다 — 맨 아래 층이다.** 저장소나 사용자 쪽에 같은 항목을 정해둔 것이
> 있으면 그쪽이 우선한다. 어디를 보고 무엇이 우선하는지는 `${CLAUDE_PLUGIN_ROOT}/references/convention-precedence.md`.

커밋 메시지를 짓는 `commit`·`auto` 가 시작 전에 읽는다.

브랜치 이름·K 모델·note 계층은 이 문서에 없다. `worktree-discipline.md` 를 본다.

## Subject

기본 형식은 [Conventional Commits](https://www.conventionalcommits.org) —
`<type>(<scope>): <요약>`. **저장소가 다른 형식을 쓰고 있으면 그것을 따른다.**

- `type` 은 그 표준이 정한 값 (`feat` / `fix` / `refactor` / `chore` / `docs` / `test` / `perf` / `style`)
- `scope` 는 도메인·기능 영역. 저장소가 이미 쓰는 표기를 그대로 쓴다
- **요약의 언어와 어투는 규정하지 않는다** — 쓰기 직전 `git log --pretty=%s -n 15` 로
  저장소가 실제로 쓰는 언어·어투를 보고 거기 맞춘다
- 72자 이내, 마침표 없음
- **식별자는 원문 유지** — 코드에 있는 이름(상수·함수·API·설정 키)은 번역하지 않는다.
  번역하면 검색이 안 된다

**이슈 제목도 같은 규칙이다** — 위 Subject 규칙을 이슈 제목에 그대로 쓴다. 한쪽만 고치면 갈린다.

**사용자 CLAUDE.md 의 지시가 이 문서보다 우선한다** — 저장소·사용자 전역 층과의 관계는
`${CLAUDE_PLUGIN_ROOT}/references/convention-precedence.md` 가 정한다. 여기 다시 적지 않는다.

## 요약은 "코드 변경" 이 아니라 "기능/동작 변경"

- ✅ `fix(auth): 토큰 만료 시 재로그인 없이 자동 갱신`
- ✅ `fix(cart): refresh the total as soon as quantity changes` — 언어는 저장소를 따른다
- ❌ `fix(auth): useSession 훅에서 token null 처리 추가`
  → 코드가 뭘 했는지 말고, **사용자/시스템 관점에서 뭐가 달라졌는지** 적기
- 예외: **동작 변화가 전혀 없는** 순수 내부 정리(이름변경·파일이동·포맷·dead code 제거)만 코드 변경 자체를 제목으로 (`refactor(store): persist 대상에서 임시 캐시 제거`)
- 단, `refactor` 라도 인증 방식·아키텍처·보안·데이터 흐름 등 **시스템 동작이 바뀌면 동작/결과 관점**으로 작성 (✅ `refactor(auth): API 요청 인증을 쿠키 자동 전송 방식으로 전환` / ❌ `refactor(auth): authApiClient 에서 Authorization 헤더 제거`)

## 본문 (권장, 강제 아님)

필요할 때만 다음 섹션 가볍게 (제목과 같은 언어로):

- 1단락 문제 상황 + 수정 내용
- `Why` — 근본 원인 / 맥락
- `변경` — 파일 + 한 줄 영향
- `테스트` — 실행한 검증 (`npx tsc --noEmit`, `npm run lint` 등)

trivial 한 변경은 subject 만으로 충분, body 강요하지 말 것.
