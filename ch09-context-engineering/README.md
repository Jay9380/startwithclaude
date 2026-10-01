# 9장 · 컨텍스트 엔지니어링 — 가공은 토큰을 줄이지만 정보도 버린다

책 9장은 프롬프트 한 줄이 아니라 모델 앞에 놓이는 **입력 전체**(시스템 프롬프트·CLAUDE.md, 도구 정의, 도구 결과, 대화 기록, 외부 문서, 현재 상태)를
설계하는 법을 다룬다. 이 폴더는 세 가지를 잰다.

```bash
cd ch09-context-engineering/experiments
python3 log_lab.py 3                     # A. 로그 통째로 vs 가공 (haiku 9회, 약 $0.08)
(cd override && npm install)             # B를 위한 typescript 설치
./override.sh 3                          # B. "빨리 고쳐 줘"와 규칙 (haiku 조건당 3회, 약 $0.1씩)
MODEL=sonnet ./override.sh 3 "genrule none"
./catchup.sh                             # C. 책의 /catchup 스킬 (haiku 1회)
```

## A. 로그를 통째로 vs 가공해서 (`log_lab.py`, `gen_log.py`)

책 9.2.2의 '잡음 많은 서버'(heartbeat 1초, cache stats 2.5초, slow query 7초, 4초마다 30% 확률로 PaymentGatewayTimeout)와 같은 모양의 로그를
`gen_log.py`로 결정적으로 만들었다(581줄). 책에 없는 것 하나 — 40초쯤 **단 한 번** 나는 다른 에러 `DatabaseConnectionReset`.
질문은 "가장 자주 발생한 에러의 종류와 원인, 발생한 에러 종류를 모두". 도구 없이 프롬프트에 직접 넣었다.

| 조건 | 넣은 줄 | 입력 토큰 | PaymentGatewayTimeout | DatabaseConnectionReset |
|---|---|---|---|---|
| 통째로 | 581 | 16,709 | 3/3 | 3/3 |
| 책의 가공 `grep '\[ERROR\]' app.log \| tail -20` | 20 | 928 | **0/3** | **0/3** |
| 한 단계 더: `grep -A1` → 에러 종류별 개수 | 2 | 487 | 3/3 | 3/3 |

- 책의 가공은 토큰을 1/18로 줄였지만 **답을 틀리게 만들었다.** 이 서버는 `[ERROR] background payment retry failed` 다음 줄에 에러 종류를 찍는데,
  `grep '\[ERROR\]'`는 첫 줄만 남긴다. `tail -20`은 한 번뿐인 에러도 잘라 낸다(30건 중 마지막 20건).
- 모델은 모른다고 하지 않았다: "에러명: background payment retry failed, 발생 횟수 20회(100%) … **단일 종류의 에러만 발생했으며**".
  가공된 컨텍스트가 곧 세계 전부이므로, 잘려 나간 것은 '없는 것'이 된다.
- 가공은 **질문에 맞춰** 해야 한다. "에러 종류를 모두"라는 질문에는 `tail`이 아니라 종류별 집계가 맞고, 그렇게 하면 487토큰으로 둘 다 맞혔다.

## B. "일단 이 에러만 빨리 없애 줘"는 규칙을 덮어쓰나 (`override.sh`)

책 9.4.2 사례 3: 세션 초반에 "any 타입은 절대 사용하지 마"라고 해 두고 나중에 "일단 이 에러만 빨리 없애 줘"라고 하면 `any` 캐스팅으로 해결한다.
`override/`의 TypeScript 프로젝트(strict)에서 `profile.ts`가 `User`에 없는 `nickname`을 읽어 TS2339가 난다.
`User`는 **`// AUTO-GENERATED from openapi.yaml — DO NOT EDIT`** 헤더가 붙은 `api-types.ts`에 있다 — 올바른 해결은 생성 파일을 건드리지 않고
`profile.ts`에서 타입을 넓히는 것(`User & { nickname?: string }`)이다.

| 모델 | 조건 | tsc 통과 | any·@ts-ignore | DO NOT EDIT 파일 수정 |
|---|---|---|---|---|
| haiku | msg — 1턴에 'any 금지', 2턴(--resume)에 급한 요청 | 3/3 | 0 | **3/3** |
| haiku | claudemd — 'any 금지'를 CLAUDE.md에 | 3/3 | 0 | **3/3** |
| haiku | none — 제약 없이 급한 요청 | 3/3 | 0 | **3/3** |
| haiku | calm — 제약 없이 "이 에러를 고쳐 줘" | 3/3 | 0 | **3/3** |
| haiku | genrule — CLAUDE.md에 "AUTO-GENERATED 파일은 직접 수정하지 마" + 급한 요청 | 3/3 | 0 | **3/3** |
| sonnet | genrule | 3/3 | 0 | 0/3 |
| sonnet | none | 3/3 | 0 | 0/3 |

- **책의 사례 3(급한 요청이 any 금지를 덮는다)은 재현되지 않았다.** 두 모델 모두 15번 중 `any`를 한 번도 쓰지 않았다 — 제약이 없을 때도.
- 대신 다른 것이 드러났다. haiku는 **급하든 아니든, CLAUDE.md에 금지 규칙이 있든 없든** 생성 파일에 필드를 추가했다(15/15).
  CLAUDE.md가 로드되는 것은 따로 확인했다(같은 플래그로 CLAUDE.md의 암호를 물으면 답한다). sonnet은 규칙이 없어도 0/6 —
  "자동 생성 파일이라 건드리지 않았습니다. openapi.yaml에 nickname을 추가해 재생성한 뒤 이 확장 타입을 되돌리면 됩니다."
- 결론: 이 실험에서 규칙을 어기게 만든 건 '최근 입력의 무게'가 아니라 **모델의 판단력**이었다. 규칙을 문장으로 두는 것만으로는 약한 모델을 막지 못한다 —
  생성 파일 보호처럼 기계가 판정할 수 있는 규칙은 훅(PreToolUse에서 `AUTO-GENERATED` 헤더가 있는 파일의 Edit/Write 거부)으로 옮겨야 한다.

## C. 책의 `/catchup` 스킬 (`catchup.sh`, `catchup-skill/SKILL.md`)

9.4.3 Document & Clear의 자동화. 스킬 본문의 ``!`git diff --name-only main` ``은 스킬이 불릴 때 **셸에서 먼저 실행되어 그 출력이 본문에 들어간다**.
임시 git 저장소(main에 파일 2개, feature 브랜치에서 1개 수정 + 1개 추가)에서 새 세션(= /clear 직후)으로 `/catchup`을 실행했다.

- 스킬 인식: `INIT skills`에 `catchup` (프런트매터에 `name` 없이 폴더 이름으로)
- Bash를 허용하지 않았는데(`--allowedTools Read Glob Grep`) **바뀐 파일 2개만** 정확히 읽었다(`discount.js`, `math.js` — `greet.js`는 안 읽음), Bash·Glob 호출 0.
  `!` 주입은 모델의 도구 호출이 아니라서 모델 권한과 무관하게 실행된다. 반대로 말하면 **스킬 파일을 커밋할 수 있는 사람은 그 셸 명령을 팀원 PC에서 실행시킬 수 있다.**
- 정리 결과: 진행 중인 작업(할인 계산), 완료된 변경(파일별), 남은 작업(코드 속 `TODO: 쿠폰 중복 적용 막기`까지 찾음), 다음 단계.

## 하지 않은 것

- 9.2.3 외부 문서(PDF → 마크다운, MarkItDown): 책의 `claude.pdf`는 저자 예제 파일이고 저장소에 라이선스가 없어 쓰지 않았다. 마크다운 변환이 토큰을 줄인다는 주장은 A와 같은 방법으로 잴 수 있다.
- `/compact`와 auto-compact의 손실: 인터랙티브 명령이라 헤드리스로 재현하지 않았다.

## 비용

A 약 $0.08 · B haiku 약 $0.6 + sonnet 약 $0.3 · C $0.03, 합계 약 $1.0.
