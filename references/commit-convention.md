# 커밋 컨벤션

커밋 메시지를 짓는 스킬(`commit`·`auto`)이 시작 전에 읽는다.
브랜치 이름·K 모델·note 계층은 여기 없다 — `worktree-discipline.md` 에 있다.

## Subject — `<type>(<scope>): <한글 요약>`

- **type 은 영어 conventional prefix** (`fix` / `feat` / `refactor` / `chore` / `docs` / `test` / `perf` / `style`)
- **scope 도 영어** (도메인/기능 영역: `auth` / `cart` / `search` / `profile` 등)
- **요약은 한글** — 사용자가 영문 subject 를 즉시 지적함
- 72자 이내, 마침표 없음
- 의심스러우면 작성 직전 `git log --pretty=%s -n 15` 로 다수 언어 확인

## 요약은 "코드 변경" 이 아니라 "기능/동작 변경"

- ✅ `fix(auth): 토큰 만료 시 재로그인 없이 자동 갱신`
- ✅ `fix(cart): 수량 변경 시 합계 즉시 갱신`
- ❌ `fix(auth): useSession 훅에서 token null 처리 추가`
  → 코드가 뭘 했는지 말고, **사용자/시스템 관점에서 뭐가 달라졌는지** 적기
- 예외: **동작 변화가 전혀 없는** 순수 내부 정리(이름변경·파일이동·포맷·dead code 제거)만 코드 변경 자체를 제목으로 (`refactor(store): persist 대상에서 임시 캐시 제거`)
- 단, `refactor` 라도 인증 방식·아키텍처·보안·데이터 흐름 등 **시스템 동작이 바뀌면 동작/결과 관점**으로 작성 (✅ `refactor(auth): API 요청 인증을 쿠키 자동 전송 방식으로 전환` / ❌ `refactor(auth): authApiClient 에서 Authorization 헤더 제거`)

## 본문 (권장, 강제 아님)

필요할 때만 다음 섹션 가볍게 — 한글:

- 1단락 문제 상황 + 수정 내용
- `Why` — 근본 원인 / 맥락
- `변경` — 파일 + 한 줄 영향
- `테스트` — 실행한 검증 (`npx tsc --noEmit`, `npm run lint` 등)

trivial 한 변경은 subject 만으로 충분, body 강요하지 말 것.

## 영문 commit prefix 만은 유지

한글 subject 라도 `fix:` / `feat:` 같은 prefix 는 영어. tooling 호환 + 다수 OSS 컨벤션.
