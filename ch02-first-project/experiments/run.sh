#!/bin/bash
# 2장 2.5: 자기소개 페이지 — 짧은 요청 vs 디자인 브리프. 브리프 쪽은 2.5.4의 후속 수정까지 이어서.
# 사용: ./run.sh [반복수=2]   (haiku, 약 $0.4)  /  ./run.sh rescore
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
RUNS=$HERE/../runs; mkdir -p "$RUNS"
export ENABLE_CLAUDEAI_MCP_SERVERS=false
[ -d "$HERE/node_modules/jsdom" ] || (cd "$HERE" && npm i -s >/dev/null 2>&1)
OPTS=(--output-format json --setting-sources project --strict-mcp-config --model haiku --allowedTools Write Edit Read --max-turns 8)
SHORT="자기소개 페이지를 하나 만들어 줘. 파일명은 index.html, CSS는 같은 파일에 포함해 줘."
BRIEF=$(cat "$HERE/brief.txt")
BRIEF_FIXED=$(cat "$HERE/brief-fixed.txt")   # 폰트 지시만 실제로 존재하는 CDN으로 바꾼 브리프
FOLLOW=$(cat "$HERE/follow-up.txt")
score() { node "$HERE/check_brief.js" "$1" | python3 -c "
import json,sys; d=json.load(sys.stdin); b=d['brief']
print(f'  브리프 {sum(b.values())}/{len(b)}  폰트={d[\"fontSource\"]}  후속: '+' '.join(('O' if v else 'x')+k for k,v in d['extra'].items()))
miss=[k for k,v in b.items() if not v]
if miss: print('    빠짐:', ', '.join(miss))"; }
if [ "${1:-}" = rescore ]; then for f in "$RUNS"/*.html; do echo "$(basename "$f")"; score "$f"; done; exit 0; fi
REPS=${1:-2}
for r in $(seq 1 "$REPS"); do
  d=$(mktemp -d); cd "$d"
  claude -p "$SHORT" "${OPTS[@]}" < /dev/null > "$RUNS/short-$r.json" 2>/dev/null || true
  cp index.html "$RUNS/short-$r.html" 2>/dev/null || echo '<html></html>' > "$RUNS/short-$r.html"
  echo "short rep$r"; score "$RUNS/short-$r.html"
  d=$(mktemp -d); cd "$d"
  claude -p "$BRIEF" "${OPTS[@]}" < /dev/null > "$RUNS/brief-$r.json" 2>/dev/null || true
  cp index.html "$RUNS/brief-$r.html" 2>/dev/null || echo '<html></html>' > "$RUNS/brief-$r.html"
  echo "brief rep$r"; score "$RUNS/brief-$r.html"
  claude -p "$FOLLOW" "${OPTS[@]}" --continue < /dev/null > "$RUNS/brief-$r-follow.json" 2>/dev/null || true
  cp index.html "$RUNS/brief-$r-follow.html" 2>/dev/null || true
  echo "brief rep$r + 2.5.4 후속 수정 (--continue)"; score "$RUNS/brief-$r-follow.html"
  d=$(mktemp -d); cd "$d"
  claude -p "$BRIEF_FIXED" "${OPTS[@]}" < /dev/null > "$RUNS/fixed-$r.json" 2>/dev/null || true
  cp index.html "$RUNS/fixed-$r.html" 2>/dev/null || echo '<html></html>' > "$RUNS/fixed-$r.html"
  echo "brief-fixed rep$r"; score "$RUNS/fixed-$r.html"
done
