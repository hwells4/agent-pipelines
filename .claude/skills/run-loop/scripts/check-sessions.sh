#!/bin/bash
# Check all loop sessions and report status

echo "Loop Sessions Status"
echo "===================="
echo ""

# Get all loop sessions from tmux
SESSIONS=$(tmux list-sessions -F "#{session_name}" 2>/dev/null | grep "^loop-")

if [ -z "$SESSIONS" ]; then
  echo "No active loop sessions found."
  exit 0
fi

NOW=$(date +%s)

for SESSION in $SESSIONS; do
  # Get session creation time
  CREATED=$(tmux list-sessions -F "#{session_name} #{session_created}" | grep "^$SESSION " | awk '{print $2}')

  if [ -n "$CREATED" ]; then
    AGE_SECONDS=$((NOW - CREATED))
    AGE_HOURS=$((AGE_SECONDS / 3600))
    AGE_MINS=$(((AGE_SECONDS % 3600) / 60))
  else
    AGE_HOURS="?"
    AGE_MINS="?"
  fi

  # Check completion status
  if tmux capture-pane -t "$SESSION" -p 2>/dev/null | grep -q "<promise>COMPLETE</promise>"; then
    STATUS="✅ Complete"
  elif [ "$AGE_HOURS" != "?" ] && [ "$AGE_HOURS" -gt 2 ]; then
    STATUS="⚠️  Stale"
  else
    STATUS="⏳ Running"
  fi

  # Get project path from state file if available
  if [ -f ".claude/loop-sessions.json" ]; then
    PROJECT=$(cat .claude/loop-sessions.json 2>/dev/null | grep -A5 "\"$SESSION\"" | grep "project_path" | cut -d'"' -f4)
  else
    PROJECT="(unknown)"
  fi

  printf "%-20s %s  %2sh %02dm  %s\n" "$SESSION" "$STATUS" "$AGE_HOURS" "$AGE_MINS" "$PROJECT"
done

echo ""
