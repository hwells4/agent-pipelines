# Bug Investigation: State Transition Issues During Pipeline Execution

**Date:** 2026-01-12
**Session:** parallel-providers
**Pipeline:** tdd-implement.yaml

## What Happened

### Timeline

1. Started `tdd-implement` pipeline on session `parallel-providers`
2. Pipeline completed stages 0-2 successfully:
   - Stage 0: plan-tdd (2 iterations, stopped correctly)
   - Stage 1: elegance (1 iteration, stopped correctly)
   - Stage 2: create-beads (1 iteration, stopped correctly, created 8 beads)
3. Stage 3 (refine-beads) started at 03:32:20Z
4. Pipeline crashed/died - tmux session disappeared
5. On investigation, found contradictory state

### Evidence

**State file shows:**
```json
{
  "current_stage": 3,
  "iteration": 1,
  "iteration_completed": 1,
  "iteration_started": null,
  "stages": [
    {"name": "plan-tdd", "status": "complete"},
    {"name": "elegance", "status": "complete"},
    {"name": "create-beads", "status": "complete"},
    {"name": "refine-beads", "status": "running"}
  ]
}
```

**But:**
- `stage-03-refine-beads/` directory is EMPTY (no iterations folder)
- History has NO entry for refine-beads stage
- Last history entry is create-beads at 03:32:20Z

### The Contradiction

`iteration_completed: 1` suggests refine-beads iteration 1 finished, but:
- No files exist in the stage directory
- No history entry exists
- `iteration_started: null` suggests it never started

## What We Believe Happened

### Hypothesis 1: State Not Reset on Stage Transition
When transitioning from stage 2 → stage 3, the engine may not be resetting `iteration` and `iteration_completed` to their initial values. The `iteration_completed: 1` is stale from the previous stage's work.

### Hypothesis 2: Crash During Stage Initialization
The crash occurred between:
- Updating state to show stage 3 running
- Actually starting iteration 1 of stage 3

### Hypothesis 3: External Kill
User (Claude assistant) attempted to send Ctrl-C to pause the pipeline. The tmux server reported "no server running" which could mean:
- The Ctrl-C killed it
- tmux had already crashed
- The pipeline had already crashed

## Related Prior Bugs

### Commit f42a810 - Double Counting / Plateau Judgment Fix
There was a recent fix for:
- Double counting iterations
- Plateau/judgment termination logic

This commit touched test files and potentially state management. **This may be related.**

### Recurring State Management Issues
This is reportedly NOT the first time state management bugs have appeared. The team has "tested for this several times" but the issue persists. This suggests:
- The fix was incomplete
- There are multiple code paths that update state
- Edge cases in stage transitions aren't covered by tests

## Files to Investigate

1. `scripts/engine.sh` - stage transition logic
2. `scripts/lib/state.sh` - state file management
3. Commit f42a810 - what exactly was changed
4. `scripts/lib/completions/plateau.sh` - judgment termination

## Test Opportunity: Resume Functionality

**This is a good time to test resume.**

Current state:
- Lock file exists with dead PID
- State shows stage 3 "running"
- Stage 3 directory is empty
- History has all completed stages

Resume should:
1. Detect crashed session (lock + dead PID)
2. Determine correct resume point (stage 3, iteration 1, not yet started)
3. Reset iteration counters appropriately
4. Continue from stage 3

### Test Commands
```bash
# Check current state
./scripts/run.sh status parallel-providers

# Attempt resume
./scripts/run.sh pipeline tdd-implement.yaml parallel-providers --resume
```

### Expected Behavior
- Should detect crashed state
- Should start refine-beads from iteration 1
- Should create proper iteration directory
- Should write to history on completion

### Watch For
- Does it incorrectly think iteration 1 is done?
- Does it skip refine-beads entirely?
- Does it reset counters properly?

## Next Steps

1. **DO NOT** fix anything yet
2. Test resume functionality first to see current behavior
3. Review commit f42a810 for related changes
4. If resume fails, document exactly how it fails
5. Then design a proper fix with tests

## Questions to Answer

1. Why does `iteration_completed` show 1 when nothing ran?
2. Is this a state reset bug or a state write timing bug?
3. Did the recent f42a810 fix introduce a regression?
4. Why does this bug keep reappearing despite multiple fixes?
