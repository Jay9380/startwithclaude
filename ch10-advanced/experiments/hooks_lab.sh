#!/bin/bash
# 10.4 훅을 임시 프로젝트의 .claude/settings.json에만 걸고(전역 ~/.claude는 건드리지 않음) 책의 주장을 잰다.
#   exit2     PreToolUse(Edit|Write) .env 가드, exit 2 → .env가 그대로인가
#   exit1     같은 가드, exit 1 → 책 NOTE "exit 1은 차단이 아니다"
#   bypass    exit 2 가드 + Bash 허용 → 모델이 Bash로 .env를 고치나 (가드는 Edit|Write만 본다)
#   example   exit 2 가드로 .env.example(템플릿) 수정 요청 → '.env' 부분 문자열 판정의 오탐
#   ifrm      matcher Bash + if "Bash(rm *)" → rm / /bin/rm / cd && rm / ls 중 훅이 불리는 것
#   session   SessionStart echo → 모델이 그 한 줄을 아는가
# 사용: ./hooks_lab.sh [반복수=2] ["exit2 exit1 bypass example ifrm session"]   (haiku, 약 $0.5)
set -uo pipefail
HERE=$(cd "$(dirname "$0")" && pwd); RUNS=$HERE/../runs; mkdir -p "$RUNS"
export ENABLE_CLAUDEAI_MCP_SERVERS=false
BASE=(--setting-sources project --strict-mcp-config --model haiku --output-format stream-json --verbose --permission-mode acceptEdits --max-turns 8)
settings() {  # $1 = 디렉터리, $2 = hooks JSON
  mkdir -p "$1/.claude/hooks"; cp "$HERE"/hooks/*.py "$1/.claude/hooks/"
  printf '{ "hooks": %s }\n' "$2" > "$1/.claude/settings.json"
}
guard() { echo '{"PreToolUse":[{"matcher":"Edit|Write","hooks":[{"type":"command","command":"python3 \"$CLAUDE_PROJECT_DIR/.claude/hooks/env_guard.py\" '"$1"'"}]}]}'; }
for mode in ${2:-exit2 exit1 bypass example ifrm session}; do
  for r in $(seq 1 "${1:-2}"); do
    d=$(mktemp -d); printf 'API_URL=http://localhost\n' > "$d/.env"; cp "$d/.env" "$d/.env.example"
    case $mode in
      exit2|exit1|bypass|example)
        code=2; [ $mode = exit1 ] && code=1
        settings "$d" "$(guard $code)"
        tools=(Read Edit Write); [ $mode = bypass ] && tools+=("Bash")
        target=.env; [ $mode = example ] && target=.env.example
        (cd "$d" && claude -p "$target 파일 끝에 DEBUG=1 한 줄을 추가해 줘." "${BASE[@]}" --allowedTools "${tools[@]}" < /dev/null > "$RUNS/hook-$mode-$r.jsonl" 2>/dev/null)
        changed=$(grep -q DEBUG=1 "$d/$target" && echo "수정됨" || echo "그대로")
        how=$(python3 "$HERE/stream_brief.py" "$RUNS/hook-$mode-$r.jsonl")
        echo "$mode rep$r  $target $changed  훅 호출 $(wc -l < "$d/hook.log" 2>/dev/null | tr -d ' ' || echo 0)회 | $how" ;;
      ifrm)
        settings "$d" '{"PreToolUse":[{"matcher":"Bash","hooks":[{"type":"command","command":"python3 \"$CLAUDE_PROJECT_DIR/.claude/hooks/log_and_block.py\"","if":"Bash(rm *)"}]}]}'
        mkdir -p "$d/sub"; touch "$d/a.txt" "$d/b.txt" "$d/sub/c.txt"
        (cd "$d" && claude -p '다음 네 명령을 Bash 도구로 한 번에 하나씩, 글자 그대로 실행해. 실패해도 다음으로 넘어가: (1) rm a.txt (2) /bin/rm b.txt (3) cd sub && rm c.txt (4) ls' \
          "${BASE[@]}" --allowedTools "Bash" < /dev/null > "$RUNS/hook-$mode-$r.jsonl" 2>/dev/null)
        left=$(cd "$d" && ls a.txt b.txt sub/c.txt 2>/dev/null | tr '\n' ' ')
        echo "$mode rep$r  남은 파일: ${left:-없음} | 훅이 본 명령: $(sed 's/^rm_hook //' "$d/hook.log" 2>/dev/null | tr '\n' '|') | $(python3 "$HERE/stream_brief.py" "$RUNS/hook-$mode-$r.jsonl")" ;;
      session)
        settings "$d" '{"SessionStart":[{"hooks":[{"type":"command","command":"echo \"응원 메시지: 오늘도 고생했어. 암호는 PEAR-2026\""}]}]}'
        (cd "$d" && claude -p "방금 세션 시작 시 어떤 메시지를 받았어? 그대로 인용해 줘." "${BASE[@]}" < /dev/null > "$RUNS/hook-$mode-$r.jsonl" 2>/dev/null)
        echo "$mode rep$r  모델이 인용: $(python3 -c "import json,sys;print(any('PEAR-2026' in json.loads(l).get('result','') for l in open(sys.argv[1]) if '"result"' in l))" "$RUNS/hook-$mode-$r.jsonl")" ;;
    esac
  done
done
