# Health Check Workflow

Quick health check of session resources.

<required_reading>
- SKILL.md for file locations and health checks
</required_reading>

<process>
## Phase 1: Get Session

If no session provided, list and ask:

```bash
echo "=== Available Sessions ==="

# Running sessions
echo "Running:"
tmux list-sessions 2>/dev/null | grep "^pipeline-" | sed 's/pipeline-/  /' || echo "  (none)"

# Sessions with state files
echo ""
echo "With state files:"
for state in .claude/pipeline-runs/*/state.json; do
  if [ -f "$state" ]; then
    session=$(dirname "$state" | xargs basename)
    run_status=$(jq -r '.status // "unknown"' "$state")
    echo "  $session ($run_status)"
  fi
done 2>/dev/null || echo "  (none)"
```

## Phase 2: Quick Health Check

Run rapid checks on all resources:

```bash
session="{session_name}"

echo "=== Health Check: $session ==="
echo ""

# Track issues
issues=0

# 1. tmux
echo -n "tmux session: "
if tmux has-session -t "pipeline-$session" 2>/dev/null; then
  echo "RUNNING"
  tmux_ok=1
else
  echo "NOT RUNNING"
  tmux_ok=0
fi

# 2. Lock file
echo -n "Lock file: "
lock_file=".claude/locks/$session.lock"
if [ -f "$lock_file" ]; then
  pid=$(jq -r '.pid // 0' "$lock_file" 2>/dev/null)
  if [ "$pid" -gt 0 ] && kill -0 "$pid" 2>/dev/null; then
    echo "OK (PID $pid alive)"
    lock_ok=1
  else
    echo "STALE (PID $pid dead)"
    lock_ok=0
    issues=$((issues + 1))
  fi
else
  echo "NOT PRESENT"
  lock_ok=0
fi

# 3. State file
echo -n "State file: "
state_file=".claude/pipeline-runs/$session/state.json"
if [ -f "$state_file" ]; then
  if jq . "$state_file" >/dev/null 2>&1; then
    run_status=$(jq -r '.status' "$state_file")
    iter=$(jq -r '.iteration_completed // 0' "$state_file")
    echo "OK ($run_status, iteration $iter)"
    state_ok=1
  else
    echo "INVALID JSON"
    state_ok=0
    issues=$((issues + 1))
  fi
else
  echo "NOT PRESENT"
  state_ok=0
  issues=$((issues + 1))
fi

# 4. Progress file
echo -n "Progress file: "
progress_file=".claude/pipeline-runs/$session/progress-$session.md"
if [ -f "$progress_file" ]; then
  lines=$(wc -l < "$progress_file")
  echo "OK ($lines lines)"
  progress_ok=1
else
  echo "NOT PRESENT"
  progress_ok=0
  issues=$((issues + 1))
fi

# 5. Iteration directories
echo -n "Iterations: "
iter_count=$(ls -d .claude/pipeline-runs/$session/stage-*/iterations/*/ 2>/dev/null | wc -l | tr -d ' ')
if [ "$iter_count" -gt 0 ]; then
  echo "$iter_count directories"

  # Check latest has status.json
  latest=$(ls -d .claude/pipeline-runs/$session/stage-*/iterations/*/ 2>/dev/null | tail -1)
  if [ -n "$latest" ] && [ -f "$latest/status.json" ]; then
    latest_decision=$(jq -r '.decision' "$latest/status.json")
    echo "  Latest decision: $latest_decision"
  fi
else
  echo "NONE"
fi
```

## Phase 3: Consistency Check

Verify resources are consistent with each other:

```bash
session="{session_name}"

echo ""
echo "=== Consistency ==="

# tmux running should have lock
if [ "$tmux_ok" -eq 1 ] && [ "$lock_ok" -eq 0 ]; then
  echo "WARNING: tmux running but no valid lock"
  issues=$((issues + 1))
fi

# Lock without tmux is stale
if [ "$lock_ok" -eq 1 ] && [ "$tmux_ok" -eq 0 ]; then
  echo "WARNING: Lock exists but tmux not running"
  issues=$((issues + 1))
fi

# State iteration should match directory count
if [ "$state_ok" -eq 1 ]; then
  state_completed=$(jq -r '.iteration_completed // 0' "$state_file")
  if [ "$state_completed" -ne "$iter_count" ]; then
    echo "WARNING: State says $state_completed completed, but $iter_count directories exist"
    issues=$((issues + 1))
  else
    echo "Iteration count matches: $iter_count"
  fi
fi
```

## Phase 4: Status Summary

```bash
echo ""
echo "=== Summary ==="

if [ "$issues" -eq 0 ]; then
  echo "Health: GOOD"
  echo "No issues detected"
else
  echo "Health: ISSUES FOUND ($issues)"
fi

# Status interpretation
if [ "$tmux_ok" -eq 1 ]; then
  echo ""
  echo "Status: ACTIVELY RUNNING"
  echo "  Session is executing iterations"
elif [ "$state_ok" -eq 1 ]; then
  run_status=$(jq -r '.status' "$state_file")
  case "$run_status" in
    complete)
      echo ""
      echo "Status: COMPLETED"
      echo "  Session finished successfully"
      ;;
    failed)
      echo ""
      echo "Status: FAILED"
      echo "  Session encountered an error"
      # Show last error
      jq -r '.history | map(select(.decision == "error")) | last | "  Last error: \(.reason // "unknown")"' "$state_file" 2>/dev/null
      ;;
    killed)
      echo ""
      echo "Status: KILLED"
      echo "  Session was manually terminated"
      ;;
    running)
      echo ""
      echo "Status: CRASHED"
      echo "  State says running but tmux is gone"
      echo "  Use --resume to continue"
      ;;
  esac
else
  echo ""
  echo "Status: UNKNOWN"
  echo "  No state file found"
fi
```

## Phase 5: Recommended Actions

Based on health status, provide recommendations:

```bash
echo ""
echo "=== Recommended Actions ==="

if [ "$tmux_ok" -eq 1 ]; then
  echo "- Watch progress: /monitor watch $session"
  echo "- Attach to tmux: tmux attach -t pipeline-$session"
elif [ "$state_ok" -eq 1 ]; then
  run_status=$(jq -r '.status' "$state_file")
  case "$run_status" in
    complete)
      echo "- Review results: cat $progress_file"
      echo "- Validate state: /monitor validate $session"
      ;;
    failed|killed)
      echo "- Resume session: ./scripts/run.sh ralph $session N --resume"
      echo "- Check errors: /monitor validate $session"
      ;;
    running)
      echo "- Resume crashed session: ./scripts/run.sh ralph $session N --resume"
      echo "- Or force restart: ./scripts/run.sh ralph $session N --force"
      ;;
  esac
fi

if [ "$lock_ok" -eq 0 ] && [ -f "$lock_file" ]; then
  echo "- Clear stale lock: rm $lock_file"
fi
```
</process>

<success_criteria>
- [ ] Session identified
- [ ] All resources checked (tmux, lock, state, progress, iterations)
- [ ] Consistency verified
- [ ] Issues counted and reported
- [ ] Status interpretation provided
- [ ] Recommended actions given
</success_criteria>
