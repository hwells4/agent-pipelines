#!/bin/bash
# Unified State Management
# Handles state for both single-stage loops and multi-stage pipelines

# Initialize state file
# Usage: init_state "$session" "$type" "$run_dir"
init_state() {
  local session=$1
  local type=$2  # "loop" or "pipeline"
  local run_dir=${3:-"$PROJECT_ROOT/.claude"}

  mkdir -p "$run_dir"
  local state_file="$run_dir/state.json"

  if [ ! -f "$state_file" ]; then
    local timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date +%Y-%m-%dT%H:%M:%S)
    jq -n \
      --arg session "$session" \
      --arg type "$type" \
      --arg started "$timestamp" \
      '{
        session: $session,
        type: $type,
        started_at: $started,
        status: "running",
        current_stage: 0,
        iteration: 0,
        iteration_completed: 0,
        iteration_started: null,
        stages: [],
        history: []
      }' > "$state_file"
  fi

  echo "$state_file"
}

# Update iteration in state
# Usage: update_iteration "$state_file" "$iteration" "$output_vars"
update_iteration() {
  local state_file=$1
  local iteration=$2
  local output_vars=${3:-"{}"}  # JSON object

  local timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date +%Y-%m-%dT%H:%M:%S)

  jq --argjson iter "$iteration" \
     --argjson vars "$output_vars" \
     --arg ts "$timestamp" \
     '.iteration = $iter | .history += [{"iteration": $iter, "timestamp": $ts} + $vars]' \
     "$state_file" > "$state_file.tmp" && mv "$state_file.tmp" "$state_file"
}

# Update stage status (for pipelines)
# Usage: update_stage "$state_file" "$stage_idx" "$stage_name" "$status"
update_stage() {
  local state_file=$1
  local stage_idx=$2
  local stage_name=$3
  local status=$4

  local timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date +%Y-%m-%dT%H:%M:%S)

  # Check if stage entry exists
  if jq -e ".stages[$stage_idx]" "$state_file" &>/dev/null; then
    jq --arg status "$status" --arg ts "$timestamp" --argjson idx "$stage_idx" \
      '.stages[$idx].status = $status | .stages[$idx].timestamp = $ts | .current_stage = $idx' \
      "$state_file" > "$state_file.tmp" && mv "$state_file.tmp" "$state_file"
  else
    jq --arg name "$stage_name" --arg status "$status" --arg ts "$timestamp" --argjson idx "$stage_idx" \
      '.stages += [{"index": $idx, "name": $name, "status": $status, "timestamp": $ts}] | .current_stage = $idx' \
      "$state_file" > "$state_file.tmp" && mv "$state_file.tmp" "$state_file"
  fi
}

# Get state value
# Usage: get_state "$state_file" "iteration"
get_state() {
  local state_file=$1
  local key=$2

  jq -r ".$key // empty" "$state_file" 2>/dev/null
}

# Get history array
# Usage: get_history "$state_file"
get_history() {
  local state_file=$1
  jq -c '.history' "$state_file" 2>/dev/null || echo "[]"
}

# Mark iteration started
# Usage: mark_iteration_started "$state_file" "$iteration"
mark_iteration_started() {
  local state_file=$1
  local iteration=$2

  local timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date +%Y-%m-%dT%H:%M:%S)

  jq --argjson iter "$iteration" \
     --arg ts "$timestamp" \
     '.iteration = $iter | .iteration_started = $ts | .status = "running"' \
     "$state_file" > "$state_file.tmp" && mv "$state_file.tmp" "$state_file"
}

# Mark iteration completed
# Usage: mark_iteration_completed "$state_file" "$iteration"
mark_iteration_completed() {
  local state_file=$1
  local iteration=$2

  local timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date +%Y-%m-%dT%H:%M:%S)

  jq --argjson iter "$iteration" \
     --arg ts "$timestamp" \
     '.iteration_completed = $iter | .iteration_started = null' \
     "$state_file" > "$state_file.tmp" && mv "$state_file.tmp" "$state_file"
}

# Mark session as failed with detailed error (v3)
# Usage: mark_failed "$state_file" "$error_message" [error_type]
# Creates structured error object with type, message, timestamp
# Also sets resume_from for crash recovery
mark_failed() {
  local state_file=$1
  local error_message=$2
  local error_type=${3:-"unknown"}

  local timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date +%Y-%m-%dT%H:%M:%S)
  local iteration_completed=$(jq -r '.iteration_completed // 0' "$state_file" 2>/dev/null)
  local resume_from=$((iteration_completed + 1))

  jq --arg error_msg "$error_message" \
     --arg error_type "$error_type" \
     --arg ts "$timestamp" \
     --argjson resume "$resume_from" \
     '.status = "failed" |
      .failed_at = $ts |
      .error = {
        type: $error_type,
        message: $error_msg,
        timestamp: $ts
      } |
      .resume_from = $resume' \
     "$state_file" > "$state_file.tmp" && mv "$state_file.tmp" "$state_file"
}

# Get the iteration to resume from
# Usage: get_resume_iteration "$state_file"
# Returns: iteration number to resume from (last_completed + 1)
get_resume_iteration() {
  local state_file=$1

  if [ ! -f "$state_file" ]; then
    echo "1"
    return 0
  fi

  local completed=$(jq -r '.iteration_completed // 0' "$state_file" 2>/dev/null)
  echo "$((completed + 1))"
}

# Reset state for resume (clears failure status, keeps history, adds resumed_at)
# Usage: reset_for_resume "$state_file"
reset_for_resume() {
  local state_file=$1
  local timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date +%Y-%m-%dT%H:%M:%S)

  jq --arg ts "$timestamp" \
     '.status = "running" | .resumed_at = $ts | del(.failed_at) | del(.error) | .iteration_started = null' \
    "$state_file" > "$state_file.tmp" && mv "$state_file.tmp" "$state_file"
}

# Mark complete
# Usage: mark_complete "$state_file" "$reason"
mark_complete() {
  local state_file=$1
  local reason=$2

  local timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date +%Y-%m-%dT%H:%M:%S)

  jq --arg status "complete" \
     --arg reason "$reason" \
     --arg ts "$timestamp" \
     '.status = $status | .completed_at = $ts | .completion_reason = $reason | .iteration_started = null' \
     "$state_file" > "$state_file.tmp" && mv "$state_file.tmp" "$state_file"
}

#-------------------------------------------------------------------------------
# Session Status (for crash recovery)
#-------------------------------------------------------------------------------

# Global variable for status details
SESSION_STATUS_DETAILS=""

# Get session status
# Usage: get_session_status "$session" "$state_file"
# Returns: "none", "active", "failed", "completed"
# Sets: SESSION_STATUS_DETAILS with human-readable info
get_session_status() {
  local session=$1
  local state_file=$2
  local lock_file="${PROJECT_ROOT:-.}/.claude/locks/${session}.lock"

  SESSION_STATUS_DETAILS=""

  # Check if state file exists
  if [ ! -f "$state_file" ]; then
    SESSION_STATUS_DETAILS="No previous session found"
    echo "none"
    return
  fi

  # Check status in state file
  local state_status=$(jq -r '.status // "unknown"' "$state_file" 2>/dev/null)

  if [ "$state_status" = "completed" ]; then
    local completed_at=$(jq -r '.completed_at // "unknown"' "$state_file" 2>/dev/null)
    local reason=$(jq -r '.completion_reason // "unknown"' "$state_file" 2>/dev/null)
    SESSION_STATUS_DETAILS="Completed at $completed_at (reason: $reason)"
    echo "completed"
    return
  fi

  # Check if lock exists
  if [ -f "$lock_file" ]; then
    local pid=$(jq -r '.pid // empty' "$lock_file" 2>/dev/null)
    local started=$(jq -r '.started_at // "unknown"' "$lock_file" 2>/dev/null)

    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
      SESSION_STATUS_DETAILS="Running since $started (PID $pid)"
      echo "active"
      return
    else
      # Lock exists but PID dead = crashed
      local last_iter=$(jq -r '.iteration // 0' "$state_file" 2>/dev/null)
      SESSION_STATUS_DETAILS="Crashed at iteration $last_iter (PID $pid no longer running)"
      echo "failed"
      return
    fi
  fi

  # No lock but status is "running" = crashed without lock
  if [ "$state_status" = "running" ]; then
    local last_iter=$(jq -r '.iteration // 0' "$state_file" 2>/dev/null)
    SESSION_STATUS_DETAILS="Crashed at iteration $last_iter (no lock file found)"
    echo "failed"
    return
  fi

  SESSION_STATUS_DETAILS="Unknown state"
  echo "none"
}

# Get crash recovery info
# Usage: get_crash_info "$session" "$state_file"
# Sets: CRASH_LAST_ITERATION, CRASH_LAST_COMPLETED
get_crash_info() {
  local session=$1
  local state_file=$2

  CRASH_LAST_ITERATION=$(jq -r '.iteration // 0' "$state_file" 2>/dev/null)
  CRASH_LAST_COMPLETED=$(jq -r '.iteration_completed // 0' "$state_file" 2>/dev/null)
}

# Show crash recovery information
# Usage: show_crash_recovery_info "$session" "$state_file" "$max_iterations"
show_crash_recovery_info() {
  local session=$1
  local state_file=$2
  local max_iterations=$3

  get_crash_info "$session" "$state_file"

  echo ""
  echo "Session '$session' crashed and can be resumed."
  echo ""
  echo "  Last iteration started:   $CRASH_LAST_ITERATION"
  echo "  Last iteration completed: $CRASH_LAST_COMPLETED"
  echo ""
  echo "To resume from iteration $((CRASH_LAST_COMPLETED + 1)):"
  echo "  ./scripts/run.sh loop <type> $session $max_iterations --resume"
  echo ""
}

# Show resume information
# Usage: show_resume_info "$session" "$start_iteration" "$max_iterations"
show_resume_info() {
  local session=$1
  local start_iteration=$2
  local max_iterations=$3

  echo ""
  echo "═══════════════════════════════════════"
  echo "  RESUMING SESSION"
  echo "  Session: $session"
  echo "  Starting from iteration: $start_iteration"
  echo "  Max iterations: $max_iterations"
  echo "═══════════════════════════════════════"
  echo ""
}
