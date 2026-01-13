# Agent Pipelines

Run autonomous agent loops. Start one, close your laptop, check back tomorrow.

```bash
./scripts/run.sh ralph my-feature 25
```

That's it. 25 iterations of Claude implementing tasks while you sleep.

## The Problem

Long-running agents degrade. By iteration 10, context is cluttered with debugging tangents, stale information, and accumulated confusion. The agent that started sharp is now stumbling.

## The Solution

**Fresh agent per iteration.** Each iteration spawns a new Claude instance that reads a progress file—accumulated learnings, patterns discovered, work completed. Iteration 50 is as sharp as iteration 1.

**Two-agent consensus.** For judgment-based stages, one agent might think "we're done" prematurely. A second agent checks. Both must agree before stopping.

**Multi-stage pipelines.** Chain stages together. Discovery feeds triage. Triage feeds refinement. Refinement feeds implementation.

## Install

```bash
git clone https://github.com/hwells4/agent-pipelines.git
cd agent-pipelines
```

**Dependencies:** `tmux`, `jq`, [Claude Code](https://docs.anthropic.com/en/docs/claude-code), `bd` ([beads CLI](https://github.com/hwells4/beads))

## Quick Start

```bash
# Run a Ralph loop - 25 iterations implementing tasks
./scripts/run.sh ralph my-feature 25

# Check on it
tmux attach -t pipeline-my-feature

# Or check status without attaching
./scripts/run.sh status my-feature
```

## Examples

### The Bug Hunt

Find bugs with fresh eyes, triage them elegantly, refine the fix tasks, then implement:

```bash
./scripts/run.sh pipeline bug-hunt.yaml overnight
```

What happens:
1. **Discovery (8 iterations):** Fresh agents explore your codebase randomly. No agenda, just "what looks wrong here?"
2. **Triage (2 iterations):** Agents pattern-match across discoveries, create elegant fix strategies
3. **Refine (3 iterations):** Polish the tasks until two agents agree they're implementation-ready
4. **Fix (25 iterations):** Execute the fixes, one task per iteration

That's 38 iterations of autonomous work. Start it Friday evening, review Monday morning.

### The Plan Refinery

Planning tokens are cheaper than implementation tokens. Before writing any code, refine your plan until it's bulletproof:

```bash
./scripts/run.sh pipeline refine.yaml my-plan
```

What happens:
1. **Plan improvement (5 iterations):** Each agent reads your plan, finds gaps, adds detail
2. **Task refinement (5 iterations):** Break the plan into executable tasks, refine until two agents agree

The two-agent consensus prevents premature stopping. One agent thinks "this plan is good enough" but the next agent finds three missing edge cases.

### The Work Queue

Classic Ralph loop. Point it at a task queue and let it work:

```bash
# Create tasks first
bd create --title="Add user authentication" --label=pipeline/auth
bd create --title="Add password reset flow" --label=pipeline/auth
bd create --title="Add session management" --label=pipeline/auth

# Let it run
./scripts/run.sh ralph auth 25
```

Each iteration: read progress, check queue, claim task, implement, commit, close task. Repeat until empty.

## Built-in Stages

| Stage | Terminates | Purpose |
|-------|------------|---------|
| `ralph` | Fixed N | The original—implement tasks from queue |
| `improve-plan` | 2 agents agree | Refine a plan document |
| `refine-tasks` | 2 agents agree | Split/merge/improve tasks |
| `elegance` | 2 agents agree | Hunt unnecessary complexity |
| `bug-discovery` | Fixed N | Explore codebase with fresh eyes |
| `bug-triage` | 2 agents agree | Pattern-match bugs, design fixes |
| `idea-wizard` | Fixed N | Brainstorm improvements |
| `research-plan` | 2 agents agree | Web research to improve plans |
| `test-scanner` | 2 agents agree | Find test coverage gaps |

## Built-in Pipelines

| Pipeline | Stages |
|----------|--------|
| `refine` | improve-plan (5) → refine-tasks (5) |
| `ideate` | idea-wizard (3) |
| `bug-hunt` | bug-discovery (8) → bug-triage (2) → refine-tasks (3) → ralph (25) |

## Creating Custom Stages

```bash
mkdir scripts/stages/my-stage
```

**stage.yaml:**
```yaml
name: my-stage
description: What this stage does

termination:
  type: judgment  # or 'fixed'
  consensus: 2    # for judgment: consecutive stops needed
  iterations: 5   # for fixed: max iterations
```

**prompt.md:**
```markdown
Read context from: ${CTX}
Progress file: ${PROGRESS}

[Your instructions here]

Write decision to: ${STATUS}
```

The agent reads `${CTX}` for session metadata, accumulates learnings in `${PROGRESS}`, and writes its continue/stop decision to `${STATUS}`.

## Session Management

```bash
# List running sessions
./scripts/run.sh

# Check specific session
./scripts/run.sh status my-feature

# Resume a crashed session
./scripts/run.sh ralph my-feature 25 --resume

# Force start (override lock)
./scripts/run.sh ralph my-feature 25 --force

# Attach to watch live
tmux attach -t pipeline-my-feature
```

## Philosophy

1. **Fresh > stale.** A new agent with curated context beats an old agent with accumulated cruft.

2. **Consensus > confidence.** One agent's "done" is another agent's "wait, what about...?"

3. **Planning > implementing.** An iteration of planning costs less and prevents more waste than an iteration of implementing the wrong thing.

4. **Set and forget.** If it needs babysitting, the automation isn't done yet.

---

**Full reference:** [CLAUDE.md](CLAUDE.md) for architecture, configuration, template variables, testing

**Stage/pipeline schema:** [scripts/pipelines/SCHEMA.md](scripts/pipelines/SCHEMA.md)

## License

MIT
