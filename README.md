# claude-wtflow

claude cli로 병렬작업을 수행할 때 필요한 요청들을 스킬로 만들어둔 스킬세트.  
작업단위별로 브랜치와 커밋을 분리하여 작업추적 및 수행을 돕습니다.

![워크트리 기반 작업 규율](./assets/workflow-worktree.svg)

## 설치

```
/plugin marketplace add JunseokAhn/claude-wtflow      ← 마켓플레이스 등록 (소스 레포)
/plugin install wtflow@claude-kit                     ← 플러그인 설치 (플러그인@마켓플레이스)
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

```

## 작업계획 공유

마일스톤으로 여러 이슈를 생성하고 동시에 실행할 경우, 
공통계약 및 작업계획을 자동으로 공유하고 갱신합니다.

```
~/.claude/notes/<group>/
  _milestone/<iid>-<slug>.md  여러 이슈·레포가 공유하는 계약
  <repo>/issue-<N>.md         이슈 하나의 계획 (K별 계약·파일 위치)
  <repo>/adhoc-<slug>.md      이슈 없이 시작한 작업의 계획 + 작업 항목 체크리스트
```

