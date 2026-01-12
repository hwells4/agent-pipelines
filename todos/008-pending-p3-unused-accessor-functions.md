---
status: closed
priority: p3
issue_id: "008"
tags: [code-review, simplification, v3-refactor]
dependencies: []
resolution: wont_fix
---

# Unused Accessor Functions in status.sh

## Problem Statement

`status.sh` contains 7 nearly identical accessor functions, but only 2-3 are actually used in the codebase. This violates YAGNI and adds unnecessary code to maintain.

**Why it matters:** Dead code increases maintenance burden and cognitive load. If needed later, `jq -r '.field'` is trivial to inline.

## Findings

**Location:** `/Users/harrisonwells/loop-agents/scripts/lib/status.sh` lines 52-129

**Used functions:**
- `get_status_decision()` - used in plateau.sh and engine.sh
- `get_status_reason()` - used in plateau.sh

**Unused functions (~45 LOC):**
- `get_status_summary()` - 0 usages
- `get_status_files()` - 0 usages
- `get_status_items()` - 0 usages
- `get_status_errors()` - 0 usages

These were presumably added anticipating future needs that haven't materialized.

## Proposed Solutions

### Option A: Remove unused functions (Recommended)
Delete the 4 unused accessor functions
- **Pros:** Less code to maintain, clearer API
- **Cons:** Must add back if needed later (trivial)
- **Effort:** Small (5 minutes)
- **Risk:** None

### Option B: Mark as deprecated
Add comments noting functions are unused
- **Pros:** Preserves code if needed
- **Cons:** Still cluttering the file
- **Effort:** Small
- **Risk:** None

## Recommended Action

Implement Option A. If needed later, re-adding a one-liner is trivial.

## Technical Details

- **Affected files:** `scripts/lib/status.sh`
- **Database changes:** None
- **Component impact:** None (code removal)

## Acceptance Criteria

- [ ] Remove get_status_summary, get_status_files, get_status_items, get_status_errors
- [ ] Confirm no usages exist via grep
- [ ] All tests pass

## Work Log

| Date | Action | Learnings |
|------|--------|-----------|
| 2026-01-12 | Created from simplicity review | YAGNI violation - speculative accessors |
| 2026-01-12 | **Kept** | Functions are documented in CLAUDE.md for debugging. Keeping as utility API even without current callers. |

## Resources

- Code simplicity reviewer agent findings
