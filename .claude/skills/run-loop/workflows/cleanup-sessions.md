# Workflow: Cleanup Stale Sessions

<process>

## Step 1: Find Stale Sessions

Run the stale check script:
```bash
bash .claude/skills/run-loop/scripts/warn-stale.sh
```

Or manually check sessions running > 2 hours:
```bash
# List all loop sessions with creation time
tmux list-sessions -F "#{session_name} #{session_created}" 2>/dev/null | grep "^loop-"
```

## Step 2: Investigate Each Stale Session

For each stale session:
```bash
# Check last output
tmux capture-pane -t SESSION_NAME -p | tail -20

# Check for completion
tmux capture-pane -t SESSION_NAME -p | grep -q "COMPLETE"

# Check for errors
tmux capture-pane -t SESSION_NAME -p | grep -i "error\|stuck\|timeout"
```

## Step 3: Categorize Sessions

- **Complete but not cleaned up:** Safe to kill
- **Stuck/erroring:** Kill and check progress.txt
- **Still working:** Leave running, note the unusual duration

## Step 4: Clean Up

For each session to remove:
```bash
# Kill session
tmux kill-session -t SESSION_NAME

# Update state file
# Remove from .claude/loop-sessions.json
```

## Step 5: Clean State File

Remove entries for sessions that no longer exist:
```bash
# Check each session in state file
# If tmux has-session fails, remove from state
```

## Step 6: Report

```
Cleanup complete:
- Killed: loop-old-feature (was stuck)
- Killed: loop-docs (was complete)
- Left running: loop-api (still making progress)
- Removed orphaned state entries: 2
```

</process>

<stale_thresholds>
| Duration | Status | Action |
|----------|--------|--------|
| < 2 hours | Normal | No action |
| 2-4 hours | Stale | Warn, investigate |
| > 4 hours | Very stale | Strongly suggest kill |
| > 8 hours | Likely stuck | Kill unless user confirms |
</stale_thresholds>

<success_criteria>
- [ ] All sessions checked
- [ ] Stale sessions investigated
- [ ] Dead sessions killed
- [ ] State file cleaned
- [ ] Report provided
</success_criteria>
