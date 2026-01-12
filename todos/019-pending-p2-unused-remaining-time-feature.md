---
status: pending
priority: p2
issue_id: "019"
tags: [code-review, simplification, dead-code, yagni]
dependencies: []
---

# YAGNI: Unused Remaining Time Calculation Feature

## Problem Statement

The `context.sh` file contains a `calculate_remaining_time()` function that computes elapsed time vs. a `max_runtime_seconds` guardrail. However, no stage configuration files define this guardrail, making this entire feature unused.

**Why it matters:** Unused features add complexity without value. This function is ~47 lines of dead code path that will never execute in production.

## Findings

**Location:** `/Users/harrisonwells/loop-agents/scripts/lib/context.sh`, lines 163-209

**Function:**
```bash
calculate_remaining_time() {
  local config_file=$1
  local start_time=$2

  # Parse max_runtime_seconds from guardrails section
  local max_runtime=$(json_get "$config" ".guardrails.max_runtime_seconds" "-1")
  # ... 40+ more lines calculating elapsed time
}
```

**Verification - no configs use this:**
```bash
$ grep -r "max_runtime_seconds\|guardrails" scripts/loops/*/loop.yaml
# No results
$ grep -r "remaining_seconds" scripts/loops/*/prompt.md
# No results - prompts don't use this context field
```

**Impact:**
- `generate_context()` always writes `"remaining_seconds": -1`
- No prompt ever reads this field
- Feature was speculatively added but never used

## Proposed Solutions

### Solution 1: Delete remaining time calculation (Recommended)

**Pros:** Removes 47 lines of unused code, simplifies context generation
**Cons:** None - not used
**Effort:** Small
**Risk:** None

```bash
# In generate_context(), instead of:
local remaining=$(calculate_remaining_time "$loop_config" "$started_at")

# Simply use:
local remaining=-1
```

### Solution 2: Document as planned feature

**Pros:** Keeps infrastructure if guardrails are planned
**Cons:** Still dead code
**Effort:** Small
**Risk:** Low

## Recommended Action

Delete `calculate_remaining_time()` and hardcode `remaining_seconds: -1` in context. If runtime guardrails are needed in the future, they can be re-implemented with actual requirements.

## Technical Details

**Lines to remove:**
- Lines 163-209: `calculate_remaining_time()` function
- Simplify context generation to hardcode -1

**Estimated LOC reduction:** 47 lines

## Acceptance Criteria

- [ ] calculate_remaining_time() function deleted
- [ ] generate_context() hardcodes remaining_seconds: -1
- [ ] All existing tests pass
- [ ] Context JSON still valid

## Work Log

| Date | Action | Learnings |
|------|--------|-----------|
| 2026-01-11 | Identified during code simplicity review | Speculative features should wait for requirements |

## Resources

- Code simplicity review findings
- YAGNI principle
