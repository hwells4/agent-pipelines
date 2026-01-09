# Workflow: List All Loop Sessions

<process>

## Step 1: Get Live Sessions from tmux

```bash
tmux list-sessions 2>/dev/null | grep "^loop-" || echo "No active loop sessions"
```

## Step 2: Cross-Reference with State File

```bash
cat .claude/loop-sessions.json 2>/dev/null || echo "No state file"
```

## Step 3: Check Each Session Status

For each session, report:
- Name
- Runtime (from state file timestamp)
- Status: Running / Complete / Stale (>2hr) / Orphaned (in state but not in tmux)

## Step 4: Run Check Script

```bash
bash .claude/skills/run-loop/scripts/check-sessions.sh
```

## Step 5: Display Summary

```
╔══════════════════════════════════════════════════════════╗
║  Loop Sessions                                           ║
╠══════════════════════════════════════════════════════════╣
║  loop-auth       ⏳ Running    1h 23m   /path/to/project ║
║  loop-docs       ✅ Complete   0h 45m   /path/to/docs    ║
║  loop-api        ⚠️  Stale      3h 10m   /path/to/api     ║
╚══════════════════════════════════════════════════════════╝
```

</process>

<success_criteria>
- [ ] All loop sessions listed
- [ ] Status shown for each
- [ ] Stale sessions flagged
</success_criteria>
