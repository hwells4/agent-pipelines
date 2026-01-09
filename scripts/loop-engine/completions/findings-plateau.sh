#!/bin/bash
# Completion strategy: findings-plateau (intelligent)
# For review loops - agent decides when findings are sufficient
# Iterates through items but can stop early if agent says so

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

  # Check if agent says to stop early
  local plateau=$(echo "$output" | grep -i "^PLATEAU:" | head -1 | cut -d: -f2 | tr -d ' ' | tr '[:upper:]' '[:lower:]')
  local reasoning=$(echo "$output" | grep -i "^REASONING:" | head -1 | cut -d: -f2-)

  if [ "$plateau" = "true" ] || [ "$plateau" = "yes" ]; then
    echo "Agent determined review sufficient: $reasoning"
    return 0
  fi

  return 1
}

# Get current item from list
get_current_item() {
  local iteration=$1
  echo "$ITEMS" | cut -d' ' -f$((iteration + 1))
}
