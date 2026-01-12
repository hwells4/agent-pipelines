---
status: closed
priority: p1
issue_id: "002"
tags: [code-review, data-integrity, v3-refactor]
dependencies: []
resolution: fixed
---

# Status Validation Not Enforced in Engine Loop

## Problem Statement

The engine reads `status.json` written by agents without calling `validate_status()` first. If an agent writes malformed JSON, the system silently falls back to defaults instead of failing fast. This could cause silent infinite loops instead of proper error notification.

**Why it matters:** A misbehaving or crashed agent could cause the pipeline to continue indefinitely without any indication of the problem.

## Findings

**Location:** `/Users/harrisonwells/loop-agents/scripts/engine.sh` line 298

**Current code:**
```bash
local history_json=$(status_to_history_json "$status_file")
```

This reads the status file without validating it. If the agent wrote malformed JSON:
- `get_status_decision()` returns `"continue"` as fallback
- `status_to_history_json()` returns `{decision: "continue"}`
- Loop continues forever instead of failing fast

**Also affected:** `/Users/harrisonwells/loop-agents/scripts/lib/status.sh` lines 52-61
- `get_status_decision()` silently returns "continue" on any error
- Should return "error" and propagate the failure

## Proposed Solutions

### Option A: Add validation before status reading (Recommended)
```bash
if ! validate_status "$status_file"; then
  create_error_status "$status_file" "Agent wrote invalid status.json"
fi
local history_json=$(status_to_history_json "$status_file")
```
- **Pros:** Catches malformed JSON immediately, preserves fail-fast philosophy
- **Cons:** Slightly more verbose
- **Effort:** Small (10 minutes)
- **Risk:** Low

### Option B: Make get_status_decision return "error" on parse failure
```bash
get_status_decision() {
  if ! jq -e '.' "$status_file" &>/dev/null; then
    echo "error"
    return 1
  fi
  jq -r '.decision // "continue"' "$status_file"
}
```
- **Pros:** Single point of change
- **Cons:** Changes behavior of widely-used function
- **Effort:** Small
- **Risk:** Medium - might break callers expecting "continue"

## Recommended Action

Implement Option A in engine.sh. Add explicit validation before reading status.

## Technical Details

- **Affected files:** `scripts/engine.sh`, potentially `scripts/lib/status.sh`
- **Database changes:** None
- **Component impact:** Iteration status handling

## Acceptance Criteria

- [ ] Engine validates status.json before using it
- [ ] Invalid status.json triggers error status creation
- [ ] Pipeline fails with clear error message when agent writes garbage
- [ ] Existing valid status.json handling unchanged

## Work Log

| Date | Action | Learnings |
|------|--------|-----------|
| 2026-01-12 | Created from data integrity review | Silent fallback to "continue" is dangerous |
| 2026-01-12 | **Fixed** | Added `validate_status()` call before reading status in both run_stage and run_pipeline. Updated `get_status_decision()` to return "error" on invalid JSON instead of "continue". |

## Resources

- Data integrity guardian agent findings
- v3 fail-fast philosophy in implementation plan
