#!/usr/bin/env python3
"""책 10.4.7 예시 1과 같은 판정: Edit/Write 대상 경로에 '.env'가 들어 있으면 막는다.
종료 코드는 인자로 받는다(2 = 차단, 1 = 책 NOTE의 '차단이 아닌' 코드). 호출될 때마다 hook.log에 한 줄 남긴다."""
import json
import os
import sys

code = int(sys.argv[1]) if len(sys.argv) > 1 else 2
data = json.load(sys.stdin)
path = data.get("tool_input", {}).get("file_path", "")
with open(os.path.join(os.environ.get("CLAUDE_PROJECT_DIR", "."), "hook.log"), "a") as f:
    f.write(f"env_guard {data.get('tool_name')} {path}\n")
if ".env" in path:
    print(".env 파일은 수동으로만 수정해야 합니다.", file=sys.stderr)
    sys.exit(code)
