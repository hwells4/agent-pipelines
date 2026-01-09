---
description: Iteratively refine plans and beads before implementation
---

# /refine Command

**Refinement loops:** Multiple agents review and improve plans and beads before you start implementing.

## Usage

```
/refine                  # Run full-refine pipeline (improve-plan → refine-beads)
/refine quick            # Quick pass (3 iterations each)
/refine deep             # Thorough pass (8 iterations each)
/refine plan             # Only refine plans
/refine beads            # Only refine beads
/refine status           # Check running refinement loops
```

---

## What This Does

**The pattern:** "Check your beads N times, implement once"

Planning tokens are cheaper than implementation tokens. Running multiple refinement iterations finds subtle issues that compound into significantly better execution.

### Two Refinement Loops

1. **improve-plan** - Reviews documents in `docs/plans/`
2. **refine-beads** - Reviews beads for a session

### Stopping Criteria

**Stops when 2 consecutive agents agree the work is done.**

Each agent makes a judgment: `PLATEAU: true/false` with reasoning.
- If Agent A says `PLATEAU: true` and Agent B also says `PLATEAU: true` → stops
- If Agent B finds real issues → counter resets, refinement continues

This prevents:
- Single-agent blind spots
- Premature stopping
- Missing subtle issues

### Pipelines

| Pipeline | improve-plan | refine-beads | Best for |
|----------|--------------|--------------|----------|
| `quick` | 3 iterations | 3 iterations | Fast validation |
| `full` | 5 iterations | 5 iterations | Standard workflow |
| `deep` | 8 iterations | 8 iterations | Complex projects |

### How It Works

1. **improve-plan loop** - Reviews plan documents in `docs/plans/`
   - Checks completeness, clarity, feasibility
   - Fixes gaps, ambiguities, inconsistencies
   - Stops when two agents agree it's ready

2. **refine-beads loop** - Reviews beads tagged for this session
   - Checks titles, descriptions, acceptance criteria
   - Ensures proper dependencies
   - Stops when two agents agree beads are implementable

---

## Execution

### Default: Full Pipeline

```yaml
question: "Run refine pipeline?"
header: "Refine"
options:
  - label: "Full refine (5+5)"
    description: "Standard: improve-plan then refine-beads"
  - label: "Quick refine (3+3)"
    description: "Fast pass, fewer iterations"
  - label: "Deep refine (8+8)"
    description: "Thorough, for complex projects"
  - label: "Plan only"
    description: "Just refine docs/plans/"
  - label: "Beads only"
    description: "Just refine beads"
```

### Ask for Session Name

```yaml
question: "Session name for this refinement?"
header: "Session"
options:
  - label: "refine-{date}"
    description: "Auto-generated name"
  - label: "Let me name it"
    description: "I'll type a custom name"
```

### Launch

**For pipelines:**
```bash
PLUGIN_DIR=".claude/loop-agents"
SESSION_NAME="{session}"

# In foreground (shows progress)
$PLUGIN_DIR/scripts/loop-engine/pipeline.sh full-refine $SESSION_NAME
```

**For single loops:**
```bash
# Plan only
$PLUGIN_DIR/scripts/loop-engine/run.sh improve-plan $SESSION_NAME 5

# Beads only
$PLUGIN_DIR/scripts/loop-engine/run.sh refine-beads $SESSION_NAME 5
```

### Show Progress

After launching, show:
```
Refine Pipeline: {pipeline}
Session: {session}

Progress file: .claude/loop-progress/progress-{session}.txt
State file: .claude/loop-state-{session}.json

Watch: tail -f .claude/loop-progress/progress-{session}.txt
```

---

## Intelligent Plateau Detection

Each iteration, the agent judges: `PLATEAU: true/false`

**Two consecutive agents must agree** before stopping. This prevents:
- Single-agent blind spots
- Premature stopping
- Missing important issues

If the second agent finds real problems, refinement continues.

---

## Subcommands

### /refine status

```bash
echo "=== Running Refinement Loops ==="
tmux list-sessions 2>/dev/null | grep -E "^loop-(refine|improve)" || echo "No refinement loops running"

echo ""
echo "=== Recent State Files ==="
for f in .claude/loop-state-*.json; do
  [ -f "$f" ] || continue
  session=$(basename "$f" .json | sed 's/loop-state-//')
  status=$(jq -r '.completed // false' "$f" 2>/dev/null)
  echo "  $session: completed=$status"
done
```

---

## After Refinement

```yaml
question: "Refinement complete. What next?"
header: "Next"
options:
  - label: "Launch work loop (Recommended)"
    description: "Start implementing with /work"
  - label: "Review changes"
    description: "Look at what was refined"
  - label: "Run another pass"
    description: "Go deeper on refinement"
```

---

## When to Use

- **Before implementing new features** - Catch planning issues early
- **When beads seem unclear** - Improve quality before work
- **For complex projects** - More refinement = better execution
- **When fresh eyes help** - Multiple agents catch more issues
