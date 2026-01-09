# Loop Scripts

Autonomous execution through the universal loop engine.

## Architecture

```
scripts/
├── loop-engine/           # Core engine (use this)
│   ├── engine.sh          # Universal loop runner
│   ├── run.sh             # Convenience wrapper
│   ├── pipeline.sh        # Multi-loop sequences
│   ├── config.sh          # Loop configuration loader
│   ├── lib/               # Shared utilities
│   │   ├── state.sh       # State file management
│   │   ├── progress.sh    # Progress file management
│   │   ├── notify.sh      # Desktop notifications
│   │   └── parse.sh       # Output parsing
│   └── completions/       # Stopping conditions
│       ├── beads-empty.sh # Stops when no beads remain
│       ├── plateau.sh     # Stops when 2 agents agree it's done
│       └── all-items.sh   # Stops when all items processed
│
├── loops/                 # Loop type definitions
│   ├── work/              # Implementation from beads
│   ├── improve-plan/      # Plan refinement
│   ├── refine-beads/      # Bead refinement
│   └── idea-wizard/       # Idea generation
│
└── pipelines/             # Multi-loop sequences
    ├── quick-refine.yaml  # 3+3 iterations
    ├── full-refine.yaml   # 5+5 iterations
    └── deep-refine.yaml   # 8+8 iterations
```

## Usage

### Running Loops

```bash
PLUGIN_DIR=".claude/loop-agents"

# Work loop - implement tasks from beads
$PLUGIN_DIR/scripts/loop-engine/run.sh work my-feature 25

# Plan refinement - improve docs/plans/
$PLUGIN_DIR/scripts/loop-engine/run.sh improve-plan my-session 5

# Bead refinement - improve bead quality
$PLUGIN_DIR/scripts/loop-engine/run.sh refine-beads my-session 5

# Idea generation - brainstorm improvements
$PLUGIN_DIR/scripts/loop-engine/run.sh idea-wizard ideas 3
```

### Running in Background (tmux)

```bash
SESSION_NAME="auth"
PLUGIN_DIR=".claude/loop-agents"

# Start work loop in background
tmux new-session -d -s "loop-$SESSION_NAME" -c "$(pwd)" \
  "$PLUGIN_DIR/scripts/loop-engine/run.sh work $SESSION_NAME 25"

# Monitor
tmux capture-pane -t "loop-$SESSION_NAME" -p | tail -20

# Attach (Ctrl+b d to detach)
tmux attach -t "loop-$SESSION_NAME"

# Kill
tmux kill-session -t "loop-$SESSION_NAME"
```

### Running Pipelines

```bash
# Refine plans then beads
$PLUGIN_DIR/scripts/loop-engine/pipeline.sh full-refine my-session

# Quick pass
$PLUGIN_DIR/scripts/loop-engine/pipeline.sh quick-refine my-session

# Thorough pass
$PLUGIN_DIR/scripts/loop-engine/pipeline.sh deep-refine my-session
```

## Loop Types

| Type | Stops When | Use Case |
|------|------------|----------|
| `work` | All beads complete | Implementing tasks |
| `improve-plan` | 2 agents agree it's ready | Plan refinement |
| `refine-beads` | 2 agents agree it's ready | Bead quality |
| `idea-wizard` | Fixed iterations | Idea generation |

## Creating New Loop Types

```bash
mkdir -p scripts/loops/my-loop
```

Create `loop.yaml`:
```yaml
name: my-loop
description: What this loop does
completion: plateau  # beads-empty, plateau, all-items
delay: 3
```

Create `prompt.md`:
```markdown
# My Loop Agent

Session: ${SESSION_NAME}
Progress: ${PROGRESS_FILE}

## Instructions
...
```

## Output Files

Progress and state files are created in YOUR project:

```
.claude/
├── loop-progress/
│   └── progress-{session}.txt   # Accumulated learnings
├── loop-state-{session}.json    # Iteration history
└── loop-completions.json        # Completion notifications
```

## Multi-Session Support

Run multiple loops simultaneously:

```bash
# Different features in parallel
tmux new-session -d -s "loop-auth" -c "$(pwd)" \
  "$PLUGIN_DIR/scripts/loop-engine/run.sh work auth 25"

tmux new-session -d -s "loop-api" -c "$(pwd)" \
  "$PLUGIN_DIR/scripts/loop-engine/run.sh work api 25"
```

Each session has:
- Separate beads (`loop/auth` vs `loop/api`)
- Separate progress file
- Separate state file
- No conflicts
