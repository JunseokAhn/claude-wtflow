#!/usr/bin/env bash
#
# git worktree 안에서만 동작하며, 워크트리에 없는 "로컬 파일"을 심링크로 채운다.
# worktree add 는 추적 파일만 체크아웃하므로 CLAUDE.md / .claude/ / .env* 처럼 gitignore
# (또는 .git/info/exclude) 된 파일이 워크트리에 없어서, Claude 가 프로젝트 지시문과 로컬
# 설정 없이 도는 문제를 막는다.
#
# wtflow note 는 여기서 걸지 않는다 — 남은 note 는 마일스톤 계약 하나뿐이고, 그건 그룹에 여러 개
# 쌓이므로 "어느 것이 이 이슈의 계약인가" 를 이 훅이 알 수 없다. 그 식별은 이슈의 마일스톤 배정을
# 읽을 수 있는 /wtflow:plan 계약 6 이 하고, 해당 문서 하나만 .claude/notes/milestone.md 로 건다.
#
# 언어·프레임워크를 가리지 않는다. 판별은 오직 "linked worktree 인가"이며, 원본에 없는
# 파일은 건너뛰고 대상에 이미 있으면 손대지 않는다. 어떤 경우에도 exit 0 이라 세션을 막지 않는다.
set -u

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

common_dir=$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || exit 0
git_dir=$(git rev-parse --path-format=absolute --git-dir 2>/dev/null) || exit 0

# 메인 체크아웃에서는 두 값이 같다. linked worktree 에서만 갈린다.
[ "$common_dir" = "$git_dir" ] && exit 0

main_root=$(dirname "$common_dir")
worktree_root=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0

[ "$main_root" = "$worktree_root" ] && exit 0
[ -d "$main_root" ] || exit 0

linked=()

link_one() {
  rel="$1"
  src="$main_root/$rel"
  dst="$worktree_root/$rel"

  [ -e "$src" ] || return 0              # 원본 없음 (다른 언어 프로젝트 등)
  if [ -e "$dst" ] || [ -L "$dst" ]; then
    return 0                             # 이미 있음 — 덮어쓰지 않는다
  fi

  mkdir -p "$(dirname "$dst")" 2>/dev/null || return 0
  if ln -s "$src" "$dst" 2>/dev/null; then
    linked+=("$rel")
  fi
}

# Claude 관련 — 어느 언어 프로젝트에서나 동일하게 필요하다.
link_one "CLAUDE.md"
link_one ".claude/docs"
link_one ".claude/settings.local.json"

# ⚠️ .claude/notes 는 여기서 건드리지 않는다. /wtflow:plan 계약 6 이 그 안에 milestone.md 를
# 만들어야 하는데, 이 훅이 .claude/notes 를 홈 그룹 디렉토리로 걸어두면 그 파일이 홈 원본 안에
# 생겨 모든 워크트리가 같은 milestone.md 를 공유하게 된다.

# 로컬 환경 파일 — 이름이 프로젝트마다 다르므로 원본에 실재하는 것만 훑는다.
# .env.example 은 추적 파일이라 워크트리에 이미 있다.
for env_src in "$main_root"/.env*; do
  [ -e "$env_src" ] || continue
  name=$(basename "$env_src")
  [ "$name" = ".env.example" ] && continue
  link_one "$name"
done

[ ${#linked[@]} -eq 0 ] && exit 0

printf '{"systemMessage":"워크트리에 로컬 파일 연결: %s"}\n' "$(IFS=', '; echo "${linked[*]}")"
exit 0
