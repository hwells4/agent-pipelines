# Unified Engine

One engine for iterative AI agent workflows.

## Architecture

```
scripts/
├── engine.sh              # The engine
├── run.sh                 # Entry point
├── lib/                   # Shared utilities
│   ├── yaml.sh
│   ├── state.sh
│   ├── progress.sh
│   ├── resolve.sh
│   ├── parse.sh
│   ├── notify.sh
│   └── completions/       # Stopping conditions
├── loops/                 # Loop definitions
│   ├── work/
│   ├── improve-plan/
│   ├── refine-beads/
│   └── idea-wizard/
└── pipelines/             # Multi-stage pipelines
    └── *.yaml
```

## Concepts

**Loop**: A prompt + completion strategy, run N iterations until done.

**Pipeline**: Multiple loops chained together.

## Usage

```bash
# Run a loop
./scripts/run.sh loop work auth 25
./scripts/run.sh loop improve-plan my-session 5

# Run a pipeline
./scripts/run.sh pipeline full-refine.yaml my-session

# List available
./scripts/run.sh
```

## Creating a Loop

Each loop has two files:

`scripts/loops/<name>/loop.yaml` - when to stop:
```yaml
name: my-loop
description: What this loop does
completion: plateau  # or beads-empty, fixed-n, all-items
delay: 3
```

`scripts/loops/<name>/prompt.md` - what Claude does each iteration:
```markdown
# My Agent

Session: ${SESSION_NAME}
Iteration: ${ITERATION}

## Task
...

## Output
PLATEAU: true/false
REASONING: [why]
```

## Pipeline Format

Pipelines chain loops together:

```yaml
name: my-pipeline
description: What this does

stages:
  - name: plan
    loop: improve-plan    # references scripts/loops/improve-plan/
    runs: 5

  - name: custom
    runs: 4
    prompt: |
      Inline prompt for one-off stages.
      Previous: ${INPUTS}
      Write to: ${OUTPUT}
```

## Variables

| Variable | Description |
|----------|-------------|
| `${SESSION_NAME}` | Session name |
| `${ITERATION}` | Current iteration (1-based) |
| `${PROGRESS_FILE}` | Path to progress file |
| `${OUTPUT}` | Path to write output |
| `${PERSPECTIVE}` | Current perspective (fan-out) |
| `${INPUTS.stage-name}` | Outputs from named stage |
| `${INPUTS}` | Outputs from previous stage |

## Completion Strategies

| Strategy | Stops When |
|----------|------------|
| `beads-empty` | No beads remain |
| `plateau` | 2 agents agree it's done |
| `fixed-n` | N iterations complete |
| `all-items` | All items processed |
