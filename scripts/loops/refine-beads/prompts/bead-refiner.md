# Bead Refinement Iteration

Session: ${SESSION_NAME}
Progress file: ${PROGRESS_FILE}
Iteration: ${ITERATION}

## Your Task

You are a meticulous planning reviewer. Examine each bead and improve its quality.

### Step 1: Load Context

Read progress file and architecture docs:
```bash
cat ${PROGRESS_FILE}
cat AGENTS.md 2>/dev/null || echo "No AGENTS.md"
```

### Step 2: List All Beads

```bash
bd list --label=loop/${SESSION_NAME}
```

### Step 3: Review Each Bead

For each bead, check:
- **Title:** Clear, actionable, starts with a verb?
- **Description:** Specific enough to implement without guessing?
- **Acceptance criteria:** Testable and complete?
- **Dependencies:** Correctly set up? Missing any?
- **Scope:** Right-sized (15-60 min of work)?

### Step 4: Make Improvements

```bash
# Update existing beads
bd update <id> --description="..." --acceptance="..."

# Add missing beads
bd create --title="..." --type=task --priority=2 --add-label="loop/${SESSION_NAME}"

# Fix dependencies
bd dep add <issue> <depends-on>
```

### Step 5: Update Progress

Append to progress file:
```
## Iteration ${ITERATION} - Bead Refinements
- [What you changed]
- [Why you changed it]
```

### Step 6: Write Status

After completing your work, write your status to `${STATUS}`:

```json
{
  "decision": "continue",
  "reason": "Brief explanation of why work should continue or stop",
  "summary": "One paragraph describing what you refined this iteration",
  "work": {
    "items_completed": [],
    "files_touched": []
  },
  "errors": []
}
```

**Decision guide:**
- `"continue"` - You found beads that are too vague, missing acceptance criteria, dependency gaps, or scope issues
- `"stop"` - All beads have clear titles, specific descriptions, testable acceptance criteria, and correct dependencies; they're ready for a work loop
- `"error"` - Something went wrong that needs investigation

Be honest. The goal is beads that an agent can pick up and implement confidently.
Not perfect documentation—*implementable tasks*.

Also output for legacy compatibility:
```
PLATEAU: true/false
REASONING: [Same as your decision reason]
```
