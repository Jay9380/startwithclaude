#!/bin/bash
# 책 1.2.2 "Accept All 전에 1~2분 투자해 4가지만 확인하라"를 자동 점검으로.
#   1 인증/권한: 접근 제어 코드가 빠지거나 약해지지 않았는지
#   2 외부 입력 처리: 사용자 입력이 검증 없이 쿼리나 명령에 들어가지 않는지
#   3 API 키/비밀번호: 하드코딩된 인증 정보가 코드에 포함되지 않았는지
#   4 새로운 의존성: 낯선 패키지가 추가되지 않았는지
# 사용: git diff | ./check.sh      또는  ./check.sh < 변경.diff
# 종료 코드: 의심 항목이 있으면 1 (훅·CI에서 '사람이 볼 것' 신호로 쓰기 위함), 없으면 0
# 정규식 기반이라 거짓 양성·음성이 있다 — 차단기가 아니라 '어디를 볼지' 알려 주는 체크리스트다.
set -uo pipefail
diff=$(cat)
added=$(printf '%s\n' "$diff" | grep -E '^\+[^+]' | sed 's/^+//')
removed=$(printf '%s\n' "$diff" | grep -E '^-[^-]' | sed 's/^-//')
hits=0
report() { echo "[$1] $2"; printf '%s\n' "$3" | sed 's/^/      /' | head -5; hits=$((hits+1)); }

# 1 인증/권한 — 지워진 줄에 auth/권한 관련 코드, 또는 추가된 줄에서 주석 처리
a=$(printf '%s\n' "$removed" | grep -Ei 'auth|authorize|permission|isAdmin|requireLogin|verify(Token|Jwt)|middleware' || true)
b=$(printf '%s\n' "$added"   | grep -Ei '^\s*(//|#).*(auth|authorize|permission|requireLogin|verify)' || true)
[ -n "$a$b" ] && report "1 인증/권한" "접근 제어 코드가 지워지거나 주석 처리됨" "$(printf '%s\n%s' "$a" "$b" | sed '/^$/d' | sort -u)"

# 2 외부 입력 — 문자열 결합/보간으로 만든 SQL·셸 명령
c=$(printf '%s\n' "$added" | grep -Ei '(select|insert|update|delete)\b.*(\$\{|"\s*\+|\+\s*")|exec(Sync)?\(.*(\$\{|\+)|os\.system\(|subprocess\..*shell=True' || true)
[ -n "$c" ] && report "2 외부 입력" "입력이 쿼리·명령에 직접 결합됨" "$c"

# 3 비밀 — 키처럼 생긴 문자열, password/secret/token에 문자열 리터럴 대입
d=$(printf '%s\n' "$added" | grep -E '(sk-[A-Za-z0-9_-]{8,}|AKIA[0-9A-Z]{16}|ghp_[A-Za-z0-9]{20,}|xox[bp]-[A-Za-z0-9-]{10,})' || true)
e=$(printf '%s\n' "$added" | grep -Ei '(api[_-]?key|secret|password|passwd|token)\s*[:=]\s*["\x27][^"\x27]{6,}["\x27]' | grep -vi 'process\.env\|getenv\|os\.environ' || true)
[ -n "$d$e" ] && report "3 비밀" "하드코딩된 인증 정보로 보임" "$(printf '%s\n%s' "$d" "$e" | sed '/^$/d' | sort -u)"

# 4 새 의존성 — package.json / requirements.txt / go.mod 등에 추가된 줄
f=$(printf '%s\n' "$diff" | awk '/^\+\+\+ /{file=$2} /^\+[^+]/{ if (file ~ /(package\.json|requirements.*\.txt|pyproject\.toml|go\.mod|Cargo\.toml|build\.gradle|pom\.xml)$/) print file": "substr($0,2)}' | grep -E '"[^"]+"\s*:\s*"[~^]?[0-9]|==|>=|^[^:]+: \s*[a-zA-Z0-9_.-]+ v[0-9]|<artifactId>|implementation' || true)
[ -n "$f" ] && report "4 새 의존성" "추가된 패키지 — 이름·출처를 확인할 것(유사 이름 악성 패키지 주의)" "$f"

[ $hits -eq 0 ] && { echo "4가지 점검: 의심 항목 없음"; exit 0; } || { echo "→ 의심 항목 ${hits}개. Accept 전에 위 줄들을 직접 보라."; exit 1; }
