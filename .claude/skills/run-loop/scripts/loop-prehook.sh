#!/bin/bash
# Pre-hook for /loop command: check deps and show active sessions

# Check dependencies
MISSING=""
command -v tmux >/dev/null 2>&1 || MISSING="$MISSING tmux"
command -v bd >/dev/null 2>&1 || MISSING="$MISSING beads(bd)"

if [ -n "$MISSING" ]; then
  echo "⚠️  Missing dependencies:$MISSING"
  echo ""
  echo "Install with:"
  [ "$MISSING" = *"tmux"* ] && echo "  brew install tmux"
  [ "$MISSING" = *"beads"* ] && echo "  brew tap steveyegge/beads && brew install bd"
  exit 1
fi

# Check for active sessions
SESSIONS=$(tmux list-sessions -F "#{session_name}" 2>/dev/null | grep "^loop-" || true)

if [ -n "$SESSIONS" ]; then
  echo "📋 Active loop sessions:"
  NOW=$(date +%s)

  for SESSION in $SESSIONS; do
    CREATED=$(tmux list-sessions -F "#{session_name} #{session_created}" 2>/dev/null | grep "^$SESSION " | awk '{print $2}')

    if [ -n "$CREATED" ]; then
      AGE=$((NOW - CREATED))
      HOURS=$((AGE / 3600))
      MINS=$(((AGE % 3600) / 60))
      TIME="${HOURS}h ${MINS}m"
    else
      TIME="?"
    fi

    # Check status
    if tmux capture-pane -t "$SESSION" -p 2>/dev/null | grep -q "COMPLETE"; then
      STATUS="✅"
    elif [ "$HOURS" -gt 2 ] 2>/dev/null; then
      STATUS="⚠️"
    else
      STATUS="⏳"
    fi

    echo "  $STATUS $SESSION ($TIME)"
  done
  echo ""
fi
