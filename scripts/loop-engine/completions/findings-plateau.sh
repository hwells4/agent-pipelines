#!/bin/bash
# Completion strategy: findings-plateau (intelligent, confirmed)
# For review loops - requires confirmation before stopping early
# Always completes all items unless two agents agree to stop

check_completion() {
  local session=$1
  local state_file=$2
  local output=$3

  local iteration=$(get_state "$state_file" "iteration")

  # First, check if we've completed all items (always stop here)
  if [ -n "$ITEMS" ]; then
    local item_count=$(echo "$ITEMS" | wc -w | tr -d ' ')
    if [ "$iteration" -ge "$item_count" ]; then
      echo "All $item_count reviewers complete"
      return 0
    fi
  fi

  # Check if agent suggests stopping early
  local plateau=$(echo "$output" | grep -i "^PLATEAU:" | head -1 | cut -d: -f2 | tr -d ' ' | tr '[:upper:]' '[:lower:]')
  local reasoning=$(echo "$output" | grep -i "^REASONING:" | head -1 | cut -d: -f2-)

  if [ "$plateau" = "true" ] || [ "$plateau" = "yes" ]; then
    # Get previous iteration's plateau decision
    local history=$(get_history "$state_file")
    local prev_plateau=""

    if command -v jq &> /dev/null && [ -n "$history" ] && [ "$history" != "[]" ]; then
      prev_plateau=$(echo "$history" | jq -r '.[-1].plateau // "false"' | tr '[:upper:]' '[:lower:]')
    fi

    if [ "$prev_plateau" = "true" ] || [ "$prev_plateau" = "yes" ]; then
      echo "Early stop CONFIRMED: Two consecutive reviewers agree findings sufficient"
      echo "  Current: $reasoning"
      return 0
    else
      echo "Early stop SUGGESTED but not confirmed"
      echo "  Current reviewer says: $reasoning"
      echo "  Continuing for independent confirmation..."
      return 1
    fi
  fi

  return 1
}

# Get current item from list
get_current_item() {
  local iteration=$1
  echo "$ITEMS" | cut -d' ' -f$((iteration + 1))
}
