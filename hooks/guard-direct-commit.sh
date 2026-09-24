#!/usr/bin/env bash
#
# PostToolUse(Bash) — 스킬을 거치지 않은 커밋 뒤 최상단 mirror 를 tip 까지 끌어올린다.
#
# mirror 분기(`<accumulator>-<NNN>`) 생성·FF 는 wtflow:commit 절차 안에만 있다. 그런데 "커밋 직전에
# 묻지 않는다" 규율은 스킬이 끝난 뒤에도 컨텍스트에 남아, 자연어로 이어간 태스크에서 모델이
# 스킬 대신 `git commit` 을 직접 쳤다. 커밋만 나고 mirror 가 4커밋 뒤처진 사고가 있었다(#47).
#
# **커밋을 막지 않는다.** 막으면 작은 후속 수정마다 스킬 절차를 다시 타게 돼 자율성을 깎는다.
# 대신 커밋이 난 뒤 불변식(최상단 mirror = worktree tip)을 이 자리에서 회복한다.
#
# 이 훅이 못 하는 것 — **새 Step 판단.** 주제가 바뀌었는지는 명령 문자열로 알 수 없어 늘 최상단
# mirror 에 붙인다. 새 작업 항목이면 모델이 `/wtflow:commit --step <N>` 으로 커밋해야 한다.
#
# 건너뛰는 것
#   WTFLOW_COMMIT=1   wtflow:commit 이 스스로를 밝힌 커밋. 그 스킬이 계약 4 로 mirror 를 직접
#                     처리하므로, 여기서 먼저 끌어올리면 이전 Step 의 mirror 가 새 Step 커밋을
#                     삼킨다.
#   작업 브랜치 밖    메인 체크아웃, accumulator 가 아닌 브랜치(mirror·스쿼시·기본 브랜치).
#
# 판정 못 하면 조용히 끝낸다(fail-open). 커밋은 이미 났고, 빠진 FF 는 다음 wtflow:commit 이 잡는다.
set -u

SENTINEL='WTFLOW_COMMIT=1'

absorbed=''                                # 1단계에서 합친 mirror — 모든 알림 앞에 붙는다

note() {                                   # 모델에게만 보이는 알림 — 커밋 흐름은 막지 않는다
  pre=''
  [ -n "$absorbed" ] && pre="작업 브랜치에 없던 커밋을 가진 mirror 를 먼저 합쳤습니다(${absorbed}). 워킹트리가 그만큼 앞으로 갔으니 이어서 작업하기 전에 바뀐 파일을 확인하세요. "
  # git 에러 문구가 그대로 실리므로 JSON 을 깨는 문자를 먼저 턴다
  msg=$(printf '%s' "${pre}$1" | tr '\n\t' '  ' | tr -d '"\\')
  printf '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"%s"}}\n' "$msg"
  exit 0
}

payload=$(cat)

# command·cwd 추출 — 문자열 이스케이프가 섞이므로 손 파싱하지 않는다.
if command -v jq >/dev/null 2>&1; then
  cmd=$(printf '%s' "$payload" | jq -r '.tool_input.command // empty' 2>/dev/null) || exit 0
  cwd=$(printf '%s' "$payload" | jq -r '.cwd // empty' 2>/dev/null) || exit 0
elif command -v python3 >/dev/null 2>&1; then
  cmd=$(printf '%s' "$payload" | python3 -c 'import json,sys
try: print(json.load(sys.stdin).get("tool_input",{}).get("command",""))
except Exception: pass' 2>/dev/null) || exit 0
  cwd=$(printf '%s' "$payload" | python3 -c 'import json,sys
try: print(json.load(sys.stdin).get("cwd",""))
except Exception: pass' 2>/dev/null) || exit 0
else
  exit 0                                   # 파서 없음 → fail-open
fi

[ -n "$cmd" ] || exit 0

# 건너뜀 — 스킬이 센티넬로 스스로를 밝힌 커밋(계약 4 가 mirror 를 직접 처리한다)
case "$cmd" in
  *"$SENTINEL"*) exit 0 ;;
esac

# `git commit` 인가 — `git -C <경로> commit`·`git -c k=v commit` 도 잡고, `git commit-tree` 는 뺀다
commit_re='(^|[;&|(`[:space:]])git([[:space:]]+-[Cc][[:space:]]+[^[:space:]]+|[[:space:]]+--[^[:space:]]+)*[[:space:]]+commit([[:space:]]|$|[;&|)])'
printf '%s' "$cmd" | grep -Eq "$commit_re" || exit 0

# 커밋이 일어난 디렉토리 — `-C <경로>` 가 있으면 그쪽, 없으면 도구 호출의 cwd
target=${cwd:-$PWD}
dash_c=$(printf '%s' "$cmd" | sed -nE 's/.*git[[:space:]]+-C[[:space:]]+("([^"]+)"|'"'"'([^'"'"']+)'"'"'|([^[:space:]]+)).*/\2\3\4/p' | head -n 1)
if [ -n "$dash_c" ]; then
  case "$dash_c" in
    /*) target=$dash_c ;;
    *)  target="$target/$dash_c" ;;
  esac
fi
[ -d "$target" ] || exit 0

git_dir=$(git -C "$target" rev-parse --path-format=absolute --git-dir 2>/dev/null) || exit 0
common_dir=$(git -C "$target" rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || exit 0

# linked worktree 에서만 — 메인 체크아웃은 두 값이 같다
[ "$git_dir" = "$common_dir" ] && exit 0

# accumulator 인가 — `<prefix>/#<N>-<slug>` 또는 `<prefix>/+<slug>`, `-<NNN>`·`-squash` 로 끝나지 않는 것
branch=$(git -C "$target" symbolic-ref --quiet --short HEAD 2>/dev/null) || exit 0
case "$branch" in
  */\#*|*/+*) ;;
  *) exit 0 ;;
esac
printf '%s' "$branch" | grep -Eq -- '-([0-9]{3}|squash)$' && exit 0

head=$(git -C "$target" rev-parse HEAD 2>/dev/null) || exit 0

# ── 1단계 : HEAD 에 없는 커밋을 가진 mirror 를 먼저 흡수한다 ─────────────────────────────
# 사용자가 자기 체크아웃에서 mirror 브랜치에 커밋하면 그 커밋은 작업 브랜치에 없다. 흡수하지
# 않으면 두 줄이 갈라진 채로 쌓이고, 나중에 어느 쪽을 버릴지 사람이 골라야 한다.
# 이력을 지우는 수단(rebase·reset·amend)은 쓰지 않는다 — FF 아니면 머지다.
while read -r ref; do
  [ -n "$ref" ] || continue
  git -C "$target" merge-base --is-ancestor "$ref" HEAD 2>/dev/null && continue   # 뒤에 있음 — 2단계 몫
  if [ -n "$(git -C "$target" status --porcelain 2>/dev/null)" ]; then
    note "mirror ${ref} 에 이 작업 브랜치에 없는 커밋이 있는데, 워킹트리에 저장 안 된 변경이 있어 합치지 못했습니다. 변경을 커밋하거나 치운 뒤 다시 시도해야 합니다 — 사용자에게 그대로 알리세요."
  fi
  if git -C "$target" merge-base --is-ancestor HEAD "$ref" 2>/dev/null; then
    merr=$(git -C "$target" merge --ff-only "$ref" 2>&1) || \
      note "mirror ${ref} 가 이 커밋보다 앞서 있어 따라가려 했으나 실패했습니다: ${merr}. 사용자에게 알리세요."
    absorbed="${absorbed} ${ref}(따라감)"
  else
    merr=$(git -C "$target" merge --no-ff --no-edit "$ref" 2>&1) || {
      git -C "$target" merge --abort 2>/dev/null
      note "mirror ${ref} 와 이 작업 브랜치가 갈라졌고 합치는 중 충돌이 났습니다: ${merr}. 머지를 되돌렸습니다 — 어느 쪽을 남길지는 사용자가 정해야 합니다. 커밋은 그대로 있습니다."
    }
    absorbed="${absorbed} ${ref}(머지)"
  fi
  head=$(git -C "$target" rev-parse HEAD 2>/dev/null) || exit 0
done <<EOF
$(git -C "$target" for-each-ref --format='%(refname:short)' "refs/heads/${branch}-[0-9][0-9][0-9]" 2>/dev/null)
EOF

# ── 2단계 : 최상단 mirror 를 tip 으로 끌어올린다 ────────────────────────────────────────
# 최상단 mirror = HEAD 의 조상 중 HEAD 에 가장 가까운 것 — 이름 sort 도 커밋 시각도 아니다.
# 시각은 같은 초에 난 커밋들을 구분하지 못하고, 이름은 Step 번호라 커밋 순서와 다를 수 있다.
top=''; top_gap=-1
while read -r ref; do
  [ -n "$ref" ] || continue
  git -C "$target" merge-base --is-ancestor "$ref" HEAD 2>/dev/null || continue
  gap=$(git -C "$target" rev-list --count "$ref..HEAD" 2>/dev/null) || continue
  # 같은 커밋을 가리키는 mirror 가 둘이면 번호가 큰 쪽(나중 Step)을 고른다
  if [ "$top_gap" -lt 0 ] || [ "$gap" -lt "$top_gap" ] ||
     { [ "$gap" -eq "$top_gap" ] && [ "$ref" \> "$top" ]; }; then
    top=$ref; top_gap=$gap
  fi
done <<EOF
$(git -C "$target" for-each-ref --format='%(refname:short)' "refs/heads/${branch}-[0-9][0-9][0-9]" 2>/dev/null)
EOF

if [ -z "$top" ]; then
  note "작업 브랜치 ${branch} 에 커밋했는데 이 커밋에 닿는 mirror 분기가 없습니다. Step 분기는 /wtflow:commit 이 만듭니다 — 이 작업을 어느 작업 항목으로 둘지 정해 /wtflow:commit 으로 --step <N> 을 주고 커밋하세요."
fi

top_sha=$(git -C "$target" rev-parse "$top" 2>/dev/null) || exit 0
if [ "$top_sha" = "$head" ]; then          # 이미 tip — 커밋이 안 났거나 1단계가 맞춰 놨다
  [ -n "$absorbed" ] && note "mirror ${top} 는 그 결과와 같은 커밋이라 더 옮길 것이 없습니다."
  exit 0
fi

err=$(git -C "$target" branch -f "$top" "$head" 2>&1) && {
  note "스킬을 거치지 않은 커밋이라 mirror ${top} 를 이 커밋으로 전진시켰습니다. 주제가 바뀐 커밋이었다면 이 mirror 가 아니라 새 Step 이어야 합니다 — 그때는 /wtflow:commit --step <N> 으로 다시 잡으세요."
}

# 다른 워킹트리가 그 mirror 를 체크아웃 중이면 ref 만 옮길 수 없다. 에러가 그 경로를 알려주므로
# 거기서 FF 머지로 ref 와 워킹트리를 함께 올린다 — 훅은 세션 격리를 안 받아 이 경로를 쓸 수 있다.
# (`git -C <PATH> merge --ff-only` 는 규율이 정한 우회로인데, 워크트리에 격리된 세션에서는
#  harness 가 거부해 모델이 실행하지 못한다 — 그래서 여기서 대신 한다)
held=$(printf '%s' "$err" | sed -nE "s/.*checked out at '([^']+)'.*/\1/p" | head -n 1)
if [ -n "$held" ] && [ -d "$held" ]; then
  if [ -n "$(git -C "$held" status --porcelain 2>/dev/null)" ]; then
    note "mirror ${top} 를 ${held} 가 체크아웃 중이고 그 워킹트리가 더티라 전진시키지 못했습니다. 그 변경을 정리한 뒤 거기서 git merge --ff-only ${branch} 를 돌려야 합니다 — 사용자에게 그대로 알리세요."
  fi
  merr=$(git -C "$held" merge --ff-only "$branch" 2>&1) && {
    note "mirror ${top} 를 ${held} 가 체크아웃 중이라 그 워킹트리에서 FF 머지로 전진시켰습니다. 그 화면도 이 커밋으로 갱신됐습니다."
  }
  note "mirror ${top} 를 ${held} 에서 FF 머지로도 전진시키지 못했습니다: ${merr}. 별개 갈래(non-FF)면 drift 이므로 손대기 전에 사용자에게 알리세요."
fi

note "mirror ${top} 를 이 커밋으로 전진시키지 못했습니다: ${err}. 별개 갈래(non-FF)면 drift 이므로 손대기 전에 사용자에게 알리세요."
