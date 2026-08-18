# claude-wtflow

git worktree 를 작업 공간으로 쓰면서 작업 항목마다 분기를 두고 태스크마다 커밋을 쌓게 하는 [Claude Code](https://claude.com/claude-code) 플러그인.

큰 작업을 한 덩어리로 밀어붙이면 리뷰도 되돌리기도 어려워진다. 작업 항목(K)을 분기 단위로, 태스크를 커밋 단위로 고정하면 어디까지 진행됐는지가 브랜치 목록과 체크박스에 그대로 남는다. 코어는 호스트를 가리지 않고, 이슈 연동만 옵션 어댑터로 붙는다(현재 GitLab).

![워크트리 기반 작업 규율](./assets/workflow-worktree.svg)

## 설치

```
/plugin marketplace add JunseokAhn/claude-wtflow      ← 마켓플레이스 등록 (소스 레포)
/plugin install wtflow@claude-kit                     ← 플러그인 설치 (플러그인@마켓플레이스)
```

스킬·훅·정리 스크립트가 한 번에 붙는다. 심링크를 걸거나 `settings.json` 을 편집할 일은 없다.

⚠️ **두 줄의 이름이 다르다.** 등록에는 **저장소** 이름(`claude-wtflow`), 설치에는 **마켓플레이스**
이름(`claude-kit`)이 들어간다. 등록 단계에 `claude-kit` 을 넣으면 그런 저장소가 없어 실패한다.

## 스킬

플러그인 스킬은 플러그인 이름으로 네임스페이스되므로 `/wtflow:plan` 처럼 부른다.

```
코어 — 호스트 무관 (GitHub·GitLab·이슈 없어도 동작)
  /wtflow:plan       워크트리·브랜치 셋업 + 마일스톤 계약 로드 + plan(작업 항목 = K) 매핑
                     이슈번호로도, 이슈 없이 작업 설명만으로도(adhoc) 시작
  /wtflow:commit     태스크 단위 커밋 + mirror 분기(…-00N) 누적
  /wtflow:auto       plan 의 K 자율 순회 (구현 → 검증 → /wtflow:commit → 완료 시 /wtflow:briefing)
  /wtflow:progress   K 진행 현황 표 (읽기 전용)
  /wtflow:briefing   작업 전체를 설계문서형 브리핑으로 정리 (git·대화 근거, 읽기 전용)
  /wtflow:merge      기본 브랜치 최신본을 작업 브랜치로 (충돌 해소 + 빌드 검증)
  /wtflow:clean      워크트리·브랜치 정리 (확인 없이 한 번에 실행. -n 이면 대상만 보여준다)

이슈 어댑터 — 옵션 · GitLab (glab 필요)
  /wtflow:mr         작업 브랜치를 origin 에 올리고 MR 생성 (본문은 briefing --mr)
  /wtflow:issue      이슈 생성 + 착수 전 계약을 이슈 note 로 1회 기록
  /wtflow:milestone  여러 이슈에 걸친 공통 계약 note + 이슈 분할 생성
                     (/wtflow:plan 의 이슈 모드도 glab 필요. adhoc 모드는 불필요)
```

2층 모델과 커밋 규율은 위 다이어그램에 정리돼 있다. 규율 전문은 스킬이 시작할 때 읽는 [작업 규율](./references/worktree-discipline.md)과 [커밋 컨벤션](./references/commit-convention.md)에 있다.

작업이 1~2단계로 끝난다면 이 흐름은 과하다. 분해 없이 커밋 한 번으로 끝내는 편이 낫고, 4단계 이상이거나 여러 날에 걸칠 때 값어치가 나온다.

## 브랜치와 note

```
                              이슈 작업              이슈 없는 작업 (adhoc)
워크트리 브랜치 (accumulator)  <prefix>/#<N>-<slug>   <prefix>/+<slug>      (plan 이 생성)
작업 항목 K 의 mirror 분기     …-<KKK> 를 뒤에 붙인다  (동일)                (commit 이 생성)
작업 항목의 진실원             이슈 본문 체크리스트    plan 출력 + mirror 분기

~/.claude/notes/<group>/
  <repo>/issue-<N>.md         착수 전 계약·배경의 1회 스냅샷 (issue 가 쓴다)
  _milestone/<iid>-<slug>.md  여러 이슈·레포가 공유하는 계약 (milestone 이 쓴다)
```

두 경우의 차이는 `#<N>` 자리에 `+` 가 들어가는 것뿐이고, K 분해·mirror·커밋·정리 규칙은 같다. 갈리는 지점은 작업 항목이 어디 사느냐 하나다 — 이슈가 있으면 본문 체크리스트가 진실원이고, 없으면 이 세션의 plan 출력이 항목 텍스트를, mirror 분기가 K 번호와 진행 상태를 나눠 갖는다.

이슈 본문에는 "무엇/왜"만 남기고 페이로드·타입·에러코드 같은 상세는 note 로 뺀다. **두 note 는 갱신 성격이 반대다** — 이슈 note 는 `/wtflow:issue` 가 이슈당 한 번 쓰고 아무도 안 고치는 스냅샷이고, 마일스톤 note 는 여러 이슈가 같은 실체를 봐야 해서 진행 중 고쳐진다. `plan` 은 둘 다 읽기만 한다.

계획 파일이 부담이었던 건 존재해서가 아니라 진행 내내 갱신해야 해서였다. 이슈 note 는 쓰는 자리를 한 번뿐인 지점으로 옮겨 그 비용을 없앴고, 대가로 낡을 수 있다 — 어긋나면 이슈 본문이 이긴다.

**작업 항목(K)은 파일로 남기지 않는다.** `/wtflow:plan` 이 `EnterWorktree` 로 같은 세션을 워크트리에 밀어넣으므로 plan 출력이 그대로 살아 있고, 세션이 끊겨도 K 번호와 커밋은 mirror 분기에 남는다.

어느 마일스톤이 이 이슈의 계약인지는 **이슈의 마일스톤 배정**이 답한다. `/wtflow:plan` 이 이슈를 조회할 때 딸려 오는 마일스톤 식별자로 경로를 조립해 홈 원본을 직접 읽는다 — 워크트리에 사본도 심링크도 두지 않으므로, 어느 세션에서 열어도 같은 실체를 보고 진행 중 고친 계약이 즉시 읽힌다.

## 비고

- 이슈 어댑터(`/wtflow:issue`·`/wtflow:milestone`, `/wtflow:plan` 의 이슈 모드) → `glab` CLI 필요. 코어는 의존성 없음
- `/wtflow:clean`·`/wtflow:merge` → 로컬 분기·워크트리만 조작. origin 은 건드리지 않는다
- `/wtflow:mr` → **origin 을 건드리는 유일한 명령.** 작업 브랜치를 올리고 MR 을 연다. 기본 브랜치는 리뷰를 거쳐서만 바뀐다
- 기본 브랜치 → `develop`, 없으면 `main` 으로 자동 폴백
- `link-worktree-local.sh` → gitignore 돼 워크트리에 안 따라오는 `CLAUDE.md`·`.claude/*`·`.env*` 를 심링크로 연결. 언어·프레임워크 무관, 원본에 없으면 건너뜀
- `/wtflow:clean` 이 부르는 `wtflow-clean` 스크립트는 **Claude 의 Bash 툴 PATH 에만** 올라간다. 사용자 셸은 별개 프로세스라 그 환경변수를 물려받지 않으므로, 터미널에서 직접 치려면 PATH 에 있는 디렉토리로 심링크를 따로 건다

  ```sh
  # 설치 경로를 먼저 확인한다 (마켓플레이스 이름과 버전이 경로에 들어간다)
  ls -d ~/.claude/plugins/cache/*/wtflow/*/bin

  # 그중 하나를 골라 건다. ~/.local/bin 이 PATH 에 있어야 한다
  ln -sf ~/.claude/plugins/cache/<마켓플레이스>/wtflow/<버전>/bin/wtflow-clean ~/.local/bin/wtflow-clean
  ```

  경로에 버전이 들어 있어 **플러그인을 업데이트하면 다시 걸어야 한다.** 스크립트는 플러그인 파일에 의존하지 않아 단독으로 돈다 (git 저장소 안에서 실행하면 된다)
