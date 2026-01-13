# Validate State Workflow

Comprehensive validation of all state files for a session.

<required_reading>
- SKILL.md for file locations and expected formats
</required_reading>

<process>
## Phase 1: Identify Session

Get session name from argument or list available:

```bash
echo "=== Available Sessions ==="
for dir in .claude/pipeline-runs/*/; do
  if [ -d "$dir" ]; then
    session=$(basename "$dir")
    echo "  $session"
  fi
done
```

## Phase 2: Validate Lock File

```bash
session="{session_name}"
lock_file=".claude/locks/$session.lock"

echo "=== Lock File Validation ==="
echo "Path: $lock_file"

if [ ! -f "$lock_file" ]; then
  echo "Status: NOT PRESENT"
  echo "Note: Lock only exists while session is running"
else
  echo "Status: EXISTS"

  # Validate JSON
  if jq . "$lock_file" >/dev/null 2>&1; then
    echo "JSON: VALID"
  else
    echo "JSON: INVALID"
    echo "Raw content:"
    cat "$lock_file"
  fi

  # Check required fields
  echo ""
  echo "Fields:"
  for field in session pid started_at; do
    value=$(jq -r ".$field // \"MISSING\"" "$lock_file")
    if [ "$value" = "MISSING" ] || [ "$value" = "null" ]; then
      echo "  $field: MISSING (required)"
    else
      echo "  $field: $value"
    fi
  done

  # Verify PID
  pid=$(jq -r '.pid' "$lock_file")
  if [ -n "$pid" ] && [ "$pid" != "null" ]; then
    if kill -0 "$pid" 2>/dev/null; then
      echo "  PID status: ALIVE"
    else
      echo "  PID status: DEAD (stale lock)"
    fi
  fi
fi
```

## Phase 3: Validate State File

```bash
session="{session_name}"
state_file=".claude/pipeline-runs/$session/state.json"

echo ""
echo "=== State File Validation ==="
echo "Path: $state_file"

if [ ! -f "$state_file" ]; then
  echo "Status: NOT PRESENT"
  echo "ERROR: State file required for active/completed sessions"
else
  echo "Status: EXISTS"

  # Validate JSON
  if jq . "$state_file" >/dev/null 2>&1; then
    echo "JSON: VALID"
  else
    echo "JSON: INVALID"
    echo "Raw content (first 500 chars):"
    head -c 500 "$state_file"
    # Cannot continue with invalid JSON
    exit 1
  fi

  # Check required fields
  echo ""
  echo "Required Fields:"
  for field in session status iteration iteration_completed; do
    value=$(jq -r ".$field // \"MISSING\"" "$state_file")
    if [ "$value" = "MISSING" ] || [ "$value" = "null" ]; then
      echo "  $field: MISSING (required)"
    else
      echo "  $field: $value"
    fi
  done

  # Check optional fields
  echo ""
  echo "Optional Fields:"
  for field in type started_at iteration_started; do
    value=$(jq -r ".$field // \"not set\"" "$state_file")
    echo "  $field: $value"
  done

  # Validate status enum
  run_status=$(jq -r '.status' "$state_file")
  case "$run_status" in
    running|complete|failed|killed)
      echo ""
      echo "Status enum: VALID ($run_status)"
      ;;
    *)
      echo ""
      echo "Status enum: INVALID ($run_status)"
      echo "  Expected: running, complete, failed, or killed"
      ;;
  esac

  # Validate history array
  echo ""
  echo "History:"
  history_len=$(jq '.history | length' "$state_file")
  echo "  Entries: $history_len"

  if [ "$history_len" -gt 0 ]; then
    # Check first and last entries
    echo "  First entry:"
    jq '.history[0] | "    decision: \(.decision), reason: \(.reason // "none")[0:50]"' "$state_file"

    if [ "$history_len" -gt 1 ]; then
      echo "  Last entry:"
      jq '.history[-1] | "    decision: \(.decision), reason: \(.reason // "none")[0:50]"' "$state_file"
    fi

    # Count decisions
    echo ""
    echo "  Decision counts:"
    jq -r '.history | group_by(.decision) | .[] | "    \(.[0].decision): \(length)"' "$state_file"
  fi
fi
```

## Phase 4: Validate Progress File

```bash
session="{session_name}"
progress_file=".claude/pipeline-runs/$session/progress-$session.md"

echo ""
echo "=== Progress File Validation ==="
echo "Path: $progress_file"

if [ ! -f "$progress_file" ]; then
  echo "Status: NOT PRESENT"
  echo "Note: Progress file should exist for all sessions"
else
  echo "Status: EXISTS"

  # Basic stats
  lines=$(wc -l < "$progress_file")
  size=$(du -h "$progress_file" | cut -f1)
  echo "Lines: $lines"
  echo "Size: $size"

  # Check for expected sections
  echo ""
  echo "Content Analysis:"
  if grep -q "^# " "$progress_file"; then
    echo "  Has H1 headers: YES"
    grep "^# " "$progress_file" | head -3
  else
    echo "  Has H1 headers: NO"
  fi

  if grep -q "^## " "$progress_file"; then
    echo "  Has H2 headers: YES"
    echo "  Count: $(grep -c "^## " "$progress_file")"
  fi

  # Check for iteration markers
  if grep -qi "iteration" "$progress_file"; then
    echo "  Mentions iterations: YES"
  fi
fi
```

## Phase 5: Validate Iteration Directories

```bash
session="{session_name}"
run_dir=".claude/pipeline-runs/$session"

echo ""
echo "=== Iteration Directory Validation ==="

# Find stage directories
stage_dirs=$(ls -d "$run_dir"/stage-*/ 2>/dev/null)

if [ -z "$stage_dirs" ]; then
  echo "Status: NO STAGE DIRECTORIES"
  echo "Note: Stage directories created on first iteration"
else
  for stage_dir in $stage_dirs; do
    stage_name=$(basename "$stage_dir")
    echo ""
    echo "Stage: $stage_name"

    iter_dir="$stage_dir/iterations"
    if [ ! -d "$iter_dir" ]; then
      echo "  Iterations dir: MISSING"
      continue
    fi

    # List iterations
    iters=$(ls -d "$iter_dir"/*/ 2>/dev/null | wc -l | tr -d ' ')
    echo "  Iteration count: $iters"

    # Validate each iteration
    for iter in $(ls -d "$iter_dir"/*/ 2>/dev/null); do
      iter_num=$(basename "$iter")
      echo ""
      echo "  Iteration $iter_num:"

      # Check context.json
      if [ -f "$iter/context.json" ]; then
        if jq . "$iter/context.json" >/dev/null 2>&1; then
          echo "    context.json: VALID"
        else
          echo "    context.json: INVALID JSON"
        fi
      else
        echo "    context.json: MISSING"
      fi

      # Check output.md
      if [ -f "$iter/output.md" ]; then
        lines=$(wc -l < "$iter/output.md")
        echo "    output.md: EXISTS ($lines lines)"
      else
        echo "    output.md: MISSING"
      fi

      # Check status.json
      if [ -f "$iter/status.json" ]; then
        if jq . "$iter/status.json" >/dev/null 2>&1; then
          decision=$(jq -r '.decision' "$iter/status.json")
          echo "    status.json: VALID (decision: $decision)"

          # Validate decision enum
          case "$decision" in
            continue|stop|error)
              ;;
            *)
              echo "      WARNING: Invalid decision value"
              ;;
          esac
        else
          echo "    status.json: INVALID JSON"
        fi
      else
        echo "    status.json: MISSING (may be in progress)"
      fi
    done
  done
fi
```

## Phase 6: Cross-Validation

```bash
session="{session_name}"
state_file=".claude/pipeline-runs/$session/state.json"

echo ""
echo "=== Cross-Validation ==="

if [ -f "$state_file" ]; then
  # Compare iteration count
  state_completed=$(jq -r '.iteration_completed // 0' "$state_file")
  dir_count=$(ls -d .claude/pipeline-runs/$session/stage-*/iterations/*/ 2>/dev/null | wc -l | tr -d ' ')

  echo "State says completed: $state_completed"
  echo "Directories exist: $dir_count"

  if [ "$state_completed" -eq "$dir_count" ]; then
    echo "Match: YES"
  else
    echo "Match: NO"
    echo "  WARNING: State and directory count mismatch"
  fi

  # Check history count matches
  history_len=$(jq '.history | length' "$state_file")
  echo ""
  echo "History entries: $history_len"

  if [ "$history_len" -eq "$state_completed" ]; then
    echo "History matches completed: YES"
  else
    echo "History matches completed: NO"
    echo "  Note: History may be pruned for long sessions"
  fi
fi
```

## Phase 7: Summary Report

Generate a summary of all findings:
- List all VALID items
- List all INVALID or MISSING items
- List all WARNINGS
- Provide recommendations for fixing any issues

</process>

<success_criteria>
- [ ] Lock file validated (if present)
- [ ] State file JSON valid with required fields
- [ ] Status enum validated
- [ ] Progress file exists and has content
- [ ] All iteration directories validated
- [ ] Cross-validation completed
- [ ] Summary report generated
</success_criteria>
