# Workflow: List Sessions

Show all running loop agent sessions with their status.

<required_reading>
**Read these reference files NOW:**
1. references/commands.md
</required_reading>

<process>
## Step 1: Gather Session Information

Collect data from three sources:

```bash
# 1. Active tmux sessions
tmux list-sessions 2>/dev/null | grep -E "^loop-" | cut -d: -f1 | sed 's/^loop-//'

# 2. Lock files
ls .claude/locks/*.lock 2>/dev/null | xargs -n1 basename | sed 's/\.lock$//'

# 3. State files
ls .claude/pipeline-runs/*/state.json 2>/dev/null | xargs -n1 dirname | xargs -n1 basename
```

## Step 2: Build Session Status Table

For each unique session found, determine status:

```bash
for session in $(get_all_sessions); do
    has_tmux=$(tmux has-session -t "pipeline-${session}" 2>/dev/null && echo "yes" || echo "no")
    has_lock=$(test -f ".claude/locks/${session}.lock" && echo "yes" || echo "no")
    has_state=$(test -f ".claude/pipeline-runs/${session}/state.json" && echo "yes" || echo "no")

    # Determine health status
    if [ "$has_tmux" = "yes" ] && [ "$has_lock" = "yes" ]; then
        if [ "$has_lock" = "yes" ]; then
            pid=$(jq -r .pid ".claude/locks/${session}.lock")
            if kill -0 "$pid" 2>/dev/null; then
                status="RUNNING"
            else
                status="CRASHED (stale lock)"
            fi
        fi
    elif [ "$has_tmux" = "yes" ] && [ "$has_lock" = "no" ]; then
        status="ORPHANED (tmux without lock)"
    elif [ "$has_tmux" = "no" ] && [ "$has_lock" = "yes" ]; then
        status="STALE (lock without tmux)"
    elif [ "$has_state" = "yes" ]; then
        state_status=$(jq -r .status ".claude/pipeline-runs/${session}/state.json")
        status="${state_status^^}"  # COMPLETE, FAILED, etc.
    fi

    # Get iteration info if available
    if [ "$has_state" = "yes" ]; then
        iteration=$(jq -r '.iteration // "?"' ".claude/pipeline-runs/${session}/state.json")
        loop_type=$(jq -r '.loop_type // "?"' ".claude/pipeline-runs/${session}/state.json")
    fi
done
```

## Step 3: Display Results

Format output as a clear table:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
LOOP AGENT SESSIONS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

SESSION         TYPE            ITER    STATUS
─────────────────────────────────────────────────────────────
auth            work            5/25    RUNNING
billing         improve-plan    3/5     RUNNING
old-feature     work            12/15   CRASHED (stale lock)
test            refine-tasks    5/5     COMPLETE

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Active: 2  |  Crashed: 1  |  Completed: 1
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### Warning Indicators

Add warnings for:
- Sessions running > 2 hours
- Crashed sessions (need resume or cleanup)
- Orphaned resources (need cleanup)

```
⚠️  'auth' has been running for 3 hours - may be stuck
⚠️  'old-feature' crashed - use --resume to continue or cleanup
```

## Step 4: Show Empty State

If no sessions found:

```
No loop agent sessions found.

To start a session:
  ./scripts/run.sh ralph my-session 25
  ./scripts/run.sh pipeline full-refine.yaml my-project

Available stage types:
  work, improve-plan, refine-tasks, elegance, idea-wizard
```

## Step 5: Provide Next Actions

Based on what was found:

**If running sessions:**
```
Actions:
  • Monitor: /agent-pipelines:sessions monitor {name}
  • Attach:  /agent-pipelines:sessions attach {name}
  • Kill:    /agent-pipelines:sessions kill {name}
```

**If crashed/stale sessions:**
```
Actions:
  • Resume:  ./scripts/run.sh {type} {name} {max} --resume
  • Cleanup: /agent-pipelines:sessions cleanup
```

**If completed sessions:**
```
Actions:
  • View results: cat .claude/pipeline-runs/{name}/progress-{name}.md
  • Start new:    /agent-pipelines:sessions start
```
</process>

<success_criteria>
List sessions workflow is complete when:
- [ ] All three sources checked (tmux, locks, state files)
- [ ] Status correctly determined for each session
- [ ] Clear table displayed with all sessions
- [ ] Warnings shown for problematic sessions
- [ ] Summary counts provided
- [ ] Relevant next actions offered
</success_criteria>
