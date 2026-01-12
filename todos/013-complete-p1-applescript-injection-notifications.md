---
status: complete
priority: p1
issue_id: "013"
tags: [code-review, security, blocks-merge]
dependencies: []
---

# AppleScript Injection in Desktop Notifications

## Problem Statement

The notification function in `notify.sh` interpolates user-controlled content directly into AppleScript without escaping, allowing command injection.

**Why it matters:** A malicious session name or status message could execute arbitrary shell commands through AppleScript.

## Findings

**Location:** `/Users/harrisonwells/loop-agents/scripts/lib/notify.sh`, lines 10-12

**Vulnerable code:**
```bash
osascript -e "display notification \"$message\" with title \"$title\"" 2>/dev/null || true
```

**Attack vector:** A session name or status message containing `" & do shell script "malicious" & "` could execute arbitrary shell commands.

**Example exploit:**
```bash
# If session name is:
session='test" & do shell script "open /System/Applications/Calculator.app" & "'

# The resulting osascript command becomes:
osascript -e "display notification \"Status\" with title \"test" & do shell script "open /System/Applications/Calculator.app" & "\""
```

**Mitigating factors:**
- Session names typically come from CLI arguments, not external sources
- Notifications are optional and often fail silently
- macOS sandboxing limits damage

## Proposed Solutions

### Solution 1: Escape quotes in message and title (Recommended)

**Pros:** Simple fix, maintains notification functionality
**Cons:** Need to handle both single and double quotes
**Effort:** Small (5-10 lines)
**Risk:** Low

```bash
send_notification() {
  local title=$1
  local message=$2

  # Escape backslashes first, then quotes
  title="${title//\\/\\\\}"
  title="${title//\"/\\\"}"
  message="${message//\\/\\\\}"
  message="${message//\"/\\\"}"

  osascript -e "display notification \"$message\" with title \"$title\"" 2>/dev/null || true
}
```

### Solution 2: Use terminal-notifier or alternative

**Pros:** More robust, no AppleScript injection surface
**Cons:** Adds external dependency
**Effort:** Medium
**Risk:** Low

### Solution 3: Remove notification feature

**Pros:** Eliminates attack surface entirely
**Cons:** Loses useful developer feedback feature
**Effort:** Small
**Risk:** Low

## Recommended Action

Implement Solution 1 - escape quotes before AppleScript interpolation.

## Technical Details

**Affected files:**
- `scripts/lib/notify.sh` - lines 10-12

**Components affected:**
- Desktop notifications for session completion

## Acceptance Criteria

- [ ] Quotes and backslashes are escaped before AppleScript interpolation
- [ ] Notification with normal text still works
- [ ] Test added with session name containing special characters
- [ ] Verify no code execution with malicious input

## Work Log

| Date | Action | Learnings |
|------|--------|-----------|
| 2026-01-11 | Identified during security review | AppleScript string interpolation is dangerous |
| 2026-01-11 | Fixed: Added quote escaping in notify() | All 295 tests pass |

## Resources

- Security review agent finding V-002
- AppleScript security considerations
