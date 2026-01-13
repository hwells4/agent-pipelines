# Start & Watch Workflow

Start a new pipeline and actively monitor it through startup and first iterations.

<required_reading>
- SKILL.md for file locations and health checks
</required_reading>

<process>
## Phase 1: Gather Pipeline Details

Use AskUserQuestion to get pipeline configuration:
```json
{
  "questions": [
    {
      "question": "What type of pipeline do you want to run?",
      "header": "Pipeline Type",
      "options": [
        {"label": "Ralph (work loop)", "description": "Run ralph loop to complete beads"},
        {"label": "Refine", "description": "Run plan+task refinement pipeline"},
        {"label": "Custom stage", "description": "Run a specific stage type"}
      ],
      "multiSelect": false
    }
  ]
}
```

Then get session name:
```json
{
  "questions": [
    {
      "question": "What session name should we use?",
      "header": "Session Name",
      "options": [
        {"label": "Generate from context", "description": "Auto-generate based on current work"},
        {"label": "Use existing", "description": "Continue an existing session name"}
      ],
      "multiSelect": false
    }
  ]
}
```

## Phase 2: Pre-flight Checks

Before starting, verify the environment:

```bash
# Check no conflicting session
session="{session_name}"
if tmux has-session -t "pipeline-$session" 2>/dev/null; then
  echo "WARNING: Session already running"
fi

# Check for stale lock
if [ -f ".claude/locks/$session.lock" ]; then
  pid=$(jq -r .pid ".claude/locks/$session.lock")
  if ! kill -0 "$pid" 2>/dev/null; then
    echo "WARNING: Stale lock found (PID $pid dead)"
  fi
fi

# Check for existing state
if [ -f ".claude/pipeline-runs/$session/state.json" ]; then
  echo "INFO: Previous state exists"
  jq -r '"Previous run: \(.status) at iteration \(.iteration_completed)"' \
    ".claude/pipeline-runs/$session/state.json"
fi
```

Report any warnings to user and ask if they want to proceed.

## Phase 3: Start the Pipeline

Based on pipeline type, construct and run the command:

```bash
# For ralph:
./scripts/run.sh ralph {session} {max_iterations}

# For refine:
./scripts/run.sh pipeline refine.yaml {session}

# For custom stage:
./scripts/run.sh loop {stage_type} {session} {max_iterations}
```

Immediately after starting:

```bash
# Wait a moment for startup
sleep 2

# Verify tmux session created
tmux has-session -t "pipeline-{session}" 2>/dev/null && echo "STARTED" || echo "FAILED TO START"

# Check lock file created
ls -la .claude/locks/{session}.lock 2>/dev/null
```

## Phase 4: Monitor Startup

Watch the first few seconds of startup:

```bash
# Capture initial output
for i in 1 2 3; do
  echo "=== Capture $i (after ${i}s) ==="
  tmux capture-pane -t "pipeline-{session}" -p | tail -20
  sleep 1
done
```

Verify state file is created:

```bash
# Check state file exists and is valid
if [ -f ".claude/pipeline-runs/{session}/state.json" ]; then
  echo "State file created:"
  jq . ".claude/pipeline-runs/{session}/state.json"
else
  echo "WARNING: State file not yet created"
fi
```

## Phase 5: Watch First Iteration

Wait for the first iteration to complete:

```bash
# Poll for first iteration
session="{session_name}"
state_file=".claude/pipeline-runs/$session/state.json"

echo "Waiting for first iteration..."
for i in $(seq 1 60); do
  if [ -f "$state_file" ]; then
    completed=$(jq -r '.iteration_completed // 0' "$state_file")
    if [ "$completed" -ge 1 ]; then
      echo "First iteration completed!"
      break
    fi
  fi
  sleep 5
  echo "Still waiting... (${i}0s)"
done
```

Once first iteration completes, read the output:

```bash
session="{session_name}"
iter_dir=$(ls -d .claude/pipeline-runs/$session/stage-*/iterations/001/ 2>/dev/null | head -1)

if [ -n "$iter_dir" ]; then
  echo "=== First Iteration Output ==="
  cat "$iter_dir/output.md" | head -100

  echo ""
  echo "=== Status Decision ==="
  jq . "$iter_dir/status.json"
else
  echo "WARNING: Iteration directory not found"
fi
```

## Phase 6: Report Status

Summarize what you observed:
1. Whether the pipeline started successfully
2. Whether all expected files were created
3. The content of the first iteration output
4. The decision (continue/stop) and reason
5. Any warnings or anomalies

Offer next actions:
- Continue watching more iterations (`/monitor watch`)
- Attach for live debugging (`/monitor attach`)
- Run health check later (`/monitor health`)
</process>

<success_criteria>
- [ ] Pipeline started in tmux session
- [ ] Lock file created with valid PID
- [ ] State file created and valid JSON
- [ ] First iteration completed and output readable
- [ ] Status.json has valid decision
- [ ] User informed of status and next steps
</success_criteria>
