---
description: Iteratively refine plans and beads before implementation
---

# /refine

Runs refinement pipelines: multiple agents review and improve plans and beads. Planning tokens are cheaper than implementation tokens—catch issues early.

**Runtime:** ~2-3 min per iteration

## Usage

```
/refine              # Full refine (5+5 iterations)
/refine quick        # Quick pass (3+3 iterations)
/refine deep         # Thorough pass (8+8 iterations)
/refine plan         # Only refine docs/plans/
/refine beads        # Only refine beads
/refine status       # Check running refinement loops
```

## Two-Stage Pipeline

1. **improve-plan** - Reviews documents in `docs/plans/`
2. **refine-tasks** - Reviews beads for the session

| Pipeline | improve-plan | refine-tasks | Best for |
|----------|--------------|--------------|----------|
| `quick`  | 3 iterations | 3 iterations | Fast validation |
| `full`   | 5 iterations | 5 iterations | Standard workflow |
| `deep`   | 8 iterations | 8 iterations | Complex projects |

## Termination

**Two-agent consensus** - stops when 2 consecutive agents agree work is done. Each agent judges `decision: stop` or `decision: continue`. If the second agent finds real issues, counter resets.

This prevents:
- Single-agent blind spots
- Premature stopping
- Missing subtle issues

## After Refinement

- `/work` → Start implementing refined beads
- `/refine` again → Go deeper if needed
