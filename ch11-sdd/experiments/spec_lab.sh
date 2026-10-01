#!/bin/bash
# 11장 실습 대신: GSD를 전역에 설치하지 않고 SDD의 두 주장을 잰다.
#   vague     책의 한 줄 "til-cli: 오늘 배운 한 줄을 날짜별 마크다운에 누적하는 CLI" — 결정이 매번 갈리나 (자기 보고 + 파일 목록)
#   checkbox  specs/til-checkbox.md (C-C-C, 수용 기준 체크박스) → 숨은 수용 테스트 7개
#   prose     같은 요구를 산문 한 문단으로 (specs/til-prose.md) → 같은 테스트
# 사용: ./spec_lab.sh [반복수=3] ["vague checkbox prose"]   (haiku)
set -uo pipefail
HERE=$(cd "$(dirname "$0")" && pwd); RUNS=$HERE/../runs; mkdir -p "$RUNS"
export ENABLE_CLAUDEAI_MCP_SERVERS=false
FLAGS=(--setting-sources project --strict-mcp-config --model "${MODEL:-haiku}" --output-format json --permission-mode acceptEdits
       --allowedTools Read Write Edit Glob "Bash(python3 *)" "Bash(ls *)" --max-turns 25)
for mode in ${2:-vague checkbox prose}; do
  for r in $(seq 1 "${1:-3}"); do
    d=$(mktemp -d)
    if [ "$mode" = vague ]; then
      (cd "$d" && claude -p 'til-cli: 오늘 배운 한 줄을 날짜별 마크다운에 누적하는 CLI를 이 폴더에 만들어 줘. 끝나면 정한 것을 이 형식으로만 보고해: 언어=… | 실행=… | 저장경로=… | 줄형식=… | 빈입력=… | 시간대=…' \
         "${FLAGS[@]}" < /dev/null > "$RUNS/spec-$mode-${TAG:-}$r.json" 2>/dev/null)
      rep=$(python3 -c "import json,sys,re;r=json.load(open(sys.argv[1])).get('result','');m=re.search(r'언어=.*',r);print(m.group(0)[:230] if m else r[-200:].replace(chr(10),' '))" "$RUNS/spec-$mode-${TAG:-}$r.json")
      echo "$mode rep$r  파일: $(cd "$d" && find . -type f -not -path '*/.*' | head -6 | tr '\n' ' ')"
      echo "        $rep"
    else
      mkdir -p "$d/specs"; cp "$HERE/specs/til-$mode.md" "$d/specs/til.md"
      (cd "$d" && claude -p 'specs/til.md 스펙대로 구현해 줘. 끝나면 한 줄로 보고해.' "${FLAGS[@]}" < /dev/null > "$RUNS/spec-$mode-${TAG:-}$r.json" 2>/dev/null)
      res=$(python3 "$HERE/acceptance.py" "$d")
      echo "$mode rep$r  $(echo "$res" | tail -1)  실패: $(echo "$res" | grep ^FAIL | sed 's/^FAIL //' | tr '\n' ',')"
      [ -f "$d/til.py" ] && cp "$d/til.py" "$RUNS/til-$mode-${TAG:-}$r.py"
    fi
  done
done
