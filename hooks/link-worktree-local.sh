#!/usr/bin/env bash
#
# git worktree 안에서만 동작하며, 워크트리에 없는 "로컬 파일"을 심링크로 채운다.
# worktree add 는 추적 파일만 체크아웃하므로 CLAUDE.md / .claude/ / .env* 처럼 gitignore
# (또는 .git/info/exclude) 된 파일이 워크트리에 없어서, Claude 가 프로젝트 지시문과 로컬
# 설정 없이 도는 문제를 막는다.
#
# wtflow note(~/.claude/notes/<group>/)도 여기서 .claude/notes 로 걸어준다 — git 밖에 단일
# 실체로 두고 심링크로 꽂아야 진행 중 고친 계약이 다른 브랜치·세션에서 즉시 읽힌다.
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

# src 를 절대경로로 받는다. note 처럼 메인 체크아웃 밖(홈)에 원본이 있는 경우가 있어서
# link_one 은 이 함수의 얇은 래퍼로 둔다.
link_from() {
  src="$1"
  rel="$2"
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

link_one() {
  link_from "$main_root/$1" "$1"
}

# Claude 관련 — 어느 언어 프로젝트에서나 동일하게 필요하다.
link_one "CLAUDE.md"
link_one ".claude/docs"
link_one ".claude/settings.local.json"

# wtflow note (~/.claude/notes/<group>/) — 이슈·마일스톤 계획.
#
# 마일스톤 note 는 여러 이슈 브랜치가 공유하고 진행 중에 고쳐지며, 그 수정이 다른 세션에서도
# 즉시 읽혀야 한다. 브랜치에 커밋하면 브랜치마다 사본이 갈라져 이 요구를 못 지킨다 —
# 그래서 홈에 단일 실체를 두고 심링크로 꽂는다.
#
# 그룹 단위로만 건다. 통짜로 걸면 무관한 그룹의 note 까지 다 보인다.
# 마일스톤이 없어도 이슈 note 가 같은 트리에 있으므로 경로는 동일하다.
remote=$(git -C "$main_root" remote get-url origin 2>/dev/null) || remote=""
if [ -n "$remote" ]; then
  # git@host:ns/repo.git · https://host/ns/repo.git → ns/repo
  ns_repo=$(printf '%s' "$remote" | sed -e 's#^[a-zA-Z+]*://[^/]*/##' -e 's#^[^@]*@[^:]*:##' -e 's#\.git$##')
  group=$(dirname "$ns_repo")
  case "$group" in .|/*|'') group="" ;; esac      # 로컬 경로 remote 등은 그룹이 없다
  if [ -n "$group" ]; then
    # 원본을 먼저 만든다. 없다고 건너뛰면 — 마일스톤 없는 첫 이슈가 딱 이 경우다 — 심링크가
    # 영영 안 걸리고, 나중에 워크트리 안에서 note 를 쓸 때 거기에 *실제* 디렉토리가 생겨
    # 홈 원본과 영구히 갈라진다.
    mkdir -p "$HOME/.claude/notes/$group" 2>/dev/null || true
    link_from "$HOME/.claude/notes/$group" ".claude/notes"
  fi
fi

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
