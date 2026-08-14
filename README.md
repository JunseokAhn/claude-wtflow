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
  /wtflow:plan       워크트리·브랜치 셋업 + note 로드 + plan(작업 항목 = K) 매핑
                     이슈번호로도, 이슈 없이 작업 설명만으로도(adhoc) 시작
  /wtflow:commit     태스크 단위 커밋 + mirror 분기(…-00N) 누적
  /wtflow:auto       plan 의 K 자율 순회 (구현 → 검증 → /wtflow:commit → 완료 시 /wtflow:briefing)
  /wtflow:progress   K 진행 현황 표 + 이슈↔note drift 보고 (읽기 전용)
  /wtflow:briefing   작업 전체를 설계문서형 브리핑으로 정리 (git·대화 근거, 읽기 전용)
  /wtflow:merge      기본 브랜치 최신본을 작업 브랜치로 (충돌 해소 + 빌드 검증)
  /wtflow:clean      워크트리·브랜치 정리 (확인 없이 한 번에 실행. -n 이면 대상만 보여준다)

이슈 어댑터 — 옵션 · GitLab (glab 필요)
  /wtflow:mr         작업 브랜치를 origin 에 올리고 MR 생성 (본문은 briefing --mr)
  /wtflow:issue      이슈 생성 + 이슈 note 작성
  /wtflow:milestone  여러 이슈에 걸친 공통 계약 note + 이슈 분할 생성
                     (/wtflow:plan 의 이슈 모드도 glab 필요. adhoc 모드는 불필요)
```

2층 모델과 커밋 규율은 위 다이어그램에 정리돼 있다. 규율 전문은 스킬이 시작할 때 읽는 [작업 규율](./references/worktree-discipline.md)과 [커밋 컨벤션](./references/commit-convention.md)에 있다.

작업이 1~2단계로 끝난다면 이 흐름은 과하다. 분해 없이 커밋 한 번으로 끝내는 편이 낫고, 4단계 이상이거나 여러 날에 걸칠 때 값어치가 나온다.

## 사전문답 (선택)

작업을 대신 해 주는 것과, 작업자가 그 코드를 계속 쥘 수 있게 하는 것은 다른 목표다. [사전문답 규율](./references/learning-protocol.md)은 후자를 위해 K 앞뒤에 문답을 끼워 넣는다. 노리는 능력은 두 축이다.

**동작 판단** — 도메인 판단이 든 K 는 착수 전에 멈춰 사용자 답을 먼저 받고(예측 후 공개), 동작이 바뀌는 몇 줄은 사용자가 쓰며, 사용자가 쓴 코드에는 고쳐 주지 않고 지적만 한다. 질문은 `file:line` 을 던지는 대신 **답에 필요한 코드를 안에 인용해** 자족적으로 낸다.

**설계 판단** — 메서드 분리·파라미터 설계·상수 여부·저장 위치처럼 **되돌리기 비용이 크고 파급이 파일 밖으로 나가는** 선택은 두 안을 나란히 내고 고르게 한다(K 당 최대 1건, 없으면 안 묻는다). 보기에는 트레이드오프만이 아니라 **무엇으로 재서 고르는지(판단 기준)** 와 추천을 함께 붙이고, 답한 **직후에 채점**한다 — 정오를 나중으로 미루면 고른 사람이 자기 판단이 맞았는지 영영 모른다. 거기에 "이 선택은 무엇이 바뀔 때 먼저 무너지나" 라는 반증 가능한 예측을 붙이고, 대가가 드러나는 K 에서 **예측과 실제를 숫자로 대조해 청구서를 낸다**. 고르고 끝내면 설문이지 훈련이 아니다 — 코드를 위임하면 코드가 느는 속도는 그대로인데 청구서를 받는 사람이 사라진다.

반대로 `export` 여부·파일 분할·조건문 모양처럼 **30초면 되돌리고 파일 하나 안에서 끝나는** 것은 묻지 않는다. 개수만 줄이고 고도를 안 재면 질문 수가 적어도 "코딩을 직접 하는 기분" 이 남는다.

**묻는 형식은 예외 없이 `AskUserQuestion` 이다** — 산문으로 늘어놓으면 답하지 않아도 대화가 굴러가서 장치가 조용히 죽는다. 한 K 의 문항은 한 번의 호출에 최대 3문항으로 모은다. `(추천)` 은 **고르게 하는 설계 선택에만** 붙이고 **맞히는 자리(예측·변경 압력)에는 붙이지 않는다** — 거기서는 추천이 곧 정답 누설이다. 자기 말로 답하고 싶으면 자동으로 붙는 "Other" 로 쓴다.

K 당 5~15분이 늘어나므로 **배울 게 있는 이슈에서만** 켠다. 마찰 관리는 대상 범위를 좁히는 대신 **개수 상한**으로 한다. 대상 K 는 `/wtflow:plan` 이 표에 `❓` 로 표시하고, `/wtflow:auto` 는 무중단이 목적이라 표시가 있어도 멈추지 않는다(설계 선택과 예측만 브리핑 뒤로 모아 낸다). 계산이나 API 트리비아처럼 **정답이 하나인 것은 대상이 아니다** — 맞혀도 판단력이 늘지 않는다.

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

두 경우의 차이는 `#<N>` 자리에 `+` 가 들어가는 것뿐이고, K 분해·mirror·커밋·정리 규칙은 같다. 갈리는 지점은 작업 항목 체크리스트의 위치 하나다(이슈 본문이냐 adhoc note 냐).

이슈 본문에는 "무엇/왜"만 남기고 페이로드·타입·에러코드 같은 상세는 note 로 뺀다. note 를 git 밖(홈)에 단일 실체로 두고 워크트리에는 심링크로 꽂으므로, 진행 중 고친 계약이 다른 브랜치·세션에서도 즉시 읽힌다. 그 심링크는 플러그인이 자동 등록하는 `hooks/link-worktree-local.sh` 가 건다.

## 비고

- 이슈 어댑터(`/wtflow:issue`·`/wtflow:milestone`, `/wtflow:plan` 의 이슈 모드) → `glab` CLI 필요. 코어는 의존성 없음
- `/wtflow:clean`·`/wtflow:merge` → 로컬 분기·워크트리만 조작. origin 은 건드리지 않는다
- `/wtflow:mr` → **origin 을 건드리는 유일한 명령.** 작업 브랜치를 올리고 MR 을 연다. 기본 브랜치는 리뷰를 거쳐서만 바뀐다
- 기본 브랜치 → `develop`, 없으면 `main` 으로 자동 폴백
- `link-worktree-local.sh` → gitignore 돼 워크트리에 안 따라오는 `CLAUDE.md`·`.claude/*`·`.env*` 를 심링크로 연결. 언어·프레임워크 무관, 원본에 없으면 건너뜀
- `guard-body-edit.sh` → 이슈·MR 본문을 스킬 밖에서 고치는 `glab issue update`·`gh issue edit`·`glab mr update`·`gh pr edit` 호출을 막는다(본문 플래그가 붙었을 때만). 재작성은 `/wtflow:issue --rewrite`·`/wtflow:mr --rewrite` 로 — 거기에만 템플릿 준수·분량 확인이 걸려 있다
- `/wtflow:clean` 이 부르는 `wtflow-clean` 스크립트는 **Claude 의 Bash 툴 PATH 에만** 올라간다. 사용자 셸은 별개 프로세스라 그 환경변수를 물려받지 않으므로, 터미널에서 직접 치려면 PATH 에 있는 디렉토리로 심링크를 따로 건다

  ```sh
  # 설치 경로를 먼저 확인한다 (마켓플레이스 이름과 버전이 경로에 들어간다)
  ls -d ~/.claude/plugins/cache/*/wtflow/*/bin

  # 그중 하나를 골라 건다. ~/.local/bin 이 PATH 에 있어야 한다
  ln -sf ~/.claude/plugins/cache/<마켓플레이스>/wtflow/<버전>/bin/wtflow-clean ~/.local/bin/wtflow-clean
  ```

  경로에 버전이 들어 있어 **플러그인을 업데이트하면 다시 걸어야 한다.** 스크립트는 플러그인 파일에 의존하지 않아 단독으로 돈다 (git 저장소 안에서 실행하면 된다)
