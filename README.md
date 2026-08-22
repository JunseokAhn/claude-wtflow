# claude-wtflow

claude cli로 병렬작업을 수행할 때 필요한 요청들을 스킬로 만들어둔 스킬세트.  
작업단위별로 브랜치와 커밋을 분리하여 작업추적 및 수행을 돕습니다.

![워크트리 기반 작업 규율](./assets/workflow-worktree.svg)

## 설치

```
/plugin marketplace add JunseokAhn/claude-wtflow 
/plugin install wtflow@claude-kit
```


## 스킬

```
  /wtflow:milestone  여러 이슈에 걸친 큰 작업단위의 공통 계약 작성 + 이슈 분할 생성 ( wtflow:issue의 오케스트레이터)
  /wtflow:issue      3~5개의 작업항목을 포함한 이슈를 생성
  /wtflow:plan -N    이슈번호를 받아 작업계획 수립
  /wtflow:commit     작업계획을 태스크 단위로 실행 및 커밋
  /wtflow:auto       작업계획을 태스크단위로 전부 실행 및 단위별 커밋
  
  /wtflow:progress   진행 현황 표 출력
  /wtflow:briefing   작업결과를 문서형태로 정리

  /wtflow:merge      워크트리 충돌시 해소
  /wtflow:clean      생성된 워크트리·브랜치 제거

  /wtflow:mr         작업 브랜치를 origin 에 올리고 MR 생성
```

## 작업단위 분리

wtflow가 자동으로 브랜치를 생성합니다.
작업항목 단위별로 브랜치를 생성하여 검증 및 항목단위 롤백을 돕습니다.


| 이슈 | 워크트리 | 브랜치 | 커밋 |
|---|---|---|---|
| 작업항목1 | `feat/#1-wtflow-intro` | `feat/#1-wtflow-intro-001` | commit1<br>commit2 |
| 작업항목2 | `feat/#1-wtflow-intro` | `feat/#1-wtflow-intro-002` | commit3 |
| 작업항목3 | `feat/#1-wtflow-intro` | `feat/#1-wtflow-intro-003` | commit4<br>commit5 |


## 작업계획 공유

마일스톤으로 여러 이슈를 생성하고 동시에 실행할 경우, 
공통계약 및 작업계획을 자동으로 공유하고 갱신합니다.

```
~/.claude/notes/<group>/
  <repo>/issue-<N>.md         착수 전 계약·배경의 1회 스냅샷 (issue 가 쓴다)
  _milestone/<iid>-<slug>.md  여러 이슈·레포가 공유하는 계약 (milestone 이 쓴다)
```


## 컨벤션 승계

커밋·이슈·MR 형식 컨벤션을 wtflow에서 기본값으로 제공합니다.
저장소나 사용자가 이미 적어둔 컨벤션규칙이 있으면 승계해서 사용합니다.

아무것도 적어두지 않았다면 아래 값이 적용됩니다. **어느 것도 특정 언어나 라벨 체계를
강요하지 않습니다.**

| | 설정이 없을 때 |
|---|---|
| 제목의 언어·어투 | **정하지 않습니다.** 저장소의 최근 커밋을 보고 맞춥니다 |
| 이슈 라벨 | **붙이지 않습니다** |
| MR 본문 | 저장소 템플릿. 없으면 `templates/pull-request/default.md` |
| 이슈 본문 | 저장소 템플릿. 없으면 `templates/issue/*.md` (종류별) |

`templates/` 아래 파일을 그대로 고쳐 쓰거나, 저장소에 자기 템플릿을 두면 그쪽이 이깁니다.
이슈 템플릿은 종류(버그·기능·문서·인프라)마다 하나씩이고, 어느 것을 쓸지는 제목의
prefix 로 고릅니다.
