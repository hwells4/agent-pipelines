---
status: pending
priority: p3
issue_id: "020"
tags: [code-review, performance, optimization]
dependencies: []
---

# Performance: Excessive jq Process Spawns

## Problem Statement

The codebase spawns individual jq processes for each JSON field extraction, resulting in ~36+ process spawns per iteration. While not critical (Claude API calls dominate runtime), this creates unnecessary overhead that compounds with iteration count.

**Why it matters:** At 100 iterations, cumulative jq overhead reaches 36-60 seconds of pure process spawn time. This is technical debt that will become noticeable at scale.

## Findings

**Example from resolve.sh lines 84-94:**
```bash
local session=$(echo "$vars_json" | jq -r '.session // empty')
local iteration=$(echo "$vars_json" | jq -r '.iteration // empty')
local index=$(echo "$vars_json" | jq -r '.index // empty')
local perspective=$(echo "$vars_json" | jq -r '.perspective // empty')
local output_file=$(echo "$vars_json" | jq -r '.output // empty')
local output_path=$(echo "$vars_json" | jq -r '.output_path // empty')
local progress_file=$(echo "$vars_json" | jq -r '.progress // empty')
local run_dir=$(echo "$vars_json" | jq -r '.run_dir // empty')
local stage_idx=$(echo "$vars_json" | jq -r '.stage_idx // "0"')
local context_file=$(echo "$vars_json" | jq -r '.context_file // empty')
local status_file=$(echo "$vars_json" | jq -r '.status_file // empty')
```

**Process count per iteration:**
- `generate_context()`: ~15 jq calls
- `resolve_prompt()`: ~12 jq calls
- State updates: ~3 jq calls
- Completion check: ~5 jq calls
- **Total: ~36 processes per iteration**

**Projected overhead:**
- 25 iterations: ~900 spawns, 9-15 seconds
- 100 iterations: ~3,600 spawns, 36-60 seconds

## Proposed Solutions

### Solution 1: Batch field extraction with @tsv (Recommended)

**Pros:** 90% reduction in jq spawns, simple refactor
**Cons:** Slightly more complex parsing
**Effort:** Small per function
**Risk:** Low

```bash
# Instead of 11 separate jq calls:
read session iteration index perspective output_file output_path progress_file run_dir stage_idx context_file status_file < <(
  echo "$vars_json" | jq -r '[.session, .iteration, .index, .perspective, .output, .output_path, .progress, .run_dir, .stage_idx, .context_file, .status_file] | @tsv'
)
```

### Solution 2: Use jq's multiple field output with --raw-output

**Pros:** Simple, no parsing
**Cons:** Requires delimiter handling
**Effort:** Small
**Risk:** Low

### Solution 3: Cache JSON parsing results

**Pros:** Eliminates redundant parsing
**Cons:** More complex state management
**Effort:** Medium
**Risk:** Medium

## Recommended Action

Implement Solution 1 in the highest-impact functions first:
1. `resolve_prompt()` - 11+ jq calls
2. `generate_context()` - 15+ jq calls

## Technical Details

**Files to optimize:**
- `scripts/lib/resolve.sh` - lines 84-94
- `scripts/lib/context.sh` - multiple sections
- `scripts/lib/status.sh` - accessor functions

## Acceptance Criteria

- [ ] resolve_prompt() uses batch extraction
- [ ] Per-iteration jq count reduced by 50%+
- [ ] All existing tests pass
- [ ] No functional changes

## Work Log

| Date | Action | Learnings |
|------|--------|-----------|
| 2026-01-11 | Identified during performance review | Shell process spawn overhead compounds |

## Resources

- Performance review findings
- jq @tsv documentation
