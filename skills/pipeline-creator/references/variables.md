# Template Variables Reference

Complete reference for variables available in prompt templates.

## V3 Variables (Preferred)

Use these in all new stage prompts.

| Variable | Type | Description |
|----------|------|-------------|
| `${CTX}` | Path | Path to context.json with full session metadata |
| `${STATUS}` | Path | Path where agent writes status.json |
| `${PROGRESS}` | Path | Path to progress file (accumulated context) |
| `${ITERATION}` | Number | Current iteration (1-based) |
| `${SESSION_NAME}` | String | Session identifier |
| `${CONTEXT}` | Text | Optional stage-specific context (from stage.yaml or pipeline.yaml) |

## Multi-Stage Variables

Available when running as part of a multi-stage pipeline.

| Variable | Type | Description |
|----------|------|-------------|
| `${INPUTS}` | Path | Previous stage's output directory |
| `${INPUTS.stage-name}` | Path | Named stage's output (when multiple inputs) |
| `${OUTPUT}` | Path | Path to write this stage's output |

## Legacy Variables (Deprecated)

Still work for backwards compatibility but prefer V3 variables.

| Legacy | Maps To | Notes |
|--------|---------|-------|
| `${SESSION}` | `${SESSION_NAME}` | Renamed for clarity |
| `${INDEX}` | `${ITERATION} - 1` | 0-based vs 1-based |
| `${PROGRESS_FILE}` | `${PROGRESS}` | Shortened |

## context.json Structure

Available at `${CTX}`:

```json
{
  "session": {
    "name": "auth-refactor",
    "type": "work",
    "started_at": "2026-01-12T10:00:00Z"
  },
  "iteration": {
    "current": 5,
    "max": 25,
    "started_at": "2026-01-12T10:25:00Z"
  },
  "paths": {
    "progress": ".claude/pipeline-runs/auth/progress-auth.md",
    "status": ".claude/pipeline-runs/auth/iterations/005/status.json",
    "output": ".claude/pipeline-runs/auth/iterations/005/output.md"
  },
  "termination": {
    "type": "queue",
    "config": {}
  },
  "history": [
    {"iteration": 1, "decision": "continue"},
    {"iteration": 2, "decision": "continue"}
  ]
}
```

## status.json Format

Agent writes to `${STATUS}`:

```json
{
  "decision": "continue | stop | error",
  "reason": "Why this decision was made",
  "summary": "What happened this iteration",
  "work": {
    "items_completed": ["beads-001"],
    "files_touched": ["src/auth.ts"]
  },
  "errors": []
}
```

## Usage in Prompts

### Reading Context

```markdown
## Context

Read the full context:
```bash
cat ${CTX} | jq
```

Read the progress file:
```bash
cat ${PROGRESS}
```
```

### Writing Status

```markdown
### Write Status

After completing your work, write to `${STATUS}`:

```json
{
  "decision": "continue",
  "reason": "More work remains",
  "summary": "Completed X and Y",
  "work": {
    "items_completed": ["item-1"],
    "files_touched": ["file.ts"]
  },
  "errors": []
}
```
```

### Multi-Stage Input

```markdown
## Previous Stage Output

Read outputs from the previous stage:
```bash
cat ${INPUTS}/summary.md
ls ${INPUTS}/
```
```

## Common Patterns

### Check Iteration Number

```markdown
This is iteration ${ITERATION}.

Read what previous iterations found:
```bash
cat ${PROGRESS}
```
```

### Append to Progress

```markdown
## Output

Append your findings to the progress file:
```bash
echo "## Iteration ${ITERATION}" >> ${PROGRESS}
echo "" >> ${PROGRESS}
echo "Findings here..." >> ${PROGRESS}
```
```

### Error Handling

```markdown
If you encounter an error, write to `${STATUS}`:

```json
{
  "decision": "error",
  "reason": "Description of what went wrong",
  "summary": "Attempted X but failed because Y",
  "work": {
    "items_completed": [],
    "files_touched": []
  },
  "errors": ["Error message here"]
}
```
```

## Environment Variables (Override)

These env vars override stage/pipeline configuration without editing files:

| Variable | Purpose |
|----------|---------|
| `CLAUDE_PIPELINE_PROVIDER` | Override provider (claude, codex) |
| `CLAUDE_PIPELINE_MODEL` | Override model (opus, o3, etc.) |

CLI flags `--provider=X` and `--model=X` take precedence over env vars.

**Precedence:** CLI flags → Env vars → Stage config → Built-in defaults

## Variable Resolution

The engine resolves variables before passing to Claude:

1. `${CTX}` → `.claude/pipeline-runs/session/context.json`
2. `${STATUS}` → `.claude/pipeline-runs/session/iterations/NNN/status.json`
3. `${PROGRESS}` → `.claude/pipeline-runs/session/progress-session.md`
4. `${ITERATION}` → `5` (number)
5. `${SESSION_NAME}` → `session` (string)

Variables are replaced literally in the prompt text.
