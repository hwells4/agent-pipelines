# Termination Strategy Guide

How to choose the right termination strategy for a pipeline stage.

## The Three Strategies

| Strategy | How It Works | Best For |
|----------|--------------|----------|
| `queue` | Engine checks external queue (`bd ready`) | Task-based work |
| `judgment` | Agents vote `stop` until consensus | Quality refinement |
| `fixed` | Runs exactly N iterations | Ideation, exploration |

## Queue Termination

**Use when:** Work is driven by an external queue of items.

**How it works:**
1. Before each iteration, engine runs `bd ready --label=pipeline/{session}`
2. If queue is empty, pipeline stops
3. If items remain, another iteration runs

**Agent responsibility:** Complete work items and close them (`bd close`).

**Configuration:**
```yaml
termination:
  type: queue
```

**Example stages:** `ralph`

**Key insight:** The agent doesn't decide when to stop. The queue does.

## Judgment Termination

**Use when:** Iterating until quality plateaus.

**How it works:**
1. Agent writes `decision: stop` or `decision: continue` to status.json
2. Engine checks for N consecutive `stop` decisions
3. When consensus reached, pipeline stops

**Agent responsibility:** Genuinely assess quality. Write `stop` when satisfied.

**Configuration:**
```yaml
termination:
  type: judgment
  min_iterations: 2    # Don't check until after this many
  consensus: 2         # Need this many consecutive stops
```

**Example stages:** `improve-plan`, `refine-tasks`, `elegance`

**Key insight:** Two-agent consensus prevents single-agent blind spots. Fresh Claude each iteration means independent judgment.

### Why Two-Agent Consensus?

A single agent might:
- Get stuck in a local optimum
- Miss obvious improvements
- Stop prematurely due to fatigue

By requiring two consecutive agents to agree work is done:
- Second agent gets fresh perspective
- Confirms first agent's assessment
- Reduces false positives

## Fixed Termination

**Use when:** You want exactly N iterations, regardless of output.

**How it works:**
1. Runs N iterations
2. Stops after N, no matter what agent writes

**Agent responsibility:** Do the work. Decision field is ignored.

**Configuration:**
```yaml
termination:
  type: fixed
  max_iterations: 5
```

**Example stages:** `idea-wizard`

**Key insight:** Useful for creative/exploratory work where "done" isn't meaningful.

## Decision Guide

Ask these questions to choose:

### 1. Is there an external queue?

**Yes → `queue`**
- Examples: beads to implement, issues to fix, items to process
- Agent pulls from queue until empty

### 2. Is this about improving quality until satisfied?

**Yes → `judgment`**
- Examples: refining a plan, improving code, polishing documentation
- Agent assesses quality each iteration

### 3. Do you want exactly N iterations?

**Yes → `fixed`**
- Examples: generate N ideas, explore for N rounds
- Quantity matters more than completion signal

## Configuration Examples

### Work Stage (Queue)
```yaml
name: work
description: Implement beads until none remain

termination:
  type: queue

delay: 3
model: sonnet
```

### Plan Refinement (Judgment)
```yaml
name: improve-plan
description: Refine plan until quality plateaus

termination:
  type: judgment
  min_iterations: 2
  consensus: 2

delay: 3
model: opus
```

### Ideation (Fixed)
```yaml
name: idea-wizard
description: Generate ideas for exactly N iterations

termination:
  type: fixed

delay: 3
model: opus
```

## Setting Iteration Bounds

### min_iterations (judgment only)

How many iterations before checking for stops.

- **Low (1-2):** Quick tasks, already near optimal
- **Medium (3-5):** Complex refinement, needs exploration time
- **High (5+):** Deep work, extensive territory to cover

### consensus (judgment only)

How many consecutive stops needed.

- **2 (default):** Standard safety, two-agent confirmation
- **3+:** High-stakes work, want extra confidence

### max_iterations (all types)

Hard cap to prevent runaway.

- **5-10:** Refinement stages (plateau expected early)
- **25-50:** Work stages (depends on queue size)
- **100+:** Only for very large queues

## Common Mistakes

### Using Queue When Judgment Is Better

**Wrong:** "Refine until the beads look good" with queue termination
**Why:** No external queue exists. Agent has no way to signal done.
**Right:** Use judgment termination

### Using Fixed When Judgment Is Better

**Wrong:** "Improve this plan" with fixed N=10
**Why:** Might plateau at 3, wastes 7 iterations. Or might need 15.
**Right:** Use judgment termination

### Setting Consensus Too High

**Wrong:** `consensus: 5` for most tasks
**Why:** Burns context with redundant confirmations
**Right:** `consensus: 2` is usually sufficient

### Forgetting min_iterations

**Wrong:** Judgment with `min_iterations: 0`
**Why:** First agent might prematurely stop before exploring
**Right:** `min_iterations: 2` gives time to explore
