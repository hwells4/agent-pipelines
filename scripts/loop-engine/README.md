# Loop Engine

Universal loop runner for autonomous agent tasks. Create any iterative workflow by defining a loop config and prompt.

## Quick Start

```bash
# Run a loop
./scripts/loop-engine/run.sh work auth 25       # Work loop, "auth" session, 25 max iterations
./scripts/loop-engine/run.sh improve-plan my-session 5  # Plan refinement until plateau
./scripts/loop-engine/run.sh refine-beads my-session 5  # Bead refinement until plateau

# See available loops
./scripts/loop-engine/run.sh
```

## Architecture

```
scripts/
├── loop-engine/
│   ├── engine.sh          # Core loop runner
│   ├── run.sh             # Convenience wrapper
│   ├── config.sh          # Config loader
│   ├── lib/
│   │   ├── state.sh       # State file management
│   │   ├── notify.sh      # Desktop notifications
│   │   ├── progress.sh    # Progress file handling
│   │   └── parse.sh       # Output parsing
│   └── completions/
│       ├── beads-empty.sh # Stop when beads done
│       ├── plateau.sh     # Stop on 2 agents agreeing
│       ├── fixed-n.sh     # Stop after N iterations
│       └── all-items.sh   # Iterate through item list
│
└── loops/                  # Loop type definitions
    ├── work/
    │   ├── loop.yaml      # Config
    │   └── prompt.md      # Agent prompt
    ├── improve-plan/
    │   ├── loop.yaml
    │   └── prompt.md
    ├── refine-beads/
    │   ├── loop.yaml
    │   └── prompt.md
    └── idea-wizard/
        ├── loop.yaml
        └── prompt.md
```

## Creating a New Loop Type

Use the skill:
```
/loop-agents:create-loop scraper
```

Or manually:

1. Create `scripts/loops/<name>/loop.yaml`:
```yaml
name: myloop
description: What this loop does
completion: plateau          # or beads-empty, fixed-n, all-items
delay: 3                     # seconds between iterations
output_parse: changes:CHANGES summary:SUMMARY  # optional
```

2. Create `scripts/loops/<name>/prompt.md`:
```markdown
# My Agent

Session: ${SESSION_NAME}
Iteration: ${ITERATION}

## Task
...

## Output
At END, output:
CHANGES: {number}
SUMMARY: {text}
```

3. Run it:
```bash
./scripts/loop-engine/run.sh myloop session-name 10
```

## Completion Strategies

| Strategy | Use Case | Stops When |
|----------|----------|------------|
| `beads-empty` | Implementation | No beads remain for session |
| `plateau` | Refinement | 2 consecutive agents agree it's done |
| `fixed-n` | Batch processing | N iterations complete |
| `all-items` | Multi-perspective | All items processed |

## Configuration Options

### loop.yaml

```yaml
name: myloop                 # Loop identifier
description: What it does    # Shown in run.sh help
completion: plateau          # Completion strategy

# Strategy-specific
plateau_threshold: 2         # Consecutive low rounds to stop
min_iterations: 3            # Don't check plateau before this
low_change_max: 1            # Max changes to count as "low"
items: a b c                 # For all-items strategy
check_before: true           # Check completion before iteration

# General
delay: 3                     # Seconds between iterations
output_parse: key1:KEY1 key2:KEY2  # Parse output into state
prompt: default              # Prompt file name (default: prompt)
```

## State Files

Each session creates:
- `.claude/loop-state-{session}.json` - Iteration history
- `.claude/loop-progress/progress-{session}.txt` - Accumulated context
- `.claude/loop-completions.json` - Completion log

## Environment Variables

Set by engine for hooks/prompts:
- `CLAUDE_LOOP_AGENT=1`
- `CLAUDE_LOOP_SESSION={session}`
- `CLAUDE_LOOP_TYPE={loop_type}`
