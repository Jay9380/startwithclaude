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

## 출처

책의 예제 저장소는 [wnghdcjfe/claude](https://github.com/wnghdcjfe/claude)다. **라이선스 파일이 없어** 이 저장소에는 예제 코드를 복사하지 않았다.
여기 있는 코드는 책의 설명을 따라 직접 작성한 것이고, 대응하는 예제 폴더는 각 장 README에 링크로 적었다. 책 본문은 포함하지 않는다.
