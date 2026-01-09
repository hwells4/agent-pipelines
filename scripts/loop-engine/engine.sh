#!/bin/bash
set -e

# Loop Engine - Universal loop runner
# Usage: engine.sh <loop_type> [session_name] [max_iterations]

LOOP_TYPE=${1:?"Usage: engine.sh <loop_type> [session_name] [max_iterations]"}
SESSION_NAME=${2:-"$LOOP_TYPE"}
MAX_ITERATIONS=${3:-25}

# Paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(pwd)"
LOOPS_DIR="$SCRIPT_DIR/../loops"

# Verify environment
if [ ! -d "$LOOPS_DIR" ]; then
  echo "Error: Loops directory not found: $LOOPS_DIR" >&2
  echo "Ensure the loop-agents plugin is installed correctly." >&2
  exit 1
fi

# Check for required dependencies
for cmd in bd jq; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "Error: Missing required command: $cmd" >&2
    case "$cmd" in
      bd) echo "  Install: brew install steveyegge/tap/bd" >&2 ;;
      jq) echo "  Install: brew install jq" >&2 ;;
    esac
    exit 1
  fi
done

# Verify beads is initialized (required for most loops)
if ! bd list --limit 1 &>/dev/null 2>&1; then
  echo "Error: Beads not initialized in this project." >&2
  echo "  Run: bd init" >&2
  exit 1
fi

export PROJECT_ROOT SESSION_NAME MAX_ITERATIONS

# Source libraries
source "$SCRIPT_DIR/lib/state.sh"
source "$SCRIPT_DIR/lib/notify.sh"
source "$SCRIPT_DIR/lib/progress.sh"
source "$SCRIPT_DIR/lib/parse.sh"
source "$SCRIPT_DIR/config.sh"

# Load loop configuration
load_config "$LOOP_TYPE"

# Source completion strategy
COMPLETION_SCRIPT="$SCRIPT_DIR/completions/${COMPLETION:-beads-empty}.sh"
if [ ! -f "$COMPLETION_SCRIPT" ]; then
  echo "Error: Unknown completion strategy: $COMPLETION" >&2
  exit 1
fi
source "$COMPLETION_SCRIPT"

# Export for hooks
export CLAUDE_LOOP_AGENT=1
export CLAUDE_LOOP_SESSION="$SESSION_NAME"
export CLAUDE_LOOP_TYPE="$LOOP_TYPE"

echo "═══════════════════════════════════════"
echo "  Loop Engine: $LOOP_TYPE"
echo "  Session: $SESSION_NAME"
echo "  Max iterations: $MAX_ITERATIONS"
echo "  Completion: ${COMPLETION:-beads-empty}"
echo "═══════════════════════════════════════"
echo ""

# Initialize state and progress
STATE_FILE=$(init_state "$SESSION_NAME" "$LOOP_TYPE")
PROGRESS_FILE=$(init_progress "$SESSION_NAME")

for i in $(seq 1 $MAX_ITERATIONS); do
  echo "═══════════════════════════════════════"
  echo "  Iteration $i of $MAX_ITERATIONS"
  echo "═══════════════════════════════════════"
  echo ""

  # Pre-iteration completion check (for beads-empty, check before starting)
  if [ "${CHECK_BEFORE:-false}" = "true" ]; then
    if check_completion "$SESSION_NAME" "$STATE_FILE" ""; then
      REASON=$(check_completion "$SESSION_NAME" "$STATE_FILE" "" 2>&1)
      echo "$REASON"
      mark_complete "$STATE_FILE" "$REASON"
      record_completion "complete" "$SESSION_NAME" "$LOOP_TYPE"
      exit 0
    fi
  fi

  # Select prompt (for multi-prompt loops like review)
  PROMPT_NAME="${PROMPT:-prompt}"
  if [ -n "$ITEMS" ]; then
    # For all-items completion, get current item as prompt name
    PROMPT_NAME=$(get_current_item "$((i - 1))" 2>/dev/null || echo "$PROMPT_NAME")
  fi

  PROMPT_FILE=$(get_prompt_file "$LOOP_TYPE" "$PROMPT_NAME")

  # Build extra vars for prompt substitution
  EXTRA_VARS="ITERATION=$i"
  [ -n "$ITEMS" ] && EXTRA_VARS="$EXTRA_VARS CURRENT_ITEM=$PROMPT_NAME"

  # Run Claude with substituted prompt
  PROMPT_CONTENT=$(substitute_prompt "$PROMPT_FILE" "$SESSION_NAME" "$PROGRESS_FILE" "$EXTRA_VARS")

  OUTPUT=$(echo "$PROMPT_CONTENT" \
    | claude --model opus --dangerously-skip-permissions 2>&1 \
    | tee /dev/stderr) || true

  # Parse output based on config
  OUTPUT_JSON="{}"
  if [ -n "$OUTPUT_PARSE" ]; then
    # OUTPUT_PARSE format: "changes:CHANGES summary:SUMMARY"
    OUTPUT_JSON=$(parse_outputs_to_json "$OUTPUT" $OUTPUT_PARSE)
  fi

  # Update state
  update_state "$STATE_FILE" "$i" "$OUTPUT_JSON"

  # Post-iteration completion check
  if check_completion "$SESSION_NAME" "$STATE_FILE" "$OUTPUT"; then
    REASON=$(check_completion "$SESSION_NAME" "$STATE_FILE" "$OUTPUT" 2>&1)
    echo ""
    echo "$REASON"
    mark_complete "$STATE_FILE" "$REASON"
    record_completion "complete" "$SESSION_NAME" "$LOOP_TYPE"
    exit 0
  fi

  # Check for explicit completion signal in output
  if type check_output_signal &>/dev/null && check_output_signal "$OUTPUT"; then
    echo ""
    echo "Completion signal received"
    mark_complete "$STATE_FILE" "completion_signal"
    record_completion "complete" "$SESSION_NAME" "$LOOP_TYPE"
    exit 0
  fi

  echo ""
  echo "Waiting ${DELAY:-3} seconds..."
  sleep "${DELAY:-3}"
done

echo ""
echo "Maximum iterations ($MAX_ITERATIONS) reached"
mark_complete "$STATE_FILE" "max_iterations"
record_completion "max_iterations" "$SESSION_NAME" "$LOOP_TYPE"
exit 1
