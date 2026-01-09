#!/usr/bin/env python3
"""
Loop Agent Stop Gate - Lightweight verification for loop agents.

Ensures loop agents:
1. Ran tests (if applicable)
2. Committed all changes (including progress file)

Only activates when CLAUDE_LOOP_AGENT=1 is set (by loop.sh).
Regular Claude sessions are unaffected.
"""

import json
import os
import subprocess
import sys


def get_env(name: str, default: str = "") -> str:
    return os.environ.get(name, default)


def run_command(cmd: list[str], timeout: int = 10) -> tuple[bool, str]:
    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=timeout,
            cwd=get_env("CLAUDE_PROJECT_DIR", os.getcwd()),
        )
        return result.returncode == 0, result.stdout.strip()
    except (subprocess.TimeoutExpired, FileNotFoundError) as e:
        return False, str(e)


def main():
    try:
        input_data = json.load(sys.stdin)
    except json.JSONDecodeError:
        sys.exit(0)

    # Only activate for loop agents
    if not get_env("CLAUDE_LOOP_AGENT"):
        sys.exit(0)

    # Prevent infinite loops
    if input_data.get("stop_hook_active", False):
        sys.exit(0)

    session_name = get_env("CLAUDE_LOOP_SESSION", "default")

    # Check for uncommitted changes
    _, git_status = run_command(["git", "status", "--porcelain"])

    # If clean, allow stop
    if not git_status:
        sys.exit(0)

    # Has uncommitted changes - prompt to verify tests and commit
    prompt = f"""## Loop Agent - Uncommitted Changes Detected

You have uncommitted changes:
```
{git_status}
```

Before stopping, ensure:

1. **Tests pass** - If this project has a test suite, run it now
2. **Commit everything** - Including any updates to the progress file

**Progress file:** Always APPEND to `scripts/loop/progress-{session_name}.txt` (never overwrite).

Once tests pass and all changes are committed, you may stop.
"""

    output = {"decision": "block", "reason": prompt}
    print(json.dumps(output))
    sys.exit(0)


if __name__ == "__main__":
    main()
