#!/usr/bin/env python3
"""9.2.2 실습 재현: 로그를 '통째로' vs '가공해서' 줄 때 토큰과 답의 정확도.

조건 (같은 질문, 같은 로그 app.log):
  full   로그 전체(581줄)를 그대로
  book   책의 가공: grep '\\[ERROR\\]' app.log | tail -20
  agg    가공을 한 단계 더: [ERROR] 다음 줄(에러 종류)까지 뽑아 종류별로 센다
채점: 답에 PaymentGatewayTimeout(가장 잦은 에러)과 DatabaseConnectionReset(한 번뿐인 에러)이 나오나.
도구 없이(--tools "") 프롬프트에 직접 넣어, input_tokens가 곧 컨텍스트 크기가 되게 했다. haiku.
사용: python3 log_lab.py [반복수=3]
"""
import concurrent.futures as cf
import json
import os
import subprocess
import sys

os.environ["ENABLE_CLAUDEAI_MCP_SERVERS"] = "false"
HERE = os.path.dirname(os.path.abspath(__file__))
RUNS = os.path.join(HERE, "..", "runs")
os.makedirs(RUNS, exist_ok=True)
LOG = os.path.join(RUNS, "app.log")
subprocess.run(f"python3 '{HERE}/gen_log.py' > '{LOG}'", shell=True, check=True)
sh = lambda c: subprocess.run(c, shell=True, capture_output=True, text=True, cwd=RUNS).stdout

CONTEXTS = {
    "full": open(LOG, encoding="utf-8").read(),
    "book": sh(r"grep '\[ERROR\]' app.log | tail -20"),
    "agg": sh(r"grep -A1 '\[ERROR\]' app.log | grep '^Error:' | cut -d: -f2 | sort | uniq -c | sort -rn"),
}
Q = "다음은 운영 서버 로그(또는 그 가공 결과)야. 가장 자주 발생한 에러의 종류와 원인을 알려 주고, 발생한 에러 종류를 모두 나열해 줘.\n\n"


def ask(ctx: str) -> dict:
    cmd = ["claude", "-p", Q + ctx, "--system-prompt", "You are a helpful assistant.", "--tools", "",
           "--setting-sources", "project", "--strict-mcp-config", "--model", "haiku", "--output-format", "json"]
    d = json.loads(subprocess.run(cmd, stdin=subprocess.DEVNULL, capture_output=True, text=True, cwd=RUNS).stdout)
    r = d.get("result", "")
    u = d["usage"]   # 긴 입력은 자동으로 캐시되므로 캐시 생성·적중분까지 더해야 컨텍스트 크기다
    return {"in": u["input_tokens"] + u.get("cache_creation_input_tokens", 0) + u.get("cache_read_input_tokens", 0), "cost": d.get("total_cost_usd", 0),
            "payment": "PaymentGatewayTimeout" in r, "db": "DatabaseConnectionReset" in r, "answer": r}


if __name__ == "__main__":
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 3
    out = {}
    for name, ctx in CONTEXTS.items():
        with cf.ThreadPoolExecutor(3) as ex:
            rs = list(ex.map(ask, [ctx] * n))
        out[name] = {"lines": len(ctx.splitlines()), "input_tokens": rs[0]["in"],
                     "payment_ok": sum(r["payment"] for r in rs), "db_found": sum(r["db"] for r in rs), "n": n,
                     "cost": round(sum(r["cost"] for r in rs), 3), "answers": [r["answer"] for r in rs]}
        o = out[name]
        print(f"{name:5s} {o['lines']:4d}줄  입력 {o['input_tokens']:6d}토큰  "
              f"PaymentGatewayTimeout {o['payment_ok']}/{n}  DatabaseConnectionReset {o['db_found']}/{n}  ${o['cost']}")
    json.dump(out, open(os.path.join(RUNS, "log_lab.json"), "w"), ensure_ascii=False, indent=1)
