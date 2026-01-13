# Ralph Agent Instructions

Read context from: ${CTX}
Progress file: ${PROGRESS}

${CONTEXT}

## Your Task

1. Read `${PROGRESS}`
   (check Codebase Patterns first)
2. Check remaining tasks:
   ```bash
   bd ready --label=pipeline/${SESSION_NAME}
   ```
3. Pick highest priority task
4. Claim it:
   ```bash
   bd update <bead-id> --status=in_progress
   ```
5. Implement that ONE task
6. Run tests (if available)
7. Commit: `feat: [bead-id] - [Title]`
8. Close the task:
   ```bash
   bd close <bead-id>
   ```
9. Append learnings to progress file

## Progress Format

APPEND to ${PROGRESS}:

```markdown
## [Date] - [bead-id]
- What was implemented
- Files changed
- **Learnings:**
  - Patterns discovered
  - Gotchas encountered
---
```

## Codebase Patterns

Add reusable patterns to the TOP of progress file:

```markdown
## Codebase Patterns
- [Pattern]: [How to use it]
- [Pattern]: [How to use it]
```

## Stop Condition

If queue is empty:
```bash
bd ready --label=pipeline/${SESSION_NAME}
# Returns nothing = done
```

Write to `${STATUS}`:

```json
{
  "decision": "stop",
  "reason": "All tasks complete",
  "summary": "Queue empty",
  "work": {"items_completed": [], "files_touched": []},
  "errors": []
}
```

Otherwise, write `"decision": "continue"` and end normally.
