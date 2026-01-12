---
status: closed
priority: p1
issue_id: "001"
tags: [code-review, security, v3-refactor]
dependencies: []
resolution: fixed
---

# JSON Injection in notify.sh record_completion

## Problem Statement

The `record_completion` function in `/Users/harrisonwells/loop-agents/scripts/lib/notify.sh` constructs JSON using string interpolation rather than jq's safe argument passing. This allows potential JSON injection if an attacker can control the `session`, `type`, or `status` parameters.

**Why it matters:** JSON injection could corrupt the completion log file, inject malicious data that downstream tools might parse, or enable log forging attacks.

## Findings

**Location:** `/Users/harrisonwells/loop-agents/scripts/lib/notify.sh` lines 32-34

**Vulnerable code:**
```bash
local entry="{\"session\": \"$session\", \"type\": \"$type\", \"status\": \"$status\", \"completed_at\": \"$timestamp\"}"
```

**Attack vector:** If `session = 'test", "malicious": "payload'`, the resulting JSON would be malformed/injected.

**Exploitability:** Low-Medium (requires control over session/type/status parameters, but session names are now validated)

## Proposed Solutions

### Option A: Use jq --arg for safe construction (Recommended)
```bash
local entry=$(jq -n --arg session "$session" --arg type "$type" --arg status "$status" --arg ts "$timestamp" \
  '{session: $session, type: $type, status: $status, completed_at: $ts}')
```
- **Pros:** Completely safe, leverages existing jq dependency
- **Cons:** One additional subprocess spawn
- **Effort:** Small (5 minutes)
- **Risk:** None

### Option B: Escape special characters manually
- **Pros:** No subprocess overhead
- **Cons:** Easy to miss edge cases, error-prone
- **Effort:** Medium
- **Risk:** Medium - may miss escaping cases

## Recommended Action

Implement Option A. The subprocess overhead is negligible and the safety guarantee is complete.

## Technical Details

- **Affected files:** `scripts/lib/notify.sh`
- **Database changes:** None
- **Component impact:** Session completion logging

## Acceptance Criteria

- [ ] JSON construction uses jq's --arg for all user-controllable values
- [ ] Existing tests still pass
- [ ] Completion log file remains valid JSON after changes

## Work Log

| Date | Action | Learnings |
|------|--------|-----------|
| 2026-01-12 | Created from security review | Found during parallel agent review |
| 2026-01-12 | **Fixed** | Replaced string interpolation with `jq -n --arg` for safe JSON construction in `record_completion()` |

## Resources

- Security review agent findings
- OWASP JSON Injection guidance
