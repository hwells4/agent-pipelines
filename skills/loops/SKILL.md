---
name: loops
description: Manage autonomous loop agents in tmux sessions. Spin up, monitor, attach, detach, and manage multiple concurrent loop executions. Use when running long autonomous tasks that should persist in the background.
---

<essential_principles>

**Session Lifecycle:**
Every tmux session you start MUST be tracked. When you start a session, update the state file. When it completes or you kill it, clean up.

**State File:** `.claude/loop-sessions.json`
```json
{
  "sessions": {
    "loop-feature-name": {
      "started_at": "2025-01-08T10:00:00Z",
      "project_path": "/path/to/project",
      "max_iterations": 50,
      "status": "running"
    }
  }
}
```

**Naming Convention:** `loop-{feature-name}` (lowercase, hyphens)

**Stale Session Warning:** Sessions running > 2 hours should trigger a warning. Check session age before any operation.

**Never Leave Orphans:** Before ending a conversation where you started a session, remind the user about running sessions and how to check on them.

</essential_principles>

<intake>
Use the AskUserQuestion tool with these options:

```json
{
  "questions": [{
    "question": "What would you like to do with tmux loop sessions?",
    "header": "Loop Action",
    "options": [
      {"label": "Start", "description": "Spin up a new loop session in tmux"},
      {"label": "Monitor", "description": "Peek at output from a running session"},
      {"label": "Attach", "description": "Connect to watch a session live"},
      {"label": "List", "description": "Show all running loop sessions"},
      {"label": "Kill", "description": "Terminate a running session"},
      {"label": "Cleanup", "description": "Find and handle stale sessions"}
    ],
    "multiSelect": false
  }]
}
```

**Wait for response before proceeding.**
</intake>

<routing>
| Response | Workflow |
|----------|----------|
| "Start" | `workflows/start-session.md` |
| "Monitor" | `workflows/monitor-session.md` |
| "Attach" | `workflows/attach-session.md` |
| "List" | `workflows/list-sessions.md` |
| "Kill" | `workflows/kill-session.md` |
| "Cleanup" | `workflows/cleanup-sessions.md` |

**After reading the workflow, follow it exactly.**
</routing>

<quick_commands>
```bash
# Start a work loop (use loop-engine)
PLUGIN_DIR=".claude/loop-agents"
tmux new-session -d -s loop-NAME -c "$(pwd)" "$PLUGIN_DIR/scripts/loop-engine/run.sh work NAME 50"

# Start other loop types
$PLUGIN_DIR/scripts/loop-engine/run.sh improve-plan NAME 5 # Plan refinement
$PLUGIN_DIR/scripts/loop-engine/run.sh refine-beads NAME 5 # Bead refinement
$PLUGIN_DIR/scripts/loop-engine/run.sh idea-wizard NAME 3  # Idea generation

# Peek at output (safe, doesn't attach)
tmux capture-pane -t loop-NAME -p | tail -50

# Attach (takes over terminal)
tmux attach -t loop-NAME
# Detach: Ctrl+b, then d

# List sessions
tmux list-sessions 2>/dev/null | grep "^loop-"

# Kill session
tmux kill-session -t loop-NAME

# Check if complete
cat .claude/loop-state-NAME.json | jq '.completed'
```
</quick_commands>

<reference_index>
| Reference | Purpose |
|-----------|---------|
| references/tmux-commands.md | Full tmux command reference |
| references/state-management.md | State file operations |
</reference_index>

<workflows_index>
| Workflow | Purpose |
|----------|---------|
| start-session.md | Spin up a new loop in tmux |
| monitor-session.md | Safely peek at output without attaching |
| attach-session.md | Connect to watch live + detach |
| list-sessions.md | Show all running loop sessions |
| kill-session.md | Terminate a session |
| cleanup-sessions.md | Find and handle stale sessions |
</workflows_index>

<scripts_index>
| Script | Purpose |
|--------|---------|
| scripts/check-sessions.sh | List sessions with age and status |
| scripts/warn-stale.sh | Check for sessions > 2 hours old |
</scripts_index>
