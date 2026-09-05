---
name: commit
description: 워크트리 작업단위 로컬 커밋 + accumulator-Step 분기. 인자 --step/--done/--push/--no-test. 한 Step 구현+검증 완료 시 "커밋할까요?" 묻지 말고 모델이 자율 호출(커밋·미러 후 멈춤). 사용자 신호는 다음 Step 진행 여부에만; 다중 Step 순회는 wtflow:auto.
allowed-tools: Bash(git *), Bash(gh *), Bash(glab *), Bash(tea *), Bash(WTFLOW_CHECKBOX_SYNC=1 gh *), Bash(WTFLOW_CHECKBOX_SYNC=1 glab *), Bash(WTFLOW_CHECKBOX_SYNC=1 tea *), Bash(./gradlew *), Bash(npm *), Bash(npx *), Read, Edit, AskUserQuestion
disable-model-invocation: false
---

# /wtflow:commit — 워크트리 작업단위 처리

**시작 전에 `${CLAUDE_PLUGIN_ROOT}/references/worktree-discipline.md`(브랜치 이름 규칙·Step 모델·note 종류)와 `${CLAUDE_PLUGIN_ROOT}/references/host-adapter.md`(이슈 호스트 판별·CLI 대응)를 읽는다. 사전문답은 `${CLAUDE_PLUGIN_ROOT}/references/learning-protocol.md`(켜는 자리·질문 형식·질문 전 검사)와 `learning-implementation.md`(§1 예측~§6 유지보수 비용·§10 수용 기준), `learning-impact.md`(§7 영향 범위)를 읽는다. `learning-direction.md`(§8 진행 방향·§9 커밋 경계)는 이슈·계획 단계 몫이라 읽지 않는다. 커밋 메시지 형식은 `${CLAUDE_PLUGIN_ROOT}/references/convention-precedence.md`(어디에 적힌 컨벤션이 우선하는지) 를 먼저 읽고 `commit-convention.md` 를 읽는다. 이슈 작업에서 체크박스를 동기화할 때만 `${CLAUDE_PLUGIN_ROOT}/references/body-rewrite.md`(훅 계약)를 읽는다.**

## 호출

`/wtflow:commit <작업 설명> [--step <번호>] [-a <accumulator>] [-n|--new-topic] [-s|--same-topic] [--done] [--no-test] [--push]`

- `<작업 설명>` (필수): 한 줄 요약. commit subject + 본문에 사용 (언어는 `commit-convention.md` 의 `## Subject` 를 따른다)
- `--step <번호>`: 작업단위(주제) 번호 = mirror 분기 `<mirror base>-<NNN>` 식별자. **작업 항목 번호와 일치**(wtflow:plan plan 의 Step N = 작업 항목 N). 명시 시 그 Step 사용(기존이면 전진, 신규면 생성). 미지정 시 아래 "주제 판단"으로 자동 결정
- `-n` / `--new-topic`: 이번 커밋부터 새 주제 — 새 분기(`기존 최고 Step + 1`) 강제
- `-s` / `--same-topic`: 현재(최고 Step) 분기에 누적 강제
- `-a <accumulator>`: 워크트리 브랜치 (예 `refactor/#30-metric-history-pg-migration`, 이슈 없는 작업이면 `refactor/+metric-history-pg-migration`). 미지정 시 자동 탐지:
  ```
  git branch --list '*/[#+]*' --format='%(refname:short)' | grep -vE -- '-[0-9]{3}$'
  ```
  중 현재 HEAD 와 ancestry 를 공유하는 것(`-<NNN>` 으로 끝나는 건 mirror 라 제외)
- `--done`: 이번 커밋으로 **현재 Step(작업 항목)가 완료**됨을 명시 → 이슈 본문 체크박스 체크(`## 작업 항목 체크박스 동기화`). 주제 전환 없이 끝나는 마지막 Step, 또는 단일 커밋으로 끝나는 Step 에 사용. **이슈 작업 전용** — 이슈 없는 작업엔 켤 체크박스가 없어 무시된다
- `--no-test`: 테스트 단계 생략
- `--push`: 분기 브랜치를 origin 에도 push (기본은 로컬만)

> **체크박스가 있느냐를 accumulator 이름이 정한다.** `/#` 뒤 정수 → 이슈 #N 본문에 체크리스트가
> 있다. `/+` 뒤 문자열 → **체크리스트가 없다** — 완료는 mirror 분기 `<accumulator>-<NNN>` 의 존재로만
> 드러난다. 커밋·분기·테스트 규율은 두 경우가 완전히 같고, 체크박스 동기화(계약 6)만 다르다.

## 한 번 호출 = 한 Step, 그리고 멈춤 (자율 다중 Step 금지)

이 스킬은 **한 작업 항목(Step)의 커밋 하나**를 처리하고 **멈춘다**. 커밋·요약·진행표(계약 8) 출력 후 **다음 Step 을 자율로 이어서 구현·커밋하지 않는다** — 다음 Step 진행은 사용자의 다음 신호를 기다린다.

- **커밋 자체는 묻지 않는다(기본).** 현재 Step 의 구현 + 검증이 끝나면 "커밋할까요?" 승인을 구하지 말고 **곧장 이 스킬을 자율 호출해 커밋**한다. 메시지는 커밋 컨벤션대로 모델이 짓고 결과만 보고. 사용자 신호를 기다리는 유일한 지점은 **다음 Step 으로 넘어갈지**다(커밋 전 승인 ✗ / 다음 Step 진행 승인 ○).
- 자연어 "step3부터 진행", "쭉 가", "남은 거 다 해줘" 가 **여러 Step 을 연속 처리하라는 뜻처럼 읽혀도**, 명시적 `/wtflow:auto` 호출이 없으면 **지명된(없으면 현재) 한 Step 만** 처리하고 멈춰 다음 진행 여부를 묻는다. 예: "step3부터 진행" → **Step 3 하나만**(Step 4 이후 자동 진행 ✗).
- 여러 Step 을 사람 개입 없이 순회하는 건 **오직 사용자가 `/wtflow:auto` 를 직접 호출**했을 때만. wtflow:commit 을 Step 마다 반복 호출하며 **손으로 wtflow:auto 를 흉내내지 말 것**(가장 흔한 오작동 — 이 가드가 그걸 막는다).
- 한 Step 안의 여러 태스크는 **같은 Step 에 커밋 누적** OK. **다른 작업 항목(새 Step)으로 넘어가는 순간** 멈추고 묻는다.
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

3. **워크트리 브랜치에 commit (항상 새 commit, amend 금지)** — subject = `<작업 설명>`, 본문에 요약 / 영향 / 검증 결과(`commit-convention.md` `## 본문`). **이 Step 에서 수용 기준을 골랐으면 `검증` 란은 조건별 한 줄이다**(§10 수용 기준 `### 기록과 미달 처리`) — 저장소 컨벤션에 `검증` 란이 없으면 계약 7 요약에만 적는다. **커밋 전에 `## 커밋 본문 자체 검사` 를 돌린다.** **본문이 그 분량 상한을 넘으면 Step 을 넓게 잡았다는 신호다** — 이 판정은 Step 모델(`worktree-discipline.md`) 소관이라 저장소가 커밋 컨벤션을 덮어도 남는다. 푸터엔 `Co-Authored-By: <현재 실행 중인 모델명> <noreply@anthropic.com>` 만(예: `Claude Opus 4.8 (1M context)` — 이 커밋을 만드는 모델의 이름·버전 그대로. 확실치 않으면 `Claude`). **`Step:` 트레일러 안 넣음** — Step 귀속은 mirror 분기 이름(`-00N`)이 유일 소스라 계약 4의 mirror 전진/생성이 필수(dangling 금지).
   - **`git commit --amend` / rebase / reset 등 history 재작성 절대 금지.** 직전 작업단위에 대한 수정·교정·리뷰 반영이라도 **새 commit 으로 쌓는다**(방금 만든 로컬·미푸시 커밋이라도 amend 하지 않음 — 이력이 곧 작업 기록).
   - 같은 주제의 후속 수정이면 mirror 를 그 새 commit 으로 **FF-전진**(계약 4). amend 가 아니라 누적이므로 force-move 불필요.

4. **분기 브랜치 = 작업단위(Step=주제) 1개, 커밋은 누적** — `<mirror base>-<NNN>`(3자리 zero-padding). 체크아웃 없음, **로컬만**. 커밋마다 새 분기 만들지 않는다.

   > **mirror base = accumulator 이름 그대로.** 뒤에 `-<NNN>` 만 붙인다 — prefix·마커를 따로 유도하지 않는다. accumulator 본체는 워크트리에 체크아웃돼 있어 커밋마다 자동 전진하므로 별도로 `git branch -f` 할 일이 없다.

   - **주제 판단**(`--step`/`-n`/`-s` 없을 때): `<작업 설명>` 이 직전 커밋과 같은 주제면 **현재 분기 전진**, 다른 주제면 **새 분기**
   - **전진(같은 주제 / 기존 Step)**: mirror 를 HEAD 로 **FF-전진**. 커밋이 분기 끝에 누적되므로 fast-forward(force-push 아님). 기존 tip 은 HEAD 의 조상이어야 함
   - **신규(새 주제 / 새 Step)**: `git branch "<mirror base>-<NNN>" HEAD`, Step = (기존 최고 Step)+1. 분기 0개면 Step=1
   - 판단 결과(**전진 vs 신규 + 어느 Step**)를 계약 7 요약에 명시 — 사용자가 틀린 판단을 `-n`/`-s` 로 잡을 수 있게

   **FF-전진(브랜치 X → 워크트리 tip) — 모든 로컬 브랜치 전진에 공통**
   1. `git branch -f X <tip>` → **성공이면 끝**(X 가 어디에도 체크아웃 안 됨 → ref 만 이동)
   2. `fatal: ... checked out at '<PATH>'` 로 **막히면** = 누군가 `<PATH>` 에서 X 를 보고 있는 중 → 그 워킹트리에서 `git -C <PATH> merge --ff-only <worktree-branch>`(ref+워킹트리 함께 전진 → 화면 즉시 갱신). non-FF 거나 `<PATH>` 가 더티면 알리고 skip
   - ⚠️ merge 는 **에러가 가리킨 그 `<PATH>` 에서만.** 임의 워킹트리(예: 메인)에서 돌리면 거기 체크아웃된 **다른 브랜치(예: develop)** 를 엉뚱하게 tip 으로 끌어올려 오염시킨다. `branch -f` 의 실패가 곧 '체크아웃 여부 + 정확한 위치' 를 알려주므로 사전 조회 불필요

   **한 곳에서 보기(viewing)** — 작업물을 한 브랜치에서만 보려면 그 브랜치를 체크아웃해 두면 된다. FF-전진 ②가 체크아웃된 브랜치를 매 커밋 자동으로 살려두므로 별도 viewing 로직이 필요 없다. 다만 mirror `-NNN` 은 Step 이 바뀌면 안 움직이니, **Step 전환을 넘어 항상 최신**을 보고 싶으면 accumulator 본체도 매 커밋 같은 FF-전진으로 올린다(로컬만).

5. **origin push** — `--push` 명시 시만. 분기 브랜치만, MR 미생성

6. **작업 항목 체크박스 동기화 (이슈 작업 전용)** — accumulator 가 `/#<N>` 일 때만. 아래 두 경우에 체크(절차는 `## 작업 항목 체크박스 동기화`). **로컬/push 무관하게 완료 시점에 즉시 반영**(진행 가시성 용도라 "로컬만" 원칙의 예외):
   - **새 Step 으로 전환(신규 분기 생성)** → 직전까지 진행하던 **이전 Step** 를 완료로 보고 체크. 첫 Step(분기 0개 → Step=1)면 이전 Step 없음 → 체크 안 함. 기존 Step 전진(같은 주제·`--step` 재방문·FF)은 완료 신호가 아니라 체크 안 함
   - **`--done` 지정** → 이번 커밋의 **현재 Step** 를 체크

   ⚠️ **미달한 수용 기준이 하나라도 있으면 `--done` 이 와도 체크하지 않는다**(§10 수용 기준
   `### 기록과 미달 처리`). 커밋은 그대로 하고, 어느 조건이 미달인지 계약 7 요약에 적는다 —
   부분 진행도 기록이고 체크박스를 안 켜면 다음 호출이 그 Step 을 이어받는다.

   **accumulator 가 `/+<slug>` 면 이 계약 전체를 건너뛴다** — 체크할 문서가 없다. `--done` 이 와도
   조용히 무시하고(경고 아님 — 정상 경로다) 계약 4 의 mirror 분기가 완료 표시를 대신한다.

7. **요약 출력** — 변경 파일 stat / commit hash / 새 브랜치명 / viewing 브랜치 전진 결과 / 테스트 결과 / push 여부 / **체크한 작업 항목**(`이슈 #N 항목 Step`, 이슈 없는 작업이면 `mirror -00N 생성/전진` 으로 대신)

   **수용 기준을 고른 Step 은 조건별 결과를 함께 적는다** — 미달이 있으면 `--done` 을 안 켠 사실과
   무엇이 남았는지까지(§10 수용 기준 `### 기록과 미달 처리`).

   **이전 Step 의 설계 선택이 이번 커밋에서 유지보수 비용을 드러냈으면 얼마였는지 함께 보고한다**
   (§6 유지보수 비용). 숫자로 적고, 반대 안이 더 쌌으면 그렇게 말한다.
   비용이 아직 안 왔으면 안 왔다고 적는다 — 없는 비용을 지어내면 다음 예측이 무의미해진다.

   ```
   비용 — Step 1 에서 B(판정 분리)를 고르셨고 "호출자가 늘면 A 를 먼저 고쳐야 한다" 고 예측하셨습니다.
            이번 테스트 Step 에서 판정만 단독 테스트 6케이스로 덮었고 스텁은 0줄이었습니다. 예측대로입니다.
   ```

   **셀 수 있는 상한 (쓰고 나서 센다)** — 계약 8 의 진행표가 바로 뒤에 붙어서, 요약이 길면
   표가 화면 밖으로 밀린다:

   | 대상 | 상한 |
   |---|---|
   | 위 항목 각각 | 1줄 — **해당 없는 항목은 줄을 만들지 않는다** |
   | 수용 기준 조건별 결과 | 조건당 1줄 — 미달일 때만 그 조건의 재현 절차 3줄을 덧붙인다 |
   | §6 유지보수 비용 보고 | 3줄 |

   변경 파일 stat 은 이 셈에서 뺀다 — 줄 수가 변경 크기에서 나온다.
   왜 그렇게 커밋했는지는 요약이 아니라 **커밋 본문**이 갖는다 — 여기 옮겨 적지 않는다.

8. **진행 현황 자동 출력** — 요약 직후 `/wtflow:progress --quiet` 1회 호출해 갱신된 Step 표를 덧붙인다. progress 가 표를 못 내도 **커밋은 이미 완료** — 막지 않고 종료

9. **영향 범위 문답 (동작이 바뀌는 커밋만)** — 번호는 뒤지만 **실행은 계약 4 mirror 전진 직후, 계약 6 체크박스 동기화보다 앞이다.** 커밋이 있어야 사용자가 `git show` 로 코드를 놓고 답할 수 있고, 답을 받기 전에 요약이 나가면 문답이 산문에 묻힌다. 절차는 §7 영향 범위, 형식은 그 섹션의 `### 형식`

   **판정·수집·질문·공개·기록의 절차와 상한(호출부 0곳·16곳), `--no-ask` 로 못 끄는 이유, 깨진
   호출부를 같은 Step 의 다음 태스크로 다루는 규칙은 전부 §7 영향 범위가 갖는다. 여기 사본을 두지 않는다.**

   - 이 스킬에서만 다른 것 : 질문 본문에 **방금 낸 commit hash** 를 적어 `git show <hash>` 로 열어 보게 한다
   - 묻지 못한 경우(0곳·16곳 초과)는 그 사실을 **요약(계약 7)에 한 줄로** 적는다

## 결정·중단 트리거

- accumulator 자동 탐지 실패 → 묻고 중단
- 주제 판단 모호 → 기본은 현재 분기 누적(보수적) + 요약에 "주제 불확실—누적함" 명시(`-n` 으로 재지정 가능)
- 같은 Step 인데 기존 분기 tip 이 HEAD 의 조상이 아님(non-FF) → 보고하고 중단 (drift 의심)
- 테스트 실패 → commit 전 중단 + 결과 보고
- 아키텍처 트레이드오프 발견 → 옵션 비교만 제시, 결정 대기
- 스코프 확장 필요 → 진행 전 보고
- 파괴적 동작(force-push, 다른 브랜치 reset, amend/rebase 등 history 재작성, 운영 영향) → 명시적 동의 전 금지. 수정은 항상 새 commit(계약 3)
- 체크박스 동기화 실패(이슈번호 추출 불가 / 이슈 CLI 실패 / 항목 수 < Step / 순서 모호 / 훅이 막음) → **경고만 하고 커밋은 그대로 완료**. 수동 체크 안내, 엉뚱한 항목을 추측해 체크하지 말 것. ⚠️ 이슈 없는 작업은 실패가 아니라 **해당 없음**이라 경고도 내지 않는다

## 짧은 변형

- "테스트 빼고" → `--no-test` · "푸쉬도" → `--push`
- "새 주제" / "분기 새로 떠" → `-n` · "같은 거에 묶어" → `-s`
- "Step12 로" → `--step 12` · "accumulator 는 X" → `-a X`
- "이 작업 항목 끝" / "항목 완료" / "체크해줘" → `--done`

## 커밋 본문 자체 검사

본문을 쓴 뒤 **커밋하기 전에** 해석된 커밋 컨벤션의 검사 표로 대조한다
(`commit-convention.md` 의 `### 분량과 문체`·`### 제목이 diff 와 맞나`, `writing-style.md`,
`convention-precedence.md`).

- **여기에 검사 항목을 적지 않는다.** 컨벤션이 갖는다 — 사본을 두면 둘이 갈라진다
- **컨벤션에 문체 항목이 없는 저장소는 이 단계를 건너뛴다.** 없는 규칙을 만들어 검사하지 않는다
- **줄 수 상한 초과는 Step 을 넓게 잡았다는 신호다**(계약 3). 이 판정만은 컨벤션이 아니라
  Step 모델 소관이라 저장소가 컨벤션을 덮어도 남는다
- 걸린 항목은 고쳐서 커밋한다. 요약에 "문체 검사 N건 수정" 같은 줄을 남기지 않는다 —
  본문을 다듬은 것은 변경 내용이 아니다

## mirror 불변식 (커밋을 mirror 밖에 방치 금지)

mirror 는 **작업단위별 로컬 북마크**일 뿐이다. 최종 산출은 워크트리 브랜치 통째로 PR 1개라 분기 격리·충돌이 없고, 모든 커밋이 한 줄로 선형 누적되므로 전진은 늘 fast-forward(계약 4) — 새 커밋 생성·history 재작성·충돌이 구조적으로 없다(rebase/amend 의 안전한 대체).

**불변식 — 최상단 mirror = worktree tip.** 커밋이 쌓이면(Step 커밋이든 **후속 정정·비-Step chore 든**) 반드시 어떤 mirror 가 tip 을 가리켜야 한다. 새 Step면 새 mirror, 아니면 **최상단 mirror 를 HEAD 로 FF**. **wtflow:commit 을 안 거친 수동 `git commit` 이라도 직접 FF**한다("비-Step 라서 생략" 없음 — 가장 흔한 누락).

**"최상단" 은 번호가 아니라 최근성(ancestry)으로.** Step 은 작업 항목 번호라 커밋 순서와 다를 수 있다(Step 6 을 Step 4 보다 먼저 커밋 → `-006` 이 `-004` 보다 옛 커밋). 최상단 = **HEAD 의 직계 조상 중 가장 최근 tip 을 가진 mirror**. `git for-each-ref`·`merge-base --is-ancestor` 로 판정 — ⚠️ `git branch --list` 의 `+`(다른 워크트리 체크아웃) 마커가 섞여 이름 `sort|tail` 은 틀린다. **손 sort 말고 ancestry 로.**

→ 라벨 번호와 tip 최신도가 어긋나 보이는 건 정상·무해. non-FF(별개 갈래)면 drift 의심 → 중단·보고.

## 작업 항목 체크박스 동기화

**이슈 작업에서만 일어난다.** 작업 항목 N = Step N = mirror `-00N` 의 1:1 매핑을 **이슈 본문의
체크리스트**에 역반영한다. Step 이 완료되면 그 N번째 체크박스를 켠다.

0. **모드 판정** — accumulator 이름이 `/+<slug>` 면 **여기서 끝**(체크할 문서 없음, 경고도 없음).
   `/#<N>` 일 때만 1로 간다
1. **이슈번호 추출** — accumulator 의 `/#` 뒤 정수 = N (repo 는 git remote 자동). 불가면 경고·skip
2. **이슈 본문 로드·쓰기**

   | 로드 | 쓰기 |
   |---|---|
   | 이슈 본문 조회 | 이슈 본문 쓰기 앞에 환경변수 `WTFLOW_CHECKBOX_SYNC=1` |

   **명령과 본문 필드 이름은 `host-adapter.md` 의 `## 이슈 명령 대응` 에서 꺼낸다** — 여기 박지
   않는다. 본문 필드가 GitHub 은 `body`, GitLab 은 `description` 이라 이름째로 다르다.

   ⚠️ **`WTFLOW_CHECKBOX_SYNC=1` 환경변수를 빼지 않는다** — 훅이 왜 막는지와 우회 금지는
   `body-rewrite.md` 가 갖는다. **여기만 이름이 다른 이유**는 본문을 다시 쓰는 게 아니라
   `- [ ]` 한 줄을 켜는 것이라서다.
   - 그러니 **이 환경변수를 붙인 호출은 실제로 체크박스 한 줄만 바꿔야 한다.** 같은 호출에
     본문 손질을 얹으면 예외를 우회로로 쓰는 것이다 — 본문을 고칠 일이면 `/wtflow:issue --rewrite`
3. **Step번째 항목** — `작업 항목`(또는 `작업 계획`) 섹션 **안의** 체크리스트에서 **위에서 Step번째** `- [ ]`/`- [x]` 줄. 항목 수 < Step·섹션 모호 → 경고·skip(추측 금지)
4. **그 줄만 토글** `- [ ]`→`- [x]` (나머지 본문 보존, 이미 `[x]` 면 no-op). 실패 시 경고만, 커밋 흐름 안 막음
5. **요약에 명시** — "이슈 #N 항목 Step 체크", 또는 실패 사유

잘못 체크할 위험(순서 모호 등)이면 체크 말고 수동 안내. 체크리스트 없는 이슈 본문이면 대상 없음 → skip. (멱등: 같은 Step 두 번 체크해도 no-op)
