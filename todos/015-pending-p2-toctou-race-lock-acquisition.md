---
status: pending
priority: p2
issue_id: "015"
tags: [code-review, security, reliability]
dependencies: []
---

# TOCTOU Race Condition in Lock Acquisition

## Problem Statement

The lock acquisition in `lock.sh` uses a check-then-act pattern that is vulnerable to time-of-check-to-time-of-use (TOCTOU) race conditions.

**Why it matters:** Two processes starting simultaneously could both pass the lock check and create duplicate sessions, leading to race conditions in state files and potential data corruption.

## Findings

**Location:** `/Users/harrisonwells/loop-agents/scripts/lib/lock.sh`, lines 18-43

**Vulnerable pattern:**
```bash
acquire_lock() {
  local session=$1
  local lock_file="$LOCKS_DIR/${session}.lock"

  # Check if lock exists
  if [ -f "$lock_file" ]; then
    # ... check PID ...
  fi

  # Race window: another process could create lock here

  # Create lock file
  mkdir -p "$LOCKS_DIR"
  jq -n ... > "$lock_file"  # Non-atomic write
}
```

**Race scenario:**
1. Process A checks for lock file - doesn't exist
2. Process B checks for lock file - doesn't exist
3. Process A creates lock file
4. Process B creates lock file (overwrites A's lock)
5. Both processes proceed, causing conflicts

## Proposed Solutions

### Solution 1: Use set -o noclobber for atomic creation (Recommended)

**Pros:** Shell-native, portable, simple
**Cons:** Slightly different error handling
**Effort:** Small (5-10 lines)
**Risk:** Low

```bash
acquire_lock() {
  local session=$1
  local lock_file="$LOCKS_DIR/${session}.lock"

  mkdir -p "$LOCKS_DIR"

  # Atomic lock creation using noclobber
  if ! (set -o noclobber; echo "$$" > "$lock_file") 2>/dev/null; then
    # Lock exists - check if stale
    if [ -f "$lock_file" ]; then
      local lock_pid=$(jq -r '.pid // empty' "$lock_file" 2>/dev/null)
      if [ -n "$lock_pid" ] && ! kill -0 "$lock_pid" 2>/dev/null; then
        # Stale lock - remove and retry
        rm -f "$lock_file"
        if ! (set -o noclobber; echo "$$" > "$lock_file") 2>/dev/null; then
          return 1  # Another process won the race
        fi
      else
        return 1  # Lock is active
      fi
    fi
  fi

  # Write full lock info (atomic via mv)
  local tmp=$(mktemp)
  jq -n --arg session "$session" --arg pid "$$" ... > "$tmp"
  mv "$tmp" "$lock_file"
}
```

### Solution 2: Use flock for advisory locking

**Pros:** Robust, handles many edge cases
**Cons:** Requires flock binary, more complex
**Effort:** Medium
**Risk:** Low

```bash
exec 200>"$lock_file"
flock -n 200 || { echo "Already running"; return 1; }
```

### Solution 3: Use mkdir as atomic operation

**Pros:** Very portable
**Cons:** Creates directory instead of file
**Effort:** Small
**Risk:** Low

```bash
if ! mkdir "$lock_dir" 2>/dev/null; then
  # Lock exists
  ...
fi
```

## Recommended Action

Implement Solution 1 - noclobber provides good atomicity with minimal changes.

## Technical Details

**Affected files:**
- `scripts/lib/lock.sh` - lines 18-43

**Components affected:**
- Session startup
- Duplicate session prevention

## Acceptance Criteria

- [ ] Lock acquisition uses atomic file creation
- [ ] Stale lock detection still works
- [ ] Test added to verify race condition is prevented
- [ ] All existing tests pass

## Work Log

| Date | Action | Learnings |
|------|--------|-----------|
| 2026-01-11 | Identified during security review | File-based locking requires atomic operations |

## Resources

- Security review agent finding V-004
- Bash noclobber documentation
