# claude-worktree-skills

git worktree 위에서 한 작업을 **작업 항목(K) 단위로 분기**하고 **태스크마다 커밋으로 누적**하는 작업 규율 [Claude Code](https://claude.com/claude-code) 스킬셋.
코어는 호스트 무관, 이슈 연동은 옵션 어댑터(현재 GitLab).

![워크트리 기반 작업 규율](./assets/workflow-worktree.svg)

## 스킬

```
코어 — 호스트 무관 (GitHub·GitLab·이슈 없어도 동작)
  /wtflow-commit     태스크 단위 커밋 + accumulator-K(…-00N) 분기 누적
  /wtflow-auto       plan 의 K 자율 순회 (구현 → 검증 → /wtflow-commit → 완료 시 /wtflow-briefing)
  /wtflow-progress   K 진행 현황 표 (읽기 전용)
  /wtflow-briefing   작업 전체를 설계문서형 브리핑으로 정리 (git·대화 근거, 읽기 전용)
  wtflow-clean       워크트리·이슈 브랜치 정리 (#마커 보존)

이슈 어댑터 — 옵션 · GitLab (glab 필요)
  /wtflow-issue      이슈 생성 + 작업 브랜치 셋업
  /wtflow-plan       이슈 → 워크트리 + plan(작업 항목 = K) 매핑
```

개념(2층 모델 · 작업 항목↔`-00N` 분기 · 커밋 규율)은 위 다이어그램에 다 있음. 행동 정책·커밋 컨벤션은 [`CLAUDE.md`](./CLAUDE.md).

## 설치

```
git clone https://github.com/JunseokAhn/claude-worktree-skills.git
cd claude-worktree-skills
./install.sh
```

`skills/*` → `~/.claude/skills/`, `wtflow-clean` → `~/.local/bin/` 심링크 (`CLAUDE_HOME`·`BIN_DIR` 로 변경, 기존 실파일은 안 덮음).

## 비고

- 이슈 어댑터(`wtflow-issue`·`wtflow-plan`)는 `glab` CLI 필요. 코어는 의존성 없음.
- `wtflow-clean` 은 origin 을 건드리지 않음 (로컬 분기·워크트리만).
