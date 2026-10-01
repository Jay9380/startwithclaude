#!/bin/bash
# 6장: 책의 '리뷰 → 수정' 루프를 재현한다. 결함 있는 naive.py와 review.md만 주고 클로드가 고치게 한 뒤,
# 클로드에게 보여 주지 않은 테스트(test_caption.py)로 채점한다.
# 사용: ./run.sh [반복수=3] [review|vague]   (haiku, 조건당 약 $0.15)
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd); PKG=$HERE/../md2short_mini; RUNS=$HERE/../runs; mkdir -p "$RUNS"
export ENABLE_CLAUDEAI_MCP_SERVERS=false
MODE=${2:-review}   # review: review.md를 준다 / vague: 리뷰 없이 "자막이 보기 안 좋아"만
if [ "$MODE" = review ]; then
  ASK="@review.md 의 C3와 H1을 반영해서 md2short_mini/caption.py 를 새로 만들어 줘."
else
  ASK="naive.py가 만드는 자막이 보기 안 좋아. 개선해서 md2short_mini/caption.py 를 새로 만들어 줘."
fi
for r in $(seq 1 "${1:-3}"); do
  d=$(mktemp -d); mkdir -p "$d/md2short_mini"
  cp "$PKG/__init__.py" "$PKG/numbers.py" "$PKG/naive.py" "$d/md2short_mini/"     # 기준 구현(caption.py)과 테스트는 주지 않는다
  [ "$MODE" = review ] && cp "$HERE/review.md" "$d/"
  (cd "$d" && claude -p "$ASK
- wrap_korean_caption(text, max_chars=14) -> list[str]  : 줄 목록
- make_screens(sentence) -> list[list[str]]              : 화면 목록(화면당 최대 2줄)
- split_display_and_speech(sentence) -> (자막 문자열, TTS 문자열)  : 숫자 읽기는 md2short_mini.numbers.to_phonetic 사용
naive.py는 고치지 마. 끝나면 무엇을 했는지 한 줄로 보고해." --output-format json --setting-sources project --strict-mcp-config \
     --model haiku --allowedTools Read Write Edit "Bash(python3 *)" --max-turns 20 < /dev/null > "$RUNS/$MODE-$r.json" 2>/dev/null || true)
  cp "$PKG/test_caption.py" "$d/md2short_mini/"                                      # 채점은 숨겨 둔 테스트로
  out=$(cd "$d" && python3 -m unittest md2short_mini.test_caption 2>&1 | tail -1)
  fails=$(cd "$d" && python3 -m unittest md2short_mini.test_caption 2>&1 | grep -E "^(FAIL|ERROR):" | sed -E 's/ \(.*//' | tr '\n' ' ' || true)
  echo "$MODE rep$r  테스트: $out  $fails"
  [ -f "$d/md2short_mini/caption.py" ] && cp "$d/md2short_mini/caption.py" "$RUNS/caption-$MODE-$r.py"
done
