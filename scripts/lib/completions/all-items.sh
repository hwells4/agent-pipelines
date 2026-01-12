#!/bin/bash
# Completion strategy: all-items (v3)
# Complete when all items in a list have been processed
#
# v3: Accepts status file parameter for consistency (not used)

check_completion() {
  local session=$1
  local state_file=$2
  local status_file=$3  # v3: Accepted for API consistency, not used

  local iteration=$(get_state "$state_file" "iteration")
  local item_count=$(echo "$ITEMS" | wc -w | tr -d ' ')

  if [ "$iteration" -ge "$item_count" ]; then
    echo "All $item_count items complete"
    return 0
  fi

  return 1
}

# Get current item from list
get_current_item() {
  local iteration=$1
  echo "$ITEMS" | cut -d' ' -f$((iteration + 1))
}
