#!/bin/bash
# Completion strategy: beads-empty (v3)
# Complete when no beads remain for this session
#
# v3: Accepts status file, checks for error status

check_completion() {
  local session=$1
  local state_file=$2
  local status_file=$3  # v3: Now receives status file path

  # Check if agent reported error - don't complete on error
  local decision=$(get_status_decision "$status_file" 2>/dev/null)
  if [ "$decision" = "error" ]; then
    echo "Agent reported error - not completing"
    return 1
  fi

  local remaining
  remaining=$(bd ready --label="pipeline/$session" 2>/dev/null | grep -c "^") || remaining=0

  if [ "$remaining" -eq 0 ]; then
    echo "All beads complete"
    return 0
  fi

  return 1
}

# Check for explicit completion signal in output (legacy support)
check_output_signal() {
  local output=$1

  if echo "$output" | grep -q "<promise>COMPLETE</promise>"; then
    return 0
  fi

  return 1
}
