#!/bin/bash
# Desktop Notifications and Completion Logging

# Send desktop notification
# Usage: notify "$title" "$message"
notify() {
  local title=$1
  local message=$2

  if command -v osascript &>/dev/null; then
    # macOS - escape backslashes and quotes to prevent AppleScript injection
    title="${title//\\/\\\\}"
    title="${title//\"/\\\"}"
    message="${message//\\/\\\\}"
    message="${message//\"/\\\"}"
    osascript -e "display notification \"$message\" with title \"$title\"" 2>/dev/null || true
  elif command -v notify-send &>/dev/null; then
    # Linux
    notify-send "$title" "$message" 2>/dev/null || true
  fi
}

# Record completion to JSON log
# Usage: record_completion "$status" "$session" "$type"
record_completion() {
  local status=$1
  local session=$2
  local type=${3:-"unknown"}
  local file="$PROJECT_ROOT/.claude/loop-completions.json"
  local timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date +%Y-%m-%dT%H:%M:%S)

  mkdir -p "$PROJECT_ROOT/.claude"

  local entry="{\"session\": \"$session\", \"type\": \"$type\", \"status\": \"$status\", \"completed_at\": \"$timestamp\"}"

  if [ -f "$file" ]; then
    jq ". += [$entry]" "$file" > "$file.tmp" && mv "$file.tmp" "$file"
  else
    echo "[$entry]" > "$file"
  fi

  notify "Loop Agent" "$type $session: $status"
}
