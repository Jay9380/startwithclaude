# 클로드 코드 제대로 시작하기 — 장별 실습

『클로드 코드 제대로 시작하기』(황진성·주홍철, 길벗)를 읽으며 **각 장의 실습과 주장을 직접 돌려 보고 확인한 기록**이다.
책의 실습을 따라 만들되, "정말 그렇게 되는가"를 측정할 수 있는 곳은 측정해 남긴다.

## 환경

| 항목 | 값 |
|---|---|
| Claude Code | 2.1.286 (헤드리스 `claude -p` 실험은 `--output-format stream-json`) |
| 실험 모델 | 대부분 `haiku`(비용 절감) — 장마다 README에 명시 |
| 도구 | `bash`, `python3`, `node 22` |

헤드리스 실험은 임시 폴더에서 돌고 로그는 각 장의 `runs/`(`.gitignore` 대상)에 남는다. 실제 API를 호출하므로 비용이 든다 — 각 장 README에 실측 비용을 적었다.

```bash
python3 tools/summarize_stream.py runs/xxx.jsonl   # INIT / TOOL 호출 / ERR / RESULT(비용·턴)
```

## 장별 목차

| 장 | 폴더 | 확인하는 것 |
|---|---|---|
| 1장 바이브 코딩 | [`ch01-vibe-coding`](ch01-vibe-coding) | 모호 vs 구체 프롬프트를 jsdom 기능 테스트로 채점(5/6 vs 6/6), Accept All 4가지 점검 스크립트 |
| 2장 첫 프로젝트 | [`ch02-first-project`](ch02-first-project) | 자기소개 페이지 — 짧은 요청 2~3/12 vs 디자인 브리프 12/12, 브리프의 틀린 폰트 지시(Google Fonts엔 Pretendard 없음)를 따르고 '완료' 보고 |
| 3장 링크나무 | [`ch03-linknamu`](ch03-linknamu) | 책의 프롬프트로 생성한 Next.js 앱 — 동시 클릭 200/200, URI에 DB 이름이 없으면 조용히 test DB로, 생성기가 CLAUDE.md를 덮은 것을 스스로 복구, 비밀 파일은 커밋에서 제외(2/2) |
| 4장 OMC | [`ch04-omc`](ch04-omc) | 플러그인을 설치하지 않고 고정 커밋 점검 — v5.6.0은 에이전트 19개(책: 30+), ultrawork 은퇴, git 가드레일은 기본 꺼짐, rm -rf는 OMC 훅이 막지 않음 |
| 5장 PRD와 플랜 모드 | [`ch05-prd-plan`](ch05-prd-plan) | 플랜 모드는 계획을 ~/.claude/plans/에 쓴다, 수용 기준 보고는 구현 가능 항목 36/36 일치 — 불가능한 기준엔 3회 중 1회 거짓 완료 |
| 6장 숏폼 파이프라인 | [`ch06-shortform`](ch06-shortform) | 리뷰가 지적한 자막 결함(어절 절단·숫자 음차 노출)을 코드·테스트로 고정, 리뷰→수정 루프는 인터페이스가 요구를 담으면 리뷰 없이도 3/3 |
| 7장 디스코드 자비스 | [`ch07-discord-jarvis`](ch07-discord-jarvis) | 봇과 같은 플래그로 격리 실측 — bypassPermissions에서 cwd 밖 쓰기·/bin/rm·python 삭제 통과, default는 4/4 거부. 경계는 owner·채널 허용 목록 |
| 8장 프롬프트 엔지니어링 | [`ch08-prompt-engineering`](ch08-prompt-engineering) | 원샷은 라벨 어휘만 고정(라벨만 출력 0/18) — 형식 지시 한 줄로 18/18, 퓨샷 형식 0→24/24, 다수 레이블 편향은 의미 단서 있는 과제에선 재현 안 됨, 한글 토큰 1.75배 |
| 9장 컨텍스트 엔지니어링 | [`ch09-context-engineering`](ch09-context-engineering) | 책의 로그 가공(grep\|tail)은 토큰 1/18이지만 에러 종류를 0/3으로 놓치고 "단일 종류"라 단정, 급한 요청이 any 금지를 덮는 사례는 재현 안 됨 — 대신 haiku는 DO NOT EDIT 생성 파일을 규칙이 있어도 15/15 수정(sonnet 0/6), /catchup의 !`git diff` 주입은 Bash 권한 없이도 실행 |
| 10장 클로드 코드 심화 | [`ch10-advanced`](ch10-advanced) | rules/ 안 파일은 paths 없으면 텍스트 참조여도 시작 시 로드(150줄≈9,900토큰) — 지연 로딩은 paths나 rules 밖, 훅 exit 1은 5/5 통과, if "Bash(rm *)"는 /bin/rm을 놓침, 스킬 description 짧으면 자동 호출 0/3 → 키워드 넣으면 2/3 |
| 11장 스펙 주도 개발 | [`ch11-sdd`](ch11-sdd) | 한 줄 요청은 3번 모두 다른 저장 경로·형식, C-C-C 체크박스 스펙은 숨은 수용 테스트 7/7을 6/6(산문 5/6), "스펙 먼저 읽어" 한 줄은 읽게만 할 뿐 스펙 갱신 0/3 — 갱신 규칙을 더하면 2/3 |
| 12장 하네스 엔지니어링 | [`ch12-harness`](ch12-harness) | 책 하네스의 투자 권유 금지 훅: 책 예시 5/5 차단, 바꿔 쓴 표현 0/6 차단, 같은 줄 부정어로 우회 / 자기 검토 vs 새 세션 검토는 --resume의 파일 변경 주입을 걷어 내자 차이 없음(haiku 4회), 대신 둘 다 해석 문장을 needs_fix |

## 출처

책의 예제 저장소는 [wnghdcjfe/claude](https://github.com/wnghdcjfe/claude)다. **라이선스 파일이 없어** 이 저장소에는 예제 코드를 복사하지 않았다.
여기 있는 코드는 책의 설명을 따라 직접 작성한 것이고, 대응하는 예제 폴더는 각 장 README에 링크로 적었다. 책 본문은 포함하지 않는다.
