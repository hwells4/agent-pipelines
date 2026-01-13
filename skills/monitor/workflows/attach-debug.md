# Attach & Debug Workflow

Attach to a running session and perform active debugging.

<required_reading>
- SKILL.md for file locations and health checks
</required_reading>

<process>
## Phase 1: Identify Session

First, list available sessions:

```bash
echo "=== Running Pipeline Sessions ==="
tmux list-sessions 2>/dev/null | grep "^pipeline-" || echo "No running sessions"

echo ""
echo "=== Lock Files ==="
ls -la .claude/locks/*.lock 2>/dev/null || echo "No locks"

echo ""
echo "=== State Files ==="
for state in .claude/pipeline-runs/*/state.json; do
  if [ -f "$state" ]; then
    session=$(dirname "$state" | xargs basename)
    run_status=$(jq -r '.status // "unknown"' "$state")
    iter=$(jq -r '.iteration_completed // 0' "$state")
    echo "$session: $run_status (iteration $iter)"
  fi
done
```

If no session name provided, ask user:
```json
{
  "questions": [{
    "question": "Which session would you like to debug?",
    "header": "Session",
    "options": [
      {"label": "{detected_session_1}", "description": "Status: running, iteration X"},
      {"label": "{detected_session_2}", "description": "Status: running, iteration Y"}
    ],
    "multiSelect": false
  }]
}
```

## Phase 2: Verify Session Health

Run comprehensive health check:

```bash
session="{session_name}"

echo "=== Session Health Check: $session ==="

# 1. Check tmux
echo ""
echo "1. TMUX SESSION:"
if tmux has-session -t "pipeline-$session" 2>/dev/null; then
  echo "   Status: RUNNING"
  tmux list-panes -t "pipeline-$session" -F "   Window: #{window_name}, Pane: #{pane_id}, Size: #{pane_width}x#{pane_height}"
else
  echo "   Status: NOT RUNNING"
fi

# 2. Check lock
echo ""
echo "2. LOCK FILE:"
lock_file=".claude/locks/$session.lock"
if [ -f "$lock_file" ]; then
  echo "   Exists: YES"
  pid=$(jq -r '.pid' "$lock_file")
  started=$(jq -r '.started_at' "$lock_file")
  echo "   PID: $pid"
  echo "   Started: $started"
  if kill -0 "$pid" 2>/dev/null; then
    echo "   Process: ALIVE"
  else
    echo "   Process: DEAD (stale lock!)"
  fi
else
  echo "   Exists: NO"
fi

# 3. Check state
echo ""
echo "3. STATE FILE:"
state_file=".claude/pipeline-runs/$session/state.json"
if [ -f "$state_file" ]; then
  echo "   Exists: YES"
  jq -r '"   Status: \(.status)\n   Type: \(.type)\n   Iteration: \(.iteration // 0)\n   Completed: \(.iteration_completed // 0)"' "$state_file"
else
  echo "   Exists: NO"
fi

# 4. Check progress
echo ""
echo "4. PROGRESS FILE:"
progress_file=".claude/pipeline-runs/$session/progress-$session.md"
if [ -f "$progress_file" ]; then
  lines=$(wc -l < "$progress_file")
  echo "   Exists: YES ($lines lines)"
else
  echo "   Exists: NO"
fi

# 5. Count iterations
echo ""
echo "5. ITERATIONS:"
iter_count=$(ls -d .claude/pipeline-runs/$session/stage-*/iterations/*/ 2>/dev/null | wc -l | tr -d ' ')
echo "   Directories: $iter_count"
```

## Phase 3: Capture Current Output

Get what's happening right now:

```bash
session="{session_name}"

echo "=== Current tmux Output (last 50 lines) ==="
tmux capture-pane -t "pipeline-$session" -p 2>/dev/null | tail -50 || echo "Could not capture"
```

## Phase 4: Review Recent Iterations

Read the most recent iteration outputs:

```bash
session="{session_name}"

echo "=== Last 3 Iterations ==="
for iter_dir in $(ls -d .claude/pipeline-runs/$session/stage-*/iterations/*/ 2>/dev/null | tail -3); do
  iter_num=$(basename "$iter_dir")
  echo ""
  echo "--- Iteration $iter_num ---"

  # Status decision
  if [ -f "$iter_dir/status.json" ]; then
    echo "Decision: $(jq -r '.decision' "$iter_dir/status.json")"
    echo "Reason: $(jq -r '.reason // "none"' "$iter_dir/status.json")"
    echo "Summary: $(jq -r '.summary // "none"' "$iter_dir/status.json" | head -c 200)"
  else
    echo "Status: NO status.json (iteration may be in progress)"
  fi

  # Output preview
  if [ -f "$iter_dir/output.md" ]; then
    echo ""
    echo "Output preview (last 20 lines):"
    tail -20 "$iter_dir/output.md"
  fi
done
```

## Phase 5: Check for Problems

Look for common issues:

```bash
session="{session_name}"
state_file=".claude/pipeline-runs/$session/state.json"

echo "=== Problem Detection ==="

# Check for errors in history
if [ -f "$state_file" ]; then
  errors=$(jq '[.history[]? | select(.decision == "error")] | length' "$state_file")
  if [ "$errors" -gt 0 ]; then
    echo "WARNING: $errors error iterations found"
    jq '.history[] | select(.decision == "error")' "$state_file"
  fi
fi

# Check for stuck iteration (started but not completed)
if [ -f "$state_file" ]; then
  started=$(jq -r '.iteration // 0' "$state_file")
  completed=$(jq -r '.iteration_completed // 0' "$state_file")
  if [ "$started" -gt "$completed" ]; then
    echo "INFO: Iteration $started in progress (last completed: $completed)"
    started_at=$(jq -r '.iteration_started // "unknown"' "$state_file")
    echo "   Started at: $started_at"
  fi
fi

# Check for missing status.json in completed iterations
for iter_dir in $(ls -d .claude/pipeline-runs/$session/stage-*/iterations/*/ 2>/dev/null); do
  iter_num=$(basename "$iter_dir")
  if [ ! -f "$iter_dir/status.json" ]; then
    # Only warn if not the current iteration
    if [ -f "$iter_dir/output.md" ]; then
      echo "WARNING: Iteration $iter_num has output.md but no status.json"
    fi
  fi
done

# Check tmux is responsive
if ! tmux capture-pane -t "pipeline-$session" -p >/dev/null 2>&1; then
  echo "WARNING: Cannot capture tmux pane (session may be hung)"
fi
```

## Phase 6: Live Monitoring Options

Offer next steps based on findings:

If session is healthy:
- "Watch live output" - Attach to tmux interactively
- "Continue monitoring iterations" - Proceed to watch-iterations workflow
- "Validate all state files" - Run full validation

If issues found:
- "Kill and restart" - Kill session, optionally resume
- "Force re-create lock" - Clear stale lock
- "Check logs" - Look for error details

Provide the tmux attach command:
```bash
echo ""
echo "To watch live, run:"
echo "  tmux attach -t pipeline-{session}"
echo ""
echo "Detach with: Ctrl+b then d"
```
</process>

<success_criteria>
- [ ] Session identified and verified
- [ ] All resources checked (tmux, lock, state, progress)
- [ ] Recent iteration outputs reviewed
- [ ] Problems detected and reported
- [ ] Next steps provided to user
</success_criteria>
