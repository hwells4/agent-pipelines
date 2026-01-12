# Loop Architecture v2: Unified Stage Model

## Executive Summary

This document outlines a comprehensive refactoring of the Loop Agents architecture. The core change: **stage becomes the fundamental unit**. We collapse redundant concepts, simplify the variable model, and standardize output handling. The changes address gaps discovered when agents incorrectly built pipelines due to inconsistent documentation and ambiguous interfaces.

---

## System Overview

### What Loop Agents Is

Loop Agents is a [Ralph loop](https://ghuntley.com/ralph/) orchestrator for Claude Code. It runs autonomous, multi-iteration agent workflows in tmux sessions.

**Core insight:** LLM context degrades over long conversations. Loop Agents solves this by spawning a **fresh Claude instance for each iteration**. Each agent reads accumulated progress from a file, does work, appends its findings, and exits. The next iteration starts fresh with full context capacity.

### Execution Model

```
┌─────────────────────────────────────────────────────────────┐
│  tmux session: loop-{session-name}                          │
│                                                             │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐     │
│  │ Iteration 1 │ →  │ Iteration 2 │ →  │ Iteration 3 │ ... │
│  │ Fresh Claude│    │ Fresh Claude│    │ Fresh Claude│     │
│  └──────┬──────┘    └──────┬──────┘    └──────┬──────┘     │
│         │                  │                  │             │
│         ▼                  ▼                  ▼             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │                    progress.md                       │   │
│  │  (accumulated context - each agent reads & appends)  │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

Each iteration:
1. Engine resolves prompt template with variables
2. Fresh Claude spawns with resolved prompt
3. Agent reads progress file, does work, appends concise findings
4. Agent writes status to status.json
5. Engine checks termination condition
6. If not complete → next iteration; if complete → stage ends

### Key Concepts

**Session**: A named execution run. Sessions are isolated - each has its own state, stages, and tmux session. Example: `./scripts/run.sh work auth 25` creates session "auth".

**Pipeline**: One or more stages executed in sequence. **Everything is a pipeline.** A single-stage run is just a one-stage pipeline.

**Stage**: The fundamental unit. A stage definition includes: prompt template, termination strategy, output configuration. Stages are reusable across pipelines.

**Iteration**: A single Claude agent execution within a stage. Fresh agent each time.

**Beads**: External task tracking system (via `bd` CLI). Work stages pull tasks tagged `loop/{session}` and close them as completed.

### Why Fresh Agents?

Claude's performance degrades as context grows:
- Attention becomes diluted across thousands of tokens
- Earlier instructions get "forgotten"
- Reasoning quality decreases

Fresh agents solve this:
- Each starts with full context capacity
- Progress file provides curated context (not raw conversation)
- Agents can work indefinitely without degradation

### Philosophy

1. **Everything is a pipeline** - Unified model, no special cases
2. **Stage is the fundamental unit** - Not "loop" - that's the execution pattern
3. **Fresh agent per iteration** - Prevents context degradation
4. **Two-agent consensus** - Judgment termination requires 2 consecutive agents to agree
5. **Progress file = append-only curated context** - Concise entries, all preserved
6. **Explicit contracts** - Stage-to-stage communication via file manifests, not content injection
7. **File paths over content injection** - Agents open what they need, avoids context bloat

---

## Problem Statement

### What Happened

An agent was asked to build a pipeline to analyze the codebase. It made several critical mistakes:

1. **Treated loops and pipelines as separate concepts** - The architecture unified them, but documentation didn't reflect this
2. **Output went to gitignored location only** - Findings "disappeared" because there was no standardized tracked output
3. **No iteration-to-iteration document flow** - Each iteration could only communicate via the progress file
4. **Taxonomy was unclear** - Agent didn't know what type of stage to create or what termination strategy to use

### Root Causes Identified

1. **Two overlapping interface layers** - Progress vs outputs vs tracked outputs caused confusion
2. **Content injection variables** - `${INPUTS}` as full content would recreate context degradation
3. **Filesystem inconsistency** - Single-stage vs multi-stage had different file structures
4. **Redundant variables** - 8 variables with aliases, claimed to be 6
5. **No machine-readable status** - Parsing `PLATEAU: true` from freeform text is brittle
6. **No guardrails** - No max_iterations, max_failures, or timeout limits
7. **Terminology confusion** - "Loop" used for both the definition and the execution pattern

---

## Current Architecture (v1)

### File Structure

```
scripts/
  loops/                          # Stage definitions (misnamed)
    work/
      loop.yaml                   # Stage config (misnamed)
      prompt.md
  pipelines/
    full-refine.yaml

.claude/pipeline-runs/{session}/
  state.json
  progress-{session}.md           # Single-stage only (inconsistent)
  stage-{N}-{name}/               # Multi-stage only
    progress.md
    output.md
```

### Current Variables (10, with 4 redundant)

| Variable | Notes |
|----------|-------|
| `${SESSION}` | Session identifier |
| `${SESSION_NAME}` | Redundant alias |
| `${ITERATION}` | 1-based iteration |
| `${INDEX}` | 0-based, never used |
| `${PROGRESS}` | Progress file path |
| `${PROGRESS_FILE}` | Redundant alias |
| `${OUTPUT}` | Internal output |
| `${OUTPUT_PATH}` | Tracked output (NEW, ambiguous with OUTPUT) |
| `${INPUTS}` | Content injection (causes bloat) |
| `${PERSPECTIVE}` | Never used |

### Problems

1. OUTPUT vs OUTPUT_PATH ambiguity
2. Content injection in INPUTS causes context bloat
3. Single-stage filesystem differs from multi-stage
4. Text scraping for status (`PLATEAU: true`)
5. No hard guardrails
6. "Loop" terminology confusion

---

## Proposed Architecture (v2)

### Core Decision: Stage is the Fundamental Unit

**Rename `scripts/loops/` → `scripts/stages/`**

A "loop" is the execution pattern (iterate until termination). A "stage" is the definition (prompt + termination + output config). The terminology now matches reality.

```
scripts/
  stages/                         # Renamed from loops/
    work/
      stage.yaml                  # Renamed from loop.yaml
      prompt.md
    improve-plan/
      stage.yaml
      prompt.md
  pipelines/
    full-refine.yaml
```

### Unified File Structure (No Special Cases)

**Always use stage directories, even for single-stage runs:**

```
.claude/pipeline-runs/{session}/
  state.json                      # Pipeline state
  stage-01-{name}/                # Always present
    progress.md                   # Append-only context
    output.md                     # Or output-{N}.md for per-iteration
    status.json                   # Machine-readable status
  stage-02-{name}/                # If multi-stage
    ...
```

No more `progress-{session}.md` at root. One contract.

### Variable Model (6 Core + 3 Manifests)

**Core variables:**

| Variable | Type | Description |
|----------|------|-------------|
| `${SESSION}` | string | Session identifier |
| `${ITERATION}` | number | 1-based iteration number |
| `${STAGE_DIR}` | path | Current stage directory |
| `${PROGRESS}` | path | Progress file (append-only) |
| `${OUTPUT}` | path | Primary artifact for this iteration |
| `${STATUS}` | path | JSON status file |

**File manifests (paths, not content):**

| Variable | Type | Description |
|----------|------|-------------|
| `${PREVIOUS_OUTPUT_FILES}` | paths | Outputs from prior iterations of this stage |
| `${INPUT_FILES}` | paths | Outputs from previous stage |
| `${INPUT_FILES.name}` | paths | Outputs from named stage |

**Optional (for queue-based stages):**

| Variable | Type | Description |
|----------|------|-------------|
| `${ITEM}` | string | Current item being processed |

**Removed:**
- `${SESSION_NAME}` - redundant alias
- `${PROGRESS_FILE}` - redundant alias
- `${INDEX}` - never used
- `${PERSPECTIVE}` - never used
- `${OUTPUT_PATH}` - collapsed into `${OUTPUT}`
- `${INPUTS}` - replaced with file manifests
- `${PREVIOUS_OUTPUTS}` - replaced with file manifests

### Key Simplification: One Output Location

**Before (ambiguous):**
```yaml
output_path: docs/plan.md   # Tracked
# Plus ${OUTPUT} pointing somewhere else (internal)
```

**After (clear):**
```yaml
output:
  mode: single              # or per-iteration
  path: docs/plan.md        # This IS ${OUTPUT}
```

`${OUTPUT}` always points to the primary artifact. If you want it tracked, set path to a repo location. If you want it internal, set path to `.claude` or omit (defaults to stage directory).

### File Paths Instead of Content Injection

**Why:** Injecting full content of previous outputs recreates context degradation inside the prompt. Fresh-agent advantage is lost.

**Before:**
```
${INPUTS} → "# Full content of file 1\n...\n# Full content of file 2\n..."
```

**After:**
```
${INPUT_FILES} → "stage-01-ideas/output-1.md\nstage-01-ideas/output-2.md"
```

Agents open what they need. The orchestrator stays lean.

### Iteration-to-Iteration vs Stage-to-Stage

```
Pipeline
├── Stage 1 (ideas) ─────────────────────────────────────────┐
│   ├── Iteration 1 → output-1.md                            │
│   ├── Iteration 2 → reads ${PREVIOUS_OUTPUT_FILES}         │
│   │                 (output-1.md)                          │
│   │                 writes output-2.md                     │
│   └── Iteration 3 → reads ${PREVIOUS_OUTPUT_FILES}         │
│                     (output-1.md, output-2.md)             │
│                     writes output-3.md                     │
│                                                            │
├── Stage 2 (synthesize) ────────────────────────────────────┤
│   └── Iteration 1 → reads ${INPUT_FILES}                   │
│                     (all outputs from Stage 1)             │
│                     writes output.md                       │
│                                                            │
└── Stage 3 (refine) ────────────────────────────────────────┘
    ├── Iteration 1 → reads ${INPUT_FILES}
    │                 (Stage 2's output)
    └── Iteration 2 → reads ${PREVIOUS_OUTPUT_FILES}
                      (Iteration 1's output)
```

- **`${PREVIOUS_OUTPUT_FILES}`** = iteration-to-iteration within a stage
- **`${INPUT_FILES}`** = stage-to-stage within a pipeline

### Machine-Readable Status

**Before (brittle text scraping):**
```markdown
Based on my analysis, I believe we've reached a good stopping point.

PLATEAU: true
REASONING: No further improvements identified.
```

**After (JSON status file):**

Each iteration writes to `${STATUS}`:
```json
{
  "plateau": true,
  "reasoning": "No further improvements identified",
  "items_completed": 3,
  "errors": []
}
```

Engine reads JSON, not text. Prompts can still output human-readable text.

### Unified Termination Configuration

**Before (multiple top-level blocks):**
```yaml
completion: plateau
min_iterations: 2
output_parse: "plateau:PLATEAU reasoning:REASONING"
```

**After (single object):**
```yaml
termination:
  type: judgment
  min_iterations: 2
  consensus_field: plateau    # Field in status.json
```

Termination types:

| Type | Triggers When |
|------|---------------|
| `queue` | External queue empty (beads or items) |
| `judgment` | 2 consecutive iterations report `{consensus_field}: true` |
| `fixed` | Exactly N iterations completed |

### Tags for Classification

**Before (required runtime field):**
```yaml
target: document  # Required, but doesn't affect execution
```

**After (optional metadata):**
```yaml
tags: [document, generation]  # For linting, docs, humans
```

Tags don't affect execution. They're metadata for tooling and documentation.

### Guardrails

Every stage has hard limits:

```yaml
guardrails:
  max_iterations: 50          # Hard stop
  max_runtime_seconds: 7200   # 2 hour timeout
  max_failures: 3             # Consecutive failures before abort
```

These are safety rails, not termination strategies. They apply regardless of termination type.

### Optional Verification Hooks

For stages that modify code:

```yaml
verify:
  - npm test
  - ruff check .
```

Results captured to `stage-dir/verify-{iteration}.log`. Prompts can reference these.

### Progress File Contract

**Append-only, concise entries.**

The progress file is the curated context that fresh agents read. All entries are preserved. Agents write concise, valuable summaries - not logs or dumps.

```markdown
## Iteration 1
- Reviewed auth module, found 3 issues
- Fixed rate limiting bug in login endpoint
- TODO: Session expiry still needs work

## Iteration 2
- Addressed session expiry
- All auth tests passing
- Ready for review
```

---

## Schema Definitions

### stage.yaml

```yaml
# Identity
name: work                        # Required
description: Implement code changes from beads
tags: [code]                      # Optional metadata

# Termination
termination:
  type: queue | judgment | fixed  # Required

  # For type: queue
  source: beads | items           # What queue to check
  label: loop/${SESSION}          # Beads label template
  items_file: items.txt           # For items source

  # For type: judgment
  min_iterations: 2               # Check after this many
  consensus_field: plateau        # Field in status.json

  # For type: fixed
  iterations: 5                   # Exact count

# Output
output:
  mode: single | per-iteration    # Default: single
  path: .claude                   # Default: stage directory
                                  # Or: docs/plan-${SESSION}.md (tracked)

# Guardrails
guardrails:
  max_iterations: 100             # Default: 100
  max_runtime_seconds: 7200       # Default: 2 hours
  max_failures: 3                 # Default: 3

# Optional
verify: []                        # Commands to run after each iteration
delay: 3                          # Seconds between iterations
model: opus | sonnet              # Default: inherit from parent

# Prompt
prompt: prompt.md                 # Default: prompt.md
```

### pipeline.yaml

```yaml
name: full-refine
description: Refine plan then beads

# Pipeline-level guardrails (apply to all stages)
guardrails:
  max_runtime_seconds: 14400      # 4 hours total

stages:
  - name: plan                    # Stage instance name
    stage: improve-plan           # References scripts/stages/improve-plan/
    runs: 5                       # Max iterations for this instance

  - name: beads
    stage: refine-beads
    runs: 5
    output:
      path: docs/beads-${SESSION}.md  # Override output location
```

### Single-Stage Execution

```bash
./scripts/run.sh work auth 25
```

Internally creates:
```yaml
stages:
  - name: work
    stage: work
    runs: 25
```

Same engine, same file structure, no special cases.

---

## Example: Complex Pipeline

```yaml
name: full-ideation
description: Generate ideas, synthesize, refine

guardrails:
  max_runtime_seconds: 7200

stages:
  # Stage 1: Idea Generation (accumulate pattern)
  - name: ideas
    stage: idea-generator
    runs: 5
    output:
      mode: per-iteration         # Creates output-1.md, output-2.md, etc.
      path: .claude               # Internal

  # Stage 2: Synthesis (single output)
  - name: synthesize
    stage: synthesizer
    runs: 1
    output:
      mode: single
      path: docs/plan-${SESSION}.md  # Tracked

  # Stage 3: Refinement (edit in place)
  - name: refine
    stage: refiner
    runs: 10                      # Max, will stop earlier on plateau
    output:
      mode: single
      path: docs/plan-${SESSION}.md  # Same file, refined
    verify:
      - markdownlint docs/plan-${SESSION}.md
```

### How It Flows

```
Stage 1: ideas (5 iterations, per-iteration mode)
├── Iter 1: ${PREVIOUS_OUTPUT_FILES}=[] → writes output-1.md
├── Iter 2: ${PREVIOUS_OUTPUT_FILES}=[output-1.md] → writes output-2.md
├── Iter 3: ${PREVIOUS_OUTPUT_FILES}=[output-1.md, output-2.md] → writes output-3.md
└── ...

Stage 2: synthesize (1 iteration)
└── Iter 1: ${INPUT_FILES}=[all 5 idea files] → writes docs/plan-{session}.md

Stage 3: refine (judgment termination, max 10)
├── Iter 1: ${INPUT_FILES}=[docs/plan-{session}.md] → edits file, status.json: {plateau: false}
├── Iter 2: edits file, status.json: {plateau: false}
├── Iter 3: edits file, status.json: {plateau: true}
├── Iter 4: edits file, status.json: {plateau: true}  ← 2 consecutive, STOP
└── (iterations 5-10 never run)
```

---

## Design Decisions

### Why Stage as Fundamental Unit?

"Loop" describes execution (iterate until done). "Stage" describes the definition (prompt + termination + output). Using "stage" as the fundamental unit:

1. Eliminates terminology confusion
2. Matches pipeline terminology naturally
3. The code already uses "stage" internally
4. "Loop Agents" remains the project name (execution pattern)

### Why File Paths Instead of Content?

If `${INPUTS}` injects full content of 5 previous outputs, each 2000 tokens, that's 10k tokens before the agent even starts. Fresh-agent advantage is lost.

File manifests let agents:
- See what's available
- Open only what they need
- Summarize or excerpt selectively
- Stay within context budget

### Why JSON Status Instead of Text Parsing?

Text parsing is brittle:
- What if agent writes "PLATEAU: true" in the middle of a sentence?
- What if formatting varies?
- What about structured data like error counts?

JSON is unambiguous. Engine reads `status.json`, prompts output human-readable text.

### Why Always Use Stage Directories?

Single-stage runs had `progress-{session}.md` at root. Multi-stage had `stage-01-name/progress.md`. Two contracts means agents learn the wrong one.

One contract: always `stage-{N}-{name}/`. Even for single-stage runs.

### Why Keep Progress Append-Only?

The append-only progress file is core to Loop Agents. It's the curated context that enables fresh agents to pick up where predecessors left off. All entries preserved, written concisely.

Bloat is controlled by prompt contract, not by making progress editable.

### Why Guardrails Separate from Termination?

Termination is "when should we stop because we're done?"
Guardrails are "when should we stop because something's wrong?"

They're orthogonal. A judgment stage might plateau at iteration 3, but guardrails ensure we never exceed 100 iterations or 2 hours even if something breaks.

---

## Implementation Plan

### Phase 1: Core Renaming

1. Rename `scripts/loops/` → `scripts/stages/`
2. Rename `loop.yaml` → `stage.yaml` in each stage
3. Update engine.sh to look for `stages/` and `stage.yaml`
4. Update run.sh for new paths

### Phase 2: File Structure Unification

5. Always create `stage-{N}-{name}/` directories
6. Remove single-stage special case (`progress-{session}.md` at root)
7. Add `status.json` creation per iteration

### Phase 3: Variable Simplification

8. Remove deprecated variables: `SESSION_NAME`, `PROGRESS_FILE`, `INDEX`, `PERSPECTIVE`
9. Remove `OUTPUT_PATH` (collapsed into `OUTPUT`)
10. Replace `${INPUTS}` with `${INPUT_FILES}` (paths)
11. Replace `${PREVIOUS_OUTPUTS}` with `${PREVIOUS_OUTPUT_FILES}` (paths)
12. Add `${STAGE_DIR}` and `${STATUS}` variables

### Phase 4: Schema Updates

13. Implement unified `termination:` config object
14. Implement `output:` config object (mode + path)
15. Implement `guardrails:` section
16. Implement optional `verify:` hooks
17. Change `target` to `tags`

### Phase 5: Status Channel

18. Create status.json writer in engine
19. Update termination strategies to read status.json
20. Update prompts to write status.json instead of text markers

### Phase 6: Validation & Documentation

21. Update linter for new schema
22. Update CLAUDE.md
23. Update skill documentation (pipeline-builder, sessions)
24. Migrate all existing stages to new schema

### Phase 7: Cleanup

25. Remove dead code (all-items.sh if not implementing items, duplicates)
26. Remove unused variable handling from resolve.sh
27. Final testing of all stage types

---

## Migration Guide

### Stage Definition Migration

```yaml
# Before (loop.yaml)
name: idea-wizard
description: Generate ideas
completion: fixed-n
delay: 1
output_path: docs/ideas-${SESSION}.md

# After (stage.yaml)
name: idea-wizard
description: Generate ideas
tags: [document, generation]

termination:
  type: fixed
  iterations: 5

output:
  mode: single
  path: docs/ideas-${SESSION}.md

guardrails:
  max_iterations: 10
  max_failures: 3

delay: 1
```

### Prompt Migration

```markdown
# Before
Session: ${SESSION_NAME}
Progress: ${PROGRESS_FILE}
Previous: ${INPUTS}

# After
Session: ${SESSION}
Progress: ${PROGRESS}
Previous files: ${INPUT_FILES}

(Agent reads files as needed)
```

### Pipeline Migration

```yaml
# Before
stages:
  - name: plan
    loop: improve-plan
    runs: 5

# After
stages:
  - name: plan
    stage: improve-plan
    runs: 5
```

---

## Success Criteria

1. **One fundamental unit** - Stage, not stage + loop
2. **One output location** - `${OUTPUT}`, no ambiguity
3. **No content injection** - File manifests preserve fresh-agent advantage
4. **One filesystem contract** - Always stage directories
5. **Machine-readable status** - JSON, not text scraping
6. **Hard guardrails** - Can't run forever
7. **Zero terminology confusion** - Stage = definition, loop = execution pattern

---

## Appendix: Quick Reference

### Variables

```
${SESSION}              Session identifier
${ITERATION}            1-based iteration number
${STAGE_DIR}            Current stage directory
${PROGRESS}             Progress file path (append-only)
${OUTPUT}               Primary artifact path
${STATUS}               Status JSON path

${PREVIOUS_OUTPUT_FILES}   Paths to prior iteration outputs
${INPUT_FILES}             Paths to previous stage outputs
${INPUT_FILES.name}        Paths to named stage outputs
${ITEM}                    Current item (queue stages only)
```

### Termination Types

```
queue     - Stop when external queue empty (beads/items)
judgment  - Stop when 2 consecutive iterations report consensus_field: true
fixed     - Stop after exactly N iterations
```

### Output Modes

```
single        - All iterations write to same file (edit pattern)
per-iteration - Each iteration writes output-{N}.md (accumulate pattern)
```
