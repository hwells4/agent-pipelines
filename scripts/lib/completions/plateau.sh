#!/bin/bash
# Completion strategy: plateau (v3)
# Requires N consecutive agents to write decision: stop
# Prevents single-agent blind spots
#
# v3: Reads from status.json instead of parsing output text

check_completion() {
  local session=$1
  local state_file=$2
  local status_file=$3  # v3: Now receives status file path

  # Get configurable consensus count (default 2)
  local consensus_needed=${CONSENSUS:-2}
  local min_iterations=${MIN_ITERATIONS:-2}

  # Read current iteration
  local iteration=$(get_state "$state_file" "iteration")

  # Must hit minimum iterations first
  if [ "$iteration" -lt "$min_iterations" ]; then
    return 1
  fi

  # Read current decision from status.json
  local decision=$(get_status_decision "$status_file")
  local reason=$(get_status_reason "$status_file")

  if [ "$decision" = "stop" ]; then
    # Get current stage name for filtering (multi-stage pipeline support)
    local current_stage_idx=$(jq -r '.current_stage // 0' "$state_file" 2>/dev/null)
    local current_stage_name=$(jq -r ".stages[$current_stage_idx].name // \"\"" "$state_file" 2>/dev/null)

    # Count consecutive "stop" decisions from history (filtered by current stage)
    local history=$(get_history "$state_file")
    local consecutive=1

    # Check previous iterations for consecutive stops (same stage only)
    local history_len=$(echo "$history" | jq 'length')
    for ((i = history_len - 1; i >= 0 && consecutive < consensus_needed; i--)); do
      local entry_stage=$(echo "$history" | jq -r ".[$i].stage // \"\"")

      # Skip entries from different stages (for multi-stage pipelines)
      if [ -n "$current_stage_name" ] && [ -n "$entry_stage" ] && [ "$entry_stage" != "$current_stage_name" ]; then
        continue
      fi

      local prev_decision=$(echo "$history" | jq -r ".[$i].decision // \"continue\"")
      if [ "$prev_decision" = "stop" ]; then
        ((consecutive++))
      else
        break
      fi
    done

    if [ "$consecutive" -ge "$consensus_needed" ]; then
      echo "Consensus reached: $consecutive consecutive agents agree to stop"
      echo "  Reason: $reason"
      return 0
    else
      echo "Stop suggested but not confirmed ($consecutive/$consensus_needed needed)"
      echo "  Current agent says: $reason"
      echo "  Continuing for independent confirmation..."
      return 1
    fi
  fi

  return 1
}
