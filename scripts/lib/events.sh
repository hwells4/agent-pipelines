#!/bin/bash
# Event Spine Helpers
# Append-only event log utilities for events.jsonl

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  set -euo pipefail
fi

# Build events.jsonl path for a session.
# Usage: events_file_path "$session" ["$run_root"]
events_file_path() {
  local session=$1
  local run_root=${2:-"${PROJECT_ROOT:-$(pwd)}/.claude/pipeline-runs"}

  echo "$run_root/$session/events.jsonl"
}

_ensure_events_dir() {
  local events_file=$1
  local events_dir
  events_dir=$(dirname "$events_file")
  mkdir -p "$events_dir"
}

_warn_invalid_event_line() {
  local events_file=$1
  local invalid_idx=$2
  local total_lines=$3

  if [ "$invalid_idx" -eq "$total_lines" ]; then
    echo "Warning: Skipping truncated final event line in $events_file" >&2
  else
    echo "Warning: Skipping invalid event line in $events_file" >&2
  fi
}

# Append event to events.jsonl using atomic temp file + mv.
# Usage: append_event "$type" "$session" "$cursor_json" "$data_json"
append_event() {
  local type=$1
  local session=$2
  local cursor_json=$3
  local data_json=${4:-"{}"}

  local events_file
  events_file=$(events_file_path "$session")
  _ensure_events_dir "$events_file"

  local timestamp
  timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date +%Y-%m-%dT%H:%M:%S)

  if [ -z "$cursor_json" ] || [ "$cursor_json" = "null" ]; then
    cursor_json="null"
  fi
  if [ -z "$data_json" ] || [ "$data_json" = "null" ]; then
    data_json="{}"
  fi

  local event_json
  if ! event_json=$(jq -c -n \
    --arg ts "$timestamp" \
    --arg type "$type" \
    --arg session "$session" \
    --argjson cursor "$cursor_json" \
    --argjson data "$data_json" \
    '{ts: $ts, type: $type, session: $session, cursor: $cursor, data: $data}'); then
    echo "Error: Failed to build event JSON" >&2
    return 1
  fi

  local tmp_event
  tmp_event=$(mktemp)
  printf '%s\n' "$event_json" > "$tmp_event"

  if [ -f "$events_file" ]; then
    local tmp_combined
    tmp_combined=$(mktemp)
    if ! cat "$events_file" "$tmp_event" > "$tmp_combined"; then
      echo "Error: Failed to append event to $events_file" >&2
      rm -f "$tmp_event" "$tmp_combined"
      return 1
    fi
    if ! mv "$tmp_combined" "$events_file"; then
      echo "Error: Failed to finalize events file $events_file" >&2
      rm -f "$tmp_event" "$tmp_combined"
      return 1
    fi
    rm -f "$tmp_event"
  else
    if ! mv "$tmp_event" "$events_file"; then
      echo "Error: Failed to create events file $events_file" >&2
      rm -f "$tmp_event"
      return 1
    fi
  fi
}

# Read events.jsonl as a JSON array.
# Usage: read_events "$session"
read_events() {
  local session=$1
  local events_file
  events_file=$(events_file_path "$session")
  _ensure_events_dir "$events_file"

  if [ ! -f "$events_file" ] || [ ! -s "$events_file" ]; then
    echo "[]"
    return 0
  fi

  local tmp_file
  tmp_file=$(mktemp)
  local total_lines=0
  local invalid_idx=0
  local invalid_count=0
  local valid_count=0
  local line=""

  while IFS= read -r line || [ -n "$line" ]; do
    total_lines=$((total_lines + 1))
    if echo "$line" | jq -e '.' >/dev/null 2>&1; then
      printf '%s\n' "$line" >> "$tmp_file"
      valid_count=$((valid_count + 1))
    else
      invalid_idx=$total_lines
      invalid_count=$((invalid_count + 1))
    fi
  done < "$events_file"

  if [ "$invalid_count" -gt 0 ]; then
    _warn_invalid_event_line "$events_file" "$invalid_idx" "$total_lines"
  fi

  if [ "$valid_count" -eq 0 ]; then
    echo "[]"
  else
    jq -s '.' "$tmp_file"
  fi

  rm -f "$tmp_file"
}

# Return the most recent event, optionally filtered by type.
# Usage: last_event "$session" ["$type"]
last_event() {
  local session=$1
  local type=${2:-""}

  local events_json
  events_json=$(read_events "$session")

  if [ -z "$type" ]; then
    echo "$events_json" | jq -c '.[-1] // null'
  else
    echo "$events_json" | jq -c --arg type "$type" '[.[] | select(.type == $type)] | last // null'
  fi
}

# Read events starting from an offset (count of events already processed).
# Usage: tail_events "$session" "$offset"
tail_events() {
  local session=$1
  local offset=${2:-0}
  if [ "$offset" -lt 0 ]; then
    offset=0
  fi

  local events_file
  events_file=$(events_file_path "$session")
  _ensure_events_dir "$events_file"

  if [ ! -f "$events_file" ] || [ ! -s "$events_file" ]; then
    echo "[]"
    return 0
  fi

  local start_line=$((offset + 1))
  local tmp_file
  tmp_file=$(mktemp)
  local total_lines=0
  local invalid_idx=0
  local invalid_count=0
  local valid_count=0
  local line=""

  while IFS= read -r line || [ -n "$line" ]; do
    total_lines=$((total_lines + 1))
    if [ "$total_lines" -lt "$start_line" ]; then
      continue
    fi

    if echo "$line" | jq -e '.' >/dev/null 2>&1; then
      printf '%s\n' "$line" >> "$tmp_file"
      valid_count=$((valid_count + 1))
    else
      invalid_idx=$total_lines
      invalid_count=$((invalid_count + 1))
    fi
  done < "$events_file"

  if [ "$invalid_count" -gt 0 ]; then
    _warn_invalid_event_line "$events_file" "$invalid_idx" "$total_lines"
  fi

  if [ "$valid_count" -eq 0 ]; then
    echo "[]"
  else
    jq -s '.' "$tmp_file"
  fi

  rm -f "$tmp_file"
}

# Count valid events in events.jsonl.
# Usage: count_events "$session"
count_events() {
  local session=$1
  local events_file
  events_file=$(events_file_path "$session")
  _ensure_events_dir "$events_file"

  if [ ! -f "$events_file" ] || [ ! -s "$events_file" ]; then
    echo "0"
    return 0
  fi

  local total_lines=0
  local invalid_idx=0
  local invalid_count=0
  local valid_count=0
  local line=""

  while IFS= read -r line || [ -n "$line" ]; do
    total_lines=$((total_lines + 1))
    if echo "$line" | jq -e '.' >/dev/null 2>&1; then
      valid_count=$((valid_count + 1))
    else
      invalid_idx=$total_lines
      invalid_count=$((invalid_count + 1))
    fi
  done < "$events_file"

  if [ "$invalid_count" -gt 0 ]; then
    _warn_invalid_event_line "$events_file" "$invalid_idx" "$total_lines"
  fi

  echo "$valid_count"
}
