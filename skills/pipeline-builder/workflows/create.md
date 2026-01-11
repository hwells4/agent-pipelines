# Workflow: Create Pipeline

Create a pipeline with one or more stages.

> **Everything is a pipeline.** Single-stage pipelines run a stage directly. Multi-stage pipelines chain stages together via a YAML config.

## Prerequisites

Read these first:
- `references/completion-strategies.md` - When to use each strategy
- `references/loop-config.md` - Stage configuration options
- `references/template-variables.md` - Available variables
- `references/pipeline-config.md` - Multi-stage pipeline structure

## Step 1: Understand the Goal

**Use your judgment.** Based on what the user described, determine:

1. **What problem does this solve?** (implementation, refinement, analysis, etc.)
2. **How many stages?** (most are single-stage)
3. **What completion strategy?**

| Goal | Stages | Strategy |
|------|--------|----------|
| Implement tasks/beads | 1 | `beads-empty` |
| Refine a document | 1 | `plateau` |
| Generate ideas | 1 | `fixed-n` |
| Refine plan then beads | 2 | `plateau` → `plateau` |
| Review from multiple angles | 2+ | custom |

**If unclear, ask:**
```json
{
  "questions": [{
    "question": "What should this pipeline accomplish?",
    "header": "Goal",
    "options": [
      {"label": "Implement tasks", "description": "Work through beads until done"},
      {"label": "Refine/improve", "description": "Iterate until quality plateaus"},
      {"label": "Explore/brainstorm", "description": "Generate ideas for N iterations"},
      {"label": "Multi-stage workflow", "description": "Chain multiple stages together"}
    ],
    "multiSelect": false
  }]
}
```

## Step 2: Determine Stage Count

```json
{
  "questions": [{
    "question": "How many stages does this pipeline need?",
    "header": "Stages",
    "options": [
      {"label": "Single-stage", "description": "One stage that iterates until completion (most common)"},
      {"label": "Multi-stage", "description": "Chain stages together (e.g., plan → implement → verify)"}
    ],
    "multiSelect": false
  }]
}
```

**Single-stage:** Creates a stage definition in `scripts/loops/{name}/`, runs directly.

**Multi-stage:** Creates stage definitions as needed, plus a pipeline YAML in `scripts/pipelines/{name}.yaml`.

## Step 3: Check Existing Stages

List what's already available:

```bash
ls scripts/loops/
```

Common stages:
- `work` - Implement beads (beads-empty)
- `improve-plan` - Refine a plan (plateau)
- `refine-beads` - Improve beads (plateau)
- `idea-wizard` - Generate ideas (fixed-n)

For each stage in the pipeline, determine:
- **Use existing?** → Reference by name
- **Create new?** → Define it in Step 4

## Step 4: Define Stages

For each stage that needs to be created:

### 4a. Get Stage Name

Short, lowercase, hyphenated. Examples: `code-review`, `doc-audit`, `test-generator`

### 4b. Determine Configuration

| Goal | completion | min_iterations | output_parse |
|------|------------|----------------|--------------|
| Task-driven | `beads-empty` | - | - |
| Quality refinement | `plateau` | `2` | `plateau:PLATEAU reasoning:REASONING` |
| Fixed exploration | `fixed-n` | - | - |

**Always use:**
- `model: opus` (unless user requests otherwise)
- `delay: 3` (prevents rate limiting)

### 4c. Create Stage Directory

```bash
mkdir -p scripts/loops/{stage-name}
```

### 4d. Write loop.yaml

**For beads-empty:**
```yaml
name: {stage-name}
description: {One sentence description}
completion: beads-empty
check_before: true
delay: 3
```

**For plateau:**
```yaml
name: {stage-name}
description: {One sentence description}
completion: plateau
min_iterations: 2
delay: 3
output_parse: "plateau:PLATEAU reasoning:REASONING"
```

**For fixed-n:**
```yaml
name: {stage-name}
description: {One sentence description}
completion: fixed-n
delay: 3
```

### 4e. Write prompt.md

Keep prompts focused. One clear task per iteration. See existing prompts in `scripts/loops/*/prompt.md` for examples.

**Template for beads-empty:**
```markdown
# {Stage Name}

Session: ${SESSION_NAME}
Progress: ${PROGRESS_FILE}

## Context

Read progress file for accumulated learnings:
\`\`\`bash
cat ${PROGRESS_FILE}
\`\`\`

## Available Work

\`\`\`bash
bd ready --label=loop/${SESSION_NAME}
\`\`\`

## Workflow

1. Choose next task
2. Claim it: `bd update <id> --status=in_progress`
3. Implement
4. Verify
5. Close: `bd close <id>`
6. Update progress file
```

**Template for plateau:**
```markdown
# {Stage Name}

Session: ${SESSION_NAME}
Iteration: ${ITERATION}
Progress: ${PROGRESS_FILE}

## Context

\`\`\`bash
cat ${PROGRESS_FILE}
\`\`\`

## Your Task

{What to review/improve this iteration}

## Plateau Decision

At the END of your response:

\`\`\`
PLATEAU: true/false
REASONING: [Your explanation]
\`\`\`

Say true if: remaining issues are cosmetic, finding same issues repeatedly
Say false if: found significant gaps, made substantial changes
```

**Template for fixed-n:**
```markdown
# {Stage Name}

Session: ${SESSION_NAME}
Iteration: ${ITERATION}

## Context

\`\`\`bash
cat ${PROGRESS_FILE}
\`\`\`

## Your Task

{What to generate/explore this iteration}

## Output

Append findings to progress file.
```

**Repeat Step 4 for each new stage needed.**

## Step 5: Create Pipeline Config (Multi-Stage Only)

If single-stage, skip to Step 6.

For multi-stage, create the pipeline YAML:

```bash
cat > scripts/pipelines/{pipeline-name}.yaml << 'EOF'
name: {pipeline-name}
description: {What this pipeline accomplishes}

stages:
  - name: {stage-1-name}
    loop: {stage-type}
    runs: {max-iterations}

  - name: {stage-2-name}
    loop: {stage-type}
    runs: {max-iterations}
EOF
```

### Multi-Stage Patterns

**Two-stage refinement:**
```yaml
name: full-refine
description: Refine plan then beads

stages:
  - name: plan
    loop: improve-plan
    runs: 5

  - name: beads
    loop: refine-beads
    runs: 5
```

**Sequential with synthesis:**
```yaml
name: analyze-and-report
description: Analyze then synthesize findings

stages:
  - name: analysis
    loop: code-audit
    runs: 10

  - name: report
    runs: 1
    prompt: |
      Analysis from previous stage:
      ${INPUTS}

      Synthesize into actionable report.
      Write to: ${OUTPUT}
    completion: fixed-n
```

## Step 6: Validate

```bash
# Validate stage(s)
./scripts/run.sh lint loop {stage-name}

# Validate pipeline (multi-stage only)
./scripts/run.sh lint pipeline {pipeline-name}

# Preview execution
./scripts/run.sh dry-run loop {stage-name} test-session
```

Fix any reported errors before proceeding.

## Step 7: Confirm to User

### For Single-Stage:

```
Pipeline created: scripts/loops/{stage-name}/
- loop.yaml: {completion} strategy
- prompt.md: Agent instructions

To run, use the sessions skill:
  /loop-agents:sessions → Start Session → Single-stage

Or directly in tmux:
  tmux new-session -d -s "loop-{session}" -c "$(pwd)" \
    "./scripts/run.sh {stage-name} {session} {max-iterations}"

Session files created at:
  .claude/pipeline-runs/{session}/
  ├── state.json
  └── progress-{session}.md
```

### For Multi-Stage:

```
Pipeline created: scripts/pipelines/{pipeline-name}.yaml

Stages:
1. {stage-1}: {loop} x{runs}
2. {stage-2}: {loop} x{runs}

To run, use the sessions skill:
  /loop-agents:sessions → Start Session → Multi-stage

Or directly in tmux:
  tmux new-session -d -s "loop-{session}" -c "$(pwd)" \
    "./scripts/run.sh pipeline {pipeline-name}.yaml {session}"

Session files created at:
  .claude/pipeline-runs/{session}/
  ├── state.json
  └── stage-{N}-{name}/
```

## Success Criteria

- [ ] Goal and completion strategy determined
- [ ] Stage count decided (single or multi)
- [ ] All stages exist (created or pre-existing)
- [ ] Stage configs have required fields
- [ ] Prompts are focused (not bloated)
- [ ] Pipeline YAML created (multi-stage only)
- [ ] Validation passed
- [ ] User shown how to run via sessions skill
