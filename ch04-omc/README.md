# 4장 · 오 마이 클로드 코드(OMC) — 설치하기 전에 무엇이 깔리는지 본다

책 4장은 서드파티 플러그인 [oh-my-claudecode](https://github.com/Yeachan-Heo/oh-my-claudecode)(MIT)를 설치하고(`/plugin marketplace add …`, `/omc-setup`),
"30개 이상의 전문 에이전트", 티어(Haiku·Sonnet·Opus) 자동 선택, 스킬 레이어(default + ultrawork + git-master + ralph), 훅으로 "`rm -rf` 같은 위험한 명령을 차단"한다고 소개한다.

**이 폴더는 OMC를 설치하지 않는다.** 이유: 플러그인의 SessionStart 훅은 Claude 설정 디렉터리(`~/.claude/.omc`)와 플러그인 캐시에 파일을 쓰고 심볼릭 링크를 만든다
(`scripts/session-start.mjs`의 `mkdirSync`·`writeFileSync`·`symlinkSync`). `--plugin-dir`로 '세션 한정' 로드를 해도 훅은 같은 일을 한다.
여러 세션이 같은 `~/.claude`를 쓰는 환경에서는 설치가 곧 공유 설정 변경이다. 대신 **고정 커밋을 받아 소스를 세고, 훅 스크립트를 빈 임시 HOME에서 직접 실행**했다.

```bash
./ch04-omc/omc_audit.sh          # 과금 없음, ~/.claude 무변경 (기본 커밋 dc7ba1d = v5.6.0, 2026-10-01)
```

## 결과 — 책(집필 2026년 상반기)과 지금(v5.6.0)

| 책 | v5.6.0 실측 |
|---|---|
| 30개 이상의 전문 에이전트 | **19개** — opus 7(analyst, architect, code-reviewer, code-simplifier, critic, planner, security-reviewer), sonnet 10(debugger, designer, document-specialist, executor, git-master, qa-tester, scientist, test-engineer, tracer, verifier), haiku 2(explore, writer) |
| 티어 예시: file-scanner·keyword-extractor(haiku), code-writer·api-integrator(sonnet), architect·reviewer(opus) | 이름이 다르다. 티어는 에이전트 정의의 `model:` 필드로 **고정**돼 있다 |
| 스킬: orchestrate, ralph, ultrawork, learner | 스킬 47개. `ralph`·`autopilot`·`team`·`ralplan`·`omc-setup`은 있음. **`ultrawork`는 은퇴**(cancel 스킬: "Treat Ultrawork as retired", 대신 `/execute`), `orchestrate`·`learner` 없음 |
| 훅이 `rm -rf` 같은 위험한 명령을 차단 | 아래 표 — **`rm -rf /`는 OMC의 PreToolUse 훅 둘 다 통과** |

### PreToolUse 훅이 실제로 막는 것

```text
git-guardrails.mjs   git push origin main       (기본)                 → 통과(exit 0)
git-guardrails.mjs   git push origin main       OMC_GIT_GUARDRAILS=1   → 차단: Git guardrail: blocked "git push".
git-guardrails.mjs   git reset --hard HEAD~1    (기본)                 → 통과(exit 0)
git-guardrails.mjs   git reset --hard HEAD~1    OMC_GIT_GUARDRAILS=1   → 차단: Git guardrail: blocked "git reset --hard".
git-guardrails.mjs   rm -rf /                   OMC_GIT_GUARDRAILS=1   → 통과(exit 0)
pre-tool-enforcer.mjs rm -rf /                   (기본)                 → 통과(exit 0)
```

- git 가드레일은 **꺼진 것이 기본**이다. 켜지는 조건은 둘 — 환경 변수 `OMC_GIT_GUARDRAILS=1`, 또는 무인 모드(ralph·autopilot·team·ultragoal)가 활성일 때(스크립트 머리 주석).
  켜지면 `git push`, `git reset --hard`, `git clean -f`, `git branch -D`, `git checkout/restore .`를 exit 2로 막는다.
- `rm -rf`를 막는 OMC 훅은 이 버전에 없다. (클로드 코드 **자체**에는 `rm -rf /` 류를 막는 내장 안전 검사가 있다 — 이 책 실습 중에도 변수 하나로 경로가 정해지는 `rm`이 그 검사에 막혔다. 플러그인의 기능과 본체의 기능을 구분해 두자.)
- 훅 스크립트 자체의 머리 주석이 좋은 원칙을 말한다: *"A guardrail must bite to count: feed it a planted violation and watch it block before trusting it."* — 이 폴더가 한 일이 그것이다.

### 훅이 붙는 지점 (11종 30개)

`UserPromptSubmit(2) SessionStart(7) PreToolUse(2) PermissionRequest(1) PostToolUse(4) PostToolUseFailure(1) SubagentStart(1) SubagentStop(2) PreCompact(3) Stop(5) SessionEnd(2)`
— 책 표 4-3의 6종보다 훨씬 많다. 매 프롬프트(UserPromptSubmit)와 매 도구 호출(PreToolUse·PostToolUse)마다 node 프로세스가 뜬다는 뜻이기도 하다.

## 결론

빠르게 변하는 서드파티 플러그인은 **책의 설명을 그대로 믿지 말고, 설치 전에 그 버전의 소스를 본다** — 에이전트 목록, 훅이 붙는 지점과 하는 일, 홈 디렉터리에 쓰는 것.
"위험한 명령을 막아 준다"는 말은 특히 **직접 위반을 넣어 보고** 확인한다.
