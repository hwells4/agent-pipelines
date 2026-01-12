---
status: closed
priority: p1
issue_id: "003"
tags: [code-review, architecture, v3-refactor]
dependencies: []
resolution: wont_implement
---

# Missing Heartbeat Implementation for Crash Detection

## Problem Statement

The implementation plan mentions 30-second heartbeats for crash detection, but `lock.sh` only checks if PID is alive, not heartbeat staleness. Long-running iterations that hang (API timeout, infinite loop in agent) won't be detected until the process actually dies.

**Why it matters:** A hung session appears "active" but isn't making progress. Without heartbeat checking, hung sessions block the session name and prevent fresh starts.

## Findings

**Location:** `/Users/harrisonwells/loop-agents/scripts/lib/lock.sh`

**Current behavior:**
- Lock file has `started_at` timestamp (line 55-56)
- State has `iteration_started` (state.sh line 100)
- But no periodic heartbeat update during iteration execution
- No staleness check beyond "is PID alive"

**From CLAUDE.md:**
> Lock file contains PID, session name, start time, and heartbeat timestamp for crash detection.

But the heartbeat timestamp is never updated after lock acquisition.

**Impact:**
- Sessions with hung Claude processes appear active indefinitely
- Users must manually kill tmux session to recover
- `--force` is the only option, losing potential session state

## Proposed Solutions

### Option A: Implement heartbeat in engine loop (Recommended)
```bash
# In engine.sh run_stage(), after starting each iteration:
update_heartbeat "$lock_file" &
HEARTBEAT_PID=$!

# Execute Claude...

kill $HEARTBEAT_PID 2>/dev/null

# In lock.sh:
update_heartbeat() {
  while true; do
    local ts=$(date +%s)
    jq --argjson hb "$ts" '.heartbeat_epoch = $hb' "$1" > "$1.tmp" && mv "$1.tmp" "$1"
    sleep 30
  done
}

is_heartbeat_stale() {
  local last_hb=$(jq -r '.heartbeat_epoch // 0' "$1")
  local now=$(date +%s)
  [ $((now - last_hb)) -gt 120 ]  # 2 minutes = stale
}
```
- **Pros:** Full heartbeat functionality, accurate hang detection
- **Cons:** Background process per session, more complexity
- **Effort:** Medium (30 minutes)
- **Risk:** Low

### Option B: Timestamp-based iteration timeout
Track `iteration_started` and consider stale after X minutes
- **Pros:** Simpler, no background process
- **Cons:** Requires knowing expected iteration duration
- **Effort:** Small
- **Risk:** Medium - false positives for long iterations

### Option C: Defer to manual intervention
Document that hung sessions require manual killing
- **Pros:** No code changes
- **Cons:** Poor UX, blocks session names
- **Effort:** None
- **Risk:** Low

## Recommended Action

Implement Option A. The heartbeat pattern is already documented in CLAUDE.md and state.json schema includes the field.

## Technical Details

- **Affected files:** `scripts/lib/lock.sh`, `scripts/engine.sh`
- **Database changes:** None
- **Component impact:** Session lifecycle, crash recovery

## Acceptance Criteria

- [ ] Lock file heartbeat_epoch is updated every 30 seconds during iteration
- [ ] `get_session_status` checks heartbeat staleness (>2 min = stale)
- [ ] Stale sessions are reported as "hung" not "active"
- [ ] Resume works correctly after detecting hung session

## Work Log

| Date | Action | Learnings |
|------|--------|-----------|
| 2026-01-12 | Created from architecture review | Plan mentions heartbeats but not implemented |
| 2026-01-12 | **Closed: Won't implement** | After analysis, heartbeat adds complexity for marginal benefit. PID death handles the common failure mode. Hung sessions (rare) can be diagnosed via `tmux attach`. If needed later, simpler approach: check `iteration_started` age in state.json rather than background heartbeat process. |

## Resources

- Architecture strategist agent findings
- CLAUDE.md lock file documentation
- docs/plans/v3-implementation-plan.md
