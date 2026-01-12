---
status: pending
priority: p2
issue_id: "016"
tags: [code-review, simplification, dead-code]
dependencies: []
---

# Dead Code: Recording Mode in mock.sh

## Problem Statement

The `mock.sh` file contains a recording mode feature (`enable_record_mode()`, `record_response()`) that is never called from anywhere in the codebase. This is dead code that adds maintenance burden and could confuse future maintainers.

**Why it matters:** Dead code increases cognitive load, can mislead developers about system capabilities, and requires ongoing maintenance without providing value.

## Findings

**Location:** `/Users/harrisonwells/loop-agents/scripts/lib/mock.sh`, lines 376-404

**Dead functions:**
```bash
enable_record_mode() {
  # ... 10 lines
}

record_response() {
  # ... 18 lines
}
```

**Verification:**
```bash
$ grep -r "enable_record_mode\|record_response" scripts/
scripts/lib/mock.sh:enable_record_mode() {
scripts/lib/mock.sh:record_response() {
# No other references
```

**Related dead code:**
- `MOCK_RECORD_MODE` variable (line 9)
- Recording mode state management

## Proposed Solutions

### Solution 1: Delete recording mode entirely (Recommended)

**Pros:** Simplest, removes 29 lines of dead code
**Cons:** None - not used
**Effort:** Small (delete)
**Risk:** None

### Solution 2: Document as planned feature

**Pros:** Keeps code if recording is planned
**Cons:** Still dead code in the meantime
**Effort:** Small (add comment)
**Risk:** Low

## Recommended Action

Delete the recording mode functions. If recording is needed in the future, it can be re-implemented based on actual requirements.

## Technical Details

**Lines to remove:**
- Lines 9: `MOCK_RECORD_MODE=false`
- Lines 376-386: `enable_record_mode()`
- Lines 388-404: `record_response()`

**Estimated LOC reduction:** 29 lines

## Acceptance Criteria

- [ ] Recording mode functions deleted
- [ ] MOCK_RECORD_MODE variable removed
- [ ] All existing tests pass
- [ ] No grep matches for removed function names

## Work Log

| Date | Action | Learnings |
|------|--------|-----------|
| 2026-01-11 | Identified during code simplicity review | Unused features should be deleted not commented |

## Resources

- Code simplicity review findings
- YAGNI principle
