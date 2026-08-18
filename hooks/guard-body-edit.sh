#!/usr/bin/env bash
#
# PreToolUse(Bash) — 이슈·MR 본문을 스킬 밖에서 고치는 호출을 막는다.
#
# 본문 재작성에는 지켜야 할 계약이 있다(저장소 템플릿 준수, 미리보기 + 확인, 분량 상한).
# 그 계약은 wtflow:issue `## 재작성 모드` 와 wtflow:mr `## 재작성 모드` 안에만 있으므로,
# `glab issue update -d` 를 직접 부르면 계약이 통째로 통과된다. 실제로 그렇게 새어나갔고,
# 4개 절 12줄이던 이슈가 확인 없이 7개 절 29줄이 된 사고가 있었다.
#
# 예외는 둘이고, 둘 다 명령 앞에 센티넬을 붙여 스스로를 밝힌다 — 훅은 명령 문자열만 보므로,
# 호출자가 밝히는 것 말고 구별할 방법이 없다. 스킬을 거친 호출인지 아닌지는 명령 형태로
# 판정할 수 없기 때문이다.
#
#   WTFLOW_CHECKBOX_SYNC=1  wtflow:commit 의 체크박스 동기화. 본문을 다시 쓰는 게 아니라
#                           `- [ ]` 한 줄을 켜는 것이라 계약을 탈 이유가 없다.
#   WTFLOW_BODY_REWRITE=1   wtflow:issue·wtflow:mr 의 `## 재작성 모드` 가 계약을 전부 통과한 뒤
#                           내는 마지막 쓰기. 이게 없으면 훅이 안내하는 경로가 훅 자신에게 막힌다.
#
# 둘을 한 값으로 합치지 않는다 — 체크박스 예외의 "한 줄만 바꾼다" 는 좁은 계약이
# 본문 전체 재작성까지 덮어버린다.
#
# 판정 못 하면 통과시킨다(fail-open). 훅이 못 읽는 payload 때문에 작업이 서는 것이,
# 막지 못한 본문 수정 하나보다 나쁘다.
set -u

SENTINEL_CHECKBOX='WTFLOW_CHECKBOX_SYNC=1'
SENTINEL_REWRITE='WTFLOW_BODY_REWRITE=1'

payload=$(cat)

# command 추출 — 문자열 이스케이프가 섞이므로 손 파싱하지 않는다.
if command -v jq >/dev/null 2>&1; then
  cmd=$(printf '%s' "$payload" | jq -r '.tool_input.command // empty' 2>/dev/null) || exit 0
elif command -v python3 >/dev/null 2>&1; then
  cmd=$(printf '%s' "$payload" | python3 -c 'import json,sys
try: print(json.load(sys.stdin).get("tool_input",{}).get("command",""))
except Exception: pass' 2>/dev/null) || exit 0
else
  exit 0                                   # 파서 없음 → fail-open
fi

[ -n "$cmd" ] || exit 0

# 예외 — 스킬이 센티넬로 스스로를 밝힌 호출
case "$cmd" in
  *"$SENTINEL_CHECKBOX"*) exit 0 ;;      # wtflow:commit 체크박스 동기화
  *"$SENTINEL_REWRITE"*)  exit 0 ;;      # wtflow:issue·wtflow:mr 재작성 모드
esac

# 본문 플래그를 동반하지 않으면 본문 수정이 아니다 (제목·라벨만 바꾸는 호출은 통과)
printf '%s' "$cmd" \
  | grep -Eq '(^|[[:space:]])(-d|-b|--description|--body|--body-file)([[:space:]]|=)' \
  || exit 0

# 어느 표면인가 — 안내할 스킬 경로가 갈린다
if printf '%s' "$cmd" | grep -Eq '(^|[[:space:]])(glab[[:space:]]+issue[[:space:]]+update|gh[[:space:]]+issue[[:space:]]+edit)([[:space:]]|$)'; then
  target='이슈'
  route='/wtflow:issue --rewrite <N>'
elif printf '%s' "$cmd" | grep -Eq '(^|[[:space:]])(glab[[:space:]]+mr[[:space:]]+update|gh[[:space:]]+pr[[:space:]]+edit)([[:space:]]|$)'; then
  target='MR'
  route='/wtflow:mr --rewrite'
else
  exit 0
fi

printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"%s 본문을 스킬 밖에서 고치려 했습니다. 재작성에는 지켜야 할 계약이 있습니다 — 저장소 템플릿 준수, 절·줄 수 변화 미리보기, 사용자 확인. 직접 호출하면 그게 전부 통과됩니다.\\n\\n%s 를 대신 쓰세요.\\n\\n체크박스 동기화라면 명령 앞에 %s 를 붙여 호출하세요(wtflow:commit 전용)."}}\n' \
  "$target" "$route" "$SENTINEL_CHECKBOX"
exit 0
