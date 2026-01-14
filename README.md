# Agent Pipelines

n8n for [Ralph loops](https://ghuntley.com/ralph/). Agent Pipelines is a Claude Code plugin with a custom engine for managing and Ralph Loops

It builds loops on top of a powerful engine, letting you 

- **Build a stage and loop on anything.** Plan files, task queues, codebases, URL lists, CSVs. Whatever.
- **Chain stages together.** Planning → task refinement → implementation.
- **Mix providers across stages.** Use Claude for planning and Codex for implementation in the same workflow.
- **Run providers in parallel.** Spin up Claude and Codex on the same stage, have each iterate separately, then synthesize the results.
- **Stop when it makes sense.** Fixed count, two-agent consensus, or queue empty.

## Install

```bash
claude plugin marketplace add https://github.com/hwells4/agent-pipelines
claude plugin install agent-pipelines@dodo-digital
```

**Dependencies:** `tmux`, `jq`, `bd` ([beads CLI](https://github.com/hwells4/beads))

## Example

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│ Stage 1         │     │ Stage 2         │     │ Stage 3         │
│ ─────────────── │     │ ─────────────── │     │ ─────────────── │
│ Plan            │ ──▶ │ Refine Tasks    │ ──▶ │ Implement       │
│ 5 iterations    │     │ 5 iterations    │     │ until empty     │
│ judgment stop   │     │ judgment stop   │     │ queue stop      │
└─────────────────┘     └─────────────────┘     └─────────────────┘
```

Each iteration spawns a fresh agent that reads a progress file containing accumulated learnings, patterns discovered, and work completed.

## How Stages Work

A stage has three parts: a prompt template, a provider, and a termination strategy.

**Prompt templates** are standardized prompts that receive context about the current session: what iteration you're on, where to read inputs, where to write outputs. You can inject additional context about the specific task, which makes stages reusable across different projects.

**Providers** are the AI agents that execute each iteration. Claude Code is the default, but you can also spin up Codex agents. The orchestrator is always Claude Code, but the workers can be either.

**Termination strategies** determine when a stage stops:

| Strategy | How it stops | Use it for |
|----------|--------------|------------|
| **Fixed** | After exactly N iterations | Traditional Ralph loops |
| **Judgment** | When two agents independently agree they've plateaued | Planning, exploration, subjective quality |
| **Queue** | When an external task queue is empty | Working through beads |

Judgment requires two-agent consensus because one agent might think the plan is done while the second catches what's missing.

## Commands

| Command | Purpose |
|---------|---------|
| `/sessions` | Start, list, monitor, and kill running pipelines |
| `/sessions plan` | Turn a feature idea into a PRD and break it into tasks |
| `/refine` | Run plan and task refinement until two agents agree it's ready |
| `/ralph` | Work through a task queue until it's empty |
| `/pipeline` | Create custom stages and pipelines |

## Built-in Pipelines

| Pipeline | What it does |
|----------|--------------|
| `refine` | 5 plan iterations → 5 task iterations |
| `ideate` | 3 brainstorming iterations |
| `bug-hunt` | Discovery (8) → Triage (2) → Refine (3) → Fix (25) |

## Built-in Stages

| Stage | Stops when | Purpose |
|-------|------------|---------|
| `ralph` | Fixed N | Work through tasks in a beads queue |
| `improve-plan` | 2 agents agree | Read a plan, find gaps, add detail |
| `refine-tasks` | 2 agents agree | Split large tasks, merge small ones, clarify scope |
| `elegance` | 2 agents agree | Look for unnecessary complexity and remove it |
| `bug-discovery` | Fixed N | Explore the codebase with no agenda, just looking for what's wrong |
| `bug-triage` | 2 agents agree | Group related bugs, find patterns, design fixes |
| `idea-wizard` | Fixed N | Brainstorm improvements and rank them |
| `research-plan` | 2 agents agree | Search the web to fill gaps in a plan |
| `test-scanner` | 2 agents agree | Find untested code paths and edge cases |

## Parallel Execution

Sometimes you want multiple perspectives on the same problem. Parallel blocks let you spin up different providers (Codex with extra-high reasoning and Claude Opus, for example), have each iterate on a plan separately, then bring the results together in a final synthesis stage.

Each provider runs in isolation with its own progress file, so they don't influence each other mid-loop. The orchestrator waits for all providers to finish before moving to the next stage.

## Philosophy

A common failure mode: you write a plan, run a Ralph loop, and the agent executes incorrectly because the plan wasn't good enough. You can solve this by running a Ralph loop on the plan itself, allowing it to iterate until two agents agree the plan is fully fleshed out.

The same pattern applies elsewhere. Bug reviews benefit from multiple passes where agents look with fresh eyes each time. Web research loops can ensure citations are correct and you're pulling in the right context from varied sources. There are many use cases beyond just completing coding work.

But these workflows need more flexibility than a basic Ralph loop provides. The engine gives you that flexibility. Different termination strategies, the ability to chain stages together, parallel execution across providers. You can build truly autonomous workflows and iterate on them.

---

**Full reference:** [CLAUDE.md](CLAUDE.md)

## License

MIT
