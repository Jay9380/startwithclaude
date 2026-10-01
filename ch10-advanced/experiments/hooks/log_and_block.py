#!/usr/bin/env python3
"""10.4.5 matcher + if 실험용: 불릴 때마다 명령을 hook.log에 남기고 exit 2로 막는다."""
import json
import os
import sys

data = json.load(sys.stdin)
cmd = data.get("tool_input", {}).get("command", "")
with open(os.path.join(os.environ.get("CLAUDE_PROJECT_DIR", "."), "hook.log"), "a") as f:
    f.write(f"rm_hook {cmd}\n")
print("rm은 훅이 막습니다.", file=sys.stderr)
sys.exit(2)
