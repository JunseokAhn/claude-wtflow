# claude-wtflow

git worktree 위에서 한 작업을 **작업 항목(K) 단위로 분기**하고 **태스크마다 커밋으로 누적**하는 작업 규율 [Claude Code](https://claude.com/claude-code) 플러그인.
코어는 호스트 무관, 이슈 연동은 옵션 어댑터(현재 GitLab).

![워크트리 기반 작업 규율](./assets/workflow-worktree.svg)

## 설치

```
/plugin marketplace add JunseokAhn/claude-wtflow
/plugin install wtflow@wtflow
```

이게 전부다. 스킬·훅·정리 스크립트가 한 번에 붙는다 — 심링크도, `settings.json` 편집도 없다.

개발 중 로컬에서 시험하려면:

```
git clone https://github.com/JunseokAhn/claude-wtflow.git
claude --plugin-dir ./claude-wtflow
```

## 스킬

플러그인 스킬은 플러그인 이름으로 네임스페이스된다 — `/wtflow:plan` 처럼 부른다.

```
코어 — 호스트 무관 (GitHub·GitLab·이슈 없어도 동작)
  /wtflow:plan       워크트리·브랜치 셋업 + note 로드 + plan(작업 항목 = K) 매핑
                     이슈번호로도, 이슈 없이 작업 설명만으로도(adhoc) 시작
  /wtflow:commit     태스크 단위 커밋 + mirror 분기(…-00N) 누적
  /wtflow:auto       plan 의 K 자율 순회 (구현 → 검증 → /wtflow:commit → 완료 시 /wtflow:briefing)
  /wtflow:progress   K 진행 현황 표 + 이슈↔note drift 보고 (읽기 전용)
  /wtflow:briefing   작업 전체를 설계문서형 브리핑으로 정리 (git·대화 근거, 읽기 전용)
  /wtflow:merge      안 머지된 작업 브랜치를 기본 브랜치로 (충돌 해소 + 빌드 검증)
  wtflow-clean       워크트리·브랜치 정리 (병합분만, 미병합은 -f/-M) — 스킬이 아니라 실행 스크립트

이슈 어댑터 — 옵션 · GitLab (glab 필요)
  /wtflow:issue      이슈 생성 + 이슈 note 작성
  /wtflow:milestone  여러 이슈에 걸친 공통 계약 note + 이슈 분할 생성
                     (/wtflow:plan 의 이슈 모드도 glab 필요 — adhoc 모드는 불필요)
```

개념(2층 모델 · 작업 항목↔`-00N` 분기 · 커밋 규율)은 위 다이어그램에 다 있음. 규율의 전문은 스킬이 시작할 때 읽는 [`references/`](./references) 에 있다 — [작업 규율](./references/worktree-discipline.md) · [커밋 컨벤션](./references/commit-convention.md).

## 브랜치와 note

```
                              이슈 작업              이슈 없는 작업 (adhoc)
워크트리 브랜치 (accumulator)  <prefix>/#<N>-<slug>   <prefix>/+<slug>      (plan 이 생성)
작업 항목 K 의 mirror 분기     …-<KKK> 를 뒤에 붙인다  (동일)                (commit 이 생성)
작업 문서 (목표·작업 항목)      이슈 본문              adhoc-<slug>.md

~/.claude/notes/<group>/
  _milestone/<iid>-<slug>.md  여러 이슈·레포가 공유하는 계약
  <repo>/issue-<N>.md         이슈 하나의 계획 (K별 계약·파일 위치)
  <repo>/adhoc-<slug>.md      이슈 없이 시작한 작업의 계획 + 작업 항목 체크리스트
```

`#<N>` 자리에 `+` 가 들어간 것뿐이고 K 분해·mirror·커밋·정리 규칙은 두 경우가 완전히 같다. 갈리는 건 **작업 항목 체크리스트가 어디 있나**(이슈 본문 ↔ adhoc note) 뿐이다.

이슈 본문은 "무엇/왜"만 두고 페이로드·타입·에러코드 같은 상세는 note 로 뺀다. note 는 git 밖(홈)에 단일 실체로 두고 워크트리엔 심링크로 꽂히므로, 진행 중 고친 계약이 다른 브랜치·세션에서도 즉시 읽힌다 — 그 심링크를 거는 게 플러그인이 자동 등록하는 `hooks/link-worktree-local.sh` 다.

## 비고

- 이슈 어댑터(`/wtflow:issue`·`/wtflow:milestone`, `/wtflow:plan` 의 이슈 모드)는 `glab` CLI 필요. 코어는 의존성 없음.
- `wtflow-clean`·`/wtflow:merge` 는 origin 을 건드리지 않음 (로컬 분기·워크트리만, push 는 사용자 몫).
- **`wtflow-clean` 은 플러그인이 켜져 있는 동안 Claude 의 Bash 툴 PATH 에만 올라간다.** 사용자가 직접 터미널에서 치려면 심링크를 따로 걸어야 한다:
  ```
  ln -s ~/.claude/plugins/*/wtflow/bin/wtflow-clean ~/.local/bin/wtflow-clean
  ```
  ⚠️ **예전 `install.sh` 로 설치했었다면 `~/.local/bin/wtflow-clean` 을 먼저 지운다.** 그쪽이 PATH 앞이라 플러그인 사본을 가려서, 업데이트해도 옛 스크립트가 계속 실행된다.
- `link-worktree-local.sh` 는 워크트리에 `CLAUDE.md`·`.claude/*`·`.env*` 처럼 gitignore 돼 따라오지 않는 로컬 파일도 함께 걸어준다. 언어·프레임워크 무관, 원본에 없으면 건너뛰고 어떤 경우에도 세션을 막지 않는다.
- 기본 브랜치는 `develop`, 없으면 `main` 으로 자동 폴백한다.
