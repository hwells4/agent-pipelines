---
status: closed
priority: p2
issue_id: "006"
tags: [code-review, architecture, v3-refactor]
dependencies: []
resolution: fixed
---

# lock.sh Has Mixed Responsibilities (Contains Status Functions)

## Problem Statement

`lock.sh` contains both lock management AND session status functions (`get_session_status`, `get_crash_info`, `show_crash_recovery_info`, `show_resume_info`). These status functions would fit better in `state.sh` which already handles session state.

**Why it matters:** Violates single responsibility principle. Makes it harder to understand where session status logic lives.

## Findings

**Location:** `/Users/harrisonwells/loop-agents/scripts/lib/lock.sh` lines 115-230

**Functions that should move to state.sh:**
- `get_session_status()` - lines 126-179
- `get_crash_info()` - lines 184-190
- `show_crash_recovery_info()` - lines 194-210
- `show_resume_info()` - lines 217-229

**Why they belong in state.sh:**
- They read from `state.json`, not lock files
- They're about session state, not concurrency control
- state.sh already has related functions (`can_resume`, `get_resume_iteration`)

**lock.sh should only contain:**
- `acquire_lock()`
- `release_lock()`
- `is_locked()`
- `cleanup_stale_locks()`

## Proposed Solutions

### Option A: Move functions to state.sh (Recommended)
Move the 4 status functions to state.sh, update any callers
- **Pros:** Clean separation, follows existing patterns
- **Cons:** Requires updating imports/calls
- **Effort:** Small (20 minutes)
- **Risk:** Low

### Option B: Create new session_status.sh
Separate file for session status queries
- **Pros:** Very clean separation
- **Cons:** More files to maintain
- **Effort:** Medium
- **Risk:** Low

## Recommended Action

Implement Option A. Move functions to state.sh where related logic already exists.

## Technical Details

- **Affected files:** `scripts/lib/lock.sh`, `scripts/lib/state.sh`, `scripts/engine.sh`
- **Database changes:** None
- **Component impact:** Code organization only

## Acceptance Criteria

- [ ] Status functions moved from lock.sh to state.sh
- [ ] All callers updated
- [ ] lock.sh only contains locking logic
- [ ] All tests pass

## Work Log

| Date | Action | Learnings |
|------|--------|-----------|
| 2026-01-12 | Created from architecture review | Mixed responsibilities in lock.sh |
| 2026-01-12 | **Fixed** | Moved get_session_status, get_crash_info, show_crash_recovery_info, show_resume_info from lock.sh to state.sh |

## Resources

- Architecture strategist agent findings
- Single Responsibility Principle
