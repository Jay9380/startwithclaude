#!/bin/bash
# 11.4.2·11.4.4: 스펙이 있는 저장소에서 새 세션이 "--tag 옵션 추가해 줘"를 받으면
#   ① 스펙(specs/til.md)을 읽나  ② 스펙의 Out of Scope(태그)와 충돌한다고 말하나  ③ 스펙도 같이 고치나(스펙 드리프트 방지)
#   none     CLAUDE.md 없음
#   pointer  CLAUDE.md에 책 11.4.4의 한 줄 ("코드 작업 전에 specs/의 관련 스펙을 먼저 읽고 수용 기준에 따라 구현")
#   sync     pointer + 책 11.4.2의 규칙 한 줄 ("코드를 바꾸면 같은 변경에서 스펙도 갱신")
# 기반 코드는 checkbox 스펙으로 만든 til.py(수용 테스트 7/7).
# 사용: ./drift.sh [반복수=3]   (haiku)
set -uo pipefail
HERE=$(cd "$(dirname "$0")" && pwd); RUNS=$HERE/../runs; mkdir -p "$RUNS"
export ENABLE_CLAUDEAI_MCP_SERVERS=false
POINTER="이 프로젝트는 SDD 워크플로를 따릅니다. 코드 작업을 시작하기 전에 specs/ 폴더의 관련 스펙 파일을 먼저 읽고, 그 안의 수용 기준에 따라 구현하세요."
SYNC="코드 동작을 바꾸면 같은 변경 안에서 specs/의 해당 스펙도 함께 갱신하세요."
for mode in ${2:-none pointer sync}; do
  for r in $(seq 1 "${1:-3}"); do
    d=$(mktemp -d); mkdir -p "$d/specs"; cp "$HERE/specs/til-checkbox.md" "$d/specs/til.md"; cp "$HERE/til_base.py" "$d/til.py"
    [ "$mode" != none ] && printf '# 프로젝트\n- %s\n' "$POINTER" > "$d/CLAUDE.md"
    [ "$mode" = sync ] && printf -- '- %s\n' "$SYNC" >> "$d/CLAUDE.md"
    (cd "$d" && claude -p 'til.py에 --tag 옵션을 추가해 줘. `python3 til.py "내용" --tag python` 하면 줄 끝에 #python 이 붙게.' \
       --setting-sources project --strict-mcp-config --model haiku --output-format stream-json --verbose --permission-mode acceptEdits \
       --allowedTools Read Write Edit Glob Grep "Bash(python3 *)" --max-turns 20 < /dev/null > "$RUNS/drift-$mode-$r.jsonl" 2>/dev/null)
    python3 - "$RUNS/drift-$mode-$r.jsonl" "$d" "$mode" "$r" <<'PY'
import json, sys, filecmp, os
f, d, mode, r = sys.argv[1:]
reads, result = [], ""
for l in open(f):
    try: x = json.loads(l)
    except: continue
    if x.get("type") == "assistant":
        for c in x["message"]["content"]:
            if c.get("type") == "tool_use" and c["name"] == "Read":
                reads.append(c["input"].get("file_path", "").split("/")[-1])
    if x.get("type") == "result": result = x.get("result", "")
spec_read = "til.md" in reads
spec_changed = open(os.path.join(d, "specs/til.md")).read() != open(os.path.join(os.path.dirname(f), "..", "experiments", "specs", "til-checkbox.md")).read()
conflict = any(k in result for k in ("Out of Scope", "범위", "스펙", "spec"))
tag_ok = "#python" in os.popen(f'cd "{d}" && TIL_DIR="{d}/o" python3 til.py "x" --tag python >/dev/null 2>&1; cat "{d}"/o/*.md 2>/dev/null').read()
print(f"{mode} rep{r}  스펙 읽음 {spec_read!s:5}  보고에 스펙 언급 {conflict!s:5}  스펙 갱신 {spec_changed!s:5}  --tag 동작 {tag_ok}")
PY
  done
done
