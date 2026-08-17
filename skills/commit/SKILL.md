---
name: commit
description: 워크트리 작업단위 로컬 커밋 + accumulator-K 분기. 인자 -K/--done/--push/--no-test. 한 K 구현+검증 완료 시 "커밋할까요?" 묻지 말고 모델이 자율 호출(커밋·미러 후 멈춤). 사용자 신호는 다음 K 진행 여부에만; 다중 K 순회는 wtflow:auto.
allowed-tools: Bash(git *), Bash(glab *), Bash(WTFLOW_CHECKBOX_SYNC=1 glab *), Bash(./gradlew *), Bash(npm *), Bash(npx *), Read, Edit, AskUserQuestion
disable-model-invocation: false
---

# /wtflow:commit — 워크트리 작업단위 처리

**시작 전에 `${CLAUDE_PLUGIN_ROOT}/references/worktree-discipline.md`(브랜치 이름 규칙·K 모델·note 계층)와 `${CLAUDE_PLUGIN_ROOT}/references/commit-convention.md`(메시지 형식)를 읽는다.**

## 호출

`/wtflow:commit <작업 설명> [-K <번호>] [-a <accumulator>] [-n|--new-topic] [-s|--same-topic] [--done] [--no-test] [--push]`

- `<작업 설명>` (필수): 한국어 한 줄. commit subject + 본문에 사용
- `-K <번호>`: 작업단위(주제) 번호 = mirror 분기 `<mirror base>-<KKK>` 식별자. **작업 항목 번호와 일치**(wtflow:plan plan 의 Step N = 작업 항목 N = K N). 명시 시 그 K 사용(기존이면 전진, 신규면 생성). 미지정 시 아래 "주제 판단"으로 자동 결정
- `-n` / `--new-topic`: 이번 커밋부터 새 주제 — 새 분기(`기존 최고 K + 1`) 강제
- `-s` / `--same-topic`: 현재(최고 K) 분기에 누적 강제
- `-a <accumulator>`: 워크트리 브랜치 (예 `refactor/#30-metric-history-pg-migration`, 이슈 없는 작업이면 `refactor/+metric-history-pg-migration`). 미지정 시 자동 탐지:
  ```
  git branch --list '*/[#+]*' --format='%(refname:short)' | grep -vE -- '-[0-9]{3}$'
  ```
  중 현재 HEAD 와 ancestry 를 공유하는 것(`-<KKK>` 로 끝나는 건 mirror 라 제외)
- `--done`: 이번 커밋으로 **현재 K(작업 항목)가 완료**됨을 명시 → 체크박스 체크(`## 작업 항목 체크박스 동기화`). 주제 전환 없이 끝나는 마지막 K, 또는 단일 커밋으로 끝나는 K 에 사용
- `--no-test`: 테스트 단계 생략
- `--push`: 분기 브랜치를 origin 에도 push (기본은 로컬만)

> **작업 문서 = accumulator 이름이 정한다.** `/#` 뒤 정수 → 이슈 #N 본문(glab), `/+` 뒤 문자열 →
> `.claude/notes/<repo>/adhoc-<slug>.md`. 체크박스가 거기 있다는 것 말고는 두 경우가 다르지 않다.

## 한 번 호출 = 한 K, 그리고 멈춤 (자율 다중 K 금지)

이 스킬은 **한 작업 항목(K)의 커밋 하나**를 처리하고 **멈춘다**. 커밋·요약·진행표(계약 8) 출력 후 **다음 K 를 자율로 이어서 구현·커밋하지 않는다** — 다음 K 진행은 사용자의 다음 신호를 기다린다.

- **커밋 자체는 묻지 않는다(기본).** 현재 K 의 구현 + 검증이 끝나면 "커밋할까요?" 승인을 구하지 말고 **곧장 이 스킬을 자율 호출해 커밋**한다. 메시지는 커밋 컨벤션대로 모델이 짓고 결과만 보고. 사용자 신호를 기다리는 유일한 지점은 **다음 K 로 넘어갈지**다(커밋 전 승인 ✗ / 다음 K 진행 승인 ○).
- 자연어 "k3부터 진행", "쭉 가", "남은 거 다 해줘" 가 **여러 K 를 연속 처리하라는 뜻처럼 읽혀도**, 명시적 `/wtflow:auto` 호출이 없으면 **지명된(없으면 현재) 한 K 만** 처리하고 멈춰 다음 진행 여부를 묻는다. 예: "k3부터 진행" → **K3 하나만**(K4 이후 자동 진행 ✗).
- 여러 K 를 사람 개입 없이 순회하는 건 **오직 사용자가 `/wtflow:auto` 를 직접 호출**했을 때만. wtflow:commit 을 K 마다 반복 호출하며 **손으로 wtflow:auto 를 흉내내지 말 것**(가장 흔한 오작동 — 이 가드가 그걸 막는다).
- 한 K 안의 여러 태스크는 **같은 K 에 커밋 누적** OK. **다른 작업 항목(새 K)로 넘어가는 순간** 멈추고 묻는다.
- 멈춰 묻거나 방식을 고르게 할 땐 산문 나열 말고 **`AskUserQuestion`**(보기 첫째에 추천안 `(추천)`). 자유 입력은 자동 "Other" 로 보장되니 "직접 입력" 보기는 넣지 않는다.

## 계약 (보장되어야 하는 것)

1. **워크트리 브랜치 그대로** — 체크아웃·이동 안 함, origin push 안 함

2. **테스트 회귀** (`--no-test` 아니면) — 프로젝트 자동 감지 후 영향 테스트 추정 실행. **실패 시 commit 전 중단·보고**

   | 감지 | 실행 |
   |---|---|
   | `build.gradle*` | `./gradlew test --tests ...` |
   | `package.json` + `scripts.test` | `npm test` |
   | `package.json`, `scripts.test` 없음 | `npm run lint` + (`tsconfig.json` 있으면) `npx tsc --noEmit` |
   | 그 외 | 사용자에게 보고하고 결정 대기 |

3. **워크트리 브랜치에 commit (항상 새 commit, amend 금지)** — subject = `<작업 설명>`, 본문에 Why / 변경 / 테스트 결과. 푸터엔 `Co-Authored-By: <현재 실행 중인 모델명> <noreply@anthropic.com>` 만(예: `Claude Opus 4.8 (1M context)` — 이 커밋을 만드는 모델의 이름·버전 그대로. 확실치 않으면 `Claude`). **`K:` 트레일러 안 넣음** — K 귀속은 mirror 분기 이름(`-00N`)이 유일 소스라 계약 4의 mirror 전진/생성이 필수(dangling 금지).
   - **`git commit --amend` / rebase / reset 등 history 재작성 절대 금지.** 직전 작업단위에 대한 수정·교정·리뷰 반영이라도 **새 commit 으로 쌓는다**(방금 만든 로컬·미푸시 커밋이라도 amend 하지 않음 — 이력이 곧 작업 기록).
   - 같은 주제의 후속 수정이면 mirror 를 그 새 commit 으로 **FF-전진**(계약 4). amend 가 아니라 누적이므로 force-move 불필요.

4. **분기 브랜치 = 작업단위(K=주제) 1개, 커밋은 누적** — `<mirror base>-<KKK>`(3자리 zero-padding). 체크아웃 없음, **로컬만**. 커밋마다 새 분기 만들지 않는다.

   > **mirror base = accumulator 이름 그대로.** 뒤에 `-<KKK>` 만 붙인다 — prefix·마커를 따로 유도하지 않는다. accumulator 본체는 워크트리에 체크아웃돼 있어 커밋마다 자동 전진하므로 별도로 `git branch -f` 할 일이 없다.

   - **주제 판단**(`-K`/`-n`/`-s` 없을 때): `<작업 설명>` 이 직전 커밋과 같은 주제면 **현재 분기 전진**, 다른 주제면 **새 분기**
   - **전진(같은 주제 / 기존 K)**: mirror 를 HEAD 로 **FF-전진**. 커밋이 분기 끝에 누적되므로 fast-forward(force-push 아님). 기존 tip 은 HEAD 의 조상이어야 함
   - **신규(새 주제 / 새 K)**: `git branch "<mirror base>-<KKK>" HEAD`, K = (기존 최고 K)+1. 분기 0개면 K=1
   - 판단 결과(**전진 vs 신규 + 어느 K**)를 계약 7 요약에 명시 — 사용자가 틀린 판단을 `-n`/`-s` 로 잡을 수 있게

   **FF-전진(브랜치 X → 워크트리 tip) — 모든 로컬 브랜치 전진에 공통**
   1. `git branch -f X <tip>` → **성공이면 끝**(X 가 어디에도 체크아웃 안 됨 → ref 만 이동)
   2. `fatal: ... checked out at '<PATH>'` 로 **막히면** = 누군가 `<PATH>` 에서 X 를 보고 있는 중 → 그 워킹트리에서 `git -C <PATH> merge --ff-only <worktree-branch>`(ref+워킹트리 함께 전진 → 화면 즉시 갱신). non-FF 거나 `<PATH>` 가 더티면 알리고 skip
   - ⚠️ merge 는 **에러가 가리킨 그 `<PATH>` 에서만.** 임의 워킹트리(예: 메인)에서 돌리면 거기 체크아웃된 **다른 브랜치(예: develop)** 를 엉뚱하게 tip 으로 끌어올려 오염시킨다. `branch -f` 의 실패가 곧 '체크아웃 여부 + 정확한 위치' 를 알려주므로 사전 조회 불필요

   **한 곳에서 보기(viewing)** — 작업물을 한 브랜치에서만 보려면 그 브랜치를 체크아웃해 두면 된다. FF-전진 ②가 체크아웃된 브랜치를 매 커밋 자동으로 살려두므로 별도 viewing 로직이 필요 없다. 다만 mirror `-KKK` 는 K 가 바뀌면 안 움직이니, **K 전환을 넘어 항상 최신**을 보고 싶으면 accumulator 본체도 매 커밋 같은 FF-전진으로 올린다(로컬만).

5. **origin push** — `--push` 명시 시만. 분기 브랜치만, MR 미생성

6. **작업 항목 체크박스 동기화** — 아래 두 경우에 체크(절차는 `## 작업 항목 체크박스 동기화`). **로컬/push 무관하게 완료 시점에 즉시 반영**(진행 가시성 용도라 "로컬만" 원칙의 예외):
   - **새 K 로 전환(신규 분기 생성)** → 직전까지 진행하던 **이전 K** 를 완료로 보고 체크. 첫 K(분기 0개 → K=1)면 이전 K 없음 → 체크 안 함. 기존 K 전진(같은 주제·`-K` 재방문·FF)은 완료 신호가 아니라 체크 안 함
   - **`--done` 지정** → 이번 커밋의 **현재 K** 를 체크

7. **요약 출력** — 변경 파일 stat / commit hash / 새 브랜치명 / viewing 브랜치 전진 결과 / 테스트 결과 / push 여부 / **체크한 작업 항목**(`이슈 #N 항목 K` 또는 `adhoc-<slug> 항목 K`)

8. **진행 현황 자동 출력** — 요약 직후 `/wtflow:progress --quiet` 1회 호출해 갱신된 K 표를 덧붙인다. progress 가 표를 못 내도 **커밋은 이미 완료** — 막지 않고 종료

## 결정·중단 트리거

- accumulator 자동 탐지 실패 → 묻고 중단
- 주제 판단 모호 → 기본은 현재 분기 누적(보수적) + 요약에 "주제 불확실—누적함" 명시(`-n` 으로 재지정 가능)
- 같은 K 인데 기존 분기 tip 이 HEAD 의 조상이 아님(non-FF) → 보고하고 중단 (drift 의심)
- 테스트 실패 → commit 전 중단 + 결과 보고
- 아키텍처 트레이드오프 발견 → 옵션 비교만 제시, 결정 대기
- 스코프 확장 필요 → 진행 전 보고
- 파괴적 동작(force-push, 다른 브랜치 reset, amend/rebase 등 history 재작성, 운영 영향) → 명시적 동의 전 금지. 수정은 항상 새 commit(계약 3)
- 체크박스 동기화 실패(식별자 추출 불가 / glab 실패 / adhoc note 없음 / 항목 수 < K / 순서 모호 / 훅이 막음) → **경고만 하고 커밋은 그대로 완료**. 수동 체크 안내, 엉뚱한 항목을 추측해 체크하지 말 것

## 짧은 변형

- "테스트 빼고" → `--no-test` · "푸쉬도" → `--push`
- "새 주제" / "분기 새로 떠" → `-n` · "같은 거에 묶어" → `-s`
- "K12 로" → `-K 12` · "accumulator 는 X" → `-a X`
- "이 작업 항목 끝" / "항목 완료" / "체크해줘" → `--done`

## mirror 불변식 (커밋을 mirror 밖에 방치 금지)

mirror 는 **작업단위별 로컬 북마크**일 뿐이다. 최종 산출은 워크트리 브랜치 통째로 PR 1개라 분기 격리·충돌이 없고, 모든 커밋이 한 줄로 선형 누적되므로 전진은 늘 fast-forward(계약 4) — 새 커밋 생성·history 재작성·충돌이 구조적으로 없다(rebase/amend 의 안전한 대체).

**불변식 — 최상단 mirror = worktree tip.** 커밋이 쌓이면(K 커밋이든 **후속 정정·비-K chore 든**) 반드시 어떤 mirror 가 tip 을 가리켜야 한다. 새 K면 새 mirror, 아니면 **최상단 mirror 를 HEAD 로 FF**. **wtflow:commit 을 안 거친 수동 `git commit` 이라도 직접 FF**한다("비-K 라서 생략" 없음 — 가장 흔한 누락).

**"최상단" 은 번호가 아니라 최근성(ancestry)으로.** K 는 작업 항목 번호라 커밋 순서와 다를 수 있다(K6 을 K4 보다 먼저 커밋 → `-006` 이 `-004` 보다 옛 커밋). 최상단 = **HEAD 의 직계 조상 중 가장 최근 tip 을 가진 mirror**. `git for-each-ref`·`merge-base --is-ancestor` 로 판정 — ⚠️ `git branch --list` 의 `+`(다른 워크트리 체크아웃) 마커가 섞여 이름 `sort|tail` 은 틀린다. **손 sort 말고 ancestry 로.**

→ 라벨 번호와 tip 최신도가 어긋나 보이는 건 정상·무해. non-FF(별개 갈래)면 drift 의심 → 중단·보고.

## 작업 항목 체크박스 동기화

작업 항목 N = K N = mirror `-00N` 의 1:1 매핑을 **작업 문서의 체크리스트**에 역반영한다. K 가 완료되면 그 N번째 체크박스를 켠다.

1. **식별자 추출** — accumulator 이름에서. `/#` 뒤 정수 → 이슈번호 N(repo 는 git remote 자동), `/+` 뒤 문자열 → slug. 불가면 경고·skip
2. **작업 문서 로드**

   | | 로드 | 쓰기 |
   |---|---|---|
   | 이슈 #N | `glab issue view <N> --output json` 의 `description` | `WTFLOW_CHECKBOX_SYNC=1 glab issue update <N> -d "<전체 본문>"` |
   | `adhoc-<slug>.md` | Read (`.claude/notes/<repo>/`) | 그 한 줄만 Edit |

   ⚠️ **`WTFLOW_CHECKBOX_SYNC=1` prefix 를 빼지 않는다.** 이슈 본문을 고치는 호출은 훅
   (`hooks/guard-body-edit.sh`)이 막는다 — 재작성에는 템플릿 준수·미리보기·확인 계약이 걸려야
   하는데 `glab issue update` 직접 호출은 그걸 전부 건너뛰기 때문이다. **여기만 예외**인 이유는
   본문을 다시 쓰는 게 아니라 `- [ ]` **한 줄을 켜는 것**이라서다. 훅은 명령 문자열만 보므로,
   호출자가 이 prefix 로 스스로를 밝히는 것 말고 정당한 호출을 구별할 방법이 없다.
   - 그러니 **이 prefix 를 붙인 호출은 실제로 체크박스 한 줄만 바꿔야 한다.** 같은 호출에
     본문 손질을 얹으면 예외를 우회로로 쓰는 것이다 — 본문을 고칠 일이면 `/wtflow:issue --rewrite`
   - 훅이 막았다는 응답을 받으면 prefix 누락을 먼저 의심한다. 훅을 끄거나 우회하지 않는다

   adhoc note 가 없으면 경고·skip — **만들지 않는다**(항목 목록을 지어내는 셈이 된다).
   note 는 git 밖 심링크 실체라 커밋·push 대상이 아니다
3. **K번째 항목** — `작업 항목`(또는 `작업 계획`) 섹션 **안의** 체크리스트에서 **위에서 K번째** `- [ ]`/`- [x]` 줄. 항목 수 < K·섹션 모호 → 경고·skip(추측 금지)
4. **그 줄만 토글** `- [ ]`→`- [x]` (나머지 본문 보존, 이미 `[x]` 면 no-op). 실패 시 경고만, 커밋 흐름 안 막음
5. **요약에 명시** — "이슈 #N 항목 K 체크" / "adhoc-<slug> 항목 K 체크", 또는 실패 사유

잘못 체크할 위험(순서 모호 등)이면 체크 말고 수동 안내. 체크리스트 없는 작업 문서면 대상 없음 → skip. (멱등: 같은 K 두 번 체크해도 no-op)
