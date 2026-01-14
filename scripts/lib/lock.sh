#!/bin/bash
# Session Lock Management
# Prevents concurrent sessions with the same name

LOCKS_DIR="${PROJECT_ROOT:-.}/.claude/locks"
LOCK_FD=""
LOCK_SESSION=""
LOCK_TOOL=""

# Detect best available lock implementation
# Returns: flock | shlock | noclobber
detect_flock() {
  if command -v flock >/dev/null 2>&1; then
    echo "flock"
    return 0
  fi

  if command -v shlock >/dev/null 2>&1; then
    echo "shlock"
    return 0
  fi

  echo "noclobber"
}

_write_lock_metadata() {
  local session=$1
  local lock_file=$2
  local mode=${3:-"atomic"}

  local timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date +%Y-%m-%dT%H:%M:%S)

  if [ "$mode" = "direct" ]; then
    jq -n \
      --arg session "$session" \
      --arg pid "$$" \
      --arg started "$timestamp" \
      '{session: $session, pid: ($pid | tonumber), started_at: $started}' > "$lock_file"
  else
    local tmp_file
    tmp_file=$(mktemp)
    jq -n \
      --arg session "$session" \
      --arg pid "$$" \
      --arg started "$timestamp" \
      '{session: $session, pid: ($pid | tonumber), started_at: $started}' > "$tmp_file"
    mv "$tmp_file" "$lock_file"
  fi
}

_acquire_noclobber() {
  local session=$1
  local force=${2:-""}

  mkdir -p "$LOCKS_DIR"
  local lock_file="$LOCKS_DIR/${session}.lock"

  # Handle --force flag: remove existing lock first
  if [ "$force" = "--force" ] && [ -f "$lock_file" ]; then
    local existing_pid=$(jq -r '.pid // empty' "$lock_file" 2>/dev/null)
    echo "Warning: Overriding existing lock for session '$session' (PID $existing_pid)" >&2
    rm -f "$lock_file"
  fi

  # Atomic lock creation using noclobber
  # This prevents TOCTOU race conditions
  if ! (set -C; echo "$$" > "$lock_file") 2>/dev/null; then
    # Lock file exists - check if it's stale
    if [ -f "$lock_file" ]; then
      local existing_pid=$(jq -r '.pid // empty' "$lock_file" 2>/dev/null)

      if [ -n "$existing_pid" ] && kill -0 "$existing_pid" 2>/dev/null; then
        # PID is alive - lock is active
        echo "Error: Session '$session' is already running (PID $existing_pid)" >&2
        echo "  Use --force to override" >&2
        return 1
      else
        # Stale lock - PID no longer running, remove and retry
        echo "Cleaning up stale lock for session '$session'" >&2
        rm -f "$lock_file"
        if ! (set -C; echo "$$" > "$lock_file") 2>/dev/null; then
          # Another process won the race
          echo "Error: Failed to acquire lock for session '$session'" >&2
          return 1
        fi
      fi
    fi
  fi

  _write_lock_metadata "$session" "$lock_file" "atomic"
  return 0
}

acquire_flock() {
  local session=$1
  local force=${2:-""}
  local lock_tool=${3:-"flock"}

  mkdir -p "$LOCKS_DIR"
  local lock_file="$LOCKS_DIR/${session}.lock"

  # Handle --force flag: remove existing lock first
  if [ "$force" = "--force" ] && [ -f "$lock_file" ]; then
    local existing_pid=$(jq -r '.pid // empty' "$lock_file" 2>/dev/null)
    echo "Warning: Overriding existing lock for session '$session' (PID $existing_pid)" >&2
    rm -f "$lock_file"
  fi

  if [ "$lock_tool" = "flock" ]; then
    local lock_fd
    exec {lock_fd}<> "$lock_file"
    if ! flock -n "$lock_fd"; then
      local existing_pid=$(jq -r '.pid // empty' "$lock_file" 2>/dev/null)
      exec {lock_fd}>&-
      if [ -n "$existing_pid" ] && kill -0 "$existing_pid" 2>/dev/null; then
        echo "Error: Session '$session' is already running (PID $existing_pid)" >&2
        echo "  Use --force to override" >&2
      else
        echo "Error: Failed to acquire lock for session '$session'" >&2
      fi
      return 1
    fi

    LOCK_FD=$lock_fd
    LOCK_SESSION=$session
    LOCK_TOOL="flock"
  elif [ "$lock_tool" = "shlock" ]; then
    if ! shlock -f "$lock_file" -p "$$" 2>/dev/null; then
      local existing_pid=$(jq -r '.pid // empty' "$lock_file" 2>/dev/null)
      if [ -n "$existing_pid" ] && kill -0 "$existing_pid" 2>/dev/null; then
        echo "Error: Session '$session' is already running (PID $existing_pid)" >&2
        echo "  Use --force to override" >&2
      else
        echo "Error: Failed to acquire lock for session '$session'" >&2
      fi
      return 1
    fi

    LOCK_SESSION=$session
    LOCK_TOOL="shlock"
  else
    return 1
  fi

  _write_lock_metadata "$session" "$lock_file" "direct"
  return 0
}

# Acquire a lock for a session
# Usage: acquire_lock "$session" [--force]
# Returns 0 on success, 1 if locked by another process
acquire_lock() {
  local session=$1
  local force=${2:-""}
  local lock_tool
  lock_tool=$(detect_flock)

  if [ "$lock_tool" = "noclobber" ]; then
    _acquire_noclobber "$session" "$force"
    return $?
  fi

  acquire_flock "$session" "$force" "$lock_tool"
  return $?
}

# Release a lock for a session
# Usage: release_lock "$session"
# Only releases if current process owns the lock (prevents accidental release of other process's lock)
release_lock() {
  local session=$1
  local lock_file="$LOCKS_DIR/${session}.lock"

  if [ -n "$LOCK_FD" ] && [ "$LOCK_SESSION" = "$session" ]; then
    exec {LOCK_FD}>&-
    LOCK_FD=""
    LOCK_SESSION=""
    LOCK_TOOL=""
  fi

  if [ -f "$lock_file" ]; then
    local lock_pid=$(jq -r '.pid // empty' "$lock_file" 2>/dev/null)
    if [ "$lock_pid" = "$$" ]; then
      rm -f "$lock_file"
    fi
  fi
}

# Check if a session is locked
# Usage: is_locked "$session"
# Returns 0 if locked (by running process), 1 if not locked
is_locked() {
  local session=$1
  local lock_file="$LOCKS_DIR/${session}.lock"

  if [ ! -f "$lock_file" ]; then
    return 1
  fi

  local existing_pid=$(jq -r '.pid // empty' "$lock_file" 2>/dev/null)

  if [ -n "$existing_pid" ] && kill -0 "$existing_pid" 2>/dev/null; then
    return 0
  fi

  return 1
}

# Clean up stale locks (for dead PIDs)
# Usage: cleanup_stale_locks
cleanup_stale_locks() {
  mkdir -p "$LOCKS_DIR"

  # Handle case where no lock files exist
  local lock_files=("$LOCKS_DIR"/*.lock)
  [ -e "${lock_files[0]}" ] || return 0

  for lock_file in "${lock_files[@]}"; do
    [ -f "$lock_file" ] || continue

    local pid=$(jq -r '.pid // empty' "$lock_file" 2>/dev/null)
    local session=$(jq -r '.session // empty' "$lock_file" 2>/dev/null)

    if [ -n "$pid" ] && ! kill -0 "$pid" 2>/dev/null; then
      echo "Removing stale lock: $session (PID $pid)" >&2
      rm -f "$lock_file"
    fi
  done
}
