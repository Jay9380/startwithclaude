#!/usr/bin/env python3
"""8장 실습: 책이 '클로드(웹)에서 눈으로 보라'고 한 주장을 숫자로 잰다.

  A. 제로샷 vs 원샷 — 같은 감정 분류를 여러 번 돌렸을 때 출력 '모양'이 몇 가지로 갈리나
  B. 퓨샷과 다수 레이블 편향 — 책의 CS 분류 예시(균형) vs 우선순위가 전부 '높음'인 예시
  C. 출력 형식은 품질 기준인가 — 8.1.1 뉴스레터 프롬프트의 '본문 200자 이내'를 실제로 지키나
  D. 한글 vs 영문 토큰 — 같은 프롬프트의 input_tokens 차이

claude.ai 웹과 비슷하게 하려고 클로드 코드의 시스템 프롬프트·도구를 모두 뺀다
(--system-prompt 한 줄, --tools ""). 모델은 haiku, 호출당 약 $0.002.
사용: python3 prompt_lab.py [A|B|C|D|all] [반복수=3]
"""
import concurrent.futures as cf
import json
import os
import re
import subprocess
import sys
from collections import Counter

os.environ["ENABLE_CLAUDEAI_MCP_SERVERS"] = "false"
HERE = os.path.dirname(os.path.abspath(__file__))
RUNS = os.path.join(HERE, "..", "runs")
os.makedirs(RUNS, exist_ok=True)


def ask(prompt: str) -> dict:
    cmd = ["claude", "-p", prompt, "--system-prompt", "You are a helpful assistant.", "--tools", "",
           "--setting-sources", "project", "--strict-mcp-config", "--model", "haiku", "--output-format", "json"]
    out = subprocess.run(cmd, stdin=subprocess.DEVNULL, capture_output=True, text=True, cwd=RUNS).stdout
    try:
        d = json.loads(out)
    except json.JSONDecodeError:
        return {"result": "", "cost": 0, "in": 0}
    return {"result": d.get("result", ""), "cost": d.get("total_cost_usd", 0), "in": d["usage"]["input_tokens"]}


def ask_many(prompts: list[str]) -> list[dict]:
    with cf.ThreadPoolExecutor(4) as ex:
        return list(ex.map(ask, prompts))


LABEL = re.compile(r"(Positive|Negative|Neutral|Mixed|긍정적?|부정적?|중립적?|혼합)", re.I)


def label_of(text: str) -> str:
    """'감정:' 뒤(없으면 본문 처음)에 처음 나오는 라벨 단어. 모델이 쓴 '어휘'를 본다."""
    t = text.split("감정:", 1)[-1] if "감정:" in text else text
    m = LABEL.search(t)
    return m.group(1) if m else "?"


def bare(text: str) -> bool:
    """설명 없이 라벨 한 단어만 냈나 (마크다운 굵게 표시는 무시)."""
    t = text.replace("*", "").strip()
    return bool(LABEL.fullmatch(t))


# ---------- A. 제로샷 vs 원샷 ----------
REVIEWS = ["별로다", "돈이 아깝지 않았다", "그냥 그랬어", "배우 연기는 좋은데 스토리가 산으로 간다", "두 번 봤다", "졸았다"]
ZERO = '다음 리뷰의 감정을 분류해 줘.\n리뷰: "{r}"\n감정:'
ONE = '리뷰: "좋아요"\n감정: Positive\n리뷰: "{r}"\n감정:'
# 원샷 + 출력 형식을 말로 못 박기 (8.1의 '5. 출력 형식')
ONE_STRICT = '라벨 한 단어(Positive/Negative/Neutral)만 출력하고 설명은 하지 마.\n' + ONE


def exp_a(n: int) -> dict:
    res = {}
    for name, tpl in [("zero-shot", ZERO), ("one-shot", ONE), ("one-shot+형식", ONE_STRICT)]:
        outs = ask_many([tpl.format(r=r) for r in REVIEWS for _ in range(n)])
        labels = Counter(label_of(o["result"]) for o in outs)
        nbare = sum(bare(o["result"]) for o in outs)
        res[name] = {"calls": len(outs), "label_vocab": labels.most_common(), "bare": nbare,
                     "avg_chars": round(sum(len(o["result"]) for o in outs) / len(outs)),
                     "cost": round(sum(o["cost"] for o in outs), 3)}
        print(f"A {name:12s} 호출 {len(outs)}  라벨만 {nbare}  평균 {res[name]['avg_chars']}자  어휘 {labels.most_common()}")
    return res


# ---------- B. 퓨샷 / 다수 레이블 편향 ----------
HEAD = ("고객 문의를 [카테고리]와 [우선순위]로 분류하세요.\n"
        "카테고리: 결제오류 | 배송문의 | 계정문제 | 환불요청 | 기타\n우선순위: 높음 | 보통 | 낮음\n\n")
# 책 p.284의 예시 4개(카테고리와 우선순위가 섞여 있다)
BALANCED = [("어제 결제했는데 카드 이중 청구됐어요. 빨리 확인해 주세요.", "결제오류", "높음"),
            ("주문한 지 5일 됐는데 배송 조회가 안 됩니다.", "배송문의", "보통"),
            ("비밀번호 바꿨는데 로그인이 계속 안 돼요. 내일까지 꼭 써야 해서요.", "계정문제", "높음"),
            ("구매한 상품 색상이 마음에 안 들어서 환불하고 싶어요.", "환불요청", "보통")]
# 같은 문의 4개인데 우선순위 라벨만 전부 '높음' — 책 NOTE의 majority label bias 조건
SKEWED = [(q, c, "높음") for q, c, _ in BALANCED]
# 정답을 내가 붙인 시험 문항. 우선순위는 급함 표현이 있으면 높음, 없으면 보통/낮음.
TESTS = [("영수증 재발행 가능한가요? 급하진 않습니다.", "기타", "낮음"),
         ("포인트 적립 기준이 궁금해요.", "기타", "낮음"),
         ("배송지 주소를 바꿀 수 있나요?", "배송문의", "보통"),
         ("결제 화면에서 쿠폰 적용이 안 돼요.", "결제오류", "보통"),
         ("이메일 수신 설정은 어디서 바꾸나요?", "계정문제", "낮음"),
         ("사이즈가 작아서 반품하려고요. 천천히 처리해 주셔도 돼요.", "환불요청", "낮음"),
         ("택배가 분실된 것 같아요. 선물이라 오늘 꼭 받아야 해요!", "배송문의", "높음"),
         ("해외 결제가 세 번이나 승인됐어요. 지금 당장 막아 주세요.", "결제오류", "높음")]
# 급하다/안 급하다는 단서가 없는 문항. 정답이 없으니 '높음'으로 몇 번 쏠리는지만 센다.
AMBIG = ["결제 수단을 변경하고 싶어요.", "주문 내역이 앱에서 안 보여요.", "적립금이 아직 안 들어왔어요.",
         "교환 신청은 어떻게 하나요?", "닉네임을 바꾸고 싶어요.", "배송 기사님 연락처를 알 수 있나요?"]


def few(examples) -> str:
    return HEAD + "".join(f'문의: "{q}"\n분류: 카테고리={c}, 우선순위={p}\n\n' for q, c, p in examples)


def parse(text: str):
    m = re.search(r"카테고리\s*=\s*(\S+?)\s*,\s*우선순위\s*=\s*(높음|보통|낮음)", text)
    return (m.group(1), m.group(2)) if m else None


def parse_loose(text: str):
    """형식은 무시하고, 처음 나오는 카테고리 단어와 우선순위 단어만 본다 (제로샷 내용 채점용)."""
    c = re.search(r"결제오류|배송문의|계정문제|환불요청|기타", text)
    p = re.search(r"높음|보통|낮음", text)
    return (c.group(0) if c else None, p.group(0) if p else None)


def exp_b(n: int) -> dict:
    res = {}
    for name, prefix in [("zero-shot", HEAD), ("few-balanced", few(BALANCED)), ("few-all-high", few(SKEWED))]:
        outs = ask_many([f'{prefix}문의: "{q}"\n분류:' for q, _, _ in TESTS for _ in range(n)])
        gold = [(c, p) for _, c, p in TESTS for _ in range(n)]
        fmt = sum(parse(o["result"]) is not None for o in outs)
        loose = [parse_loose(o["result"]) for o in outs]
        cat = sum(l[0] == g[0] for l, g in zip(loose, gold))
        pri = sum(l[1] == g[1] for l, g in zip(loose, gold))
        amb = ask_many([f'{prefix}문의: "{q}"\n분류:' for q in AMBIG for _ in range(n)])
        amb_p = Counter(parse_loose(o["result"])[1] for o in amb)
        res[name] = {"calls": len(outs) + len(amb), "format_ok": fmt, "category_ok": cat, "priority_ok": pri,
                     "n": len(outs), "ambiguous_priority": amb_p.most_common(),
                     "cost": round(sum(o["cost"] for o in outs + amb), 3)}
        print(f"B {name:12s} 형식 {fmt}/{len(outs)}  카테고리 {cat}  우선순위 {pri}  모호 문항 우선순위 {amb_p.most_common()}")
    return res


# ---------- C. 뉴스레터 '본문 200자 이내' ----------
NEWS = open(os.path.join(HERE, "newsletter_prompt.txt"), encoding="utf-8").read()


def exp_c(n: int) -> dict:
    outs = ask_many([NEWS] * n)
    rows = []
    for o in outs:
        m = re.search(r"\{.*\}", o["result"], re.S)
        try:
            d = json.loads(m.group(0)) if m else None
        except json.JSONDecodeError:
            d = None
        if not d:
            rows.append({"parsed": False})
            continue
        for v in d.get("versions", []):
            body = v.get("body", "")
            rows.append({"parsed": True, "label": v.get("label"), "body_chars": len(body),
                         "over_200": len(body) > 200, "has_280": "280" in body + v.get("title", ""),
                         "has_5min": "5분" in body + v.get("title", ""),
                         "cta_sentences": len([s for s in re.split(r"[.!?]\s*", v.get("cta", "")) if s.strip()])})
    ok = [r for r in rows if r.get("parsed")]
    print(f"C 버전 {len(ok)}개 파싱  본문 길이 {[r['body_chars'] for r in ok]}  "
          f"200자 초과 {sum(r['over_200'] for r in ok)}  CTA 1문장 {sum(r['cta_sentences'] == 1 for r in ok)}  "
          f"A에 280 {sum(r['has_280'] for r in ok if r['label'] == 'A')}  B에 5분 {sum(r['has_5min'] for r in ok if r['label'] == 'B')}")
    return {"rows": rows, "cost": round(sum(o["cost"] for o in outs), 3)}


# ---------- D. 한글 vs 영문 토큰 ----------
def exp_d(_: int) -> dict:
    ko = NEWS
    en = open(os.path.join(HERE, "newsletter_prompt_en.txt"), encoding="utf-8").read()
    base, k, e = ask_many(["hi", ko, en])
    kt, et = k["in"] - base["in"], e["in"] - base["in"]
    print(f"D 기준선 {base['in']}  한글 +{kt}  영문 +{et}  비율 {kt / et:.2f}배  (글자 수 한글 {len(ko)} 영문 {len(en)})")
    return {"baseline": base["in"], "ko_tokens": kt, "en_tokens": et, "ratio": round(kt / et, 2),
            "ko_chars": len(ko), "en_chars": len(en)}


if __name__ == "__main__":
    which = sys.argv[1] if len(sys.argv) > 1 else "all"
    n = int(sys.argv[2]) if len(sys.argv) > 2 else 3
    out = {}
    for key, fn in [("A", exp_a), ("B", exp_b), ("C", exp_c), ("D", exp_d)]:
        if which in (key, "all"):
            out[key] = fn(n)
    json.dump(out, open(os.path.join(RUNS, f"lab-{which}.json"), "w"), ensure_ascii=False, indent=1, default=str)
