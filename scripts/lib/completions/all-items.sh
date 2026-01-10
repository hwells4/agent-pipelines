#!/bin/bash
# Completion strategy: all-items
# Complete when all items in a list have been processed

check_completion() {
  local session=$1
  local state_file=$2
  local output=$3

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
