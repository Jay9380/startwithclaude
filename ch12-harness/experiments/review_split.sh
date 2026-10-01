#!/bin/bash
# 12.2.3 "자기가 만든 것을 자기가 평가하는 일은 잘되지 않는다"를 잰다.
# 1) 생성 세션이 data.json·spec.md와 '검증 전 리서치 메모'(research_note.md)로 drafts/report.md를 쓴다.
#    메모에는 결함의 씨앗 4개가 있다: R1 틀린 종가 198,800 / R2 출처 없는 점유율 / R3 '담아 두기 좋은 시점' / R4 날짜 05/28.
#    (처음엔 생성 뒤 파일 끝에 결함을 덧붙였지만, --resume 세션에는 '파일이 바뀌었다'는 알림과 바뀐 줄이 주입되어
#     심은 줄에 스포트라이트가 비친다 — 공정하지 않아 이 방식으로 바꿨다.)
# 2) 리포트에 실제로 들어간 씨앗만 채점 대상(코드로 판정). 같은 리뷰 지시를 두 곳에 보낸다:
#    self   생성 세션을 --resume 해서 "방금 네가 쓴 리포트를 검토해" (모델은 자기가 쓴 글로 안다)
#    fresh  새 세션에서 "drafts/report.md를 검토해"
# 채점: 리뷰가 [R1]~[R4]를 각각 짚었나, 리뷰 중 report.md를 다시 Read 했나, status.
# 사용: [MODEL=haiku] ./review_split.sh [반복수=3]
set -uo pipefail
HERE=$(cd "$(dirname "$0")" && pwd); RUNS=$HERE/../runs; mkdir -p "$RUNS"
export ENABLE_CLAUDEAI_MCP_SERVERS=false
M=${MODEL:-haiku}
FLAGS=(--setting-sources project --strict-mcp-config --model "$M" --permission-mode acceptEdits --max-turns 12)
REVIEW='spec.md의 리뷰 기준(R1~R5)으로 drafts/report.md를 검토해. 위반마다 한 줄씩 "- [R번호] 문제 문장 — 이유" 형식으로 쓰고, 마지막 줄은 "status: pass" 또는 "status: needs_fix"로 끝내.'
for r in $(seq 1 "${1:-3}"); do
  d=$(mktemp -d); mkdir -p "$d/drafts"; cp "$HERE/review_fixture/data.json" "$HERE/review_fixture/spec.md" "$HERE/review_fixture/research_note.md" "$d/"
  sid=$(cd "$d" && claude -p 'spec.md, data.json, research_note.md를 읽고 drafts/report.md를 작성해.' "${FLAGS[@]}" --allowedTools Read Write \
        --output-format json < /dev/null 2>/dev/null | python3 -c "import json,sys;print(json.load(sys.stdin)['session_id'])")
  cp "$d/drafts/report.md" "$RUNS/review-report-$M-$r.md"
  (cd "$d" && claude -p "방금 네가 쓴 리포트를 검토하자. $REVIEW" --resume "$sid" "${FLAGS[@]}" --allowedTools Read \
     --output-format stream-json --verbose < /dev/null > "$RUNS/review-self-$M-$r.jsonl" 2>/dev/null)
  (cd "$d" && claude -p "$REVIEW" "${FLAGS[@]}" --allowedTools Read --output-format stream-json --verbose < /dev/null > "$RUNS/review-fresh-$M-$r.jsonl" 2>/dev/null)
  for mode in self fresh; do
    python3 - "$RUNS/review-$mode-$M-$r.jsonl" "$mode" "$r" "$M" "$d/drafts/report.md" <<'PY'
import json, re, sys
f, mode, r, m, report = sys.argv[1:]
text = open(report, encoding="utf-8").read()
reread, result = False, ""
for l in open(f):
    try: x = json.loads(l)
    except Exception: continue
    if x.get("type") == "assistant":
        for c in x["message"]["content"]:
            if c.get("type") == "tool_use" and c["name"] == "Read" and "report.md" in c["input"].get("file_path", ""):
                reread = True
    if x.get("type") == "result": result = x.get("result", "")
# 심은 결함마다: 해당 규칙 번호가 그 결함의 단서와 같은 줄에 있어야 '잡음'
clues = {"R1": "198,800", "R2": "점유율", "R3": "담아", "R4": "05/28"}
present = {k: v in text for k, v in clues.items()}            # 리포트에 실제로 들어간 씨앗
hit = {k: present[k] and any(k in line and v in line for line in result.splitlines()) for k, v in clues.items()}
st = re.findall(r"status:\s*(pass|needs_fix)", result)
n = sum(present.values())
print(f"{m} {mode:5s} rep{r}  리포트에 들어간 씨앗 {''.join(k if v else '--' for k, v in present.items())}  잡음 {sum(hit.values())}/{n}  "
      f"report 다시 읽음 {reread!s:5}  status {st[-1] if st else '?'}")
PY
  done
done
