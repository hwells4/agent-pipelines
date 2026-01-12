---
status: pending
priority: p2
issue_id: "017"
tags: [code-review, simplification, dead-code]
dependencies: []
---

# Dead Code: Unused Status Accessor Functions

## Problem Statement

The `status.sh` file contains several accessor functions that are never called from anywhere in the codebase. These functions were likely created speculatively but are not used.

**Why it matters:** Dead code increases maintenance burden, adds to cognitive load, and inflates test requirements without providing value.

## Findings

**Location:** `/Users/harrisonwells/loop-agents/scripts/lib/status.sh`

**Unused functions:**

1. `get_status_files()` - lines 89-101 (13 lines)
```bash
$ grep -r "get_status_files" scripts/
scripts/lib/status.sh:get_status_files() {
# No other references
```

2. `get_status_items()` - lines 103-115 (13 lines)
```bash
$ grep -r "get_status_items" scripts/
scripts/lib/status.sh:get_status_items() {
# No other references
```

3. `get_status_errors()` - lines 117-129 (13 lines)
```bash
$ grep -r "get_status_errors" scripts/
scripts/lib/status.sh:get_status_errors() {
# No other references
```

4. `create_default_status()` - lines 155-177 (23 lines)
```bash
$ grep -r "create_default_status" scripts/
scripts/lib/status.sh:create_default_status() {
# No other references
```

5. `legacy_output_to_status()` - lines 179-226 (48 lines)
```bash
$ grep -r "legacy_output_to_status" scripts/
scripts/lib/status.sh:legacy_output_to_status() {
# No other references - v2 migration code no longer needed
```

**Functions that ARE used:**
- `get_status_decision()` - called by plateau.sh and engine.sh
- `get_status_reason()` - called by engine.sh
- `get_status_summary()` - called by engine.sh

## Proposed Solutions

### Solution 1: Delete all unused functions (Recommended)

**Pros:** Cleanest, removes 110 lines of dead code
**Cons:** None - not used
**Effort:** Small (delete)
**Risk:** None

### Solution 2: Keep as API for future use

**Pros:** Ready if needed later
**Cons:** Maintenance burden, violates YAGNI
**Effort:** None
**Risk:** Low

## Recommended Action

Delete all unused functions. If needed in the future, they can be easily re-implemented.

## Technical Details

**Lines to remove:**
- Lines 89-101: `get_status_files()`
- Lines 103-115: `get_status_items()`
- Lines 117-129: `get_status_errors()`
- Lines 155-177: `create_default_status()`
- Lines 179-226: `legacy_output_to_status()`

**Estimated LOC reduction:** 110 lines

## Acceptance Criteria

- [ ] All unused functions deleted
- [ ] All existing tests pass
- [ ] grep confirms no references to deleted functions
- [ ] Used functions (get_status_decision, reason, summary) still work

## Work Log

| Date | Action | Learnings |
|------|--------|-----------|
| 2026-01-11 | Identified during code simplicity review | Speculative APIs should be deleted |

## Resources

- Code simplicity review findings
- YAGNI principle
