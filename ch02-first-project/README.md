# 2장 · 클로드 코드, 새로운 개발 파트너 — 첫 프로젝트(자기소개 페이지)

책 2.5의 실습은 `my-intro/index.html` 자기소개 페이지 한 장이다. 핵심 주장은 **"디자이너에게 의뢰서를 건네듯" 디자인 브리프 네 칸(톤·레퍼런스 / 레이아웃 / 구성 요소 / 디테일)으로 전달하면 결과 품질이 눈에 띄게 달라진다**는 것.
그 주장을 브리프 항목 12개 점검으로 잰다.

```bash
cd ch02-first-project/experiments
./run.sh 2          # 짧은 요청 / 브리프 / 브리프+후속 수정 / 고친 브리프 (haiku, 약 $0.4)
./run.sh rescore    # 저장된 결과(../runs/*.html)만 다시 점검
```

| 파일 | 내용 |
|---|---|
| `brief.txt` | 책의 브리프(2.5.1)를 그대로 |
| `follow-up.txt` | 책의 후속 수정(2.5.4) — 떠다니는 점 30개, stagger, prefers-reduced-motion |
| `brief-fixed.txt` | 폰트 지시 한 줄만 바꾼 브리프(아래 '폰트' 참고) |
| `check_brief.js` | 브리프 12항목 + 후속 2항목을 정적 검사·jsdom으로 점검 |

## 결과 (Claude Code 2.1.286, haiku, 2026-10-02)

| 요청 | 브리프 12항목 | 폰트 | 후속(reduced-motion, stagger) |
|---|---|---|---|
| "자기소개 페이지를 하나 만들어 줘" ×2 | 2/12, 3/12 | 없음 | — |
| 책의 브리프 ×2 | **12/12, 12/12** | Google Fonts 링크 → **없는 폰트** | — |
| 브리프 + 후속 수정(`--continue`) ×2 | 12/12 유지 | (그대로) | **둘 다 반영** |
| 폰트 줄만 고친 브리프 ×1 | 12/12 | jsDelivr — 실제로 로드됨 | — |

- 브리프의 효과는 압도적이다. 짧은 요청은 색·구성·링크를 전부 모델의 평균값으로 채웠다(책: "모델이 추측하게 두면 어디서 본 듯한 무난한 페이지").
- 후속 수정은 `claude -p … --continue`(같은 세션 이어 가기)로 보냈고, 기존 12항목을 깨지 않고 추가 요구만 반영했다 — 책의 "말로 요청 → 결과 확인 → 다시 다듬기".

### 폰트 — 브리프의 틀린 지시를 그대로 따르고 '완료'라고 보고했다

책의 브리프는 "폰트는 Pretendard를 **Google Fonts CDN**으로 로드"다. 그런데 Google Fonts에는 Pretendard가 없다.

```text
$ curl -o /dev/null -w "%{http_code}" "https://fonts.googleapis.com/css2?family=Pretendard&display=swap"   → 400
$ curl -o /dev/null -w "%{http_code}" "https://cdn.jsdelivr.net/gh/orioncactus/pretendard@v1.3.9/dist/web/static/pretendard.min.css" → 200
```

두 번 모두 모델은 `fonts.googleapis.com/css2?family=Pretendard…` 링크를 넣었고, 완료 보고에 **"Google Fonts CDN — Pretendard 폰트 로드"**라고 적었다.
페이지는 시스템 폰트로 대체돼 겉보기엔 멀쩡하다 — 그래서 더 알아차리기 어렵다. 지시를 실제 CDN 주소로 바꾸자 그대로 따랐다.

> 모델은 **지시가 틀렸는지 확인하지 않고 지시대로** 만든다. 브리프의 '디테일' 칸에 외부 자원(URL, 버전, 서비스 이름)을 적을 때는 그 자원이 실제로 있는지 먼저 확인한다.
> 결과 확인도 눈으로 보는 것만으로는 부족하다 — 이번처럼 '조용한 대체'는 개발자 도구의 네트워크 탭(400)이나 점검 스크립트로만 보인다.

## 책 내용 중 지금 버전과 다른 점 (2.1.286 `claude --help` 기준)

| 책 | 지금 |
|---|---|
| 실행 모드 '기본(default)' | `--permission-mode` 선택지: `acceptEdits`, `auto`, `bypassPermissions`, `manual`, `dontAsk`, `plan` |
| `/effort high / medium / low` | `--effort` 선택지: `low`, `medium`, `high`, `xhigh`, `max` |

## 책 예제

대응하는 예제: https://github.com/wnghdcjfe/claude/tree/main/02 (라이선스 없음 — 코드는 복사하지 않았다)
