# Workflow: Check Session Status

Get detailed status of a specific session.

<required_reading>
**Read these reference files NOW:**
1. references/commands.md
</required_reading>

<process>
## Step 1: Get Session Name

If session name not provided, list available and ask:

```bash
# Get all known sessions
sessions=$(ls .claude/pipeline-runs/ 2>/dev/null | head -10)

if [ -z "$sessions" ]; then
    echo "No session data found."
    exit 0
fi
```

## Step 2: Use Built-in Status Command

```bash
./scripts/run.sh status ${session}
```

This returns one of:
- `running` - Session is actively executing
- `crashed` - Stale lock detected (PID dead)
- `complete` - Session finished successfully
- `failed` - Session ended with error
- `not_found` - No session data exists

## Step 3: Gather Detailed Information

```bash
# Check all three resources
has_tmux=$(tmux has-session -t "pipeline-${session}" 2>/dev/null && echo "yes" || echo "no")
has_lock=$(test -f ".claude/locks/${session}.lock" && echo "yes" || echo "no")
has_state=$(test -f ".claude/pipeline-runs/${session}/state.json" && echo "yes" || echo "no")

# Get state details
if [ "$has_state" = "yes" ]; then
    state=$(cat ".claude/pipeline-runs/${session}/state.json")
fi

# Get lock details
if [ "$has_lock" = "yes" ]; then
    lock=$(cat ".claude/locks/${session}.lock")
    pid=$(echo "$lock" | jq -r .pid)
    pid_alive=$(kill -0 "$pid" 2>/dev/null && echo "yes" || echo "no")
fi
```

## Step 4: Display Comprehensive Status

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
SESSION STATUS: ${session}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Overview:
  Status:     RUNNING
  Type:       work
  Started:    2025-01-10 10:00:00 (2h 15m ago)

Progress:
  Iteration:  5/25
  Completed:  4
  In progress: 5

Resources:
  tmux:       ✓ loop-auth (running)
  Lock:       ✓ PID 12345 (alive)
  State:      ✓ .claude/pipeline-runs/auth/state.json

Files:
  Progress:   .claude/pipeline-runs/auth/progress-auth.md
  State:      .claude/pipeline-runs/auth/state.json
  Iterations: .claude/pipeline-runs/auth/iterations/

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### For Work Sessions - Show Beads Status

```bash
if [ "$loop_type" = "work" ]; then
    remaining=$(bd ready --label="pipeline/${session}" 2>/dev/null | wc -l)
    in_progress=$(bd list --label="pipeline/${session}" --status=in_progress 2>/dev/null | wc -l)
    completed=$(bd list --label="pipeline/${session}" --status=closed 2>/dev/null | wc -l)

    echo "Beads:"
    echo "  Completed:   ${completed}"
    echo "  In Progress: ${in_progress}"
    echo "  Remaining:   ${remaining}"
fi
```

### Show History (Last Few Iterations)

```bash
if [ -d ".claude/pipeline-runs/${session}/iterations" ]; then
    echo ""
    echo "Recent iterations:"
    ls -t ".claude/pipeline-runs/${session}/iterations/" | head -5 | while read dir; do
        if [ -f ".claude/pipeline-runs/${session}/iterations/${dir}/status.json" ]; then
            summary=$(jq -r '.summary // "No summary"' ".claude/pipeline-runs/${session}/iterations/${dir}/status.json" | head -1)
            echo "  ${dir}: ${summary:0:60}..."
        fi
    done
fi
```

## Step 5: Status-Specific Guidance

### If Running
```
Actions:
  • Monitor: tmux capture-pane -t pipeline-${session} -p | tail -50
  • Attach:  tmux attach -t pipeline-${session}
  • Kill:    tmux kill-session -t pipeline-${session}
```

### If Crashed
```
⚠️  Session crashed (process died unexpectedly)

Last successful iteration: 4
Can resume from iteration: 5

Actions:
  • Resume: ./scripts/run.sh ralph ${session} 25 --resume
  • Cleanup: /agent-pipelines:sessions cleanup
  • View progress: cat .claude/pipeline-runs/${session}/progress-${session}.md
```

### If Complete
```
✓ Session completed successfully

Final iteration: 25/25
Runtime: 3h 45m

Results:
  • Progress file: .claude/pipeline-runs/${session}/progress-${session}.md
  • Beads completed: 15

Actions:
  • View results: cat .claude/pipeline-runs/${session}/progress-${session}.md
  • Start new: /agent-pipelines:sessions start
```

### If Failed
```
✗ Session failed

Failed at iteration: 12/25
Last successful: 11
Error: (check state.json for details)

Actions:
  • Resume: ./scripts/run.sh ralph ${session} 25 --resume
  • Force restart: ./scripts/run.sh ralph ${session} 25 --force
  • View state: cat .claude/pipeline-runs/${session}/state.json
```
</process>

<success_criteria>
Check status workflow is complete when:
- [ ] Session name obtained
- [ ] Built-in status command run
- [ ] All resources checked (tmux, lock, state)
- [ ] Comprehensive status displayed
- [ ] Beads status shown (for work sessions)
- [ ] Recent iteration history shown
- [ ] Status-appropriate guidance provided
</success_criteria>
