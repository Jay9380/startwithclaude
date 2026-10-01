#!/bin/bash
# 10.1.7 "@ 임포트는 세션 시작 즉시 로드, 경로를 텍스트로만 적으면 지연 로드, rules/의 paths는 해당 파일을 다룰 때만"을 잰다.
# 임시 프로젝트에 큰 규칙 파일(약 150줄, 맨 끝에 암호 한 줄)을 두고 네 가지 방식으로 연결한다:
#   import   CLAUDE.md에 @.claude/rules/react-query.md
#   text     CLAUDE.md에 .claude/rules/react-query.md 참조 (경로 텍스트만, @ 없음)
#   paths    .claude/rules/react-query.md 에 paths: ["src/queries/**/*.ts"] 프런트매터 (CLAUDE.md엔 언급 없음)
#   always   .claude/rules/react-query.md 에 프런트매터 없음
#   docs     같은 파일을 rules/ 밖 docs/react-query.md 에 두고 CLAUDE.md에 경로 텍스트만
# 측정 ① 첫 턴 입력 토큰(시작 시 로드량) ② 파일을 안 건드리고 암호를 아는가 ③ src/queries/user.ts를 읽게 한 뒤 암호를 아는가
# 사용: ./memory_load.sh ["none import text paths always docs"]   (haiku 12회, 약 $0.3)
set -uo pipefail
HERE=$(cd "$(dirname "$0")" && pwd); RUNS=$HERE/../runs; mkdir -p "$RUNS"
export ENABLE_CLAUDEAI_MCP_SERVERS=false
FLAGS=(--setting-sources project --strict-mcp-config --model haiku --output-format json --allowedTools Read --max-turns 6)
rules() {  # 큰 규칙 파일 본문
  echo "# React Query 작성 규칙"
  for i in $(seq 1 150); do echo "- 규칙 $i: 쿼리 키 [도메인, 식별자 $i] 형태, fetch는 src/repositories/ 함수 $i 경유, 에러는 react-error-boundary로 throwOnError."; done
  echo "- 이 규칙 파일의 확인 암호는 KIWI-7731 이다."
}
tok() { python3 -c "import json,sys;d=json.load(open(sys.argv[1]));u=d['usage'];print(u['input_tokens']+u['cache_creation_input_tokens']+u['cache_read_input_tokens'], 'KIWI-7731' in d.get('result',''))" "$1"; }
for mode in ${1:-none import text paths always docs}; do
  d=$(mktemp -d); mkdir -p "$d/.claude/rules" "$d/src/queries" "$d/docs"
  printf 'export const userKey = (id: string) => ["user", id] as const;\n' > "$d/src/queries/user.ts"
  printf '# demo\n' > "$d/README.md"
  case $mode in
    none)   printf '# 프로젝트\n- 커밋: Conventional Commits\n' > "$d/CLAUDE.md" ;;
    import) printf '# 프로젝트\n- 커밋: Conventional Commits\n- 데이터 패칭: @.claude/rules/react-query.md\n' > "$d/CLAUDE.md"; rules > "$d/.claude/rules/react-query.md" ;;
    text)   printf '# 프로젝트\n- 커밋: Conventional Commits\n- 데이터 패칭: .claude/rules/react-query.md 참조 (paths: src/queries/**)\n' > "$d/CLAUDE.md"; rules > "$d/.claude/rules/react-query.md" ;;
    paths)  printf '# 프로젝트\n- 커밋: Conventional Commits\n' > "$d/CLAUDE.md"; { printf -- '---\npaths:\n  - "src/queries/**/*.ts"\n---\n'; rules; } > "$d/.claude/rules/react-query.md" ;;
    docs)   printf '# 프로젝트\n- 커밋: Conventional Commits\n- 데이터 패칭: docs/react-query.md 참조 (src/queries/** 작업 시)\n' > "$d/CLAUDE.md"; rules > "$d/docs/react-query.md" ;;
    always) printf '# 프로젝트\n- 커밋: Conventional Commits\n' > "$d/CLAUDE.md"; rules > "$d/.claude/rules/react-query.md" ;;
  esac
  (cd "$d" && claude -p "파일을 열지 말고 답해. 이 프로젝트 규칙의 확인 암호를 알면 그대로, 모르면 '모름'이라고만 답해." "${FLAGS[@]}" < /dev/null > "$RUNS/mem-$mode-start.json" 2>/dev/null)
  (cd "$d" && claude -p "src/queries/user.ts 를 Read로 읽어. 그 다음 이 프로젝트 규칙의 확인 암호를 알면 그대로, 모르면 '모름'이라고만 답해. 규칙 파일을 직접 찾아 열지는 마." "${FLAGS[@]}" < /dev/null > "$RUNS/mem-$mode-touch.json" 2>/dev/null)
  read t1 k1 <<< "$(tok "$RUNS/mem-$mode-start.json")"; read t2 k2 <<< "$(tok "$RUNS/mem-$mode-touch.json")"
  reads=$(python3 -c "import json,sys;d=json.load(open(sys.argv[1]));print(d.get('num_turns'))" "$RUNS/mem-$mode-touch.json")
  printf '%-7s 시작 입력 %6s토큰  암호(안 건드림) %-5s | user.ts 읽은 뒤 암호 %-5s (턴 %s)\n' "$mode" "$t1" "$k1" "$k2" "$reads"
done
