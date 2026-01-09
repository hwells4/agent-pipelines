# State File Management

<location>
State file: `.claude/loop-sessions.json`

This file tracks metadata that tmux doesn't provide:
- When session was started (for stale detection)
- Original project path
- Intended max iterations
- Status tracking
</location>

<schema>
```json
{
  "sessions": {
    "loop-feature-name": {
      "started_at": "2025-01-08T10:00:00Z",
      "project_path": "/Users/name/project",
      "max_iterations": 50,
      "status": "running"
    }
  }
}
```

**Status values:**
- `running` - Active session
- `complete` - Finished successfully
- `killed` - Terminated by user
- `failed` - Exited with error
</schema>

<operations>

**Read state:**
```bash
cat .claude/loop-sessions.json 2>/dev/null
```

**Add session:**
```bash
# Using jq if available
jq '.sessions["loop-NAME"] = {"started_at": "TIMESTAMP", "project_path": "PATH", "max_iterations": 50, "status": "running"}' \
  .claude/loop-sessions.json > tmp && mv tmp .claude/loop-sessions.json

# Or write directly for simple cases
```

**Update status:**
```bash
jq '.sessions["loop-NAME"].status = "complete"' \
  .claude/loop-sessions.json > tmp && mv tmp .claude/loop-sessions.json
```

**Remove session:**
```bash
jq 'del(.sessions["loop-NAME"])' \
  .claude/loop-sessions.json > tmp && mv tmp .claude/loop-sessions.json
```

</operations>

<sync_with_tmux>
State file can drift from reality. Always verify:

```bash
# For each session in state file
for session in $(jq -r '.sessions | keys[]' .claude/loop-sessions.json); do
  if ! tmux has-session -t "$session" 2>/dev/null; then
    echo "Orphaned: $session (in state but not in tmux)"
  fi
done
```
</sync_with_tmux>

<stale_detection>
```bash
# Get current timestamp
NOW=$(date +%s)

# Get session start time from state
START=$(jq -r '.sessions["loop-NAME"].started_at' .claude/loop-sessions.json)
START_EPOCH=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$START" +%s 2>/dev/null)

# Calculate age in hours
AGE_HOURS=$(( (NOW - START_EPOCH) / 3600 ))

if [ "$AGE_HOURS" -gt 2 ]; then
  echo "⚠️ Session is stale ($AGE_HOURS hours)"
fi
```
</stale_detection>
