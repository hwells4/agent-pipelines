# Loop

Autonomous execution of multi-step plans with context management.

## Before you start

Generate your plan and tasks first:

```bash
# 1. Define what you're building
/generate-prd

# 2. Break it into executable tasks (creates beads)
/generate-stories
```

This creates beads tagged `loop/{session-name}` that the loop can execute autonomously.

> **Note:** Currently optimized for coding tasks (commits, tests, verification). Could be generalized for other work types.

## When to use

- Extending Sapling OS with new features
- Long-running batch processing (e.g., process 1000 documents)
- Any multi-step work that benefits from fresh context per task
- Plans too large to hold in a single conversation

## How it works

```
/generate-prd → /generate-stories → beads → loop.sh → Autonomous execution
```

1. **Plan**: `/generate-prd` defines what you're building
2. **Tasks**: `/generate-stories` breaks it into beads with acceptance criteria
3. **Configure**: `prompt.md` contains instructions for how the agent should work
4. **Run**: `loop.sh` picks a task, implements it, commits, repeats
5. **Learn**: `progress-{session}.txt` accumulates patterns across iterations

## Files

| File | Purpose |
|------|---------|
| `prompt.md` | Instructions for each iteration |
| `progress-{session}.txt` | Accumulated learnings for each session |

Tasks are stored in `.beads/` directory, tagged with `loop/{session-name}`.

## Usage

```bash
# Test single iteration first
./loop-once.sh my-feature

# Run autonomously (default 25 iterations)
./loop.sh 25 my-feature

# Run with custom limit
./loop.sh 50 my-feature

# Check remaining work
bd ready --tag=loop/my-feature

# Archive completed work (optional, for old prd.json files)
./loop-archive.sh "feature-name"
```

## Multi-Agent Support

Multiple loops can run simultaneously:

```bash
# Terminal 1: Auth feature
./loop.sh 50 user-auth

# Terminal 2: Dashboard feature (parallel)
./loop.sh 50 dashboard
```

Each session:
- Uses its own beads (`loop/user-auth` vs `loop/dashboard`)
- Has its own progress file
- Claims work with `bd update --status=in_progress`
- No file conflicts

## The loop

Each iteration:
1. Agent reads `progress-{session}.txt` for context
2. Lists available tasks: `bd ready --tag=loop/{session}`
3. Uses judgment to pick the most logical next task
4. Claims the task: `bd update <id> --status=in_progress`
5. Implements and verifies
6. Commits changes
7. Closes the task: `bd close <id>`
8. Updates progress file with learnings
9. Signals `<promise>COMPLETE</promise>` when `bd ready` returns empty

Fresh context each iteration prevents degradation on long runs.
