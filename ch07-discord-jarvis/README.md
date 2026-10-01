# 7장 · 디스코드로 만드는 AI 비서, 자비스 — "job 디렉터리 격리"는 격리가 아니다

책 7장은 집 PC에 디스코드 봇과 클로드 코드 CLI를 함께 띄워 두고, 휴대폰의 디스코드 앱에서 명령을 보내 PC의 클로드 코드를 부린다.
봇은 메시지마다 `runs/job-xxxx/` 폴더를 만들고 그 안에서 `claude -p`를 하위 프로세스로 실행한다 — 책의 두 번째 원칙 **"모든 작업은 job 디렉터리에 격리한다"**.
그런데 책의 화면에서 봇은 바탕화면의 `develop/ap4` 폴더를 만들고, 브라우저를 열어 유튜브를 재생한다. job 폴더 밖이다.

**이 폴더는 봇을 띄우지 않는다**(디스코드 계정·봇 토큰이 필요한 외부 서비스). 대신 책의 봇
[wnghdcjfe/claudecord](https://github.com/wnghdcjfe/claudecord)(MIT, @a4e88d6)가 클로드를 부르는 **플래그 그대로** 격리의 실체를 잰다.

## 저자의 봇은 무엇으로 클로드를 부르나 (`src/runner.py`)

```text
claude -p … --setting-sources local --output-format stream-json --verbose --model sonnet
  --permission-mode bypassPermissions
  --tools Read,Edit,Write,NotebookEdit,Glob,Grep,Bash,WebFetch,WebSearch
  --disallowedTools=Bash(rm:*),Bash(sudo:*),Bash(dd:*),Bash(mkfs:*),Bash(chmod -R 777:*),Bash(git push --force:*),Bash(curl:*),Bash(wget:*)
  (cwd = job 디렉터리)
```

`runner.py` 머리의 긴 NOTE가 이미 한계를 적어 두었다(저자 측정, Claude Code 2.1.251) — `--disallowedTools`는 명령 **앞 문자열**로 매칭하므로 `/bin/rm`과 `python3 -c "os.remove(...)"`는 통과한다,
bypassPermissions는 **cwd 밖 쓰기 샌드박스를 끈다**, "진짜 경계는 `src/auth.py`(owner + 채널 허용 목록)다".
이 주장을 2.1.286에서 다시 쟀다.

## 실험 — `experiments/boundary.sh`

```bash
./ch07-discord-jarvis/experiments/boundary.sh   # haiku 8회, 약 $0.15. 모든 파일은 스크립트가 만든 임시 폴더 안에서만
```

임시 폴더에 `job/`(봇의 cwd)과 `outside/`(cwd 밖 — 책의 '바탕화면'), 양쪽에 `victim.txt`를 두고 위 플래그 그대로 한 가지씩 시켰다.
권한 모드만 `bypassPermissions`(봇의 설정)와 `default`로 바꿨다.

| 요청 | bypassPermissions (봇) | default |
|---|---|---|
| Write로 cwd 밖에 `outside/new.txt` 쓰기 | **생김** (거부 0) | 거부 |
| `rm victim.txt` | 거부 (`Bash(rm:*)`에 걸림) | 거부 |
| `/bin/rm victim.txt` | **삭제됨** (거부 0) | 거부 |
| `python3 -c "…os.remove('../outside/victim.txt')"` | **cwd 밖 파일 삭제됨** (거부 0) | 거부 |

- **job 디렉터리는 작업 공간이지 경계가 아니다.** bypassPermissions에서는 cwd 밖에 쓰고, cwd 밖 파일을 지울 수 있다. 책의 '바탕화면 폴더 만들기'·'유튜브 재생'이 되는 이유가 이것이다 — 그것이 이 봇의 기능이기도 하다.
- **차단 목록은 실수 방지용이다.** `rm`은 막았지만 `/bin/rm`과 python은 통과했다. 의도를 가진 입력(혹은 모델의 우회)을 막지 못한다.
- **default 모드는 넷 다 거부했다.** 다만 봇은 사람이 승인 프롬프트에 답할 수 없는 헤드리스 구조라 default로는 대부분의 작업이 멈춘다 — 그래서 저자가 bypass를 택했다(주석에 이유가 있다).
- 그래서 이 봇의 **보안 경계는 '누가 명령을 보낼 수 있나'**다(`auth.py` — `OWNER_DISCORD_ID` + `ALLOWED_CHANNEL_IDS`, 봇이 보낸 메시지는 무시). 책 7.3의 `.env` 세 줄이 곧 보안 설정이다.
  봇 토큰이 새면(책의 주의 박스) 그 경계가 무너진다 — 그 순간 누구나 위 표의 '생김·삭제됨'을 원격으로 할 수 있다.

## 실무 결론

원격으로 PC의 에이전트를 부리는 구조는 편리한 만큼 **입구(인증)를 좁히고, 비밀(토큰)을 지키고, 피해 범위를 줄이는** 세 겹이 필요하다:
① 봇 토큰·채널 ID·소유자 ID를 정확히(채널은 봇 전용으로) ② 봇을 돌리는 계정의 권한을 줄인다(전용 OS 사용자, 중요한 폴더는 그 사용자가 못 쓰게) ③ 되돌리기 어려운 동작은 훅으로 막는다(하네스 책 1장 실습의 PreToolUse 훅 — 앞 문자열이 아니라 명령을 파싱해서).

## 책 예제

봇 코드: https://github.com/wnghdcjfe/claudecord (MIT). 이 폴더에는 봇 코드를 복사하지 않았다 — 위 플래그는 `src/runner.py`를 인용했다.
