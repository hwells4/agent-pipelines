---
name: pipeline-editor
description: Edit existing stages and pipelines. Use when user wants to modify loop.yaml, prompt.md, or pipeline.yaml configurations.
---

## What This Skill Does

Modifies existing stage and pipeline configurations. Direct editing—no architecture agent needed.

## Natural Skill Detection

Trigger on:
- "Edit the elegance stage"
- "Change the termination strategy for..."
- "Modify the work loop to use..."
- "Update the pipeline config..."
- `/pipeline edit`

## Intake

Use AskUserQuestion to identify the target:

```json
{
  "questions": [{
    "question": "What do you want to edit?",
    "header": "Target",
    "options": [
      {"label": "Stage", "description": "Edit a stage in scripts/loops/"},
      {"label": "Pipeline", "description": "Edit a multi-stage pipeline in scripts/pipelines/"}
    ],
    "multiSelect": false
  }]
}
```

## Workflow

```
Step 1: IDENTIFY TARGET
├─ Stage or Pipeline?
└─ Which specific one?

Step 2: LOAD CURRENT CONFIG
├─ Read loop.yaml + prompt.md (for stage)
└─ Read pipeline.yaml (for pipeline)

Step 3: COLLECT CHANGES
├─ What aspects to change?
├─ Termination, iterations, model, prompt?
└─ Get specific values

Step 4: APPLY CHANGES
├─ Edit files
├─ Run lint validation
└─ Show diff

Step 5: CONFIRM
├─ Present changes
└─ Get yes/no confirmation
```

Read `workflows/edit.md` for detailed steps.

## Quick Reference

```bash
# List stages
ls scripts/loops/

# List pipelines
ls scripts/pipelines/*.yaml

# View stage config
cat scripts/loops/{stage}/loop.yaml
cat scripts/loops/{stage}/prompt.md

# View pipeline config
cat scripts/pipelines/{name}.yaml

# Validate after edits
./scripts/run.sh lint loop {stage}
./scripts/run.sh lint pipeline {name}.yaml
```

## Editable Properties

### Stage (loop.yaml)

| Property | Description |
|----------|-------------|
| `termination.type` | queue, judgment, or fixed |
| `termination.min_iterations` | Start checking after N (judgment) |
| `termination.consensus` | Consecutive stops needed (judgment) |
| `termination.max_iterations` | Hard limit (fixed) |
| `model` | opus, sonnet, or haiku |
| `delay` | Seconds between iterations |

### Stage (prompt.md)

| Section | Notes |
|---------|-------|
| Context section | Preserve ${CTX}, ${PROGRESS}, ${STATUS} |
| Autonomy grant | Preserve the philosophy |
| Guidance | Edit task-specific instructions |
| Status template | Preserve JSON format |

### Pipeline (pipeline.yaml)

| Property | Description |
|----------|-------------|
| `stages[].loop` | Which stage to run |
| `stages[].runs` | Max iterations for this stage |
| `stages[].inputs` | Dependencies on previous stages |

## References Index

| Reference | Purpose |
|-----------|---------|
| (inherits from pipeline-designer) | |

## Workflows Index

| Workflow | Purpose |
|----------|---------|
| edit.md | Full editing workflow |

## Success Criteria

- [ ] Target correctly identified
- [ ] Current config loaded and presented
- [ ] Changes collected and applied
- [ ] Lint validation passed
- [ ] Diff shown to user
- [ ] Explicit confirmation received
