#!/bin/bash
# Completion strategy: plateau (intelligent)
# Agent decides when work has plateaued, not the engine

check_completion() {
  local session=$1
  local state_file=$2
  local output=$3

  # Parse agent's plateau decision from output
  local plateau=$(echo "$output" | grep -i "^PLATEAU:" | head -1 | cut -d: -f2 | tr -d ' ' | tr '[:upper:]' '[:lower:]')
  local reasoning=$(echo "$output" | grep -i "^REASONING:" | head -1 | cut -d: -f2-)

  if [ "$plateau" = "true" ] || [ "$plateau" = "yes" ]; then
    echo "Agent determined plateau: $reasoning"
    return 0
  fi

  # Fallback: check iteration count against min_iterations
  local iteration=$(get_state "$state_file" "iteration")
  local min=${MIN_ITERATIONS:-3}

  if [ "$iteration" -lt "$min" ]; then
    # Haven't hit minimum yet, keep going regardless
    return 1
  fi

  return 1
}
