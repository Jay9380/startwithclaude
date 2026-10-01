#!/usr/bin/env python3
"""stream-json 한 줄 요약: 도구 호출(이름·대상)과 오류 여부를 순서대로, 끝에 결과 앞부분."""
import json
import sys

calls, result = [], ""
for line in open(sys.argv[1], encoding="utf-8"):
    try:
        d = json.loads(line)
    except json.JSONDecodeError:
        continue
    if d.get("type") == "assistant":
        for c in d["message"]["content"]:
            if c.get("type") == "tool_use":
                i = c["input"]
                calls.append(f'{c["name"]}({i.get("command") or i.get("file_path", "").split("/")[-1]})')
    elif d.get("type") == "user" and isinstance(d["message"].get("content"), list):
        for c in d["message"]["content"]:
            if c.get("type") == "tool_result" and c.get("is_error") and calls:
                calls[-1] += "✗"
    elif d.get("type") == "result":
        result = d.get("result", "")[:70].replace("\n", " ")
print(" → ".join(calls), "|", result)
