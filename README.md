# Loop Agents

A Claude Code plugin for autonomous multi-task execution through iterative loops.

## The Problem

Long-running AI agent sessions suffer from **context degradation**—as context windows fill up, the agent loses access to earlier information, makes inconsistent decisions, and produces lower-quality work. Manual checkpointing is tedious and error-prone.

## The Solution

Loop Agents solves this by spawning **fresh Claude instances for each task** while preserving accumulated knowledge in progress files. Each iteration starts clean, reads what came before, does focused work, and hands off to the next iteration.

This is an evolution of the [Ralph Wiggum loop](https://ghuntley.com/ralph/) pattern, enhanced with:

- **Claude Code as orchestrator** - Describe your work and Claude handles planning, task breakdown, and loop management
- **Background execution** - Loops run in tmux sessions, independent of your active Claude session
- **Intelligent stopping** - Loops stop when work is done, not after arbitrary iteration counts
- **Multi-loop support** - Run several independent loops simultaneously without conflicts
- **Desktop notifications** - Get alerted when loops complete (macOS/Linux)

## Installation

```bash
# Add the marketplace
claude plugin marketplace add https://github.com/hwells4/loop-agents

# Install the plugin
claude plugin install loop-agents@dodo-digital
```

## Dependencies

The plugin checks for these on startup:

| Dependency | Purpose | Install |
|------------|---------|---------|
| [tmux](https://github.com/tmux/tmux) | Background execution | `brew install tmux` or `apt install tmux` |
| [beads](https://github.com/steveyegge/beads) | Task management CLI | `brew install steveyegge/tap/bd` |
| [jq](https://github.com/jqlang/jq) | JSON state management | `brew install jq` or `apt install jq` |

## Commands

### Primary Commands

```bash
/loop              # Orchestration hub: plan, status, attach, kill
/work              # Run the work loop: implement tasks from beads
/refine            # Run refinement pipelines: improve plans and beads
/ideate            # Generate improvement ideas (one-shot)
```

### Loop Management

```bash
/loop status       # Check all running loops
/loop attach NAME  # Watch a loop live (Ctrl+b, d to detach)
/loop kill NAME    # Stop a session
/loop plan         # Plan a new feature (PRD → beads)
```

### Supporting Skills

```bash
/loop-agents:create-prd     # Generate product requirements document
/loop-agents:create-tasks   # Break PRD into executable beads
/loop-agents:build-loop     # Scaffold a new custom loop type
```

Or just talk to Claude naturally:

```
"I want to add user authentication to this app"
"Check on my running loops"
"Attach to the auth loop"
```

## How It Works

Run `/loop` and tell Claude what you're working on:

1. **Planning phase**: Claude gathers context through adaptive questioning, generates a PRD, and breaks it into discrete tasks (beads)
2. **Loop launch**: Claude spawns a tmux session running the loop engine
3. **Iteration cycle**: Each iteration, a fresh Claude instance reads the progress file, picks a task, implements it, commits, and updates progress
4. **Completion**: When work is done (all tasks complete, or quality has plateaued), you get a desktop notification

```
You describe work → Claude plans → tmux loop spawns → Fresh Claude per task → Desktop notification
```

The loop runs **independently** of your Claude Code session. You can:
- Continue working on other things while loops run
- Attach to watch live progress (`/loop attach`)
- Spin up multiple loops for parallel work
- Recover if Claude Code crashes—loops keep running in tmux

## Loop Types

The plugin includes four loop types, each designed for a different phase of work:

| Loop | Purpose | Stops When |
|------|---------|------------|
| **work** | Implement tasks from beads | All beads are complete |
| **improve-plan** | Iteratively refine planning docs | Two agents agree quality has plateaued |
| **refine-beads** | Improve task definitions and dependencies | Two agents agree beads are implementable |
| **idea-wizard** | Brainstorm improvements | Fixed iteration count |

### Work Loop

The primary loop for implementation. Each iteration:

1. Reads progress file for accumulated context
2. Lists available beads: `bd ready --label=loop/{session}`
3. Picks the next logical task (considering dependencies)
4. Claims it: `bd update {id} --status=in_progress`
5. Implements, tests, commits
6. Closes: `bd close {id}`
7. Appends learnings to progress file

### Refinement Loops

Use `/refine` to polish plans and tasks before implementation:

```bash
/refine quick    # 3+3 iterations (fast validation)
/refine full     # 5+5 iterations (standard, default)
/refine deep     # 8+8 iterations (thorough)
/refine plan     # Only improve the plan
/refine beads    # Only improve the beads
```

Each iteration reviews the work critically, makes improvements, and outputs a plateau assessment.

### Idea Wizard

Use `/ideate` to generate improvement ideas. The agent:

1. Analyzes your codebase and existing plans
2. Brainstorms 20-30 ideas across six dimensions (UX, performance, reliability, simplicity, features, DX)
3. Evaluates each: Impact (1-5), Effort (1-5), Risk (1-5)
4. Winnows to top 5 and saves to `docs/ideas.md`

## Intelligent Stopping

Traditional loops run for a fixed number of iterations. Loop Agents uses **intelligent completion strategies** that stop when work is actually done.

### Completion Strategies

| Strategy | How It Works | Used By |
|----------|--------------|---------|
| **beads-empty** | Stops when no beads remain | work |
| **plateau** | Stops when two agents agree quality has plateaued | improve-plan, refine-beads |
| **fixed-n** | Stops after N iterations | idea-wizard |
| **all-items** | Stops after iterating through all items | (custom loops) |

### Two-Agent Confirmation

The plateau strategy prevents single-agent blind spots:

1. Each agent outputs a judgment: `PLATEAU: true/false` with reasoning
2. The loop **only stops** when two consecutive agents both say `PLATEAU: true`
3. If the second agent finds real issues, the counter resets

This ensures no single agent can prematurely stop a loop. Both must independently confirm the work is done.

```
Agent 1: "PLATEAU: true - plan covers all requirements"
Agent 2: "PLATEAU: false - missing error handling section"  ← counter resets
Agent 3: "PLATEAU: true - added error handling, plan complete"
Agent 4: "PLATEAU: true - confirmed, nothing to add"  ← loop stops
```

### Pre-Iteration Checks

The work loop uses `check_before: true` to verify beads exist **before** starting an iteration. This prevents wasted work when all tasks are already complete.

## Pipelines

Chain multiple loops in sequence with pipelines:

```yaml
# pipelines/full-refine.yaml
name: full-refine
description: Complete planning refinement

steps:
  - loop: improve-plan
    max: 5

  - loop: refine-beads
    max: 5
```

Available pipelines:
- `quick-refine` - 3+3 iterations
- `full-refine` - 5+5 iterations
- `deep-refine` - 8+8 iterations

## Architecture

```
scripts/
├── loop-engine/
│   ├── engine.sh          # Core loop runner
│   ├── run.sh             # Convenience wrapper
│   ├── pipeline.sh        # Multi-loop sequencing
│   ├── config.sh          # YAML configuration loader
│   ├── lib/
│   │   ├── state.sh       # JSON state management
│   │   ├── progress.sh    # Progress file handling
│   │   ├── notify.sh      # Desktop notifications
│   │   └── parse.sh       # Output parsing
│   └── completions/       # Stopping strategies
│       ├── beads-empty.sh
│       ├── plateau.sh
│       ├── fixed-n.sh
│       └── all-items.sh
│
├── loops/                 # Loop type definitions
│   ├── work/
│   │   ├── loop.yaml      # Configuration
│   │   └── prompt.md      # Agent instructions
│   ├── improve-plan/
│   ├── refine-beads/
│   └── idea-wizard/
│
└── pipelines/             # Pipeline definitions
    ├── quick-refine.yaml
    ├── full-refine.yaml
    └── deep-refine.yaml
```

### Loop Configuration

Each loop type is defined by a `loop.yaml`:

```yaml
name: work
description: Implement features from beads until done
completion: beads-empty       # Stopping strategy
check_before: true            # Check before iteration starts
delay: 3                      # Seconds between iterations
```

For plateau-based loops:

```yaml
name: improve-plan
completion: plateau
min_iterations: 2             # Don't check plateau before this
output_parse: plateau:PLATEAU reasoning:REASONING
```

## State Management

The plugin creates files in your project (not the plugin directory):

```
your-project/
├── docs/
│   └── plans/                        # PRDs
│       └── 2025-01-09-auth-prd.md
├── .claude/
│   ├── loop-progress/
│   │   └── progress-auth.txt         # Accumulated context
│   ├── loop-state-auth.json          # Iteration history
│   └── loop-completions.json         # Completion log
└── .beads/                           # Task database
```

### Progress Files

Each iteration appends to the progress file:

```
# Progress: auth

Verify: npm test && npm run build

## Codebase Patterns
(Patterns discovered during implementation)

---

## 2025-01-09 - auth-123
- Implemented JWT validation middleware
- Files: auth/middleware.js, auth/utils.js
- Learning: Token expiry needs graceful handling
---
```

Fresh agents read this file to maintain context without degradation.

### State Files

JSON files track iteration history for completion checks:

```json
{
  "session": "auth",
  "loop_type": "work",
  "started_at": "2025-01-09T10:00:00Z",
  "status": "running",
  "iteration": 5,
  "history": [
    {"iteration": 1, "timestamp": "...", "plateau": false},
    {"iteration": 2, "timestamp": "...", "plateau": true}
  ]
}
```

## Multi-Session Support

Run multiple loops simultaneously—each has isolated:
- Beads (via `loop/{session}` label)
- Progress file
- State file
- tmux session

```bash
# These run independently
loop-auth      → beads tagged loop/auth
loop-dashboard → beads tagged loop/dashboard
```

## Notifications

When a loop completes or hits max iterations:
- **macOS**: Native notification center (via `osascript`)
- **Linux**: `notify-send` (requires `libnotify`)

All completions are logged to `.claude/loop-completions.json` for retrieval.

## Environment Variables

Loops export these for use by hooks and prompts:

| Variable | Description |
|----------|-------------|
| `CLAUDE_LOOP_AGENT` | Always `1` when inside a loop |
| `CLAUDE_LOOP_SESSION` | Current session name |
| `CLAUDE_LOOP_TYPE` | Current loop type |

## Creating Custom Loops

Use `/loop-agents:build-loop` to scaffold a new loop type:

```bash
/loop-agents:build-loop myloop
```

This creates:
- `scripts/loops/myloop/loop.yaml` - Configuration
- `scripts/loops/myloop/prompt.md` - Agent instructions

Configure the completion strategy, delay, and any output parsing in `loop.yaml`.

## Design Principles

1. **Fresh context per iteration** - Each Claude instance starts with a clean context window, preventing degradation
2. **Accumulated knowledge via files** - Progress files preserve learnings across iterations without consuming context
3. **Agent judgment over thresholds** - Agents decide when work is done, not arbitrary iteration counts
4. **Two-agent confirmation** - No single agent can stop a refinement loop—both must agree
5. **Background independence** - Loops survive Claude Code crashes and don't block your terminal
6. **Files in your project** - All state lives in your project directory, not the plugin

## Limitations

- **Local execution**: tmux sessions are local—if your machine sleeps, loops pause. Use a keep-awake utility for async work.
- **No remote execution**: Loops run on your machine, not in the cloud.

## License

MIT
