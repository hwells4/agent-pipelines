#!/bin/bash
# Completion strategy: fixed-n
# Complete after exactly N iterations

check_completion() {
  local session=$1
  local state_file=$2
  local output=$3

  local iteration=$(get_state "$state_file" "iteration")
  local target=${FIXED_ITERATIONS:-$MAX_ITERATIONS}

  if [ "$iteration" -ge "$target" ]; then
    echo "Completed $iteration iterations"
    return 0
  fi

  return 1
}
