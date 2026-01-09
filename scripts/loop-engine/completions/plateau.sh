#!/bin/bash
# Completion strategy: plateau (intelligent, confirmed)
# Requires TWO consecutive agents to agree on plateau
# No single agent can unilaterally stop the loop

check_completion() {
  local session=$1
  local state_file=$2
  local output=$3

  # Parse current agent's plateau decision
  local plateau=$(echo "$output" | grep -i "^PLATEAU:" | head -1 | cut -d: -f2 | tr -d ' ' | tr '[:upper:]' '[:lower:]')
  local reasoning=$(echo "$output" | grep -i "^REASONING:" | head -1 | cut -d: -f2-)

  # Get current iteration
  local iteration=$(get_state "$state_file" "iteration")
  local min=${MIN_ITERATIONS:-2}

  # Must hit minimum iterations first
  if [ "$iteration" -lt "$min" ]; then
    return 1
  fi

  # If current agent says plateau, check if previous agent agreed
  if [ "$plateau" = "true" ] || [ "$plateau" = "yes" ]; then
    # Get previous iteration's plateau decision from history
    local history=$(get_history "$state_file")
    local prev_plateau=""

    if command -v jq &> /dev/null && [ -n "$history" ] && [ "$history" != "[]" ]; then
      prev_plateau=$(echo "$history" | jq -r '.[-1].plateau // "false"' | tr '[:upper:]' '[:lower:]')
    fi

    if [ "$prev_plateau" = "true" ] || [ "$prev_plateau" = "yes" ]; then
      echo "Plateau CONFIRMED: Two consecutive agents agree"
      echo "  Previous: plateau=true"
      echo "  Current:  plateau=true - $reasoning"
      return 0
    else
      echo "Plateau SUGGESTED but not confirmed"
      echo "  Current agent says: $reasoning"
      echo "  Continuing for independent confirmation..."
      return 1
    fi
  fi

  # Agent says not plateau, reset any pending confirmation
  return 1
}
