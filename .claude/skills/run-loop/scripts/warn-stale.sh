#!/bin/bash
# Warn about stale sessions (running > 2 hours)

STALE_THRESHOLD=7200  # 2 hours in seconds
NOW=$(date +%s)
FOUND_STALE=0

SESSIONS=$(tmux list-sessions -F "#{session_name} #{session_created}" 2>/dev/null | grep "^loop-")

if [ -z "$SESSIONS" ]; then
  exit 0
fi

echo "$SESSIONS" | while read -r LINE; do
  SESSION=$(echo "$LINE" | awk '{print $1}')
  CREATED=$(echo "$LINE" | awk '{print $2}')

  if [ -n "$CREATED" ]; then
    AGE=$((NOW - CREATED))
    AGE_HOURS=$((AGE / 3600))

    if [ "$AGE" -gt "$STALE_THRESHOLD" ]; then
      FOUND_STALE=1
      echo "⚠️  STALE SESSION: $SESSION has been running for ${AGE_HOURS}+ hours"
      echo "   Check: tmux capture-pane -t $SESSION -p | tail -20"
      echo "   Kill:  tmux kill-session -t $SESSION"
      echo ""
    fi
  fi
done

if [ "$FOUND_STALE" -eq 0 ]; then
  # Silent if no stale sessions
  exit 0
fi
