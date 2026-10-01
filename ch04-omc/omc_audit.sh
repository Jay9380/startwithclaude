#!/bin/bash
# 4장: 오 마이 클로드 코드(OMC)를 '설치하지 않고' 점검한다. 과금 없음, ~/.claude를 건드리지 않음.
#  1) 고정 커밋을 임시 폴더에 받아 에이전트 수·모델 티어, 스킬 수, 훅 이벤트를 센다
#  2) PreToolUse 훅 스크립트를 '빈 임시 HOME'에서 직접 실행해 무엇을 막는지 본다
# 사용: ./omc_audit.sh [커밋=dc7ba1d]
set -uo pipefail
PIN=${1:-dc7ba1d}   # 2026-10-01 받은 main (v5.6.0)
O=$(mktemp -d)/omc; git clone -q https://github.com/Yeachan-Heo/oh-my-claudecode "$O" && git -C "$O" checkout -q "$PIN"
echo "== OMC $(python3 -c "import json;print(json.load(open('$O/.claude-plugin/plugin.json'))['version'])") @ $PIN"
python3 - "$O" <<'PY'
import glob,json,re,os,sys,collections
O=sys.argv[1]; tiers=collections.defaultdict(list)
for f in sorted(glob.glob(O+'/agents/*.md')):
    m=re.search(r'^model:\s*(\S+)',open(f).read(),re.M); tiers[m.group(1) if m else '(없음)'].append(os.path.basename(f)[:-3])
print(f"에이전트 {sum(map(len,tiers.values()))}개"); [print(f"  {k:6s} {len(v):2d}  {', '.join(v)}") for k,v in tiers.items()]
sk=json.load(open(O+'/.claude-plugin/plugin.json'))['skills']; print(f"스킬 {len(sk)}개")
h=json.load(open(O+'/hooks/hooks.json'))['hooks']; print("훅 이벤트:", ', '.join(f"{k}({sum(len(x['hooks']) for x in v)})" for k,v in h.items()))
PY
H=$(mktemp -d); P=$(mktemp -d); (cd "$P" && git init -q)
probe() {  # probe <hook> <command> [ENV=VAL]
  local out rc
  out=$(printf '{"session_id":"s1","cwd":"%s","hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":%s}}' \
    "$P" "$(python3 -c 'import json,sys;print(json.dumps(sys.argv[1]))' "$2")" \
    | env -i PATH="$PATH" HOME="$H" CLAUDE_PLUGIN_ROOT="$O" ${3:-} node "$O/scripts/run.cjs" "$O/scripts/$1" 2>&1); rc=$?
  printf '  %-20s %-26s %-22s → %s\n' "$1" "$2" "${3:-(기본)}" "$([ $rc -eq 2 ] && echo "차단: $(echo "$out" | head -1 | cut -c1-60)" || echo "통과(exit $rc)")"
}
echo "== PreToolUse 훅 직접 실행 (빈 임시 HOME)"
for c in "git push origin main" "git reset --hard HEAD~1" "rm -rf /"; do
  probe git-guardrails.mjs "$c"; probe git-guardrails.mjs "$c" OMC_GIT_GUARDRAILS=1
done
probe pre-tool-enforcer.mjs "rm -rf /"
echo "== 임시 HOME에 남은 파일: $(find "$H" -type f | wc -l | tr -d ' ')개"
