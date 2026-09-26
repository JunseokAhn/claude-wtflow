---
name: squash
description: 워크트리 작업의 커밋 이력을 고른 단위로 접어 별도 스쿼시 브랜치로 낸다. "커밋 정리해줘", "이력 접어줘", "스쿼시해줘", "커밋 너무 많아" 요청에. 원본 accumulator 와 mirror 는 손대지 않는다. 사용자만 호출.
allowed-tools: Bash(git *), Bash(wtflow-move-branch *), AskUserQuestion
disable-model-invocation: true
---

# /wtflow:squash — 커밋 이력을 고른 단위로 접기

**시작 전에 `${CLAUDE_PLUGIN_ROOT}/references/worktree-discipline.md`(브랜치 이름 규칙·Step 모델·note 종류)를 읽는다. 커밋 메시지 형식은 `${CLAUDE_PLUGIN_ROOT}/references/convention-precedence.md`(어디에 적힌 컨벤션이 우선하는지) 를 먼저 읽고 `commit-convention.md` 를 읽는다.**

한 작업 항목 안에 진단·재시도 커밋이 쌓이면 브랜치 이력을 리뷰하기 어렵다. 접을 단위는
이미 있다 — mirror `-<NNN>` 이 작업 항목 경계를 선언하고 있다.

**원본을 고치지 않는다.** 접은 결과는 `<accumulator>-squash` 라는 **별도 브랜치**로 나가고,
accumulator 와 mirror 의 커밋 SHA 는 하나도 안 바뀐다. 그래서 `wtflow:commit` 계약 3 의
`history 재작성 절대 금지` 와 mirror 불변식(`최상단 mirror = worktree tip`)을 건드리지 않는다.

## 호출

`/wtflow:squash [-a <accumulator>] [-u <단위>] [-b <base>] [--dry-run]`

| 인자 | 뜻 |
|---|---|
| 생략 | 현재 워크트리의 accumulator 를 대상으로, 단위는 물어서 고른다 |
| `-a <accumulator>` | 대상 워크트리 브랜치 명시. 미지정 시 자동 탐지 (`worktree-discipline.md` 의 accumulator 탐지) |
| `-u <단위>` | 묻지 않고 단위 고정 — `step` · `all` · `churn` · `manual` (아래 `## 접는 단위`) |
| `-b <base>` | 접기 시작점. 미지정 시 accumulator 의 분기 베이스(`develop`, 없으면 `main`) |
| `--dry-run` | 브랜치를 만들지 않고 **접힌 뒤의 커밋 목록만** 출력 |

## 접는 단위

단위는 **`AskUserQuestion` 으로 고르게 한다** — 어느 단위가 맞는지는 이력을 본 사람만 안다.
`-u` 로 명시했으면 묻지 않는다.

| 단위 | 무엇이 한 커밋이 되나 | 언제 |
|---|---|---|
| `step` | mirror `-<NNN>` 경계 하나 = 커밋 하나 | 기본 — `작업 항목 1개 = 커밋 1개` 로 떨어진다 |
| `all` | base..tip 전체 = 커밋 하나 | 작업 자체가 작아 항목 구분이 의미 없을 때 |
| `churn` | 진단·실패 커밋만 **바로 앞 커밋에 흡수** | 항목 경계는 살리고 churn 만 걷을 때 |
| `manual` | 사용자가 준 경계 SHA 마다 커밋 하나 | 위 셋 중 맞는 게 없을 때 |

- **`churn` 판정 규칙은 고정이다** — 아래 중 하나에 걸리는 커밋이 churn 이다:
  - subject 가 `fixup!`·`squash!`·`wip`·`WIP`·`temp`·`debug` 로 시작
  - 바로 앞 커밋과 **subject 가 완전히 같음**
- ⚠️ **churn 판정은 추측이 아니다.** 위 둘 밖의 커밋을 "실패한 시도 같아 보인다" 로 접지 않는다 —
  판정을 넓히면 사용자가 미리보기를 못 믿게 되고, 그러면 이 단위 자체가 안 쓰인다
- `manual` 은 커밋 목록(`%h %s`)을 먼저 내고 **경계가 될 SHA 들**을 받는다. 각 SHA 가 한 구간의
  **마지막 커밋**이고, tip 은 자동으로 마지막 구간의 끝이 된다

## 계약 (보장되어야 하는 것)

1. **원본을 건드리지 않는다** — accumulator·mirror 를 체크아웃하지도, `-f` 로 옮기지도,
   reset·rebase·amend 하지도 않는다. 이 스킬이 쓰는 ref 는 `<accumulator>-squash` 하나뿐이다.
   - 워크트리 브랜치에서 떠나지 않는다(`worktree-discipline.md` 의 행동 정책)

2. **되돌릴 근거는 accumulator 자신이다 — 백업 ref 를 따로 두지 않는다.** 계약 1 이 원본을
   안 건드리므로 접기 전 커밋은 accumulator tip 에서, Step 별로는 mirror `-<NNN>` 에서 그대로
   도달 가능하다. 접어도 잃는 것이 없다.
   - **백업 ref 를 만들지 않는다** — 이미 도달 가능한 것을 한 번 더 가리키는 ref 는 쌓이기만
     하고, 안전장치가 둘로 흩어지면 어느 쪽이 실제로 지키는지가 흐려진다
   - 되찾기: `git log <accumulator>` · `git branch <새 이름> <accumulator>`
   - ⚠️ **그래서 `wtflow-clean` 이 accumulator 를 지울 때 `-squash` 도 같이 지워야 한다.**
     접힌 브랜치만 남으면 그 순간 원본이 도달 불가능해진다 — 이 스킬이 원본 보존으로 성립하는
     전제가 거기서 깨진다

3. **체크아웃 없이 접는다 — `git commit-tree` 를 쓴다.** 워킹트리도 인덱스도 안 건드린다.
   ```
   prev=$(git rev-parse "<base>")
   # 구간마다: 그 구간 마지막 커밋의 트리를 그대로 새 부모 위에 올린다
   tree=$(git rev-parse "<구간 마지막 커밋>^{tree}")
   prev=$(git commit-tree "$tree" -p "$prev" -F "<메시지 파일>")
   ```
   - **`merge --squash` 를 쓰지 않는다** — 인덱스와 워킹트리를 거치므로 워크트리가 더러워지고,
     충돌이 나면 작업 중이던 상태가 깨진다. `commit-tree` 는 오브젝트만 만든다
   - **구간의 트리를 통째로 쓰므로 내용이 안 바뀐다** — diff 를 다시 적용하는 게 아니라
     이미 만들어진 트리를 가리키는 것이라, 접는 과정에 충돌이라는 개념이 없다
   - 마지막 구간의 트리 = accumulator tip 의 트리 → **접힌 브랜치 tip 의 트리 해시가 원본과 같다**

4. **구간 경계는 ancestry 로 정한다 — 이름 정렬로 정하지 않는다.** Step 번호는 작업 항목
   번호라 커밋 순서와 다를 수 있다(Step 6 을 Step 4 보다 먼저 커밋). `step` 단위의 구간은
   `git merge-base --is-ancestor` 로 줄을 세워 만든다.
   ```
   git branch --list '<accumulator>-[0-9][0-9][0-9]' --format='%(refname:short)'
   ```
   - mirror 가 accumulator tip 의 조상이 아니면 그 mirror 는 **구간에서 뺀다** — 갈라진 갈래라
     한 줄로 못 세운다. 뺀 사실을 미리보기에 적는다
   - 최상단 mirror 뒤에 커밋이 더 있으면(비-Step chore 등) **마지막 구간에 붙는다**

5. **스쿼시 브랜치는 accumulator 당 하나** — `<accumulator>-squash`. 이미 있으면 **덮어쓴다**.
   - 이름 규칙과 `-squash-2` 를 만들면 안 되는 이유는 `worktree-discipline.md` 의
     `## 브랜치 이름 규칙 (세 종류, 역할이 다르다)` 가 갖는다. **여기 사본을 두지 않는다**
   - 덮어쓰기 전에 기존 스쿼시 브랜치가 어디를 가리켰는지 계약 9 요약에 적는다
   - **덮어쓰기는 `wtflow-move-branch "<accumulator>-squash" <접은 마지막 커밋>` 으로 한다.**
     `git branch -f` 는 그 브랜치를 다른 워킹트리가 체크아웃 중이면 거부하는데(리뷰하려고 열어 두는
     자리다), 접은 커밋은 옛 tip 의 자손이 아니라 mirror 처럼 FF 머지로 올릴 수도 없다.
     그 스크립트가 물린 워킹트리에서 `checkout -B` 로 갈아끼운다 — 리뷰용 산출물이라
     갈아끼워도 잃는 것이 없다(계약 2)
     - **저장 안 된 변경이 있으면 옮기지 않고 무엇이 남았는지 보고한다** — 그때는 사용자가
       정리한 뒤 다시 부른다. 접은 커밋은 이미 만들어져 있으니 다시 접을 필요는 없다

6. **접힌 커밋의 메시지는 그 구간의 커밋들에서 만든다** — 지어내지 않는다.
   - 구간에 **의미 있는 커밋이 하나**면 그 메시지를 그대로 쓴다
   - 여럿이면 **구간의 비-churn 커밋 전부의 제목·본문을 읽고 커밋 컨벤션대로 새로 쓴다**
     (`commit-convention.md` — 한 커밋을 새로 짓는 것과 같은 규칙이다)
     - **제목** : 구간 전체에서 무엇이 달라졌는지. 마지막 커밋 제목을 그대로 가져오지 않는다 —
       앞 커밋들이 한 변경이 제목에서 사라진다
     - **type** : 동작이 바뀐 커밋(`feat`·`fix`·`perf`, 동작을 바꾼 `refactor`)이 있으면 그쪽을
       `docs`·`chore`·`test`·`style` 보다 앞세운다. `fix` 2개 + `docs` 1개를 접으면 `fix` 다
     - **`요약`** : 원본 본문들이 적어 둔 **왜** 를 모아 2줄 안으로 줄인다. 원본 어디에도 없는
       이유를 만들어 넣지 않는다 — 없으면 란째로 뺀다
     - **`영향`·`검증`** : 구간 끝 시점에도 참인 것만 남긴다 — 뒤 커밋이 되돌린 영향은 뺀다
   - ⚠️ **접은 커밋 수를 본문에 적지 않는다** — 개수는 `요약` 의 "왜" 가 아니고, 미리보기
     (계약 8)와 요약 출력(계약 9)이 이미 낸다
   - 푸터의 `Co-Authored-By` 는 구간 안에 있던 것을 **중복 없이 모아** 남긴다
   - ⚠️ **원본 본문을 이어 붙이지 않는다** — 커밋 컨벤션의 분량 상한(`요약` 2줄·본문 12줄)을
     넘는다. 새로 쓴 메시지도 그 상한 안이어야 한다. 원본 본문은 accumulator 에 그대로 있다

7. **트리 해시를 대조하고, 어긋나면 브랜치를 안 만든다.** 접은 마지막 커밋의 트리는
   원본 tip 의 트리와 **같아야** 한다 — 같지 않으면 내용이 바뀐 것이라 스쿼시가 아니다.
   ```
   git rev-parse "<accumulator>^{tree}"      # 원본
   git rev-parse "<접은 마지막 커밋>^{tree}"   # 접은 결과
   ```
   - **계약 3 대로 접었으면 이 둘은 구조적으로 같다** — 그래도 대조한다. 구간 경계를 잘못
     세워 마지막 구간이 tip 이 아닌 커밋에서 끝나면 조용히 달라지는데, 그걸 잡는 자리가 여기다
   - 어긋나면 **`<accumulator>-squash` 를 만들지도 옮기지도 않는다.** 두 해시와 어느 구간이
     마지막이었는지를 보고하고 멈춘다
   - 만들어 둔 커밋 오브젝트는 ref 가 안 붙어 GC 가 걷어간다 — 따로 지우지 않는다
   - **이 대조는 `--dry-run` 에서도 돈다.** 미리보기가 거짓이면 미리보기의 의미가 없다

8. **미리보기 → 확인 → 생성 순서를 지킨다.** `--dry-run` 이 아니어도 **항상 미리보기를 먼저 낸다**:
   ```
   feat/#37-commit-squash-skill  15커밋  →  feat/#37-commit-squash-skill-squash  4커밋

     -001  252cd91 feat(worktree): 스쿼시 브랜치 이름 규칙 신설 …            (1커밋)
     -002  a1b2c3d feat(squash): 커밋 스쿼시 스킬 신설                      (7커밋 접힘)
     …
   ```
   - 구간마다 **접히는 커밋 수**를 적는다. 1커밋이면 `(그대로)` 로 적어 접히지 않음을 드러낸다
   - 확인은 `AskUserQuestion` — 산문으로 "이대로 만들까요?" 나열 금지

9. **요약 출력** — 스쿼시 브랜치명 / 원본 대비 커밋 수(`15 → 4`) / 구간별 접힌 수 /
   덮어쓴 경우 이전 tip / 원본 accumulator tip(안 바뀌었음을 보이려고 SHA 를 적는다) /
   **트리 해시 대조 결과**

## 결정·중단 트리거

- accumulator 자동 탐지 실패 → 묻고 중단
- base 를 못 구함(분기 베이스가 모호) → `-b` 요청하고 중단. 추측해서 접지 않는다
- 접을 커밋이 **2개 미만** → 접을 게 없다고 알리고 중단. 브랜치를 만들지 않는다
- `step` 단위인데 mirror 가 하나도 없음 → `all`·`manual` 로 갈지 묻는다
- `manual` 인데 받은 SHA 가 base..tip 밖이거나 순서가 ancestry 와 어긋남 → 어느 SHA 가
  문제인지 짚고 중단
- 워크트리 밖에서 `-a` 없이 호출 → accumulator 를 못 정하므로 중단
- **트리 해시 불일치** → 브랜치를 만들지 않고 두 해시와 마지막 구간을 보고하고 중단 (계약 7)
- 파괴적 동작(원본 reset·rebase·amend, force-push) → **이 스킬은 하지 않는다.** 요청받아도
  거절하고 이유를 말한다 — 원본 보존이 이 스킬이 성립하는 전제다

## 짧은 변형

- "작업 항목별로 하나씩" / "Step 단위로" → `-u step`
- "다 합쳐서 하나로" → `-u all`
- "실패한 시도만 걷어줘" / "wip 커밋 정리" → `-u churn`
- "내가 경계 정할게" → `-u manual`
- "일단 어떻게 되는지만" / "미리보기만" → `--dry-run`

## 비고

- 스쿼시 브랜치는 origin 에 push 하지 않는다 — 올리는 것은 `/wtflow:mr` 하나다
- 접은 뒤에도 `wtflow:progress` 의 Step 표는 **원본 mirror** 로 읽는다. 스쿼시 브랜치는
  진행 상태의 근거가 아니다 — 리뷰용 산출물이다
- `wtflow-clean` 은 스쿼시 브랜치를 accumulator 로 세지 않는다(`-squash` 로 끝나는 이름을 제외)
- **`wtflow-clean` 은 accumulator 와 함께 `-squash` 도 지운다** — 접힌 브랜치만 남으면
  원본이 도달 불가능해진다(계약 2)
