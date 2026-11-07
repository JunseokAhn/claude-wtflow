#!/usr/bin/env bash
#
# UserPromptSubmit — 작업 브랜치(accumulator)에 선 세션에 이슈 번호·작업 이름을 세션 이름으로 붙인다.
#
# 세션이 이름 없이 떠서 프롬프트 칸과 /resume 목록에서 어느 작업인지 구분이 안 됐다(#63).
# 모델이 세션 이름을 바꿀 도구는 없고, 훅 출력의 `sessionTitle` 만 받는다(UserPromptSubmit·SessionStart).
# 디렉토리 이동 훅(CwdChanged)은 받지 않아서, /wtflow:plan 이 워크트리로 들어간 **다음 입력부터** 붙는다.
#
# 이름 꼴
#   이슈 작업   <prefix>/#<N>-<slug>  →  #<N>-<짧은 이름>
#   이슈 없음   <prefix>/+<slug>      →  +<짧은 이름>
#   <짧은 이름> 은 /wtflow:plan 이 브랜치 메모 `branch.<accumulator>.wtflowTitle` 에 적어 둔 한글 이름.
#   없으면(이 기능 전에 만든 브랜치 등) slug 를 그대로 쓴다.
#   전용 칸을 쓰는 이유 — 표준 칸 `description` 은 format-patch·request-pull 도 읽어 이미 쓰는 사람과 겹친다.
#
# 덮어쓰는 이름은 둘뿐이다 — 비어 있거나, 위 꼴(`#<숫자>-` · `+`)로 시작하는 것.
# 사용자가 /rename · claude -n 으로 정한 이름은 건드리지 않는다. 이 훅은 입력마다 돌므로,
# 덮어쓰면 사용자가 바꾼 이름이 다음 입력에서 되돌아간다.
#
# 판정 못 하면 아무것도 내지 않는다(fail-open). UserPromptSubmit 의 stdout 은 모델 컨텍스트에
# 실리므로 JSON 한 줄 말고는 찍지 않는다.
set -u

payload=$(cat)

# cwd·현재 세션 이름 추출 — 문자열 이스케이프가 섞이므로 손 파싱하지 않는다.
if command -v jq >/dev/null 2>&1; then
  parser=jq
  cwd=$(printf '%s' "$payload" | jq -r '.cwd // empty' 2>/dev/null) || exit 0
  current=$(printf '%s' "$payload" | jq -r '.session_title // empty' 2>/dev/null) || exit 0
elif command -v python3 >/dev/null 2>&1; then
  parser=python3
  cwd=$(printf '%s' "$payload" | python3 -c 'import json,sys
try: print(json.load(sys.stdin).get("cwd") or "")
except Exception: pass' 2>/dev/null) || exit 0
  current=$(printf '%s' "$payload" | python3 -c 'import json,sys
try: print(json.load(sys.stdin).get("session_title") or "")
except Exception: pass' 2>/dev/null) || exit 0
else
  exit 0                                   # 파서 없음 → fail-open
fi

[ -n "$cwd" ] && [ -d "$cwd" ] || exit 0
cd "$cwd" 2>/dev/null || exit 0

branch=$(git symbolic-ref --quiet --short HEAD 2>/dev/null) || exit 0

# accumulator 만 — mirror(-NNN)·스쿼시(-squash)는 같은 prefix 를 쓰므로 꼬리로 거른다
case "$branch" in
  *-[0-9][0-9][0-9]|*-squash) exit 0 ;;
esac

rest=${branch#*/}                          # prefix/ 를 뗀 나머지
[ "$rest" != "$branch" ] || exit 0         # prefix 없는 브랜치(main·develop 등)

case "$rest" in
  \#[0-9]*-?*)
    num=${rest#\#}; num=${num%%-*}
    case "$num" in *[!0-9]*|'') exit 0 ;; esac
    slug=${rest#\#"$num"-}
    head="#${num}-"
    ;;
  +?*)
    slug=${rest#+}
    head='+'
    ;;
  *) exit 0 ;;                             # 작업 브랜치 아님
esac

short=$(git config --get "branch.${branch}.wtflowTitle" 2>/dev/null | head -n 1)
[ -n "$short" ] || short=$slug
title="${head}${short}"

# 사용자가 정한 이름은 그대로 둔다 — 비었거나 이 훅이 붙인 꼴일 때만 바꾼다
if [ -n "$current" ]; then
  [[ $current =~ ^#[0-9]+- || $current == +* ]] || exit 0
fi

[ "$current" = "$title" ] && exit 0        # 이미 맞음

if [ "$parser" = jq ]; then
  jq -cn --arg t "$title" '{hookSpecificOutput:{hookEventName:"UserPromptSubmit",sessionTitle:$t}}'
else
  WTFLOW_TITLE="$title" python3 -c 'import json,os
print(json.dumps({"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","sessionTitle":os.environ["WTFLOW_TITLE"]}},ensure_ascii=False))'
fi
exit 0
