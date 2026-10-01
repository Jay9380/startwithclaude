#!/bin/bash
# 10.5.7 "description을 '테스트 자동 수정'이라고만 적었더니 '테스트 통과시켜 줘'에 스킬을 안 찾았다"를 잰다.
#   vague     description: 테스트 자동 수정
#   rich      description: 책 10.5.8처럼 키워드와 '이런 요청에 사용' 문장
#   disabled  rich + disable-model-invocation: true (자동 호출 금지)
# 같은 프로젝트(실패하는 unittest 1개)에서 "테스트 통과시켜 줘." 한 마디. Skill 도구 호출 여부와 테스트 통과 여부를 센다.
# 사용: ./skill_trigger.sh [반복수=3]   (haiku 9회, 약 $0.3)
set -uo pipefail
HERE=$(cd "$(dirname "$0")" && pwd); RUNS=$HERE/../runs; mkdir -p "$RUNS"
export ENABLE_CLAUDEAI_MCP_SERVERS=false
BODY='# 테스트 실행 및 자동 수정
다음 루프를 최대 3회 반복하세요.
1. 테스트 실행: `python3 -m unittest -q`
2. 모두 통과하면 결과를 보고하고 종료
3. 실패하면 메시지를 분석해 원인이 있는 쪽(테스트 또는 소스)을 고치고 1로'
RICH='테스트를 실행하고 실패하면 자동으로 수정합니다. 테스트 수정, 테스트 통과, 테스트 고쳐 줘 같은 요청에 사용하세요.'
for mode in vague rich disabled; do
  for r in $(seq 1 "${1:-3}"); do
    d=$(mktemp -d); mkdir -p "$d/.claude/skills/test-and-fix"
    printf 'def total(prices):\n    return sum(prices) - 1\n' > "$d/cart.py"
    printf 'import unittest\nfrom cart import total\n\nclass T(unittest.TestCase):\n    def test_total(self):\n        self.assertEqual(total([1, 2, 3]), 6)\n' > "$d/test_cart.py"
    case $mode in
      vague)    fm=$'name: test-and-fix\ndescription: 테스트 자동 수정' ;;
      rich)     fm=$'name: test-and-fix\ndescription: '"$RICH" ;;
      disabled) fm=$'name: test-and-fix\ndescription: '"$RICH"$'\ndisable-model-invocation: true' ;;
    esac
    printf -- '---\n%s\n---\n%s\n' "$fm" "$BODY" > "$d/.claude/skills/test-and-fix/SKILL.md"
    (cd "$d" && claude -p "테스트 통과시켜 줘." --setting-sources project --strict-mcp-config --model haiku \
       --allowedTools Skill Read Edit "Bash(python3 *)" --output-format stream-json --verbose --max-turns 12 \
       < /dev/null > "$RUNS/skill-$mode-$r.jsonl" 2>/dev/null)
    pass=$(cd "$d" && python3 -m unittest -q > /dev/null 2>&1 && echo 통과 || echo 실패)
    echo "$mode rep$r  테스트 $pass | $(python3 "$HERE/stream_brief.py" "$RUNS/skill-$mode-$r.jsonl" | cut -c1-150)"
  done
done
