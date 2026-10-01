#!/usr/bin/env python3
"""리포트의 기계로 판정 가능한 규칙(R1 수치·R4 날짜·R5 결론)을 data.json과 대조한다. 사용: python3 check_report.py report.md data.json
R1: 리포트의 'N,NNN원'과 날짜-가격 쌍이 data.json과 맞는지, 기간 첫/끝 종가·최고·최저·등락률을 다시 계산해 비교."""
import json
import re
import sys

text = open(sys.argv[1], encoding="utf-8").read()
data = json.load(open(sys.argv[2], encoding="utf-8"))
closes = {r["date"]: r["close"] for r in data["closes"]}
vals = list(closes.values())
first, last = vals[0], vals[-1]
derived = {first, last, max(vals), min(vals), abs(last - first)}
pct = round((last - first) / first * 100, 2)
issues = []
for m in re.finditer(r"(\d{1,3}(?:,\d{3})+)\s*원", text):
    v = int(m.group(1).replace(",", ""))
    if v not in vals and v not in derived:
        issues.append(f"R1 data.json에 없는 가격 {m.group(1)}원")
for m in re.finditer(r"(\d{4}-\d{2}-\d{2})의?\s*(\d{1,3}(?:,\d{3})+)\s*원", text):
    d, v = m.group(1), int(m.group(2).replace(",", ""))
    if d in closes and closes[d] != v:
        issues.append(f"R1 {d} 종가 불일치: 리포트 {m.group(2)} / data {closes[d]:,}")
for m in re.finditer(r"(\d+(?:\.\d+)?)\s*%", text):
    v = float(m.group(1))
    if abs(v - abs(pct)) > 0.01 and v not in (12.0,):   # 12%는 사실 S2
        issues.append(f"R1 등락률 {m.group(0)} (data 기준 {pct}%)")
for m in re.finditer(r"\d{1,2}/\d{1,2}|\d{4}년\s*\d{1,2}월(?:\s*\d{1,2}일)?|\d{1,2}월\s*\d{1,2}일", text):
    issues.append(f"R4 날짜 형식 '{m.group(0)}'")
if "## 결론" not in text:
    issues.append("R5 ## 결론 없음")
print(f"data: 첫 {first:,} 끝 {last:,} 최고 {max(vals):,}({max(closes, key=closes.get)}) 최저 {min(vals):,}({min(closes, key=closes.get)}) 등락 {pct}%")
print("\n".join(issues) if issues else "기계 판정 위반 없음")
