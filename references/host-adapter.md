# 이슈 호스트 어댑터

이슈를 읽고 쓰는 스킬이 공유하는 규칙. **어느 호스트인지 판별하는 자리를 여기 하나로 둔다.**
**`issue`·`plan`·`progress`·`commit`·`milestone`·`briefing` 이 시작 전에 읽는다.**

브랜치 이름·K 모델·note 계층은 `worktree-discipline.md`, 커밋 메시지 형식은
`commit-convention.md` 를 본다.

## 판별은 remote 주소 하나로 — 묻지 않는다

`git remote get-url origin` 의 호스트 부분만 본다. `-R <repo>` 처럼 다른 저장소를 명시받았으면
그 주소로 판별한다.

| remote 호스트 | 호스트 | CLI |
|---|---|---|
| `github.com` | GitHub | `gh` |
| `gitlab.com` | GitLab | `glab` |
| Gitea·Forgejo·Codeberg | Gitea 계열 | `tea` |
| 그 외 | 판별 실패 | 아래 `## 판별이 안 되면 묻는다` |

- **자체호스팅은 주소만으로 못 가른다.** `gitlab.example.com` 처럼 이름에 단서가 있으면 그걸 쓴다
- `tea` 는 Gitea 서버용으로 만들어졌다. Forgejo·Codeberg 는 Gitea 에서 갈라져 나온 것이라
  대체로 통하지만 **공식 문서가 보장하지는 않는다** — 실패하면 API 로 내려간다

## 판별이 안 되면 묻는다 — CLI 를 하나씩 시험하지 않는다

주소에 단서가 없으면 사용자에게 어느 호스트인지 묻고 멈춘다.
`gh` → 실패 → `glab` → 실패 → `tea` 순으로 찔러보지 않는다.

**Why:** 실패한 호출이 남기는 것이 호스트마다 다르다. 조회는 대개 무해하지만 생성·수정이
섞이면 어디까지 반영됐는지 알 수 없게 된다. 판별은 쓰기 전에 끝나 있어야 한다.

## CLI 가 실패하면 에러를 읽는다 — 다른 CLI 로 재시도하지 않는다

각 CLI 는 남의 호스트에서 실패할 때 이유를 밝힌다. `glab` 은 설정된 remote 까지 찍어준다:

```
ERROR: could not determine base repository: none of the git remotes
configured for this repository point to a known GitLab host.
Configured remotes: github.com
```

이 메시지가 곧 판별 결과다. 읽고 이 문서의 표로 돌아온다.

## CLI 로 안 되는 것은 API 로 내려간다

CLI 하위명령이 없거나 호스트마다 모델이 다른 작업(마일스톤이 대표적)은 raw API 를 쓴다.
**통로가 호스트마다 다르고, Gitea 계열에는 아예 없다:**

| CLI | raw API 통로 |
|---|---|
| `gh` | `gh api` |
| `glab` | `glab api` |
| `tea` | **없음** — `curl` + 토큰 |
| 판별 실패 | 해당 없음 (위에서 이미 멈춘다) |

- 표에 없는 호스트(Bitbucket 등)도 CLI 가 없으니 전부 이 경로다
- ⚠️ **API 로 내려가도 본문 쓰기는 그대로 계약 대상이다.** `gh api --method PATCH … -f body=`
  같은 형태는 `hooks/guard-body-edit.sh` 가 잡지 못하므로, 훅이 막지 않는다는 것이
  계약을 안 타도 된다는 뜻이 아니다. 이슈 본문은 `wtflow:issue` 의 재작성 모드로만 바꾼다

## 이슈 명령 대응 — 스킬은 이 표를 보고 부른다

각 스킬 본문에 한 호스트의 명령을 박아두지 않는다. **하는 일(왼쪽 열)로 찾아 이 표에서 꺼낸다.**

| 하는 일 | GitHub (`gh`) | GitLab (`glab`) | Gitea (`tea`) |
|---|---|---|---|
| 이슈 본문·제목 조회 | `gh issue view <N> --json body,title` | `glab issue view <N> --output json` | `tea issue <N> --output json` |
| 이슈 생성 | `gh issue create -t … -l … -F <파일>` | `glab issue create -t … -l … -d "…"` | `tea issue create -t … -l …` |
| 이슈 본문 쓰기 | `gh issue edit <N> --body-file <파일>` | `glab issue update <N> -d "$(cat <파일>)"` | `tea issue edit <N>` |
| 라벨 목록 | `gh label list` | `glab label list -R <repo>` | `tea label ls` |

⚠️ **응답 필드 이름이 다르다 — 명령만 갈아끼우면 깨진다:**

| | 본문 | 번호 |
|---|---|---|
| GitHub | **`body`** | `number` |
| GitLab | **`description`** | `iid` |

`gh issue view <N> --json description` 은 존재하지 않는 필드라 그 자리에서 실패한다.
`gh` 의 `--json` 은 필드를 **명시해야** 하고(`--output json` 처럼 통째로 주지 않는다),
없는 이름을 주면 쓸 수 있는 필드 목록과 함께 에러를 낸다.

⚠️ **본문 쓰기는 어느 호스트든 계약 대상이다** — `wtflow:issue` 의 재작성 모드,
또는 `wtflow:commit` 의 체크박스 동기화만이 정당한 경로다(`hooks/guard-body-edit.sh`).
계약을 다 거쳤음을 밝히는 환경변수(명령 앞에 붙인다)는 호스트를 갈아끼워도 그대로 붙인다.

- `gh` 는 본문을 파일로 넘기는 옵션이 있다(`--body-file`, 단축 `-F`). `glab` 에는 없어
  `-d "$(cat <파일>)"` 로 넘긴다 — 줄바꿈·백틱·따옴표 때문에 인자에 직접 이어붙이지 않는다
- 표에 없는 하는 일(마일스톤 등)은 `## CLI 로 안 되는 것은 API 로 내려간다` 로 간다

## 마일스톤 — 계층이 있는 호스트와 없는 호스트

**여기는 명령을 갈아끼우는 문제가 아니라 개념이 다른 문제다.**

| | 마일스톤이 사는 곳 | 여러 저장소가 공유 | 식별자 |
|---|---|---|---|
| GitLab | 그룹 **또는** 프로젝트 | ✅ 그룹 마일스톤 | `id`(글로벌) · `iid`(프로젝트 안 번호) |
| GitHub | 저장소만 | ❌ **조직 레벨이 없다** | `number` |
| Gitea 계열 | 저장소만 | ❌ | `id` |

**계층이 없는 호스트에서는 저장소 마일스톤으로 내리고, 여러 저장소를 묶는 일은 마일스톤 note 가 맡는다.**

- 저장소마다 **같은 제목**의 마일스톤을 만든다. 그게 사람이 보는 묶음이다
- 여러 저장소에 걸친 계약의 진실원은 원래도 note 였다(`worktree-discipline.md`). 잃는 건
  GitLab UI 에서 한 화면에 모아 보는 것뿐이고, 계약 자체는 안 잃는다
- ⚠️ **없는 계층을 흉내내지 않는다** — 조직 레벨 마일스톤이 없는 호스트에서 그걸 만들려고
  API 를 뒤지지 않는다. 없으면 없는 것이다

**note 경로에 쓰는 식별자도 갈린다** — `~/.claude/notes/<group>/_milestone/<식별자>-<slug>.md`:

| GitLab | GitHub | Gitea |
|---|---|---|
| `iid` | `number` | `id` |

이슈 조회 응답에서 마일스톤 객체를 꺼낼 때 이 이름으로 읽는다. **`iid` 를 GitHub 응답에서 찾으면
비어 있고, 그러면 마일스톤이 없는 것으로 잘못 판정한다.**

## 호스트마다 갈리는 건 명령 이름만이 아니다

명령만 갈아끼우면 되는 줄 알고 접근하면 깨진다. 아래로 갈수록 대응이 안 되고 **정책을 정해야 한다:**

| 갈리는 층 | 예 | 대응 |
|---|---|---|
| 명령 이름 | `glab issue update` ↔ `gh issue edit` | 표로 대응된다 |
| 플래그 | `-d` ↔ `--body` · `--body-file`(단축 `-F`) | 표로 대응된다 |
| 응답 필드 이름 | GitLab `description` ↔ GitHub `body` | 표로 대응된다 |
| 개념 자체 | GitLab 그룹 마일스톤 — GitHub 에 없음 | **대응이 없다 — 정책** |
| 값 자체 | 라벨 `종류:*` — 저장소마다 있을 수도 없을 수도 | **대응이 없다 — 정책** |

⚠️ **아래 두 줄을 표로 풀려고 하지 않는다.** 없는 것을 억지로 대응시키면 조용히 틀린 값이
들어간다. 없으면 없다고 적고, 그때 무엇을 할지를 정해 둔다.
