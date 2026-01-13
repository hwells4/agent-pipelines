# Agent Pipelines

A composable engine for [Ralph loops](https://ghuntley.com/ralph/). 

## Install

```bash
claude plugin marketplace add https://github.com/hwells4/agent-pipelines
claude plugin install agent-pipelines@dodo-digital
```

**Dependencies:** `tmux`, `jq`, `bd` (beads CLI)

## What It Does

Agent Pipelines extend basic Ralph loops:

  - **Loop on anything.** Plan files, task queues, codebases, URL lists, CSVs. Whatever.
  - **Chain stages together.** Planning → task refinement → implementation.
  - **Stop when it makes sense.** Fixed count, two-agent consensus, or queue empty.

## Example
```
Plan (5 iterations)  →  Refine Tasks (5 iterations)  →  Implement (until done)
      ↓                        ↓                              ↓
  judgment stop            judgment stop                  queue empty
```

A single stage is a [Ralph loop](https://ghuntley.com/ralph/). Agent Pipelines extends Ralph with:

- **Multi-stage chaining:** output from one stage feeds the next
- **Three termination strategies:** fixed count, consensus judgment, or queue empty
- **Crash recovery:** resume from the last completed iteration
- **Session management:** run multiple pipelines in parallel via tmux

## Workflow

```
/sessions plan  →  /refine  →  /ralph  →  done
```

| Command | Purpose |
|---------|---------|
| `/sessions plan` | Turn feature ideas into PRD + tasks |
| `/refine` | Improve plan and tasks until two agents agree they're ready |
| `/ralph` | Implement tasks one by one until the queue is empty |
| `/pipeline` | Design and create custom stages |

Each session runs in tmux. Start one, close your laptop, check back tomorrow.

## Built-in Pipelines

| Pipeline | What it does |
|----------|--------------|
| `refine` | 5 plan iterations → 5 task iterations |
| `ideate` | 3 idea generation iterations |
| `bug-hunt` | discover (8) → triage (2) → refine (3) → fix (25) |

## Built-in Stages

| Stage | Stops when | Purpose |
|-------|------------|---------|
| `ralph` | N iterations | The original Ralph loop - implement tasks |
| `improve-plan` | 2 agents agree | Refine PRD until quality plateaus |
| `refine-tasks` | 2 agents agree | Split/merge tasks until ready |
| `elegance` | 2 agents agree | Hunt unnecessary complexity |
| `bug-discovery` | N iterations | Explore codebase, find bugs |
| `bug-triage` | 2 agents agree | Triage bugs, create elegant fixes |
| `idea-wizard` | N iterations | Brainstorm and rank ideas |
| `research-plan` | 2 agents agree | Web research to improve plans |
| `test-scanner` | 2 agents agree | Find test coverage gaps |

## Philosophy

Long-running agents degrade. The longer the conversation, the worse the output. Context windows fill with debugging tangents and stale information.

Agent Pipelines fixes this by resetting context each iteration. A progress file carries forward only what matters: patterns discovered, work completed, learnings captured. Iteration 50 is as sharp as iteration 1.

For subjective quality decisions, two-agent consensus prevents premature stopping. One agent might think the plan is done; the second catches what's missing.

---

**Full reference:** [CLAUDE.md](CLAUDE.md) for architecture, configuration, template variables, testing framework

**Creating custom stages:** [scripts/pipelines/SCHEMA.md](scripts/pipelines/SCHEMA.md)

## License

MIT
