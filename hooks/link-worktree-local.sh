#!/usr/bin/env bash
#
# git worktree 안에서만 동작하며, 워크트리에 없는 "로컬 파일"을 심링크로 채운다.
# worktree add 는 추적 파일만 체크아웃하므로 CLAUDE.md / .claude/ / .env* 처럼 gitignore
# (또는 .git/info/exclude) 된 파일이 워크트리에 없어서, Claude 가 프로젝트 지시문과 로컬
# 설정 없이 도는 문제를 막는다.
#
# wtflow note 는 여기서 걸지 않는다 — 남은 note 는 마일스톤 계약 하나뿐이고, /wtflow:plan 계약 6 이
# 이슈의 마일스톤 배정에서 경로를 조립해 홈 원본(~/.claude/notes/<group>/_milestone/)을 직접 읽는다.
# 워크트리에 걸어줄 이유가 없다.
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

# ⚠️ .claude/notes 는 여기서 건드리지 않는다. 마일스톤 note 를 읽는 유일한 소비자(/wtflow:plan
# 계약 6)가 홈 절대경로로 직접 읽으므로 워크트리 심링크에 소비자가 없다. 예전엔 그룹 디렉토리를
# 통째로 걸었는데, 빈 그룹 디렉토리를 mkdir 로 만들어두는 부작용까지 있어 함께 걷어냈다.

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
