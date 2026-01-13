# Workflow: Cleanup Sessions

Handle stale locks, orphaned tmux sessions, and zombie state files.

<required_reading>
**Read these reference files NOW:**
1. references/commands.md
</required_reading>

<process>
## Step 1: Scan for Problems

Check all three resource types for inconsistencies:

```bash
echo "Scanning for session problems..."

# Collect all known sessions
all_sessions=$(
    (tmux list-sessions 2>/dev/null | grep -E "^loop-" | cut -d: -f1 | sed 's/^loop-//';
     ls .claude/locks/*.lock 2>/dev/null | xargs -n1 basename | sed 's/\.lock$//';
     ls .claude/pipeline-runs/*/state.json 2>/dev/null | xargs -n1 dirname | xargs -n1 basename) | sort -u
)
```

### Identify Problem Types

```bash
problems=()

for session in $all_sessions; do
    has_tmux=$(tmux has-session -t "pipeline-${session}" 2>/dev/null && echo "yes" || echo "no")
    has_lock=$(test -f ".claude/locks/${session}.lock" && echo "yes" || echo "no")
    has_state=$(test -f ".claude/pipeline-runs/${session}/state.json" && echo "yes" || echo "no")

    # Check for stale lock (lock exists, PID dead)
    if [ "$has_lock" = "yes" ]; then
        pid=$(jq -r .pid ".claude/locks/${session}.lock")
        if ! kill -0 "$pid" 2>/dev/null; then
            problems+=("STALE_LOCK:${session}")
        fi
    fi

    # Check for orphaned tmux (tmux exists, no lock)
    if [ "$has_tmux" = "yes" ] && [ "$has_lock" = "no" ]; then
        problems+=("ORPHAN_TMUX:${session}")
    fi

    # Check for zombie state (state says running, but tmux gone)
    if [ "$has_state" = "yes" ] && [ "$has_tmux" = "no" ]; then
        state_status=$(jq -r '.status // ""' ".claude/pipeline-runs/${session}/state.json")
        if [ "$state_status" = "running" ]; then
            problems+=("ZOMBIE_STATE:${session}")
        fi
    fi
done
```

## Step 2: Display Problems Found

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
SESSION CLEANUP SCAN
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Problems found: ${#problems[@]}

STALE LOCKS (lock exists but process dead):
  • auth - PID 12345 (died ~2h ago)
  • old-feature - PID 67890 (died ~1d ago)

ORPHANED TMUX (tmux without lock/state):
  • mystery-session

ZOMBIE STATE (state says "running" but tmux gone):
  • billing - iteration 3/5

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### No Problems Found

```
✓ No session problems found.

All sessions are healthy:
  • auth (running, iteration 5/25)
  • billing (complete)
```

## Step 3: Offer Cleanup Actions

If problems found, use AskUserQuestion:

```json
{
  "questions": [{
    "question": "How would you like to handle these problems?",
    "header": "Cleanup",
    "options": [
      {"label": "Fix All", "description": "Automatically clean up all problems (Recommended)"},
      {"label": "Interactive", "description": "Ask about each problem individually"},
      {"label": "Stale Locks Only", "description": "Just remove stale lock files"},
      {"label": "Cancel", "description": "Don't make any changes"}
    ],
    "multiSelect": false
  }]
}
```

## Step 4: Execute Cleanup

### Fix Stale Locks

```bash
for problem in "${problems[@]}"; do
    if [[ "$problem" == STALE_LOCK:* ]]; then
        session="${problem#STALE_LOCK:}"

        # Remove the stale lock
        rm ".claude/locks/${session}.lock"
        echo "✓ Removed stale lock for '${session}'"

        # Check if it can be resumed
        if [ -f ".claude/pipeline-runs/${session}/state.json" ]; then
            iteration=$(jq -r .iteration ".claude/pipeline-runs/${session}/state.json")
            loop_type=$(jq -r .loop_type ".claude/pipeline-runs/${session}/state.json")
            echo "  → Can resume: ./scripts/run.sh ${loop_type} ${session} N --resume"
        fi
    fi
done
```

### Fix Orphaned tmux

```bash
for problem in "${problems[@]}"; do
    if [[ "$problem" == ORPHAN_TMUX:* ]]; then
        session="${problem#ORPHAN_TMUX:}"

        # Ask what to do with orphan
        echo "Orphaned tmux session: ${session}"
        echo "Options:"
        echo "  1. Kill it (no useful data)"
        echo "  2. Leave it (investigate manually)"

        # If Fix All, default to kill
        tmux kill-session -t "pipeline-${session}"
        echo "✓ Killed orphaned tmux session '${session}'"
    fi
done
```

### Fix Zombie State

```bash
for problem in "${problems[@]}"; do
    if [[ "$problem" == ZOMBIE_STATE:* ]]; then
        session="${problem#ZOMBIE_STATE:}"

        # Update state to reflect unknown termination
        jq '.status = "unknown_termination" | .terminated_at = now | .terminated_at |= todate' \
            ".claude/pipeline-runs/${session}/state.json" > /tmp/state.json \
            && mv /tmp/state.json ".claude/pipeline-runs/${session}/state.json"

        echo "✓ Updated zombie state for '${session}' (status: unknown_termination)"
        echo "  → Can resume: ./scripts/run.sh ${loop_type} ${session} N --resume"
    fi
done
```

## Step 5: Summary Report

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
CLEANUP COMPLETE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Fixed:
  ✓ 2 stale locks removed
  ✓ 1 orphaned tmux killed
  ✓ 1 zombie state updated

Sessions available to resume:
  • auth:        ./scripts/run.sh ralph auth 25 --resume
  • old-feature: ./scripts/run.sh ralph old-feature 15 --resume

Next actions:
  • List sessions: /agent-pipelines:sessions list
  • Start new:     /agent-pipelines:sessions start

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```
</process>

<success_criteria>
Cleanup workflow is complete when:
- [ ] All three resource types scanned
- [ ] Problems categorized (stale locks, orphans, zombies)
- [ ] Clear report shown of problems found
- [ ] User confirmed cleanup action
- [ ] Stale locks removed
- [ ] Orphaned tmux sessions killed
- [ ] Zombie states updated
- [ ] Summary of fixes provided
- [ ] Resumable sessions identified
</success_criteria>
