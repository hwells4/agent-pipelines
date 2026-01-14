# Workflow: Discover Pipelines

Browse available stages and pipelines with intelligent suggestions based on recent usage and context.

<context_awareness>
This workflow may receive partial context from ambiguous natural language:

- User said "start something on auth" → We know session="auth" but not the stage
- User said "run a quick loop" → We know they want something fast but not what

Use this context to pre-filter or highlight relevant options.
</context_awareness>

<process>
## Step 1: Gather Available Options

Run these discovery commands:

```bash
# Get all stages with descriptions
for stage in scripts/stages/*/; do
  name=$(basename "$stage")
  desc=$(grep -m1 "^description:" "$stage/stage.yaml" 2>/dev/null | cut -d: -f2- | xargs)
  termination=$(grep -A1 "^termination:" "$stage/stage.yaml" 2>/dev/null | grep "type:" | cut -d: -f2 | xargs)
  echo "$name|$desc|$termination"
done

# Get all pipelines with descriptions
for pipeline in scripts/pipelines/*.yaml; do
  [ -f "$pipeline" ] || continue
  name=$(basename "$pipeline")
  desc=$(grep -m1 "^description:" "$pipeline" 2>/dev/null | cut -d: -f2- | xargs)
  stages=$(grep -c "^  - name:" "$pipeline" 2>/dev/null || echo "?")
  echo "$name|$desc|${stages} stages"
done
```

## Step 2: Check Recent Sessions

```bash
# Find sessions from last 7 days
find .claude/pipeline-runs -maxdepth 1 -type d -mtime -7 2>/dev/null | while read dir; do
  session=$(basename "$dir")
  [ "$session" = "pipeline-runs" ] && continue

  # Get stage type and last status
  state_file="$dir/state.json"
  if [ -f "$state_file" ]; then
    stage=$(jq -r '.stage // "unknown"' "$state_file")
    status=$(jq -r '.status // "unknown"' "$state_file")
    iteration=$(jq -r '.iteration // 0' "$state_file")
    echo "$session|$stage|$status|iteration $iteration"
  fi
done | sort -t'|' -k1 -r | head -10
```

## Step 3: Check Currently Running

```bash
# Active sessions
tmux list-sessions 2>/dev/null | grep -E "^pipeline-" | while read line; do
  session=$(echo "$line" | cut -d: -f1 | sed 's/^pipeline-//')
  echo "$session (running)"
done
```

## Step 4: Present Options

Organize discoveries into categories and present with AskUserQuestion:

```json
{
  "questions": [{
    "question": "Select a stage or pipeline to start:",
    "header": "Pipeline",
    "options": [
      {"label": "ralph (Recommended)", "description": "Work through beads until queue empty"},
      {"label": "refine.yaml", "description": "5+5 plan and task refinement"},
      {"label": "improve-plan", "description": "Iterative plan improvement with consensus"},
      {"label": "See All Stages", "description": "Browse the full list of available stages"}
    ],
    "multiSelect": false
  }]
}
```

**Dynamic option building:**
- First option: Most recently used stage/pipeline (if available)
- Next 2-3: Popular choices (ralph, refine.yaml, improve-plan)
- Last: "See All" to browse complete list

## Step 5: Handle "See All" Selection

If user selects "See All Stages" or "See All Pipelines", show complete categorized list:

**Stages by Category:**

| Category | Stages | Best For |
|----------|--------|----------|
| **Work** | ralph | Implementing beads tasks |
| **Planning** | improve-plan, research-plan, tdd-plan-refine | Refining plans/designs |
| **Tasks** | refine-tasks, tdd-create-beads | Breaking down and improving tasks |
| **Review** | elegance, code-review, test-review | Code quality and review |
| **Discovery** | bug-discovery, idea-wizard, test-scanner | Finding issues and ideas |
| **Documentation** | readme-sync, doc-updater | Keeping docs current |
| **Testing** | test-analyzer, test-planner, tdd-work | Test coverage and quality |

**Pipelines:**

| Pipeline | Description | Stages |
|----------|-------------|--------|
| refine.yaml | Plan + task refinement | improve-plan → refine-tasks |
| quick-refine.yaml | Fast refinement (3+3) | improve-plan → refine-tasks |
| deep-refine.yaml | Thorough refinement (8+8) | improve-plan → refine-tasks |
| ideate.yaml | Generate improvement ideas | idea-wizard |
| bug-hunt.yaml | Full bug hunting workflow | discover → triage → refine → fix |
| tdd-implement.yaml | TDD implementation flow | plan → create-beads → work |

Then ask again with full list.

## Step 6: Route to Launch

Once a stage or pipeline is selected, route to `workflows/launch.md` with the selection.

Pass context:
- `selected_type`: "stage" or "pipeline"
- `selected_name`: e.g., "ralph" or "refine.yaml"
- `recent_session`: If resuming a recent session
</process>

<smart_suggestions>
## Suggestion Logic

**Priority order for default recommendation:**

1. **Crashed session needing resume** - If found, suggest resuming
2. **Recent successful pattern** - Same stage type as last 3 successful runs
3. **Context clues:**
   - Beads exist with `pipeline/*` label → suggest ralph
   - Plan file mentioned → suggest improve-plan
   - Bug discussed → suggest bug-discovery
4. **Safe default** - ralph (most common use case)

## Future Marketplace Integration

When marketplace is implemented, discovery will also scan:
- `.claude/marketplace/stages/` - Community stages
- `.claude/marketplace/pipelines/` - Community pipelines
- `.claude/team/` - Team-shared configurations

Each will have metadata for filtering and search.
</smart_suggestions>

<success_criteria>
- [ ] All local stages discovered and categorized
- [ ] All local pipelines discovered
- [ ] Recent sessions identified with status
- [ ] Running sessions highlighted
- [ ] Smart default suggested based on context
- [ ] User can browse full list if needed
- [ ] Selection routed to launch workflow
</success_criteria>
