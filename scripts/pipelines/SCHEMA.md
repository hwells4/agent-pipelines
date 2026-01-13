# Pipeline Schema Reference

This document defines the YAML schema for pipeline definitions.

## Pipeline Structure

```yaml
# Required: Pipeline identifier
name: my-pipeline

# Optional: Human-readable description
description: What this pipeline does

# Optional: Schema version (default: 1)
version: 1

# Optional: Default settings for all stages
defaults:
  provider: claude-code    # claude-code, codex, gemini
  model: sonnet            # Provider-specific model name

# Required: List of stages to execute
stages:
  - name: stage-name       # Required: Unique identifier
    description: ...       # Optional: What this stage does
    runs: 1                # Optional: How many times to run (default: 1)
    model: opus            # Optional: Override default model
    provider: claude-code  # Optional: Override default provider
    completion: plateau    # Optional: Early-stop strategy
    parallel: false        # Optional: Hint for parallel execution (not yet implemented)
    perspectives: []       # Optional: Array of values for ${PERSPECTIVE}

    # Prompt source - use ONE of these:
    stage: stage-name        # Option A: Use existing loop type's prompt
    prompt: |              # Option B: Define prompt inline
      Your instructions here...
```

## Variables

Use these in your prompts - they're resolved at runtime:

| Variable | Description | Example |
|----------|-------------|---------|
| `${CTX}` | Path to context.json with full context | `.claude/pipeline-runs/.../context.json` |
| `${STATUS}` | Path to write status.json | `.claude/pipeline-runs/.../status.json` |
| `${SESSION}` | Pipeline session name | `review-20250110-1423` |
| `${ITERATION}` | Current iteration (1-based) | `1`, `2`, `3` |
| `${INDEX}` | Current run index (0-based) | `0`, `1`, `2` |
| `${PERSPECTIVE}` | Current item from perspectives array | `security` |
| `${OUTPUT}` | Path to write this run's output | `.claude/pipeline-runs/.../run-0.md` |
| `${PROGRESS}` | Path to accumulating progress file | `.claude/pipeline-runs/.../progress.md` |

**Stage-style variables** (for compatibility when using `stage:`):

| Variable | Maps To |
|----------|---------|
| `${SESSION_NAME}` | `${SESSION}` |
| `${PROGRESS_FILE}` | `${PROGRESS}` |

## Inter-Stage Inputs

To pass outputs from one stage to another, use the `inputs` config:

```yaml
stages:
  - name: improve-plan
    stage: improve-plan
    runs: 5

  - name: refine-beads
    stage: refine-beads
    runs: 5
    inputs:
      from: improve-plan    # Name of source stage
      select: latest        # "latest" (default) or "all"
```

The inputs are available in `context.json`. Agents read them via:

```bash
# Read previous stage outputs
jq -r '.inputs.from_stage | to_entries[] | .value[]' ${CTX} | while read file; do
  cat "$file"
done

# Read previous iterations of current stage
jq -r '.inputs.from_previous_iterations[]' ${CTX} | while read file; do
  cat "$file"
done
```

## Completion Strategies

- **none** (default): Run exactly `runs` times
- **plateau**: Stop when 2 consecutive runs output `PLATEAU: true`
- **beads-empty**: Stop when `bd ready --label=pipeline/${SESSION}` returns 0

## Providers

| Provider | CLI | Models |
|----------|-----|--------|
| `claude-code` | `claude` | opus, sonnet, haiku |
| `codex` | `codex` | o3, o3-mini, gpt-4o |
| `gemini` | `gemini` | flash, pro |

## Examples

### Using Existing Loop Types

```yaml
name: full-refine
stages:
  - name: improve-plan
    stage: improve-plan    # Uses stages/improve-plan/prompt.md
    runs: 5               # Inherits termination from stage.yaml

  - name: refine-beads
    stage: refine-beads
    runs: 5
```

### Simple One-Shot

```yaml
name: analyze
stages:
  - name: analyze
    runs: 1
    prompt: |
      Analyze the codebase structure.
      Write findings to ${OUTPUT}
```

### Fan-Out and Fan-In

> Note: `parallel: true` is a schema hint for future parallel execution.
> Currently, runs execute sequentially but outputs are still aggregated correctly.

```yaml
name: multi-review
stages:
  - name: review
    runs: 4
    perspectives:
      - security
      - performance
      - maintainability
      - testing
    prompt: |
      Review from ${PERSPECTIVE} perspective.
      Write to ${OUTPUT}

  - name: synthesize
    runs: 1
    inputs:
      from: review
      select: all
    prompt: |
      Combine all reviews from previous stage.

      Read review outputs:
      jq -r '.inputs.from_stage.review[]' ${CTX} | xargs cat

      Write synthesis to ${OUTPUT}
```

### Iterative Refinement

```yaml
name: refine-doc
stages:
  - name: improve
    runs: 10
    completion: plateau
    prompt: |
      Read the document and improve it.

      Previous progress: ${PROGRESS}

      Make improvements and update ${PROGRESS}.

      PLATEAU: true/false
      REASONING: why
```

## Output Structure

After running a pipeline, outputs are in:

```
.claude/pipeline-runs/{session}/
├── pipeline.yaml          # Copy of pipeline definition
├── state.json             # Execution state
├── stage-1-{name}/
│   ├── output.md          # Single run output
│   └── progress.md        # If using ${PROGRESS}
├── stage-2-{name}/
│   ├── run-0.md           # Multiple run outputs
│   ├── run-1.md
│   └── ...
└── ...
```
