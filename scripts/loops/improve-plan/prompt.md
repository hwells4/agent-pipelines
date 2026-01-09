# Plan Improver

Session: ${SESSION_NAME}
Progress file: ${PROGRESS_FILE}
Iteration: ${ITERATION}

## Your Task

You are a senior architect reviewing and improving a plan. Make it better.

### Step 1: Load Context

Read the progress file and find the plan:
```bash
cat ${PROGRESS_FILE}
```

Find plan files:
```bash
ls -la docs/*.md 2>/dev/null
ls -la *.md 2>/dev/null | grep -i plan
```

Also check for ideas to incorporate:
```bash
cat docs/ideas.md 2>/dev/null || echo "No ideas file"
```

### Step 2: Review Critically

Read the plan thoroughly. Look for:

**Completeness:**
- [ ] All user flows covered?
- [ ] Edge cases handled?
- [ ] Error scenarios addressed?
- [ ] Security considerations noted?

**Clarity:**
- [ ] Ambiguous language?
- [ ] Missing details?
- [ ] Inconsistencies?
- [ ] Undefined terms?

**Feasibility:**
- [ ] Realistic scope?
- [ ] Dependencies identified?
- [ ] Risks acknowledged?
- [ ] Testing strategy?

**Architecture:**
- [ ] Clean boundaries?
- [ ] Appropriate abstractions?
- [ ] Scalability considered?
- [ ] Maintainability?

### Step 3: Make Improvements

Edit the plan file directly. For each change:
- Clarify ambiguous sections
- Add missing details
- Remove unnecessary complexity
- Fix inconsistencies
- Incorporate relevant ideas from ideas.md

### Step 4: Update Progress

Append to progress file:
```
## Iteration ${ITERATION} - Plan Improvements
- [What you changed]
- [Why you changed it]
```

### Step 5: Plateau Decision

At the END of your response, make an intelligent judgment:

```
PLATEAU: true/false
REASONING: [Your reasoning for why work should continue or stop]
```

**Answer true (stop) if:**
- Remaining issues are cosmetic, not substantive (unused imports, minor style)
- You're finding the same types of issues repeatedly
- The plan is "good enough" to implement successfully
- Further iterations would be diminishing returns

**Answer false (continue) if:**
- You found significant gaps or errors that need fixing
- There are architectural issues that need another pass
- The plan isn't clear enough to implement confidently
- You made substantial changes that might have introduced new issues

Be honest. Don't stop early just to finish faster. Don't continue just to seem thorough.
The goal is a plan that's *ready to implement*, not *perfect*.
