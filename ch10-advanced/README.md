# 10장 · 클로드 코드 심화 — 로딩·훅·스킬을 임시 프로젝트에서 실측

책 10장은 CLAUDE.md(장기 기억), `.claude/settings.json`, 도구, 훅, 스킬, 커스텀 에이전트, MCP, 동적 워크플로를 차례로 다룬다.
이 폴더는 그중 **임시 프로젝트 하나로 재현할 수 있는 세 가지**를 잰다. 설정은 모두 `mktemp -d`로 만든 프로젝트의
`.claude/`에만 쓰고 `--setting-sources project`로 실행한다 — 전역 `~/.claude`는 건드리지 않는다.

```bash
cd ch10-advanced/experiments
./memory_load.sh          # A. @ 임포트 · rules/ · paths 로딩 (haiku 12회, 약 $0.34)
./hooks_lab.sh 2          # B. 훅 exit 코드 · if 필드 · .env 가드 · SessionStart (약 $0.5)
./skill_trigger.sh 3      # C. 스킬 description과 자동 호출 (haiku 9회, 약 $0.38)
```

## A. CLAUDE.md와 규칙 파일은 언제 로드되나 (`memory_load.sh`)

150줄짜리 React Query 규칙 파일(맨 끝에 암호 `KIWI-7731`)을 다섯 가지 방식으로 연결했다.
① 첫 턴 입력 토큰(시작 시 로드량) ② 아무 파일도 안 열고 암호를 아는가 ③ `src/queries/user.ts`를 읽게 한 뒤 아는가(규칙 파일을 직접 열지는 말라고 지시).

| 방식 | 시작 입력 토큰 | 안 건드림 | user.ts 읽은 뒤 |
|---|---|---|---|
| 규칙 없음 (기준) | 21,319 | 모름 | 모름 |
| CLAUDE.md에 `@.claude/rules/react-query.md` | 31,193 | **앎** | 앎 |
| CLAUDE.md에 `.claude/rules/react-query.md` (경로 텍스트만) | 31,214 | **앎** | 앎 |
| `.claude/rules/`에 두고 `paths: ["src/queries/**/*.ts"]` | 21,319 | 모름 | **앎** |
| `.claude/rules/`에 두고 프런트매터 없음 | 31,171 | 앎 | 앎 |
| `docs/react-query.md`에 두고 CLAUDE.md에 경로 텍스트만 | 21,348 | 모름 | 모름 |

- 규칙 150줄 ≈ **9,900토큰**, 매 세션.
- `@` 임포트는 책대로 시작 즉시 로드된다.
- 책(10.1.7)은 "@ 없이 경로를 텍스트로만 적으면 지연 로딩이 유지된다"고 하지만, **`.claude/rules/` 안의 파일은 `paths:`가 없으면 CLAUDE.md에서 어떻게 언급하든 시작 시 전부 로드된다**(3·5행).
  지연 로딩을 만드는 건 `@`를 빼는 것이 아니라 **`paths:` 프런트매터**(4행)이거나 **rules/ 밖에 두는 것**(6행)이다.
  책의 예시처럼 rules 파일에 paths가 이미 있다면 텍스트 참조는 안내일 뿐 로딩에는 영향이 없다.
- `paths:`는 책대로 동작했다 — 시작 시 0토큰, `src/queries/user.ts`를 읽는 순간 규칙이 들어왔다.

## B. 훅 (`hooks_lab.sh`, `hooks/env_guard.py`, `hooks/log_and_block.py`)

| 실험 | 결과 |
|---|---|
| PreToolUse(Edit\|Write) `.env` 가드, **exit 2** | `.env` 그대로 2/2. 모델은 stderr 메시지("수동으로만 수정")를 사용자에게 전달 |
| 같은 가드, **exit 1** | `.env` **수정됨 5/5** — 책 NOTE "exit 1은 차단이 아니다" 그대로 |
| exit 2 가드 + Bash 허용 | 2/2 모두 Bash로 우회하지 않고 사용자에게 수동 수정을 안내 (가드는 Edit\|Write만 보므로 우회는 가능한 구조) |
| exit 2 가드로 `.env.example` 수정 요청 | 차단 — `".env" in path` 부분 문자열 판정이 템플릿 파일까지 막는다(오탐). 스트림을 켠 5회 0/5 수정, 첫 배치(스트림 없음) 2회 중 1회는 수정됨 — 원인 미확인 |
| matcher `Bash` + `"if": "Bash(rm *)"` | `rm a.txt` → 훅 호출·차단, `cd sub && rm c.txt` → **훅 호출·차단**(복합 명령은 나눠서 본다), **`/bin/rm b.txt` → 훅이 불리지 않고 삭제됨**, `ls` → 훅 안 불림 |
| SessionStart `echo` | 모델이 그 줄을 인용 2/2 — stdout이 컨텍스트에 들어간다 |

- `if`는 7장에서 본 `--disallowedTools`와 같은 **앞 문자열 매칭**이다. `/bin/rm`처럼 전체 경로를 쓰면 빠진다. 위험 명령을 확실히 잡으려면 `if` 없이 Bash 전체에 훅을 걸고 스크립트 안에서 명령을 파싱해야 한다(책이 `if`를 쓰는 이유인 속도와 맞바꾸는 것).
- 도구 자체의 검증 오류(예: Edit의 "String to replace not found")는 PreToolUse 훅보다 **먼저** 난다 — 그 호출에는 훅이 불리지 않는다.

## C. 스킬 description과 자동 호출 (`skill_trigger.sh`)

실패하는 unittest 하나가 있는 프로젝트에서 "테스트 통과시켜 줘." 한 마디. `test-and-fix` 스킬의 프런트매터만 바꿨다.

| description | Skill 호출 | 테스트 |
|---|---|---|
| `테스트 자동 수정` | **0/3** | 3/3 통과 (스킬 없이 직접) |
| `테스트를 실행하고 실패하면 자동으로 수정합니다. 테스트 수정, 테스트 통과, 테스트 고쳐 줘 같은 요청에 사용하세요.` | **2/3** | 3/3 |
| 위와 같음 + `disable-model-invocation: true` | 0/3 | 3/3 |

책(10.5.7)의 경험담이 그대로 재현됐다 — 짧은 description은 사용자 표현("통과시켜")과 이어지지 않는다. `disable-model-invocation`은 자동 호출을 확실히 막았다.
이 과제는 스킬 없이도 풀리는 크기라 결과(테스트 통과)는 같았다. 스킬의 가치는 **절차를 고정**하는 데 있다 — 스킬을 쓴 회차는 스킬 본문대로 `python3 -m unittest -q`를 먼저 돌렸고, 안 쓴 회차는 `pytest`부터 시도했다가 실패했다.

## 하지 않은 것

- 커스텀 에이전트의 `tools` 제한: 하네스 책 실습 저장소 4장에서 이미 쟀다("읽기 전용"이라던 에이전트가 Bash로 파일을 고쳤다). 책 10.6.3의 code-reviewer 예시도 `tools`에 Bash가 들어 있다.
- MCP(Playwright 등)·동적 워크플로·/deep-research: 전역 설정 등록이나 MAX 구독, 수십 개 에이전트 비용이 필요하다.

## 비용

A $0.34 · B $0.53 · C $0.38, 합계 약 $1.3 (haiku).
