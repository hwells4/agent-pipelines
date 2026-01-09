#!/bin/bash
# Completion strategy: findings-plateau
# Stops when new findings plateau (good for review loops)
# Combines all-items iteration with plateau detection on findings

# Config
FINDINGS_PLATEAU_THRESHOLD=${FINDINGS_PLATEAU_THRESHOLD:-2}
MIN_FINDINGS_ITERATIONS=${MIN_FINDINGS_ITERATIONS:-2}

check_completion() {
  local session=$1
  local state_file=$2
  local output=$3

  local iteration=$(get_state "$state_file" "iteration")

  # First, check if we've completed all items
  if [ -n "$ITEMS" ]; then
    local item_count=$(echo "$ITEMS" | wc -w | tr -d ' ')
    if [ "$iteration" -ge "$item_count" ]; then
      echo "All $item_count reviewers complete"
      return 0
    fi
  fi

  # Then check for findings plateau (only after min iterations)
  if [ "$iteration" -ge "$MIN_FINDINGS_ITERATIONS" ]; then
    local history=$(get_history "$state_file")

    if command -v jq &> /dev/null; then
      # Get last N findings counts
      local recent_findings=$(echo "$history" | jq -r "[.[-${FINDINGS_PLATEAU_THRESHOLD}:][].findings // \"0\"] | map(tonumber)")

      # Check if all recent findings are 0 or very low
      local all_low=$(echo "$recent_findings" | jq "all(. <= 1)")

      if [ "$all_low" = "true" ]; then
        echo "Findings plateaued at iteration $iteration - no significant new issues found"
        return 0
      fi
    fi
  fi

  return 1
}

# Get current item from list (same as all-items)
get_current_item() {
  local iteration=$1
  echo "$ITEMS" | cut -d' ' -f$((iteration + 1))
}
