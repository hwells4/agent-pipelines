---
status: complete
priority: p1
issue_id: "012"
tags: [code-review, security, blocks-merge]
dependencies: []
---

# Python Code Injection in YAML Parser

## Problem Statement

The YAML parser in `yaml.sh` uses Python with unsanitized file path interpolation, allowing code injection if an attacker controls the file path.

**Why it matters:** If a malicious file path is passed (e.g., from a compromised pipeline config), arbitrary Python code could execute in the context of the pipeline orchestrator.

## Findings

**Location:** `/Users/harrisonwells/loop-agents/scripts/lib/yaml.sh`, lines 18-22

**Vulnerable code:**
```bash
python3 -c "
import sys, json, yaml
with open('$file') as f:
    print(json.dumps(yaml.safe_load(f)))
"
```

**Attack vector:** If `$file` contains `'); import os; os.system('malicious command'); #`, arbitrary code executes.

**Example exploit:**
```bash
# If someone creates a pipeline.yaml with a malicious path reference
# or if $file is somehow user-controlled
file="'); import os; os.system('rm -rf /'); #"
yaml_to_json "$file"  # Executes the injected code
```

**Mitigating factors:**
- File paths typically come from trusted local config files
- The system runs in a developer-controlled environment
- `yq` is the preferred path and doesn't have this vulnerability

## Proposed Solutions

### Solution 1: Pass file path as command-line argument (Recommended)

**Pros:** Eliminates injection entirely, minimal code change
**Cons:** None
**Effort:** Small (2 lines)
**Risk:** Low

```bash
python3 -c "import sys, json, yaml; print(json.dumps(yaml.safe_load(open(sys.argv[1]))))" "$file"
```

### Solution 2: Use shell quoting and escape

**Pros:** Works in place
**Cons:** Complex quoting, still potentially vulnerable to edge cases
**Effort:** Small
**Risk:** Medium

## Recommended Action

Implement Solution 1 - pass file as sys.argv[1].

## Technical Details

**Affected files:**
- `scripts/lib/yaml.sh` - lines 18-22

**Components affected:**
- YAML loading for all loop and pipeline configs

## Acceptance Criteria

- [ ] Python fallback uses sys.argv instead of string interpolation
- [ ] All existing tests pass
- [ ] Test added with file path containing special characters

## Work Log

| Date | Action | Learnings |
|------|--------|-----------|
| 2026-01-11 | Identified during security review | Python string interpolation in shell is dangerous |
| 2026-01-11 | Fixed: Changed to sys.argv[1] | All 295 tests pass |

## Resources

- Security review agent finding V-001
- OWASP Code Injection: https://owasp.org/www-community/attacks/Code_Injection
