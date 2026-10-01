#!/bin/bash
# 1장: 모호한 프롬프트 vs 구체적 프롬프트 — 첫 결과물이 요구사항을 얼마나 채우나 (haiku, 조건당 3회, 약 $0.3)
# 두 프롬프트 모두 "index.html 한 파일"이라는 형식만 같게 맞췄다(기능 테스트를 위해). 책의 구체적 프롬프트는 React+TS인데
# 한 파일로 실행·검사하려고 바닐라 JS로 바꿨다.
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
RUNS=$HERE/../runs; mkdir -p "$RUNS"
export ENABLE_CLAUDEAI_MCP_SERVERS=false
REPS=${1:-3}
# ./run.sh rescore → 저장된 HTML만 다시 채점
VAGUE="할 일 앱 만들어 줘. index.html 한 파일로 만들어."
SPEC="할 일 관리 웹 앱을 index.html 한 파일(바닐라 JS)로 만들어 줘.
- 할 일 추가, 완료 체크, 삭제 기능
- 완료된 항목은 목록 아래쪽으로 이동
- 데이터는 브라우저 로컬 스토리지에 저장
- 모바일 반응형 디자인"
[ -d "$HERE/node_modules/jsdom" ] || (cd "$HERE" && npm i -s >/dev/null 2>&1)
if [ "${1:-}" = rescore ]; then for f in "$RUNS"/*.html; do printf '%-12s %s\n' "$(basename "$f" .html)" "$(node "$HERE/check_todo.js" "$f")"; done; exit 0; fi
for kind in vague spec; do
  [ $kind = vague ] && P=$VAGUE || P=$SPEC
  for r in $(seq 1 "$REPS"); do
    d=$(mktemp -d); cd "$d"
    claude -p "$P" --output-format json --setting-sources project --strict-mcp-config --model haiku \
      --allowedTools Write Edit Read --max-turns 6 < /dev/null > "$RUNS/$kind-$r.json" 2>/dev/null || true
    cp index.html "$RUNS/$kind-$r.html" 2>/dev/null || echo '<html></html>' > "$RUNS/$kind-$r.html"
    res=$(node "$HERE/check_todo.js" "$RUNS/$kind-$r.html")
    cost=$(python3 -c "import json;print(round(json.load(open('$RUNS/$kind-$r.json')).get('total_cost_usd',0),3))" 2>/dev/null || echo "?")
    python3 - "$kind" "$r" "$res" "$cost" "$(wc -c < "$RUNS/$kind-$r.html")" <<'PY'
import json,sys
k,r,res,cost,size=sys.argv[1:6]; d=json.loads(res)
keys=['add','toggle','delete','completedToBottom','persist','viewport']
print(f"{k:5s} rep{r}  {sum(d[x] for x in keys)}/6  " + ' '.join(('O' if d[x] else 'x')+x for x in keys) + f"  ${cost}  {size}B" + (f"  ERR {d['error']}" if d['error'] else ''))
PY
  done
done
