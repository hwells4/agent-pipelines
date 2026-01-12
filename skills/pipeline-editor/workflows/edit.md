# Workflow: Edit Existing Configuration

Modify existing stage or pipeline configurations. Direct modification—no architecture agent needed.

## Step 1: Identify Target

Ask what to edit:

```json
{
  "questions": [{
    "question": "What do you want to edit?",
    "header": "Target",
    "options": [
      {"label": "Stage (loop)", "description": "Edit a stage in scripts/loops/"},
      {"label": "Pipeline", "description": "Edit a pipeline in scripts/pipelines/"}
    ],
    "multiSelect": false
  }]
}
```

## Step 2: List Available Options

### For Stage

```bash
ls scripts/loops/
```

Present as options:

```json
{
  "questions": [{
    "question": "Which stage do you want to edit?",
    "header": "Stage",
    "options": [
      {"label": "work", "description": "Implementation stage"},
      {"label": "improve-plan", "description": "Plan refinement stage"},
      // ... dynamically from ls output
    ],
    "multiSelect": false
  }]
}
```

### For Pipeline

```bash
ls scripts/pipelines/*.yaml 2>/dev/null
```

Present similarly.

## Step 3: Load Current Config

### For Stage

```bash
cat scripts/loops/{stage}/loop.yaml
cat scripts/loops/{stage}/prompt.md
```

### For Pipeline

```bash
cat scripts/pipelines/{pipeline}.yaml
```

Present the current configuration to the user.

## Step 4: Collect Changes

Ask what they want to change:

```json
{
  "questions": [{
    "question": "What would you like to change?",
    "header": "Change Type",
    "options": [
      {"label": "Termination strategy", "description": "Change when/how it stops"},
      {"label": "Iteration counts", "description": "Adjust min/max/consensus"},
      {"label": "Model", "description": "Change which model runs"},
      {"label": "Prompt", "description": "Edit the prompt template"}
    ],
    "multiSelect": true
  }]
}
```

For each selected change, ask for specifics.

## Step 5: Apply Changes

Make the edits using the Edit tool. Keep a record of changes.

### For loop.yaml changes

```yaml
# Example: Change termination strategy
termination:
  type: judgment
  min_iterations: 3
  consensus: 2
```

### For prompt.md changes

Edit the specific sections. Preserve the overall structure:
- Context section with `${CTX}`, `${PROGRESS}`, `${STATUS}`
- Autonomy grant
- Status.json template

## Step 6: Validate

Run the linter:

```bash
./scripts/run.sh lint loop {stage}
# or
./scripts/run.sh lint pipeline {pipeline}.yaml
```

If lint fails, show errors and fix.

## Step 7: Show Diff and Confirm

Present what changed:

```markdown
## Changes Made

### loop.yaml
```diff
- type: fixed
+ type: judgment
+ min_iterations: 3
+ consensus: 2
```

### prompt.md
No changes.

Lint: PASSED
```

Ask for final confirmation:

```json
{
  "questions": [{
    "question": "Save these changes?",
    "header": "Confirm",
    "options": [
      {"label": "Yes, save", "description": "Keep the changes"},
      {"label": "No, revert", "description": "Discard and try again"}
    ],
    "multiSelect": false
  }]
}
```

### On "No, revert"

Undo changes and return to Step 4.

### On "Yes, save"

Confirm the changes are saved. No further action needed.

## Success Criteria

- [ ] Target identified (stage or pipeline)
- [ ] Current config loaded and presented
- [ ] Changes collected and applied
- [ ] Lint validation passed
- [ ] Diff shown to user
- [ ] Explicit confirmation received
