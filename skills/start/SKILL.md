---
name: start
description: Universal pipeline launcher with discovery, smart suggestions, and quick-start capabilities. Browse available stages and pipelines, see recent sessions, and launch with minimal friction.
---

<objective>
Make starting any pipeline as easy as possible. Discover what's available, suggest the most relevant options, and launch with intelligent defaults. Designed for extensibility toward a future marketplace of community stages and pipelines.
</objective>

<essential_principles>
## Discovery First

Users often don't remember exact names. The launcher should:
- Show what's available without requiring memorization
- Suggest based on recent usage and context
- Allow quick-start for users who know what they want

## Smart Defaults

Reduce friction by inferring:
- Session names from context (beads label, current branch, etc.)
- Reasonable iteration counts based on stage type
- Provider/model from user preferences or stage defaults

## Marketplace Ready

Architecture supports future extension:
- Local stages: `scripts/stages/`
- Local pipelines: `scripts/pipelines/`
- Future marketplace: `.claude/marketplace/{stages,pipelines}/`
- Future team shared: `.claude/team/{stages,pipelines}/`
</essential_principles>

<usage>
Users type natural language after `/start`:

```
/start                                              # Interactive discovery
/start a ralph loop on auth for 25 iterations       # Natural language
/start refinement on my-project                     # Infers pipeline type
/start resume the auth session                      # Resume crashed session
/start bug discovery on the payment module          # Stage + context
```
</usage>

<intake>
**Users speak naturally.** Parse their intent from natural language.

## Examples

| User Says | What To Do |
|-----------|------------|
| "a ralph loop on auth for 25 iterations" | `./scripts/run.sh ralph auth 25` |
| "refinement on my-project" | `./scripts/run.sh pipeline refine.yaml my-project` |
| "resume the auth session" | `./scripts/run.sh ralph auth 25 --resume` |
| "bug discovery on payment" | `./scripts/run.sh bug-discovery payment 8` |
| "quick refinement on api-refactor" | `./scripts/run.sh pipeline quick-refine.yaml api-refactor` |
| "generate ideas for the homepage" | `./scripts/run.sh idea-wizard homepage 5` |

## Missing Information

If something's missing, infer from context (git branch, beads labels) or ask.

## Empty Input

If user just types `/start` with no arguments, go to `workflows/discover.md` for interactive browsing.
</intake>

<routing>
| Detected Intent | Workflow |
|-----------------|----------|
| Empty input / browsing | `workflows/discover.md` |
| Resume request | Direct: `./scripts/run.sh {stage} {session} {max} --resume` |
| Clear stage + session + iterations | Direct launch command |
| Stage identified, missing details | `workflows/launch.md` (gather remaining) |
| Ambiguous intent | `workflows/discover.md` (with context) |

## Direct Launch (Skip Workflows)

If you can extract all required info from natural language, launch directly:

```bash
# All info present: stage=ralph, session=auth, max=25
./scripts/run.sh ralph auth 25

# Resume: action=resume, session=auth
./scripts/run.sh ralph auth 25 --resume
```

## Workflow Handoff

Pass extracted context to workflows:

```
Extracted: stage=improve-plan, session=billing (iterations missing)
→ workflows/launch.md with context: {stage: "improve-plan", session: "billing"}
```

**After reading the workflow, follow it exactly.**
</routing>

<quick_reference>
## Discovery Commands

```bash
# List stages
ls scripts/stages/

# List pipelines
ls scripts/pipelines/*.yaml 2>/dev/null | xargs -n1 basename

# Recent sessions (last 7 days)
find .claude/pipeline-runs -maxdepth 1 -type d -mtime -7 | sort -r

# Check for running sessions
tmux list-sessions 2>/dev/null | grep -E "^pipeline-"
```

## Launch Commands

```bash
# Single-stage
./scripts/run.sh {stage} {session} {max}

# Multi-stage pipeline
./scripts/run.sh pipeline {file}.yaml {session}

# With options
./scripts/run.sh {stage} {session} {max} \
  --provider=codex \
  --model=opus \
  --context="Focus on X" \
  --input=docs/plan.md
```

## Stage Categories

| Category | Stages | Termination |
|----------|--------|-------------|
| **Work** | ralph | Fixed (beads queue) |
| **Refinement** | improve-plan, refine-tasks | Judgment (consensus) |
| **Review** | elegance, code-review, test-review | Judgment |
| **Discovery** | bug-discovery, idea-wizard, test-scanner | Fixed |
| **Research** | research-plan, tdd-plan-refine | Judgment |
</quick_reference>

<workflows_index>
| Workflow | Purpose |
|----------|---------|
| discover.md | Browse available stages/pipelines with smart suggestions |
| launch.md | Configure and launch a selected stage or pipeline |
</workflows_index>

<success_criteria>
A successful `/start` invocation:
- [ ] User finds what they want quickly (discovery or quick-start)
- [ ] Smart suggestions reduce decision fatigue
- [ ] Session launches successfully in tmux
- [ ] Clear confirmation with monitoring instructions
- [ ] No orphaned resources on failure
</success_criteria>
