# Watch Iterations Workflow

Real-time monitoring of iteration outputs as they complete.

<required_reading>
- SKILL.md for file locations and health checks
</required_reading>

<process>
## Phase 1: Setup Watch

Get session name and current state:

```bash
session="{session_name}"
state_file=".claude/pipeline-runs/$session/state.json"

echo "=== Watch Setup: $session ==="

# Get current iteration count
if [ -f "$state_file" ]; then
  current=$(jq -r '.iteration_completed // 0' "$state_file")
  max=$(jq -r '.iteration // 0' "$state_file")
  run_status=$(jq -r '.status' "$state_file")
  echo "Current iteration: $current"
  echo "Status: $run_status"
else
  echo "WARNING: No state file found"
  current=0
fi
```

Verify session is running:

```bash
session="{session_name}"

if tmux has-session -t "pipeline-$session" 2>/dev/null; then
  echo "Session: RUNNING"
else
  echo "Session: NOT RUNNING"
  echo "Cannot watch a non-running session"
  # Offer to start one instead
fi
```

## Phase 2: Establish Baseline

Record what iterations already exist:

```bash
session="{session_name}"

echo "=== Existing Iterations ==="
existing=$(ls -d .claude/pipeline-runs/$session/stage-*/iterations/*/ 2>/dev/null | wc -l | tr -d ' ')
echo "Existing iteration directories: $existing"

# Get the latest one
latest_dir=$(ls -d .claude/pipeline-runs/$session/stage-*/iterations/*/ 2>/dev/null | tail -1)
if [ -n "$latest_dir" ]; then
  latest_num=$(basename "$latest_dir")
  echo "Latest iteration: $latest_num"
fi
```

## Phase 3: Poll for New Iterations

Set up polling loop to detect new iterations:

```bash
session="{session_name}"
state_file=".claude/pipeline-runs/$session/state.json"
last_seen=0

# Get current completed count
if [ -f "$state_file" ]; then
  last_seen=$(jq -r '.iteration_completed // 0' "$state_file")
fi

echo "Starting watch from iteration $((last_seen + 1))..."
echo "Polling every 10 seconds..."
echo ""

# Poll loop (run for up to 30 minutes)
for poll in $(seq 1 180); do
  sleep 10

  if [ -f "$state_file" ]; then
    current=$(jq -r '.iteration_completed // 0' "$state_file")
    run_status=$(jq -r '.status' "$state_file")

    if [ "$current" -gt "$last_seen" ]; then
      # New iteration completed!
      for iter in $(seq $((last_seen + 1)) $current); do
        echo "========================================"
        echo "NEW ITERATION COMPLETED: $iter"
        echo "========================================"

        # Find the iteration directory
        iter_padded=$(printf "%03d" $iter)
        iter_dir=$(ls -d .claude/pipeline-runs/$session/stage-*/iterations/$iter_padded/ 2>/dev/null | head -1)

        if [ -n "$iter_dir" ]; then
          # Read status
          if [ -f "$iter_dir/status.json" ]; then
            echo ""
            echo "--- Decision ---"
            jq -r '"Decision: \(.decision)\nReason: \(.reason // "none")\nSummary: \(.summary // "none")"' "$iter_dir/status.json"
          fi

          # Read output preview
          if [ -f "$iter_dir/output.md" ]; then
            echo ""
            echo "--- Output Preview (last 30 lines) ---"
            tail -30 "$iter_dir/output.md"
          fi

          # Check for errors
          if [ -f "$iter_dir/status.json" ]; then
            errors=$(jq -r '.errors // [] | length' "$iter_dir/status.json")
            if [ "$errors" -gt 0 ]; then
              echo ""
              echo "--- ERRORS DETECTED ---"
              jq -r '.errors[]' "$iter_dir/status.json"
            fi
          fi
        fi

        last_seen=$iter
      done
    fi

    # Check if session completed
    if [ "$run_status" != "running" ]; then
      echo ""
      echo "========================================"
      echo "SESSION ENDED: $run_status"
      echo "========================================"
      break
    fi
  fi

  # Show heartbeat every minute
  if [ $((poll % 6)) -eq 0 ]; then
    echo "[$(date '+%H:%M:%S')] Watching... (iteration $last_seen, status: ${run_status:-unknown})"
  fi
done
```

## Phase 4: Real-time Output Monitoring

In addition to polling iterations, periodically capture tmux output:

```bash
session="{session_name}"

echo ""
echo "=== Current tmux Activity ==="
tmux capture-pane -t "pipeline-$session" -p 2>/dev/null | tail -30 || echo "Cannot capture"
```

## Phase 5: Interactive Watch Options

Between polls, offer the user options:

```json
{
  "questions": [{
    "question": "What would you like to do while watching?",
    "header": "Watch Options",
    "options": [
      {"label": "Continue watching", "description": "Keep polling for new iterations"},
      {"label": "Read latest output", "description": "See full output of most recent iteration"},
      {"label": "Check health", "description": "Run quick health check"},
      {"label": "Stop watching", "description": "End the watch session"}
    ],
    "multiSelect": false
  }]
}
```

If "Read latest output":
```bash
session="{session_name}"
latest_dir=$(ls -d .claude/pipeline-runs/$session/stage-*/iterations/*/ 2>/dev/null | tail -1)

if [ -n "$latest_dir" ]; then
  echo "=== Full Output: $(basename $latest_dir) ==="
  cat "$latest_dir/output.md"
else
  echo "No iterations found"
fi
```

## Phase 6: Watch Summary

When watch ends (session completes or user stops), provide summary:

```bash
session="{session_name}"
state_file=".claude/pipeline-runs/$session/state.json"

echo ""
echo "=== Watch Summary ==="

if [ -f "$state_file" ]; then
  echo "Final status: $(jq -r '.status' "$state_file")"
  echo "Total iterations: $(jq -r '.iteration_completed // 0' "$state_file")"

  # Decision breakdown
  echo ""
  echo "Decision breakdown:"
  jq -r '.history | group_by(.decision) | .[] | "  \(.[0].decision): \(length)"' "$state_file"

  # Any errors?
  errors=$(jq '[.history[] | select(.decision == "error")] | length' "$state_file")
  if [ "$errors" -gt 0 ]; then
    echo ""
    echo "WARNING: $errors error iterations occurred"
  fi
fi
```
</process>

<success_criteria>
- [ ] Session verified as running before watching
- [ ] Baseline iteration count established
- [ ] New iterations detected and output read
- [ ] Errors surfaced when they occur
- [ ] Session completion detected
- [ ] Watch summary provided
</success_criteria>
