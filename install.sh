#!/usr/bin/env bash
# claude-worktree-skills 설치
# 스킬을 ~/.claude/skills/ 에, wtflow-clean 을 ~/.local/bin/ 에 심볼릭 링크한다.
# 환경변수로 위치 변경 가능: CLAUDE_HOME(기본 ~/.claude), BIN_DIR(기본 ~/.local/bin)
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_DST="${CLAUDE_HOME:-$HOME/.claude}/skills"
BIN_DST="${BIN_DIR:-$HOME/.local/bin}"

link() { # link <src> <dst>
  local src="$1" dst="$2"
  if [ -e "$dst" ] && [ ! -L "$dst" ]; then
    echo "  ⚠ 건너뜀 (실파일 존재 — 백업 후 재실행): $dst"; return
  fi
  ln -sfn "$src" "$dst"
  echo "  ✓ $(basename "$dst")"
}

mkdir -p "$SKILLS_DST" "$BIN_DST"

echo "스킬 → $SKILLS_DST"
for d in "$SRC"/skills/*/; do
  link "${d%/}" "$SKILLS_DST/$(basename "$d")"
done

echo "스크립트 → $BIN_DST"
link "$SRC/bin/wtflow-clean" "$BIN_DST/wtflow-clean"

echo
echo "완료."
echo "· CLAUDE.md 를 글로벌 가이드로 쓰려면:  ln -s \"$SRC/CLAUDE.md\" \"${CLAUDE_HOME:-$HOME/.claude}/CLAUDE.md\""
echo "· PATH 에 $BIN_DST 가 없으면 추가하세요."
echo "· GitLab 어댑터(wtflow-issue·wtflow-plan)는 glab CLI 가 필요합니다."
