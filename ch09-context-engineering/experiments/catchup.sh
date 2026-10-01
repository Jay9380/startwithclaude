#!/bin/bash
# 9.4.3 Document & Clear의 /catchup 스킬을 새 세션(= /clear 직후와 같은 상태)에서 실행해 본다.
# 임시 git 저장소: main에 파일 2개, feature 브랜치에서 1개 수정 + 1개 추가(TODO 포함).
# 확인: ① 스킬이 인식되나 ② !`git diff` 결과가 주입되나(스트림에 Bash 호출 없이 파일명을 아는가) ③ 바뀐 파일만 정리하나
# 사용: ./catchup.sh   (haiku 1회, 약 $0.05)
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd); RUNS=$HERE/../runs; mkdir -p "$RUNS"
export ENABLE_CLAUDEAI_MCP_SERVERS=false
d=$(mktemp -d); cd "$d"
git init -q -b main && git config user.email t@t && git config user.name t
printf 'export const add = (a, b) => a + b;\n' > math.js
printf 'export const greet = (n) => `hi ${n}`;\n' > greet.js
git add math.js greet.js && git commit -qm init
git checkout -qb feature/discount
printf 'export const add = (a, b) => a + b;\nexport const pct = (v, p) => v * p / 100;\n' > math.js
printf 'import { pct } from "./math.js";\n// TODO: 쿠폰 중복 적용 막기\nexport const discount = (price, p) => price - pct(price, p);\n' > discount.js
git add math.js discount.js && git commit -qm "할인 계산 추가(진행 중)"
mkdir -p .claude/skills/catchup && cp "$HERE/catchup-skill/SKILL.md" .claude/skills/catchup/
claude -p "/catchup" --setting-sources project --strict-mcp-config --model haiku --allowedTools Read Glob Grep \
  --output-format stream-json --verbose < /dev/null > "$RUNS/catchup.jsonl" 2>/dev/null || true
python3 "$HERE/../../tools/summarize_stream.py" "$RUNS/catchup.jsonl" | grep -vE "^INIT agents" | head -30
# 스킬이 펼쳐진 본문은 스트림에 사용자 메시지로 찍히지 않는다. 그래서 간접 증거로 판정한다:
# Bash가 허용되지 않았는데(--allowedTools에 없음) 바뀐 파일 2개만 정확히 읽었다면 !`git diff` 결과가 주입된 것이다.
python3 - "$RUNS/catchup.jsonl" <<'PY'
import json, sys
tools = []
for l in open(sys.argv[1]):
    d = json.loads(l)
    if d.get("type") == "assistant":
        tools += [(c["name"], c["input"].get("file_path", c["input"].get("command", "")).split("/")[-1])
                  for c in d["message"]["content"] if c.get("type") == "tool_use"]
print("도구 호출:", tools)
read = {f for n, f in tools if n == "Read"}
print("판정: 바뀐 파일만 읽음" if read == {"math.js", "discount.js"} else "판정: 다름", "| Bash/Glob 호출", sum(n in ("Bash", "Glob") for n, _ in tools))
PY
