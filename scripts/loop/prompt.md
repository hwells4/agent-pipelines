# Autonomous Agent

## Context

Session: ${SESSION_NAME}
Progress file: scripts/loop/progress-${SESSION_NAME}.txt

## Workflow

1. **Read progress file** for accumulated context and patterns:
   ```bash
   cat scripts/loop/progress-${SESSION_NAME}.txt
   ```

2. **List available stories** for this session:
   ```bash
   bd ready --tag=loop/${SESSION_NAME}
   ```

3. **Choose the most logical next story** based on:
   - What was already implemented (from progress file)
   - Dependencies and building blocks
   - Your judgment on what makes sense next

4. **Claim the story** you've chosen:
   ```bash
   bd update <bead-id> --status=in_progress
   ```

5. **Read full story details** including acceptance criteria:
   ```bash
   bd show <bead-id>
   ```

6. **Implement that ONE story**

## Verification (ALL must pass before proceeding)

```bash
npm run typecheck
npm test
```

If ANY verification fails → fix it before marking done.

## After Verification Passes

7. **Commit** with detailed message:
   ```
   feat: [bead-id] - [Title]

   - What was added/changed
   - Key implementation details
   - Any notable decisions made
   ```

8. **Close the story**:
   ```bash
   bd close <bead-id>
   ```

9. **Append to progress file**:
   ```
   ## [Date] - [bead-id]
   - What was implemented
   - Files changed
   - Learnings/gotchas discovered
   ---
   ```

   Add new patterns to **Codebase Patterns** section at top of progress file.

## Stop Condition

Check if any work remains:
```bash
bd ready --tag=loop/${SESSION_NAME}
```

If no stories returned (empty output), all work is complete:
```
<promise>COMPLETE</promise>
```

Otherwise, end normally after completing ONE story.
