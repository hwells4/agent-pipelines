# Loop Prompt Patterns

Loop prompts are fundamentally different from one-shot prompts. Each iteration spawns a **fresh agent** that reads accumulated context. The prompt must enable iterative progress, not one-shot completion.

## The Core Paradigm Shift

**One-shot thinking (WRONG for loops):**
```
Do steps 1, 2, 3 completely.
Checklist:
- [ ] Finish A
- [ ] Finish B
- [ ] Finish C
Output: completed deliverable
```

**Loop thinking (CORRECT):**
```
You're one agent in a sequence. Previous agents made progress.
Read what they learned. Continue from where they stopped.
Make meaningful progress. Don't try to finish everything.
When you've done good work, hand off to the next agent.
```

## Designing Loop Prompts: Questions Not Categories

Instead of forcing loops into fixed categories, ask these questions. The answers reveal what kind of prompt to write.

### Question 1: Autonomy Level

**How much latitude does the agent have?**

| Level | Agent Decides... | Prompt Style |
|-------|------------------|--------------|
| Full | Everything—what to look at, what matters, when done | "Follow your curiosity. Trust your instincts." |
| High | Approach and depth, but goal is clear | "Achieve X however you see fit." |
| Medium | What to work on, but quality bar is set | "Improve toward quality bar. You pick what." |
| Low | Only execution details, tasks are defined | "Complete task X. Then hand off." |

### Question 2: Starting Point

**What does the agent have to work with?**

| Starting Point | Examples | Prompt Framing |
|----------------|----------|----------------|
| Nothing | Bug discovery, fresh research | "Explore with fresh eyes. You don't know what you'll find." |
| Seeds | Web research expansion, initial sources | "Build on what exists. Expand and validate." |
| Existing work | Plan refinement, code review | "Continue from where the last agent stopped." |
| Defined tasks | Work queue, beads | "Pick the next task. Execute it fully." |

### Question 3: Progress Framing

**What counts as "good work this iteration"?**

| Progress Type | What Agent Reports | Handoff Style |
|---------------|-------------------|---------------|
| Exploration | "What I found, what seems interesting" | "Here's what to investigate next" |
| Validation | "What I verified, what needs checking" | "These sources are solid, these need work" |
| Improvement | "What got better, what's still weak" | "Focus on X next iteration" |
| Completion | "What's done, what's left" | "Next agent should tackle Y" |

### Question 4: Termination Signal

**When should the loop stop?**

| Signal | Mechanism | Prompt Guidance |
|--------|-----------|-----------------|
| Time-boxed | Fixed iterations | Don't mention stopping—just do good work |
| Quality plateau | Judgment (consensus) | "Stop when further changes would be marginal" |
| External signal | Queue empty, file exists | "Stop when queue is empty" |

### Question 5: Quality Bar

**What does "good enough" look like?**

This must be **concrete and testable**. Examples:

| Domain | Weak Quality Bar | Strong Quality Bar |
|--------|------------------|-------------------|
| Code review | "Find bugs" | "Find bugs that would cost >1 hour to fix in production" |
| Plan refinement | "Improve the plan" | "Tasks implementable without asking clarifying questions" |
| Research | "Find sources" | "3+ independent sources per claim, all verified accessible" |
| Ideation | "Generate ideas" | "Ideas implementable in <1 week with clear ROI" |

## Example Loop Patterns

These are **common patterns, not an exhaustive taxonomy**. Your loop might be a hybrid or something entirely new.

### Discovery Pattern
- Autonomy: Full
- Starting point: Nothing
- Progress: Exploration
- Termination: Fixed

*Example: Bug hunting, security review, code archaeology*

### Validation/Expansion Pattern
- Autonomy: High
- Starting point: Seeds
- Progress: Validation + Improvement
- Termination: Judgment (comprehensive + verified)

*Example: Web research, source verification, fact-checking*

### Refinement Pattern
- Autonomy: Medium
- Starting point: Existing work
- Progress: Improvement
- Termination: Judgment (quality plateau)

*Example: Plan improvement, documentation polish, code elegance*

### Execution Pattern
- Autonomy: Low
- Starting point: Defined tasks
- Progress: Completion
- Termination: Queue empty

*Example: Work loops, task queues, implementation*

### Ideation Pattern
- Autonomy: Full
- Starting point: Domain/constraints only
- Progress: Exploration (quantity)
- Termination: Fixed

*Example: Brainstorming, alternative generation, creative exploration*

## Prompt Structure for Loops

### 1. Context Loading (Keep Brief)

```markdown
## Context

Read context: `${CTX}`
Progress file: `${PROGRESS}`
Iteration: ${ITERATION}

Load what previous agents learned:
\`\`\`bash
cat ${PROGRESS}
\`\`\`
```

This section should be **mechanical and short**. Don't over-explain.

### 2. The Core Work (Grant Autonomy)

This is where loop prompts differ most from one-shot prompts.

**BAD (one-shot thinking):**
```markdown
## Your Task

1. Read all 35 issues
2. Analyze each against the PRD
3. Update descriptions with missing details
4. Verify dependencies
5. Check for gaps
```

**GOOD (loop thinking):**
```markdown
## This Iteration

You're continuing work that previous agents started.

The goal: [clear quality bar - e.g., "issues ready for implementation"]

How you get there is up to you. Trust your judgment about:
- What needs attention most
- How deep to go
- When you've done enough for this iteration

Don't try to finish everything. Make meaningful progress.
```

### 3. Autonomy Grant (Essential for Loops)

Every loop prompt MUST include something like:

```markdown
This is NOT a checklist. You have latitude to:
- Follow your curiosity
- Go deep on what seems important
- Skip what seems fine
- Change approach if something isn't working

Trust your intelligence. You're not executing steps—you're solving a problem.
```

### 4. Iteration Handoff (Not "Done")

Loop prompts should frame completion as **handoff**, not **done**:

```markdown
## Wrapping Up This Iteration

When you've made good progress:

1. Update the progress file with what you learned
2. Note what the next agent should focus on
3. Write your status

You're passing the baton, not crossing the finish line.
```

### 5. Status Writing (Judgment Loops)

For judgment-terminated loops, the status decision is crucial:

```markdown
### Write Status

Write to `${STATUS}`:

\`\`\`json
{
  "decision": "continue",  // or "stop"
  "reason": "Why you chose this",
  "summary": "What you did this iteration",
  "next_focus": "What the next agent should prioritize"
}
\`\`\`

**Decision guide:**
- `"continue"` - There's more meaningful work to do
- `"stop"` - Quality bar met, further changes would be marginal

Don't stop just because you did a lot. Stop when the work is genuinely good.
```

## Anti-Patterns to Avoid

### 1. The Big Checklist
```markdown
## Your Task
- [ ] Do step 1
- [ ] Do step 2
- [ ] Do step 3
- [ ] Do step 4
```
**Why it fails:** Agent tries to complete all checkboxes in one iteration.

### 2. Completion Framing
```markdown
Complete the following tasks...
When you're finished...
```
**Why it fails:** "Finished" implies one-shot. Use "this iteration" instead.

### 3. Specific Numbers Without Rationale
```markdown
Analyze exactly 4 issues per iteration.
```
**Why it fails:** Arbitrary constraint kills judgment. Better: "Analyze what needs attention."

### 4. No Plateau Signal
```markdown
Keep improving until done.
```
**Why it fails:** When is "done"? Agent either stops too early or makes busywork changes.

### 5. Ignoring Previous Work
```markdown
Start fresh and...
```
**Why it fails:** Loop agents MUST build on previous iterations. Always read progress first.

## Stage Generalization

Good loop stages are **reusable with different inputs**.

**Overly specific (bad):**
```yaml
name: linear-issue-refiner
description: Refines Linear issues against a PRD
```

**Generalized (good):**
```yaml
name: issue-refiner
description: Refines project issues toward implementation-ready quality
# Works with Linear, GitHub Issues, Jira, etc.
# Context injection tells it what system and what quality bar
```

The stage prompt stays general. The `${CONTEXT}` injection or input files tell it:
- What issue system (Linear, GitHub, etc.)
- What PRD/spec to compare against
- What quality bar to target

## Quality Bar Examples

Good loop prompts have clear quality bars:

| Loop Type | Quality Bar |
|-----------|-------------|
| Bug discovery | "Find bugs that would cost >1 hour to fix in production" |
| Ideation | "Ideas that would take <1 week to implement with clear ROI" |
| Elegance | "Code that a new team member could understand without asking questions" |
| Planning | "Tasks that an engineer could implement without asking clarifying questions" |
| Work | "Implementation that passes tests and meets acceptance criteria" |

## Template: Planning/Refinement Loop

```markdown
# [Domain] Refinement

Read context: `${CTX}`
Progress file: `${PROGRESS}`
Iteration: ${ITERATION}

${CONTEXT}

## Goal

[Clear quality bar - e.g., "Issues ready for implementation"]

An issue is ready when:
- An engineer could start work without asking questions
- Dependencies are explicit
- Acceptance criteria are testable
- Scope is clear (2-8 hours of work)

## This Iteration

Previous agents have made progress. Read what they learned:
\`\`\`bash
cat ${PROGRESS}
\`\`\`

Continue from where they stopped. You decide:
- What needs the most attention
- How deep to go
- What can be skipped

Don't try to refine everything. Make meaningful progress on what matters.

## Your Intelligence

This is NOT a checklist task. You have full latitude to:
- Follow your intuition about what's weak
- Go deep where depth is needed
- Skim what's already solid
- Reorganize if the structure is wrong

Trust your judgment. You're smarter than a checklist.

## Handoff

When you've done good work this iteration:

1. Update progress file with what you refined and why
2. Note what the next agent should focus on
3. Write status

### Status

Write to `${STATUS}`:
\`\`\`json
{
  "decision": "continue",
  "reason": "Why continue or stop",
  "summary": "What you did",
  "next_focus": "What needs attention next"
}
\`\`\`

**Stop when:** Further refinement would be polishing, not improving.
**Continue when:** There's still meaningful quality to add.
```

## Template: Discovery/Exploration Loop

```markdown
# [Domain] Discovery

Read context: `${CTX}`
Progress file: `${PROGRESS}`
Iteration: ${ITERATION}

${CONTEXT}

## Your Mission

Explore [domain] with fresh eyes. Find what others missed.

You don't know what you'll find. That's the point.

## This Iteration

Read what previous agents discovered:
\`\`\`bash
cat ${PROGRESS}
\`\`\`

Go somewhere they didn't. Look at what they skimmed. Question what they assumed.

## Exploration

You have complete freedom to:
- Follow hunches
- Go deep on suspicious patterns
- Trace execution paths
- Question assumptions
- Explore tangents

Don't search systematically—search intelligently. Your intuition about "this feels wrong" is valuable.

## What You Find

When you find something interesting:
- Document it clearly in the progress file
- Include enough context that the next agent understands
- Note confidence level (certain, suspicious, hunch)

## Handoff

This is a fixed-iteration loop. You don't decide when to stop.

Just do good exploration work and hand off to the next agent.

### Status

Write to `${STATUS}`:
\`\`\`json
{
  "decision": "continue",
  "summary": "What you explored and found",
  "interesting_threads": ["Things worth deeper investigation"]
}
\`\`\`
```

## Template: Validation/Expansion Loop

```markdown
# [Domain] Validation & Expansion

Read context: `${CTX}`
Progress file: `${PROGRESS}`
Iteration: ${ITERATION}

${CONTEXT}

## Your Mission

You have seed material to work with. Your job is to:
1. **Validate** what exists - verify it's accurate, current, and trustworthy
2. **Expand** what's there - find related sources, fill gaps, add depth

## Quality Bar

[Concrete and testable - e.g., "3+ independent sources per major claim, all verified accessible within last 6 months"]

## This Iteration

Read what previous agents have built:
\`\`\`bash
cat ${PROGRESS}
\`\`\`

Continue their work. You might:
- Verify claims they added
- Find sources for unverified sections
- Expand areas that are thin
- Cross-reference between sources
- Flag contradictions or outdated info

Trust your judgment about what needs attention most.

## Your Intelligence

You're not just following links. Use your judgment:
- Which sources are authoritative?
- What's missing that should be there?
- What smells wrong even if it looks okay?
- Where would a skeptic poke holes?

## Documentation

As you work, update the progress file with:
- Sources verified (with confidence level)
- New sources found
- Gaps identified
- Contradictions or concerns

## Handoff

When you've done good validation/expansion work:

1. Update progress with your findings
2. Note what still needs verification
3. Write status

### Status

Write to `${STATUS}`:
\`\`\`json
{
  "decision": "continue",
  "reason": "Why continue or stop",
  "summary": "What you validated and expanded",
  "verified": ["Claims now well-sourced"],
  "needs_work": ["Areas still thin or unverified"]
}
\`\`\`

**Stop when:** All major claims are well-sourced and cross-verified.
**Continue when:** There are still gaps, unverified claims, or thin sections.
```

## Checklist for Loop Prompt Review

Before finalizing a loop prompt, verify:

- [ ] **Autonomy granted** - "Use your judgment" appears somewhere
- [ ] **Not a checklist** - Explicitly says this is not step-by-step
- [ ] **Quality bar clear** - Agent knows what "good enough" looks like
- [ ] **Iteration framing** - Uses "this iteration" not "complete/finish"
- [ ] **Builds on previous** - Reads progress file, continues work
- [ ] **Handoff not done** - Frames ending as passing baton
- [ ] **Termination guidance** - Clear when to continue vs stop (for judgment loops)
- [ ] **Generalized** - Could work with different inputs/contexts
