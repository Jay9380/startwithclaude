#!/usr/bin/env python3

import sys
import os
import fcntl
from datetime import datetime
from pathlib import Path

def main():
    if len(sys.argv) < 2:
        sys.stderr.write("Error: Missing argument\n")
        sys.exit(1)

    text = sys.argv[1]

    # Validate input
    if not text or not text.strip():
        sys.stderr.write("Error: Empty input\n")
        sys.exit(1)

    # Determine save directory
    til_dir = os.getenv("TIL_DIR") or os.path.expanduser("~/til")
    til_path = Path(til_dir)
    til_path.mkdir(parents=True, exist_ok=True)

    # Get current local time
    now = datetime.now()
    date_str = now.strftime("%Y-%m-%d")
    time_str = now.strftime("%H:%M")

    # File path
    file_path = til_path / f"{date_str}.md"

    # Lock and write
    try:
        # Try to open existing file, or create new one
        try:
            f = open(file_path, "r+", encoding="utf-8")
        except FileNotFoundError:
            f = open(file_path, "w", encoding="utf-8")
            f.write(f"# {date_str}\n\n")

        # Acquire exclusive lock
        fcntl.flock(f.fileno(), fcntl.LOCK_EX)
        try:
            # Move to end of file and append entry
            f.seek(0, 2)
            f.write(f"- {time_str} {text}\n")
            f.flush()
        finally:
            fcntl.flock(f.fileno(), fcntl.LOCK_UN)
            f.close()
    except Exception as e:
        sys.stderr.write(f"Error: {e}\n")
        sys.exit(1)

if __name__ == "__main__":
    main()
