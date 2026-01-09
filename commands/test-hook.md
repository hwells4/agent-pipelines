---
description: Test hook configuration
hooks:
  PreToolUse:
    - matcher: ""
      hooks:
        - type: command
          command: "echo 'HOOK FIRED: CLAUDE_PLUGIN_ROOT=${CLAUDE_PLUGIN_ROOT}' && echo 'CLAUDE_PROJECT_DIR=${CLAUDE_PROJECT_DIR}'"
          once: true
---

# Test Hook Command

This command tests whether:
1. PreToolUse hooks fire in command frontmatter
2. Environment variables like ${CLAUDE_PLUGIN_ROOT} are available

When you run this, watch for "HOOK FIRED" in the output before any tool executes.

## Test

Run any tool to trigger the hook:

```
Read a file, list directory, or do anything that uses a tool.
```
