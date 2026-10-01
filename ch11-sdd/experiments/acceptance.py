#!/usr/bin/env python3
"""til.py 숨은 수용 테스트 (모델에게 보여 주지 않는다). 사용: python3 acceptance.py <til.py가 있는 폴더>
각 항목을 PASS/FAIL로 찍고 마지막 줄에 'score n/7'."""
import os
import subprocess
import sys
import tempfile
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime

ROOT = os.path.abspath(sys.argv[1])
TIL = os.path.join(ROOT, "til.py")


def run(text, tdir, tz=None):
    env = dict(os.environ, TIL_DIR=tdir)
    if tz:
        env["TZ"] = tz
    return subprocess.run([sys.executable, TIL, text], env=env, capture_output=True, text=True, timeout=20)


def today(tz=None):
    env = dict(os.environ)
    if tz:
        env["TZ"] = tz
    return subprocess.run([sys.executable, "-c", "from datetime import datetime;print(datetime.now().strftime('%Y-%m-%d'))"],
                          env=env, capture_output=True, text=True).stdout.strip()


def lines(tdir, day):
    p = os.path.join(tdir, f"{day}.md")
    return open(p, encoding="utf-8").read().splitlines() if os.path.exists(p) else None


def check(name, fn):
    try:
        ok = fn()
    except Exception as e:  # 실행 자체가 깨지면 FAIL
        ok = False
        name += f" ({type(e).__name__})"
    print(("PASS " if ok else "FAIL ") + name)
    return bool(ok)


def t_format():
    d = tempfile.mkdtemp(); run("첫 줄", d); ls = lines(d, today())
    return ls and ls[0] == f"# {today()}" and ls[1] == "" and ls[2].startswith("- ") and ls[2][2:7].count(":") == 1 and ls[2].endswith(" 첫 줄")


def t_append():
    d = tempfile.mkdtemp(); run("하나", d); run("둘", d); ls = lines(d, today())
    return ls and sum(l.startswith("# ") for l in ls) == 1 and sum(l.startswith("- ") for l in ls) == 2


def t_empty():
    d = tempfile.mkdtemp(); r1 = run("", d); r2 = run("   ", d)
    return r1.returncode != 0 and r2.returncode != 0 and r1.stderr.strip() and r2.stderr.strip() and not os.listdir(d)


def t_utf8():
    d = tempfile.mkdtemp(); run("한글 그대로 🌧️ 우산", d); ls = lines(d, today())
    return ls and ls[-1].endswith("한글 그대로 🌧️ 우산")


def t_localtz():
    ok = True
    for tz in ("Pacific/Kiritimati", "Pacific/Pago_Pago"):   # UTC+14, UTC-11 — 둘 중 하나는 UTC 날짜와 다르다
        d = tempfile.mkdtemp(); run("tz", d, tz)
        ok &= os.path.exists(os.path.join(d, f"{today(tz)}.md"))
    return ok


def t_concurrent():
    d = tempfile.mkdtemp()
    with ThreadPoolExecutor(20) as ex:
        list(ex.map(lambda i: run(f"동시 {i}", d), range(20)))
    ls = lines(d, today())
    return ls and sum(l.startswith("# ") for l in ls) == 1 and sum(l.startswith("- ") for l in ls) == 20


def t_default_dir():
    # TIL_DIR이 없으면 ~/til — HOME을 임시 폴더로 바꿔서 확인 (실제 홈은 건드리지 않는다)
    h = tempfile.mkdtemp(); env = dict(os.environ, HOME=h); env.pop("TIL_DIR", None)
    subprocess.run([sys.executable, TIL, "홈"], env=env, capture_output=True, timeout=20)
    return os.path.exists(os.path.join(h, "til", f"{today()}.md"))


if not os.path.exists(TIL):
    print("FAIL til.py 없음\nscore 0/7"); sys.exit(0)
tests = [("형식(헤더·빈 줄·- HH:MM 본문)", t_format), ("같은 날 누적", t_append), ("빈 입력 거부", t_empty),
         ("UTF-8", t_utf8), ("로컬 시간대", t_localtz), ("동시 실행 20", t_concurrent), ("기본 경로 ~/til", t_default_dir)]
score = sum(check(n, f) for n, f in tests)
print(f"score {score}/{len(tests)}")
