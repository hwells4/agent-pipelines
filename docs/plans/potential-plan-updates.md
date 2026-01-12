## What you already got right

* Stage as the sole reusable definition unit is the correct anchor.
* Always-on stage directories eliminates the biggest “two contracts” failure mode.
* Paths instead of content injection preserves the fresh-agent advantage.
* Machine-readable status is mandatory, and you correctly made it first-class.
* Guardrails separated from “done” termination is the right model.

The remaining elegance problems are not conceptual. They’re interface surface area, duplicated limits, and missing contracts for long-running runs, multi-artifact work, and failure classification.

## Minimal kernel you can reduce to

You can make the whole system reducible to one loop invariant:

Engine writes context → Agent reads context + filesystem → Agent writes output + status → Engine decides next step

Everything else becomes metadata.

The minimum set of runtime concepts that still supports all your use cases:

1. **Session**
2. **Pipeline** as an ordered list of stage instances
3. **Stage template** as prompt + default policies
4. **Iteration**
5. **Context manifest** (single JSON file per iteration)
6. **Status** (single JSON file per iteration)
7. **Primary artifact** (the one thing other stages can rely on)
8. **Optional queue item** (for beads or item lists)

Everything else can collapse into the manifest.

## 14 concrete simplifications

### 1) Collapse almost all variables into one `${CTX}` manifest

Right now you still have a variable taxonomy problem: `${INPUT_FILES}`, `${INPUT_FILES.name}`, `${PREVIOUS_OUTPUT_FILES}`, plus core variables.

Replace that with one engine-written JSON manifest, and keep only a tiny stable set of env vars:

* `${CTX}` path to manifest JSON
* `${PROGRESS}` (or `${HANDOFF}`) path
* `${OUTPUT}` path
* `${STATUS}` path
* `${ITEM}` only when present

Everything else goes inside `${CTX}`.

Manifest shape example:

```json
{
  "session": "auth",
  "pipeline": "full-ideation",
  "stage": { "index": 1, "id": "ideas", "template": "idea-generator", "dir": "..." },
  "iteration": 3,
  "paths": {
    "session_dir": "...",
    "stage_dir": "...",
    "handoff": ".../handoff.md",
    "progress_log": ".../progress.log.md",
    "output": ".../output.md",
    "status": ".../iterations/003/status.json"
  },
  "inputs": {
    "previous_stage": [".../stage-00-init/output.md"],
    "by_stage": { "ideas": [".../stage-01-ideas/iterations/001/output.snapshot.md"] },
    "previous_outputs": [".../iterations/001/output.snapshot.md", ".../iterations/002/output.snapshot.md"]
  },
  "queue_item": { "id": "bd-123", "title": "Fix auth expiry", "source": "beads" },
  "limits": { "max_iterations": 50, "max_runtime_seconds": 7200 }
}
```

This single change removes most doc ambiguity and eliminates templated string-list bugs.

### 2) Standardize status to a single required `decision` enum

Your `consensus_field` is avoidable complexity.

Make status schema fixed and universal:

```json
{
  "decision": "continue",
  "stop_reason": null,
  "summary": "One tight paragraph",
  "work": { "items_completed": [], "files_touched": [], "artifacts": [] },
  "errors": []
}
```

Valid `decision` values:

* `continue`
* `stop`
* `error`

Now “judgment termination” becomes “two consecutive iterations wrote `decision=stop`”, with optional `min_iterations`.

No stage-specific field naming. No consensus_field. No prompt variance.

### 3) Delete `output.mode` and replace with engine-side history snapshots

`single` vs `per-iteration` is a schema knob that leaks an internal storage decision into every stage definition and every prompt.

Instead:

* Agent always writes to `${OUTPUT}` (stable path).
* Engine optionally snapshots `${OUTPUT}` after each iteration into `iterations/NNN/output.snapshot.*`.
* The manifest exposes `inputs.previous_outputs` as the list of snapshots.

That gives you both behaviors:

* “Refine in place” uses the stable `${OUTPUT}`.
* “Accumulate alternatives” uses snapshot list without forcing the agent to invent filenames.

Stage-to-stage can choose “latest snapshot” or “all snapshots” via input selection policy.

### 4) Make “what counts as failure” explicit and split failure types

`max_failures` is currently underspecified. A verify fail is not the same as “agent crashed” or “status.json missing”.

Split these counters in engine state:

* `max_consecutive_agent_errors`
  Missing status, malformed status, tool crash, timeout, non-zero orchestrator exit.
* `max_consecutive_verify_failures`
  Tests failing.
* `max_consecutive_task_failures`
  Queue item attempted but not completed.

This prevents premature abort during legitimate debugging iterations.

### 5) Replace append-only progress as the read target with a compact handoff file

Append-only progress as the read source will eventually degrade, even if curated. Long sessions and queue work will bloat it.

Keep both:

* `progress.log.md` append-only archive, never read by default
* `handoff.md` compact rolling context, overwritten each iteration

Agents read `handoff.md` and update it. Engine preserves history in `progress.log.md` by appending the prior handoff plus metadata.

This preserves your “all entries preserved” principle without turning the read contract into a time bomb.

### 6) Make inputs selection a first-class policy

Right now `${INPUT_FILES}` implicitly means “all outputs from previous stage”. That is often wrong for refinement stages and creates accidental bloat.

Add a small input policy:

* `inputs.select: latest | all | glob`
* `inputs.from: previous | <stage-id>`

Default:

* `latest` from previous stage

Override to `all` only for synthesis stages.

### 7) Generalize queue handling into a provider interface, not a termination subtype

You currently embed queue specifics under `termination`.

Instead define:

```yaml
queue:
  provider: beads | file | cmd
  claim: one
  ack: on_success
  config: ...
```

Then `termination.type: queue` just means “stop when provider empty”.

This cleanly extends to GitHub Issues, Jira, Linear, a CSV file, or a custom script without touching termination semantics.

### 8) Add an iteration artifact manifest for multi-file work

A single `${OUTPUT}` is not enough for code work, research packs, and generators that create multiple files.

Per iteration, write `iterations/NNN/artifacts.json`:

```json
{
  "primary": "output.snapshot.md",
  "files": ["output.snapshot.md", "refs.bib", "notes.md"],
  "patch": "changes.patch"
}
```

Engine merges artifacts into `${CTX}`. Next stages can consume a set, not a single path.

This prevents the “findings disappeared” class of errors in a more general way than “tracked output path”.

### 9) Make stage instances addressable by stable `id`, not human `name`

You have `name` and also stage reference names. Humans will collide names.

Use:

* `id` for stable machine reference in pipeline
* `template` for stage template directory
* optional `label` for display

Example:

```yaml
- id: ideas
  template: idea-generator
  label: Idea generation
```

Then `${CTX.inputs.by_stage.ideas}` is stable.

### 10) Collapse `runs` into `max_iterations` everywhere

`runs` duplicates `guardrails.max_iterations` conceptually.

Use only:

* `max_iterations` as a stage-instance cap
* `termination.type=fixed` with `iterations` when exact count is desired

Single-stage CLI argument becomes `--max-iterations`.

### 11) Restrict template interpolation to a safe whitelist

Interpolation of arbitrary strings inside YAML lists and paths becomes a footgun.

Allow `${SESSION}` expansion only in:

* output paths
* queue label strings
* verify command strings

Everything else comes from `${CTX}`.

### 12) Make verify results part of status, not just logs

Keep verify logs, but also force a small verify object into status:

```json
"verify": { "ran": true, "passed": false, "log": "verify-003.log" }
```

This allows termination policies like “plateau only valid if verify passed”, without scraping logs.

### 13) Encode “two-agent consensus” as a generic engine policy

Do not bake “2 consecutive” into narrative docs only.

Define:

* `termination.consensus: 2` default for judgment
* Engine checks last N statuses `decision=stop`

Now you can reuse it for other consensus gates later.

### 14) Make restart and resume semantics deterministic

You need explicit behavior for partial iterations:

* If `status.json` missing → treat iteration as agent error, increment agent-error counter, retry with next fresh agent.
* If status exists but output missing → treat as task failure, retry.
* If verify running when crash → mark verify as not run.

This is what makes long queue runs reliable.

## What is missing for generalizability

### A) Fan-out then fan-in without inventing new primitives

You already have enough if you combine:

* queue provider for fan-out items
* artifacts manifest to collect outputs
* synthesis stage with `inputs.select=all`

No new execution model required, just formalize it in docs as an archetype.

### B) Human gates and review checkpoints

For real code workflows, you need “stop and wait for human approval” between stages. This can be a stage template that terminates only when a file exists or contains an approval token, implemented as a queue provider variant or a `termination.type=external`.

Minimal mechanism:

* `termination.type: external`
* `external.check_cmd: ./scripts/approved.sh ${SESSION}`

### C) Workspace and workdir contract

Verify hooks and many agents need a consistent working directory. Add:

* `workdir: repo_root | stage_dir | <path>`

Expose in `${CTX.paths.workdir}`.

### D) Output path safety constraints

If stages can write anywhere, a prompt mistake can trash the repo or write outside. Enforce:

* output paths must be under repo root or session dir unless explicitly allowed
* no `..` traversal

This is a correctness feature, not a security theater feature.

### E) Explicit “primary artifact” definition for non-markdown work

Code stages often have “primary artifact is a patch”, not a markdown file. Your model should allow:

* primary artifact file type varies
* stage-to-stage consumes primary artifact plus artifacts set

That is handled by artifacts manifest plus a primary pointer.

## The smallest schema that still supports everything

### stage.yaml minimal template

```yaml
name: refiner
prompt: prompt.md

termination:
  type: judge | queue | fixed
  min_iterations: 2        # judge only
  consensus: 2             # judge only, default 2
  iterations: 5            # fixed only

defaults:
  output: output.md
  history: true
  workdir: repo_root
  verify: []
```

### pipeline.yaml minimal

```yaml
name: full-ideation
max_runtime_seconds: 7200

stages:
  - id: ideas
    template: idea-generator
    max_iterations: 5
    inputs: { select: latest }
    output: { path: stage, file: output.md, history: true }

  - id: synth
    template: synthesizer
    max_iterations: 1
    inputs: { from: ideas, select: all }
    output: { path: docs/plan-${SESSION}.md, history: false }

  - id: refine
    template: refiner
    max_iterations: 10
    inputs: { from: synth, select: latest }
    output: { path: docs/plan-${SESSION}.md, history: true }
    verify:
      - markdownlint ${OUTPUT}
```

`output.path: stage` means resolve to `${CTX.paths.stage_dir}/output.md`. Everything else is explicit file path.

## Directory layout that stays simple and debuggable

```
.claude/pipeline-runs/{session}/
  state.json
  stage-01-ideas/
    handoff.md
    progress.log.md
    output.md
    iterations/
      001/ ctx.json status.json artifacts.json verify.log output.snapshot.md
      002/ ...
  stage-02-synth/
    ...
  stage-03-refine/
    ...
```

No special cases. History always exists when enabled. Debugging always means “open iterations/NNN”.

## The main elegance move

The single change that buys the most simplicity without losing power:

* `${CTX}` manifest becomes the only nontrivial interface
* status schema becomes universal with `decision`
* output mode becomes engine-side snapshotting
* progress becomes a rolling handoff plus append-only archive

That reduces cognitive load for humans and LLMs, while expanding supported workflows.
