# AGENTS Constitution

Codex is a compiler for intent. This document is the constitution that constrains every run so the agent can produce auditable, high-quality changes.

## Execution Envelope

- **Access mode**: Start every run in read-only analysis. Escalate to write only after you know the target files and affected tests. Never run destructive git commands (reset/rebase) without explicit user approval.
- **Writable paths**: Only files inside this repository are writable. Treat the repo root as the sandbox; do not touch `~` except to read shared config under `~/.codex/`.
- **Network**: Assume network access is off. Do not hit remote resources (curl, package install, API calls) unless the task explicitly requires it and you have confirmed with the user.
- **Shell**: Default to `bash -lc "<command>"` with `set -euo pipefail` expectations mirrored in scripts.

## Definition of Done

Work is complete only after running the proof command below and reporting the result:

- **Proof command**: `scripts/tests/run_tests.sh --ci`
  - If a narrower target is provided (e.g., `./scripts/run.sh test staging --verbose`), run that too but the CI suite is the default.
- Capture stderr/stdout highlights for any failures and block closing the task until they are addressed or waivers are documented.

## Required Workflow Artifacts

Every run must produce:
1. **Short plan** outlining assumptions, affected subsystems, and the next discrete actions.
2. **Unified diff** (or summarized changes) tied to file paths so reviewers can grep the edits.
3. **Verification commands** exactly as executed (tests, lint, or formatters).
4. **Change narrative** explaining what changed and why, including any tradeoffs or skipped validations.

## Guidance & Input Contract

- Reference concrete repro data: failing test names, stack traces, file paths, and symbols. If the user cannot provide them, request the missing info rather than guessing.
- Keep instructions point-form. Skip narration and fluff; make everything greppable.
- When pulling context, prefer project primitives (`rg`, `scripts/run.sh status`, etc.) over ad-hoc commands to keep history consistent.

## Autonomy Ladder

- Begin in read-only or approval mode and earn trust by shipping repeatable loops (plan → edit → test).
- Once the workflow is stable (tests green twice in a row), you may automate that loop via scripts/pipelines, but reset to read-only whenever requirements change.

## Mission & Core Concepts

- Agent Pipelines is a Ralph loop orchestrator that runs autonomous tmux sessions where each iteration spins up a fresh agent to avoid context drift. Two-agent consensus (plateau completion) is the default guardrail against premature stopping.
- Everything is a pipeline: a loop is just a single-stage pipeline. Multi-stage pipelines chain prompts via `scripts/pipelines/*.yaml`, while single-stage configs live under `scripts/stages/<name>/`.
- Sessions write state into `.claude/pipeline-runs/{session}/`, including `progress-<session>.md`, per-iteration outputs, and `state.json` for crash detection/resume.

## CLI & Dependencies

Dependencies required on every workstation: `jq`, `claude`, `codex`, `tmux`, and `bd`.

Common commands (all via `./scripts/run.sh`):

```bash
# Single-stage loop (3 paths)
./scripts/run.sh ralph auth 25
./scripts/run.sh loop ralph auth 25
./scripts/run.sh pipeline --single-stage ralph auth 25

# Multi-stage pipeline
./scripts/run.sh pipeline refine.yaml my-session

# Session ops
./scripts/run.sh ralph auth 25 --force        # override lock
./scripts/run.sh ralph auth 25 --resume       # continue crashed session
./scripts/run.sh status auth                  # inspect status/locks
./scripts/run.sh                              # list stages/pipelines
```

## Skills & Slash Commands

Skills (under `skills/`) extend Codex/Caudex; invoke them inside Claude via slash commands:

| Skill | Slash Command | Purpose |
|-------|---------------|---------|
| `start` | `/start [pipeline]` | Discover and launch pipelines |
| `sessions` | `/sessions [list|start]` | tmux session management |
| `plan-refinery` | `/plan-refinery` | Iterative planning with Opus subagents |
| `create-prd` | `/agent-pipelines:create-prd` | Generate PRDs via guided discovery |
| `create-tasks` | `/agent-pipelines:create-tasks` | Break PRDs into beads |
| `pipeline-designer` | `/pipeline` | Architect new pipelines |
| `pipeline-creator` | `/pipeline create` | Scaffold stage.yaml + prompt.md |
| `pipeline-editor` | `/pipeline edit` | Modify existing stages/pipelines |

User-facing slash commands under `commands/` (`/ralph`, `/refine`, `/ideate`, `/robot-mode`, `/readme-sync`, etc.) should be referenced verbatim when guiding humans or other agents.

## Operational Playbooks

- **Feature flow**: `/sessions plan` or `/agent-pipelines:create-prd` → `/agent-pipelines:create-tasks` → `/refine` (5+5 plan iterations) → `/ralph` until beads close.
- **Bug-hunt flow**: `./scripts/run.sh pipeline bug-hunt.yaml <session>` which executes Discover (8), Elegance (≤5), Refine (3), Fix (25) stages sequentially.

## Debugging & Recovery

- Attach to tmux: `tmux attach -t pipeline-<session>`.
- Inspect progress/state: `cat .claude/pipeline-runs/<session>/progress-<session>.md` or `state.json | jq`.
- Resume after crash: rerun with `--resume`; engine tracks `iteration_started`/`iteration_completed`.
- Manage locks: lock files live in `.claude/locks/<session>.lock`; verify PID before removing. Use `--force` only when the prior process is gone.

## Environment & Context Variables

- Pipelines export `CLAUDE_PIPELINE_AGENT=1`, `CLAUDE_PIPELINE_SESSION`, and `CLAUDE_PIPELINE_TYPE`. Override defaults via `CLAUDE_PIPELINE_PROVIDER`, `CLAUDE_PIPELINE_MODEL`, `CLAUDE_PIPELINE_CONTEXT`, or CLI `--provider/--model/--context`. Precedence: CLI → env → pipeline config → stage config → defaults.
- Prompts should consume v3 template vars: `${CTX}` (context.json path), `${PROGRESS}`, `${STATUS}`, `${ITERATION}`, `${SESSION_NAME}`, `${CONTEXT}`, `${OUTPUT}`. Legacy names (`${SESSION}`, `${INDEX}`, etc.) still resolve but should be avoided.
- `context.json` describes inputs from CLI (`inputs.from_initial`), previous stages (`inputs.from_stage`), parallel providers (`inputs.from_parallel`), and command passthroughs (e.g., `.commands.test`). Read it with `jq` instead of hardcoding repo-specific assumptions.
- When exposing repo commands to agents, define them in pipeline/stage YAML (`commands.test`, `commands.lint`, etc.) or pass them via CLI `--command` overrides so Codex can run the correct tooling without guesswork.

## Issue Tracking

This project uses **bd (beads)** for issue tracking.
Run `bd prime` for workflow context, or install hooks (`bd hooks install`) for auto-injection.

**Quick reference:**
- `bd ready` - Find unblocked work
- `bd create "Title" --type task --priority 2` - Create issue
- `bd close <id>` - Complete work
- `bd sync` - Sync with git (run at session end)

For full workflow details: `bd prime`

## Specialized Agents

Agents live in `agents/` at the plugin root (per Claude Code plugin structure):

| Agent | Purpose |
|-------|---------|
| **pipeline-architect** | Design pipeline architectures, termination strategies, I/O flow, and parallel blocks. |
| **stage-creator** | Create stage.yaml and prompt.md files for new stages. |
| **pipeline-assembler** | Assemble multi-stage pipeline configurations. |

Invoke via Task tool: `subagent_type: "pipeline-architect"` with requirements summary.

## Project Structure & Module Organization

The automation engine lives in `scripts/`: `run.sh` is the CLI entry point, `engine.sh` drives each iteration, and `lib/` holds reusable YAML/state helpers. Stage prompts plus stop criteria live in `scripts/stages/<stage>/{stage.yaml,prompt.md}`, while composed flows sit in `scripts/pipelines/*.yaml` with human-facing cues in `commands/`. Agent briefs live in `agents/`, durable references in `docs/`, reusable prompt snippets in `skills/`, and every regression fixture or shell suite belongs in `scripts/tests/` beside the logic it protects.

## Build, Test, and Development Commands

- `./scripts/run.sh pipeline bug-hunt.yaml overnight` — run the bundled multi-stage pipeline.
- `./scripts/run.sh loop ralph auth 25 --tmux` — kick off a single stage with persistent tmux output.
- `./scripts/run.sh lint [loop|pipeline] [name]` — schema-check stage or pipeline definitions.
- `./scripts/run.sh test [name] --verbose` or `scripts/tests/run_tests.sh --ci` — execute regression suites.
- `./scripts/run.sh status <session>` — inspect locks before resuming or forcing reruns.

## Coding Style & Naming Conventions

Bash is the canonical implementation language; keep shebangs at `#!/bin/bash`, enable `set -euo pipefail`, and favor snake_case helpers that declare locals explicitly. YAML uses two-space indents, lowercase kebab-case directories, and descriptive `description` lines surfaced by `run.sh`. Prompts and Markdown should stay imperative and concise, mirroring the `commands/*.md` tone.

## Testing Guidelines

Shell suites follow the `scripts/tests/test_*.sh` pattern and rely on fixtures under `scripts/tests/fixtures`. Add or update fixtures when state machines or prompt IO change, and lean on the shared helpers already sourced at the top of each test file for assertions. Always run `./scripts/run.sh test <target>` before submitting, and capture tmux output when validating new sessions.

## Commit & Pull Request Guidelines

Commits follow conventional prefixes seen in history (`feat:`, `docs:`, etc.) and should stay focused on one stage or helper tweak. Reference the bd issue ID in the commit body and PR description, summarize intent, list validation commands, and attach key CLI or tmux snippets for reviewer context. Call out every touched stage/pipeline so automation runners know which lint/test paths to rerun.
