---
status: complete
priority: p1
issue_id: "014"
tags: [code-review, security, blocks-merge]
dependencies: []
---

# Missing Session Name Validation

## Problem Statement

Session names are used directly in file paths, shell commands, and directory creation without validation. Malicious session names could contain path traversal sequences, shell metacharacters, or excessively long strings.

**Why it matters:** A session name like `../../../etc/cron.d/backdoor` could write files outside intended directories. A name like `test; rm -rf /` could cause command injection in certain contexts.

## Findings

**Location:** Multiple files including `engine.sh`, `lock.sh`, `run.sh`

**Vulnerable patterns:**
```bash
# engine.sh line 364
local run_dir="$PROJECT_ROOT/.claude/pipeline-runs/$session"

# lock.sh line 15
local lock_file="$LOCKS_DIR/${session}.lock"

# state.sh and other files use session in paths
```

**Path traversal example:**
```bash
./scripts/run.sh work "../../../tmp/malicious" 25
# Creates: .claude/pipeline-runs/../../../tmp/malicious/
# Which resolves to: /tmp/malicious/
```

**Shell metacharacter risks:**
- Semicolons, pipes, and backticks in session names
- Newlines and null bytes
- Glob patterns (* and ?)

## Proposed Solutions

### Solution 1: Add session name validation function (Recommended)

**Pros:** Single point of validation, reusable across codebase
**Cons:** Need to add validation calls in multiple places
**Effort:** Small (15-20 lines)
**Risk:** Low

```bash
# Add to scripts/lib/validate.sh
validate_session_name() {
  local name=$1

  # Check for empty
  if [ -z "$name" ]; then
    echo "Error: Session name cannot be empty" >&2
    return 1
  fi

  # Check length (max 64 chars)
  if [ ${#name} -gt 64 ]; then
    echo "Error: Session name too long (max 64 characters)" >&2
    return 1
  fi

  # Check for valid characters (alphanumeric, underscore, hyphen)
  if [[ ! "$name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    echo "Error: Session name must contain only alphanumeric characters, underscores, and hyphens" >&2
    return 1
  fi

  return 0
}
```

### Solution 2: Sanitize session names

**Pros:** Allows more flexible input
**Cons:** May produce unexpected results, harder to debug
**Effort:** Small
**Risk:** Medium

## Recommended Action

Implement Solution 1 - strict validation with clear error messages.

## Technical Details

**Affected files:**
- `scripts/run.sh` - entry point validation
- `scripts/engine.sh` - pipeline execution validation
- `scripts/lib/lock.sh` - lock file creation

**Components affected:**
- All session creation and lookup operations

## Acceptance Criteria

- [ ] `validate_session_name()` function added to validate.sh
- [ ] run.sh validates session name at entry point
- [ ] Clear error message for invalid session names
- [ ] Tests added for: empty name, too long, special characters, path traversal
- [ ] All existing tests pass

## Work Log

| Date | Action | Learnings |
|------|--------|-----------|
| 2026-01-11 | Identified during security review | User input validation is critical at system boundaries |
| 2026-01-11 | Fixed: Added validate_session_name() to validate.sh, called from engine.sh | All 295 tests pass |

## Resources

- Security review agent finding V-003
- OWASP Path Traversal: https://owasp.org/www-community/attacks/Path_Traversal
