#!/bin/bash
# Completion strategy: fixed-n (v3)
# Complete after exactly N iterations
#
# v3: Accepts status file parameter for consistency (not used)

check_completion() {
  local session=$1
  local state_file=$2
  local status_file=$3  # v3: Accepted for API consistency, not used

  local iteration=$(get_state "$state_file" "iteration")
  local target=${FIXED_ITERATIONS:-$MAX_ITERATIONS}

  if [ "$iteration" -ge "$target" ]; then
    echo "Completed $iteration iterations"
    return 0
  fi

  return 1
}
