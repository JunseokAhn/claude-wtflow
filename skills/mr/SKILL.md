---
name: mr
description: 작업 브랜치를 origin 에 올리고 MR 을 생성한다. "MR 올려줘", "머지 리퀘스트 올려줘", "리뷰 올려줘" 요청에. 제목은 커밋 컨벤션을 따르고 본문은 브리핑 압축본을 쓴다. 사용자만 호출.
allowed-tools: Bash(glab *), Bash(git *), Read, AskUserQuestion, Skill
disable-model-invocation: true
---

# /wtflow:mr — 작업 브랜치로 MR 생성

**시작 전에 `${CLAUDE_PLUGIN_ROOT}/references/commit-convention.md`(`## Subject`)를 읽는다** — MR 제목이 그 규칙을 그대로 쓴다.

작업이 끝난 브랜치를 origin 에 올리고 MR 을 연다. `/wtflow:merge` 와 **방향이 갈린다**:

| | 방향 | 하는 일 |
|---|---|---|
| `/wtflow:merge` | 기본 브랜치 → 현재 브랜치 | 최신 기본 브랜치를 가져와 충돌을 해소해 커밋 |
| `/wtflow:mr` | 현재 브랜치 → 기본 브랜치 (요청) | origin 에 올리고 MR 을 열어 리뷰에 맡긴다 |

⚠️ 그래서 **이 스킬만이 기본 브랜치를 바꿀 수 있는 경로**다. 로컬에서 기본 브랜치에 직접 머지해
push 하면 리뷰를 건너뛴다 — 그 길을 쓰지 않는다.

## 호출

`/wtflow:mr [이슈번호] [-t <제목>] [-b <타깃>] [--draft] [--no-push]`

| 인자 | 뜻 |
|---|---|
| 생략 | 현재 워크트리의 accumulator 가 소스, 기본 브랜치가 타깃 |
| `<이슈번호>` | 그 이슈의 accumulator 를 소스로 (위치 무관) |
| `-t <제목>` | 제목 강제. 미지정 시 이슈 제목·커밋에서 유도 |
| `-b <타깃>` | 타깃 브랜치. 미지정 시 `develop`, 없으면 `main` |
| `--draft` | Draft MR 로 생성 |
| `--no-push` | push 를 건너뛴다(이미 올려둔 경우) |

## 계약 (보장되어야 하는 것)

1. **accumulator 를 origin 에 push 한다 — 규율의 예외다.** 워크트리 브랜치는 로컬 전용이고
   origin 에 노출되는 건 mirror 뿐이라는 규칙(`plan` 계약·`auto` 비고)의 **유일한 예외**가 이 스킬이다.
   MR 은 소스 브랜치가 origin 에 있어야 성립하고, 그 브랜치는 작업 전체를 담은 accumulator 여야 한다
   - **mirror(`-<KKK>`)를 소스로 쓰지 않는다** — K 단위 조각이라 통짜 MR 이 안 된다
   - push 는 이 명령이 부를 때만. 다른 스킬은 여전히 accumulator 를 올리지 않는다
   - 되돌리기: MR 을 닫고 `git push origin --delete '<accumulator>'`
2. **제목은 커밋 컨벤션의 `## Subject` 를 그대로 쓴다** — `<type>(<scope>): <한글 요약>`, 명사구 종결,
   두 산출물이면 `+` 병기. 이슈가 있으면 이슈 제목을 그대로 쓰는 것이 기본이다(같은 규칙으로 쓰였다)
3. **force-push 하지 않는다.** 이미 올라간 브랜치가 갈라져 있으면 멈추고 보고한다

4. **이미 열린 MR 이 있으면 만들지 않는다** — 먼저 확인한다:
   ```
   glab mr list -s '<accumulator>'
   ```
   있으면 그 URL 을 보고하고 끝낸다. 본문·제목 갱신은 사용자 결정이다(중복 MR 을 만들지 않는다)

5. **push 를 먼저, 생성을 나중에** — 순서를 뒤집지 않는다:
   ```
   git push -u origin '<accumulator>'
   glab mr create -s '<accumulator>' -b <타깃> …
   ```
   - glab 의 `--push` 는 **MR 을 만든 뒤** 올리므로 쓰지 않는다. 생성 시점에 소스 브랜치가 이미
     origin 에 있어야 타깃 대비 diff·충돌을 판단할 수 있다
   - `--create-source-branch` 도 쓰지 않는다 — 커밋 없는 빈 브랜치가 올라갈 수 있다

6. **비대화형으로 부른다 — `-y` 와 `--no-editor` 를 반드시 붙인다.**
   ```
   glab mr create -s '<accumulator>' -b <타깃> -t "<제목>" -d "<본문>" -y --no-editor
   ```
   ⚠️ 빼면 glab 이 제목·본문·확인을 입력받으려 기다리는데, **이 명령에는 사용자 입력이 도달하지
   않는다**(터미널이 아니라 도구를 통해 실행되므로). 멈춘 채 타임아웃되거나 빈 값으로 통과한다

7. **이슈가 있으면 `-i <이슈번호>` 를 함께 넘긴다** — MR 과 이슈가 엮이고, `-t` 가 없으면 제목을
   이슈에서 가져온다. `-t` 가 주어지면 그것이 이긴다
   - 라벨을 이슈에서 가져오려면 `--copy-issue-labels` 를 붙인다(`-i` 와 함께만 동작)

8. **`--draft` 는 사용자가 줬을 때만.** 임의로 Draft 로 만들지 않는다
