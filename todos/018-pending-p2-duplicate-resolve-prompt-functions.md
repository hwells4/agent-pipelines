---
status: pending
priority: p2
issue_id: "018"
tags: [code-review, simplification, duplicate-code]
dependencies: []
---

# Duplicate Logic: resolve_prompt Functions

## Problem Statement

The `resolve.sh` file contains two template resolution functions (`resolve_prompt()` and `resolve_prompt_v3()`) with ~90% overlapping logic. This duplication increases maintenance burden and risk of drift.

**Why it matters:** Duplicate code means changes need to be made in multiple places, increasing the risk of bugs and inconsistencies.

## Findings

**Location:** `/Users/harrisonwells/loop-agents/scripts/lib/resolve.sh`

**Functions:**
- `resolve_prompt_v3()` - lines 21-66 (46 lines)
- `resolve_prompt()` - lines 71-129 (59 lines)

**Overlap analysis:**
- Both do `${INPUTS.*}` resolution (identical logic)
- Both do basic variable substitution
- `resolve_prompt()` already routes to v3 for context files (lines 75-79)
- The v3 function exists primarily for direct invocation but is rarely called directly

**Current routing:**
```bash
# resolve_prompt() lines 75-79
if [[ "$vars_arg" == *.json && -f "$vars_arg" ]]; then
  resolve_prompt_v3 "$prompt_file" "$vars_arg"
  return $?
fi
```

## Proposed Solutions

### Solution 1: Inline v3 logic into main function (Recommended)

**Pros:** Single function, no routing overhead, clearer code flow
**Cons:** Slightly longer function
**Effort:** Small (merge and delete)
**Risk:** Low

```bash
resolve_prompt() {
  local prompt_file=$1
  local vars_arg=$2
  local run_dir=${3:-}

  local resolved=$(cat "$prompt_file")

  # Handle context file (v3 mode) - inline the v3 logic
  if [[ "$vars_arg" == *.json && -f "$vars_arg" ]]; then
    local ctx=$vars_arg
    resolved="${resolved//\$\{CTX\}/$ctx}"
    # ... rest of v3 substitutions
    # ... then do INPUTS resolution
    echo "$resolved"
    return
  fi

  # Handle JSON vars object (legacy mode)
  # ... existing v2 logic
}
```

### Solution 2: Extract shared logic to helper

**Pros:** DRY for the shared parts
**Cons:** Adds another function, more indirection
**Effort:** Medium
**Risk:** Low

## Recommended Action

Implement Solution 1 - inline v3 logic into the main function, delete the separate function.

## Technical Details

**Changes:**
1. Move v3 substitution logic into resolve_prompt()
2. Keep the context file detection (lines 75-79)
3. Delete resolve_prompt_v3() function entirely
4. Update any direct callers (if any) to use resolve_prompt()

**Estimated change:** -46 lines (delete v3 function), +20 lines (inline logic) = net -26 lines

## Acceptance Criteria

- [ ] Single resolve_prompt() function handles both modes
- [ ] resolve_prompt_v3() deleted
- [ ] All existing tests pass
- [ ] Context file resolution still works
- [ ] Legacy JSON vars resolution still works

## Work Log

| Date | Action | Learnings |
|------|--------|-----------|
| 2026-01-11 | Identified during code simplicity review | Routing functions often indicate opportunity for consolidation |

## Resources

- Code simplicity review findings
- DRY principle
