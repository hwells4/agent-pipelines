# Workflow: Monitor a Session

Safely peek at output from a running session without attaching.

## Step 1: List Running Sessions

```bash
# Get all loop and pipeline sessions
tmux list-sessions 2>/dev/null | grep -E "^(loop-|pipeline-)" || echo "No sessions running"
```

If no sessions running, tell the user and stop.

## Step 2: Select Session

If multiple sessions are running, use AskUserQuestion:

```json
{
  "questions": [{
    "question": "Which session do you want to monitor?",
    "header": "Session",
    "options": [
      {"label": "loop-auth", "description": "Started 30 mins ago"},
      {"label": "pipeline-refine", "description": "Started 1 hour ago"}
    ],
    "multiSelect": false
  }]
}
```

Build options from the list output. If only one session, use it directly.

## Step 3: Capture Recent Output

```bash
# Capture the visible pane content (what you'd see if attached)
tmux capture-pane -t {session-name} -p | tail -100
```

This shows the last 100 lines of output without attaching.

## Step 4: Check Session State

All sessions use the unified pipeline-runs directory:

```bash
# Extract session tag from name (e.g., "auth" from "loop-auth")
if [[ "$SESSION_NAME" == loop-* ]]; then
  SESSION_TAG="${SESSION_NAME#loop-}"
elif [[ "$SESSION_NAME" == pipeline-* ]]; then
  SESSION_TAG="${SESSION_NAME#pipeline-}"
else
  SESSION_TAG="$SESSION_NAME"
fi

# Check session state file (unified location)
if [ -f ".claude/pipeline-runs/$SESSION_TAG/state.json" ]; then
  echo "Session State:"
  cat ".claude/pipeline-runs/$SESSION_TAG/state.json" | jq '{
    status: .status,
    iteration: .iteration,
    iteration_completed: .iteration_completed,
    current_stage: .current_stage,
    completed_at: .completed_at,
    completion_reason: .completion_reason
  }'
fi
```

## Step 5: Show Session Age

```bash
# Get from our state file
if [ -f .claude/loop-sessions.json ]; then
  STARTED=$(cat .claude/loop-sessions.json | jq -r ".sessions[\"$SESSION_NAME\"].started_at // empty")
  if [ -n "$STARTED" ]; then
    # Calculate age
    START_EPOCH=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$STARTED" "+%s" 2>/dev/null || date -d "$STARTED" "+%s")
    NOW_EPOCH=$(date "+%s")
    AGE_MINS=$(( (NOW_EPOCH - START_EPOCH) / 60 ))
    echo "Session age: $AGE_MINS minutes"

    if [ $AGE_MINS -gt 120 ]; then
      echo "WARNING: Session has been running for over 2 hours"
    fi
  fi
fi
```

## Step 6: Check for Beads Progress (Loops Only)

For work loops, show bead status:

```bash
if [[ "$SESSION_NAME" == loop-* ]]; then
  SESSION_TAG="${SESSION_NAME#loop-}"
  echo ""
  echo "Beads Status:"
  bd list --label="loop/$SESSION_TAG" --format=short 2>/dev/null || echo "No beads found for this session"

  echo ""
  echo "Ready to work:"
  bd ready --label="loop/$SESSION_TAG" 2>/dev/null || echo "None ready"
fi
```

## Step 7: Show Summary

Present a clean summary:

```
Session: {session-name}
Type: {loop|pipeline}
Status: {running|complete|failed}
Age: {X} minutes

Recent Output:
---
{last 20 lines of captured output}
---

{For loops: "Beads remaining: X"}
{For pipelines: "Current stage: X of Y"}

Commands:
  Refresh:  tmux capture-pane -t {session-name} -p | tail -50
  Attach:   tmux attach -t {session-name}
  Kill:     tmux kill-session -t {session-name}
```

## Step 8: Offer Next Actions

```json
{
  "questions": [{
    "question": "What would you like to do next?",
    "header": "Next",
    "options": [
      {"label": "Refresh", "description": "See latest output again"},
      {"label": "Attach", "description": "Connect to watch live"},
      {"label": "Kill", "description": "Terminate this session"},
      {"label": "Done", "description": "I'm finished monitoring"}
    ],
    "multiSelect": false
  }]
}
```

Handle accordingly:
- Refresh: Loop back to Step 3
- Attach: Follow `workflows/attach.md`
- Kill: Follow `workflows/kill.md`
- Done: End workflow

## Success Criteria

- [ ] Session identified and validated
- [ ] Recent output captured and displayed
- [ ] State information shown (iteration, stage, etc.)
- [ ] Session age displayed with stale warning if needed
- [ ] User given clear next action options
