---
date: 2026-01-15
type: prd
status: draft
project: go-engine-rewrite
---

## Overview

**What we're building:** A Go-based rewrite of the Agent Pipelines engine designed as an **SDK-first platform** that can be imported as a library, extended with custom providers, and integrated with external systems via hooks and event streaming.

**Why:** The current Bash/jq/yq/tmux-based engine has fundamental limitations that prevent it from becoming a platform:

1. **Not embeddable:** Shell scripts can't be imported as a library. Building an SDK, MCP server, or programmatic interface requires a rewrite.

2. **No hook system:** Human-in-the-loop workflows require pausing pipelines, injecting context, and resuming—impossible with the current architecture.

3. **Provider lock-in:** Adding new providers (E2B sandboxes, OpenCode, custom agents) requires modifying core engine code rather than registering at runtime.

4. **Concurrency hazards:** Events/state races when multiple providers write simultaneously (parallel.sh uses subshells that re-source libraries, creating isolated state).

5. **Operational complexity:** 25+ library files totaling ~300KB of shell scripts with fragile `set -e` error handling.

A Go implementation enables:
- **SDK imports:** `import "github.com/dodo-digital/agent-pipelines/engine"`
- **Event streaming:** Channels for real-time progress to UIs, webhooks, or MCP clients
- **Hook registration:** Pause at any point, chat with user, resume with new context
- **Provider plugins:** Register E2B, OpenCode, or custom providers at runtime
- **Future frontends:** WebSocket API for visualization dashboards

**Scope:** Project-level PRD for a full engine rewrite. Preserve user-facing behavior and file formats for backward compatibility while architecting for SDK use and extensibility.

**Non-Goals (v1):**
- Frontend UI or web dashboard (future phase)
- WebSocket server (future phase—architecture supports it)
- Multi-node distributed execution

---

## User Stories

**Core Engine:**
- As a developer, I want to run pipelines on macOS or Linux without installing Bash tooling, so that setup is `go install` or a single binary download.
- As an operator, I want parallel blocks to run without corrupting events or state, so that resumes and status views are trustworthy.
- As a pipeline author, I want existing stage/pipeline YAML and prompts to keep working, so that I do not need to rewrite content.
- As a CI user, I want deterministic outputs (`plan.json`, `context.json`, `events.jsonl`) so that test fixtures remain stable.
- As a platform engineer, I want to run multiple sessions concurrently without lock contention or data loss, so that workflows scale.

**SDK & Embedding:**
- As an SDK consumer, I want to `import` the engine as a Go library so that I can run pipelines programmatically without shelling out to a CLI.
- As an MCP developer, I want to expose pipelines as tools so that agents can orchestrate multi-step workflows.
- As a frontend developer, I want to subscribe to an event channel so that I can visualize pipeline progress in real-time.

**Human-in-the-Loop:**
- As a product manager, I want pipelines to pause and ask for confirmation at key decision points, so that I stay in control of long-running workflows.
- As a researcher, I want to inject new context mid-pipeline based on intermediate results, so that the workflow can adapt to discoveries.
- As a team lead, I want to review agent outputs between stages and approve or redirect, so that quality is maintained without babysitting every iteration.

**Provider Extensibility:**
- As a cost-conscious user, I want to run stages with OpenCode and open-source models, so that I can reduce API costs for routine tasks.
- As a security-conscious user, I want stages to run in E2B sandboxes, so that agent code execution is isolated from my infrastructure.
- As a platform builder, I want to register custom providers at runtime, so that I can integrate proprietary or internal AI systems.

---

## Features

### Engine Parity

#### Feature 1.1: Pipeline Compilation Parity
**Description:** Compile pipeline YAML into `plan.json` identical in structure to the Bash engine (see `scripts/lib/compile.sh`).

**Acceptance Criteria:**
- [ ] Given an existing pipeline YAML, when compiled, then `plan.json` matches schema v1 structure with `nodes[]`, `dependencies{}`, `session{}`, and `pipeline{}` fields.
- [ ] Given deprecated `stages:` key, when compiled, then a warning is emitted to stderr and output is equivalent to `nodes:`.
- [ ] Given CLI overrides (`--provider`, `--model`, `--context`, `--input`), when compiled, then `plan.json` reflects overrides in `.pipeline.overrides` and stage-level configs.
- [ ] Given a `--recompile` flag, when invoked, then `plan.json` is regenerated even if newer than source YAML.
- [ ] Given `commands:` in pipeline YAML, when compiled, then commands are propagated to `context.json` for agent access.

#### Feature 1.2: Stage Execution Parity
**Description:** Run stage iterations with the same prompt resolution and context generation behavior (see `scripts/lib/context.sh`, `scripts/lib/resolve.sh`).

**Acceptance Criteria:**
- [ ] Given a stage YAML and prompt, when run, then output is written to `.claude/pipeline-runs/<session>/stage-XX-<name>/iterations/NNN/` paths.
- [ ] Given template variables (`${CTX}`, `${PROGRESS}`, `${STATUS}`, `${ITERATION}`, `${SESSION_NAME}`, `${CONTEXT}`, `${OUTPUT}`), when resolved, then values match Bash engine behavior.
- [ ] Given a completion strategy (`fixed`, `judgment`, `queue`), when run, then iteration termination matches current completion logic.
- [ ] Given agent failure (non-zero exit), when run, then state is marked failed with `error`, `error_type`, and resume guidance printed.
- [ ] Given `output_path:` in stage config, when run, then agent output is written to resolved path (with `${SESSION}` substitution).

#### Feature 1.3: Termination Strategy Parity
**Description:** Implement all three termination strategies: `fixed`, `judgment`, and `queue` (see `scripts/lib/completions/`).

**Acceptance Criteria:**
- [ ] `fixed`: Stop after exactly N iterations (from `termination.iterations` or `termination.max`).
- [ ] `judgment`: Use external judge (Haiku by default) to evaluate iteration history. Stop when N consecutive iterations signal `stop` (default N=2). Respect `min_iterations` before checking.
- [ ] `queue`: Check `bd ready --label=pipeline/<session>` and stop when empty. Require `bd` CLI presence.
- [ ] Given agent writes `decision: error` in result.json, when completing, then loop stops immediately regardless of strategy.

#### Feature 1.4: Judge Module for Judgment Termination
**Description:** External evaluator that reads iteration history and decides stop/continue (see `scripts/lib/judge.sh`).

**Acceptance Criteria:**
- [ ] Judge prompt template loaded from `scripts/prompts/judge.md` or `~/.config/agent-pipelines/prompts/judge.md`.
- [ ] Prompt receives: stage name, iteration number, result.json, progress file, iteration history (all previous output.md files).
- [ ] Judge invoked via provider shell-out (default: `claude --model haiku`).
- [ ] JSON output stripped from markdown fences if present (`json...`).
- [ ] Judge output normalized to `{stop: bool, reason: string, confidence: number}`.
- [ ] Retry logic: up to 2 attempts on invocation failure.
- [ ] Failure tracking: count consecutive judge failures per node via events; skip judge after 3 failures (return `{stop: false, reason: "judge_unreliable"}`).
- [ ] Emit `judge_start` and `judge_complete` events with provider, model, and result.
- [ ] Write judge output to `iterations/NNN/judge.json` for debugging.

#### Feature 1.5: Iteration Delay and Runtime Guards
**Description:** Control timing between iterations and enforce runtime limits (see `delay` in stage.yaml, `guardrails.max_runtime_seconds` in context.sh).

**Acceptance Criteria:**
- [ ] Stage `delay:` config (seconds): Sleep between iterations after completion. Default varies by stage (e.g., `ralph`: 3s, `improve-plan`: 2s).
- [ ] `guardrails.max_runtime_seconds` in plan or stage config: Calculate `remaining_seconds` in context.json for agent awareness.
- [ ] Context generation includes `limits.remaining_seconds`: `-1` if unbounded, otherwise seconds until session should stop.
- [ ] Mock mode (`MOCK_MODE=true`): Skip delays for faster testing (`MOCK_DELAY` env var overrides).
- [ ] Delay is applied after iteration completes, before next iteration starts (not before first iteration).

**Stage Delay Configuration:**
```yaml
# In stage.yaml
delay: 3  # seconds between iterations (default: 3)

# In plan or stage
guardrails:
  max_runtime_seconds: 7200  # Session-wide timeout (optional)
```

### Concurrency and Parallel Safety

#### Feature 2.1: Event Log Writer
**Description:** Append-only `events.jsonl` writer with file locking and buffering to prevent race conditions (see `scripts/lib/events.sh`).

**Acceptance Criteria:**
- [ ] Given concurrent event emissions from parallel providers, when events are appended, then no events are lost or corrupted.
- [ ] Given a crashed writer, when resumed, then existing events remain intact and new events append correctly.
- [ ] Given large sessions, when appending events, then write cost is O(1) per event.
- [ ] Event types supported: `session_start`, `session_complete`, `node_start`, `node_complete`, `iteration_start`, `iteration_complete`, `worker_complete`, `parallel_provider_start`, `parallel_provider_complete`, `error`.
- [ ] Each event includes: `type`, `timestamp`, `session`, `cursor` (node_path, node_run, iteration, optional provider), `data`.

#### Feature 2.2: Parallel Block Execution
**Description:** Run parallel providers in goroutines with isolated state directories and a deterministic completion manifest (see `scripts/lib/parallel.sh`).

**Acceptance Criteria:**
- [ ] Given a parallel block, when run, then provider stages run concurrently with isolated directories under `parallel-XX-<name>/providers/<provider>/`.
- [ ] Given provider list as strings `["claude", "codex"]`, when parsed, then each provider uses its default model.
- [ ] Given provider list as objects `[{name: "claude", model: "opus", inputs: {...}}]`, when parsed, then per-provider model and inputs are respected.
- [ ] Given partial provider failure, when run, then block status is `failed` and `manifest.json` is not written.
- [ ] Given resume with completed providers (checked via events or state), when run, then completed providers are skipped and incomplete providers re-run.
- [ ] Given successful completion, when writing manifest, then `manifest.json` aggregates all provider outputs for downstream stages.

**Per-Provider Configuration (Object Format):**
```yaml
# Simple string format - uses default model
parallel:
  providers: [claude, codex]

# Object format - per-provider model and inputs
parallel:
  providers:
    - name: claude
      model: opus                    # Override model for this provider
      inputs:                        # Provider-specific inputs
        from_parallel:
          stage: generate
          providers: [codex]         # Claude receives Codex's output
    - name: codex
      model: gpt-5.2-codex:xhigh     # Model with reasoning effort
      inputs:
        from_parallel:
          stage: generate
          providers: [claude]        # Codex receives Claude's output
```

**Per-Provider Input Use Cases:**
- **Cross-evaluation:** Each provider evaluates the other's output (debate pattern)
- **Asymmetric routing:** Different providers receive different upstream outputs
- **Selective history:** One provider gets full history, another gets only latest

**from_parallel Scope Rule (IMPORTANT):**
- `inputs.from_parallel` only resolves outputs from *completed* parallel blocks via `manifest.json`
- Providers in the same parallel block CANNOT depend on each other's outputs in the same iteration
- Cross-evaluation must be modeled as separate stages/blocks: parallel generate → parallel evaluate
- Validation error if `from_parallel` references the current parallel block
- Exception: Within a block, a provider's *second stage* can reference another provider's *first stage* if execution order guarantees completion

#### Feature 2.3: Session Locking
**Description:** File-based session locking to prevent duplicate concurrent sessions (see `scripts/lib/lock.sh`).

**Acceptance Criteria:**
- [ ] Given a new session, when starting, then acquire lock in `.claude/locks/<session>.lock` with PID and start time.
- [ ] Given an existing lock with dead PID, when starting, then clean stale lock and proceed (release orphaned `bd` beads).
- [ ] Given an existing lock with live PID, when starting, then error with guidance to use `--force` or attach.
- [ ] Given `--force` flag, when starting with existing lock, then override and proceed.
- [ ] Given session completion or failure, when exiting, then release lock via trap.
- [ ] Lock tool hierarchy: Try flock first (Linux), then shlock (macOS), then noclobber fallback (portable).
- [ ] Noclobber mode: Use `set -C` equivalent in Go (O_EXCL flag) for atomic lock creation without TOCTOU race.
- [ ] On stale lock cleanup: Also release orphaned `bd` beads (reset `in_progress` → `open` for beads with `pipeline/{session}` label).

#### Feature 2.4: Graceful Shutdown and Signal Handling
**Description:** Handle SIGTERM/SIGINT gracefully to prevent data corruption and enable clean resume.

**Acceptance Criteria:**
- [ ] On SIGINT (Ctrl+C): Set shutdown flag, wait for current iteration to complete (with timeout), then exit.
- [ ] On SIGTERM: Same as SIGINT (allows `kill -TERM` to cleanly stop sessions).
- [ ] Shutdown timeout: If iteration doesn't complete within 30s of signal, emit `error` event and force exit.
- [ ] Lock release: Release session lock on any exit (success, failure, or signal).
- [ ] Child process cleanup: Forward signals to provider subprocess (claude/codex CLI).
- [ ] State consistency: Ensure `iteration_started` and `iteration_completed` are never both set for an incomplete iteration.

#### Feature 2.5: Event Reconciliation for Crash Recovery
**Description:** Reconstruct state from events.jsonl when resuming after crash (see `reconcile_with_events` pattern).

**Acceptance Criteria:**
- [ ] On resume, if events.jsonl exists but state.json is stale/missing, reconstruct state from events.
- [ ] Derive `iteration_completed` from last `iteration_complete` event.
- [ ] Derive `current_stage` from last `node_start` or `iteration_*` event's cursor.
- [ ] Derive session status from presence/absence of `session_complete` event.
- [ ] Skip reconciliation if session is actively locked (avoids race with running session).
- [ ] Event spine mode toggled by `AGENT_PIPELINES_LEGACY=1` env var (defaults to enabled).

### Portability and Installability

#### Feature 3.1: Single Binary CLI
**Description:** Provide a static binary with no runtime dependency on jq/yq/tmux.

**Acceptance Criteria:**
- [ ] Given macOS (amd64, arm64) or Linux (amd64, arm64), when building, then produce static binaries.
- [ ] Windows binaries: Out of scope for v1. Cross-compilation target may be added later but is untested.
- [ ] Given `go install github.com/dodo-digital/agent-pipelines/cmd/agent-pipelines@latest`, when run, then installation succeeds.
- [ ] Given missing provider CLIs (claude, codex), when executing a provider, then error message names the missing CLI and suggests installation.
- [ ] Given no tmux, when running with `--foreground`, then sessions execute in the current terminal.
- [ ] Given tmux available, when running without `--foreground`, then sessions run in a detached tmux session named `pipeline-<session>`.

#### Feature 3.2: Provider Support
**Description:** Support Claude and Codex providers via CLI shell-out (see `scripts/lib/provider.sh`).

**Acceptance Criteria:**
- [ ] `claude` provider: Shell out to `claude` CLI with `--print`, `--dangerously-skip-permissions`, optional `--model`.
- [ ] `codex` provider: Shell out to `codex` CLI with `--dangerously-bypass-approvals-and-sandbox`, optional `--model` and `--reasoning-effort`.
- [ ] Model aliases: `opus` → `claude-opus`, `sonnet` → `claude-sonnet`, `haiku` → `claude-haiku`.
- [ ] Codex reasoning effort: Support `:xhigh`, `:high`, `:medium`, `:low`, `:minimal` suffixes on model (e.g., `gpt-5.2-codex:xhigh`).
- [ ] Given `CLAUDE_PIPELINE_PROVIDER` or `CLAUDE_PIPELINE_MODEL` env vars, when executing, then override stage config.

**Codex-Specific Behaviors:**
- [ ] `CODEX_TIMEOUT` env var: Default 900 seconds (15 min). Use `timeout` (Linux) or `gtimeout` (macOS) to wrap Codex process.
- [ ] Timeout cascade: Send SIGTERM first; if not dead after 30s, send SIGKILL.
- [ ] Exit code 124 = SIGTERM timeout; exit code 137 = SIGKILL. Log warning for both.
- [ ] Prompt augmentation: Append exit instruction to Codex prompts to prevent waiting for follow-up in pipeline mode.
- [ ] Codex model validation: Reject unknown models (supported: `gpt-5.2-codex`, `gpt-5.1-codex-max`, `gpt-5.1-codex-mini`, `gpt-5.1-codex`, `gpt-5-codex`, `gpt-5-codex-mini`).
- [ ] If `timeout`/`gtimeout` unavailable, warn and run without timeout protection.

### Compatibility Layer

#### Feature 4.1: CLI Compatibility
**Description:** Go binary CLI matches existing `scripts/run.sh` interface exactly.

**Acceptance Criteria:**
- [ ] `agent-pipelines <stage-type> [session] [max]` → single-stage pipeline (shortcut).
- [ ] `agent-pipelines loop <type> [session] [max]` → single-stage pipeline (explicit).
- [ ] `agent-pipelines pipeline <file.yaml> [session] [runs]` → multi-stage pipeline.
- [ ] `agent-pipelines status <session>` → show session status from events/state.
- [ ] `agent-pipelines tail <session> [lines]` → stream events.jsonl with formatting.
- [ ] `agent-pipelines list [count]` → list recent pipeline runs.
- [ ] `agent-pipelines lint [loop|pipeline] [name]` → validate configurations.
- [ ] `agent-pipelines dry-run <loop|pipeline> <name> [session]` → preview execution.
- [ ] All flags: `--force`, `--resume`, `--recompile`, `--foreground`, `--input=<file>`, `--provider=<name>`, `--model=<name>`, `--context=<text>`, `--command=<key>=<cmd>`.
- [ ] `--command` flag: Override commands in context.json (e.g., `--command=test="pytest tests/" --command=lint="ruff check ."`). Multiple allowed.

#### Feature 4.2: Input System Parity
**Description:** Support all input sources: initial files, previous stage outputs, parallel block outputs, and intra-stage iteration history (see `scripts/lib/context.sh`).

**Acceptance Criteria:**
- [ ] `--input=<file>` flag: Resolve to absolute paths, support globs and directories.
- [ ] `inputs.from: <node-id>`: Reference previous stage outputs in multi-stage pipelines.
- [ ] `inputs.from_parallel: <stage-id>`: Reference parallel block outputs with optional provider filter.
- [ ] `inputs.from_parallel` supports both string shorthand and full object form with `stage`, `block`, `select`, `providers` fields.
- [ ] `select: latest` (default) or `select: history`: Control whether to include only latest or all iterations.
- [ ] `inputs.from_previous_iterations`: Automatically populated with all `output.md` files from previous iterations of the current stage (for iteration 3, includes iterations 1 and 2).
- [ ] `from_previous_iterations` population: Scan `stage-XX-{name}/iterations/` directory, collect all `output.md` files from iterations < current, sort by iteration number ascending.
- [ ] `from_previous_iterations` for iteration 1: Empty array (no previous iterations exist).
- [ ] All inputs accessible in `context.json` under `inputs.from_initial[]`, `inputs.from_stage{}`, `inputs.from_parallel{}`, `inputs.from_previous_iterations[]`.

**from_parallel Format Details:**
```yaml
# String shorthand - gets all providers' latest outputs
inputs:
  from_parallel: iterate

# Full object form with options
inputs:
  from_parallel:
    stage: iterate             # Stage id within the parallel block
    block: dual-refine         # Optional: parallel block name (if ambiguous)
    providers: [claude]        # Optional: filter to specific providers (default: all)
    select: history            # Optional: "latest" (default) or "history" (all iterations)

# Array form - receive from multiple parallel sources (cross-evaluation pattern)
inputs:
  from_parallel:
    - stage: generate
      providers: [claude]      # Get Claude's output from generate
    - stage: rate
      providers: [codex]       # Get Codex's output from rate
```

**Array-based from_parallel Details:**
- When `from_parallel` is an array, each entry is resolved independently
- Context.json `inputs.from_parallel` becomes an array of resolved source objects
- Enables cross-evaluation patterns where a provider needs both:
  - Their own previous iteration output
  - Another provider's evaluation/critique of that output
- Each array entry supports the same fields as single object form (`stage`, `block`, `providers`, `select`)

**Context.json Output (single source):**
```json
{
  "inputs": {
    "from_parallel": {
      "stage": "iterate",
      "block": "dual-refine",
      "providers": {
        "claude": { "output": ".../claude/output.md", "history": [] },
        "codex": { "output": ".../codex/output.md", "history": [] }
      }
    }
  }
}
```

**Context.json Output (array source):**
```json
{
  "inputs": {
    "from_parallel": [
      {
        "stage": "generate",
        "block": "ideate",
        "providers": { "claude": { "output": "..." } }
      },
      {
        "stage": "rate",
        "block": "evaluate",
        "providers": { "codex": { "output": "..." } }
      }
    ]
  }
}
```

#### Feature 4.3: Parallel Scope Isolation
**Description:** When stages run inside parallel blocks, they must have provider-isolated context (see `parallel_scope` in context.sh).

**Acceptance Criteria:**
- [ ] `parallel_scope.scope_root`: Path to provider's isolated directory (e.g., `parallel-01-dual/providers/claude/`).
- [ ] `parallel_scope.pipeline_root`: Path to session root for cross-scope lookups.
- [ ] Input resolution checks scope_root first, then falls back to pipeline_root.
- [ ] Progress files are provider-isolated within parallel blocks.
- [ ] Manifest lookup traverses both scope_root and pipeline_root when resolving `from_parallel`.

### Observability

#### Feature 5.1: Status Command
**Description:** Show session status by reading events.jsonl or falling back to state.json.

**Acceptance Criteria:**
- [ ] Display: session name, status (active/completed/failed), current stage, iteration, start time.
- [ ] For failed sessions: show error, last completed iteration, resume guidance.
- [ ] For parallel blocks: show per-provider status.

#### Feature 5.2: Tail Command
**Description:** Stream formatted events from events.jsonl in real-time.

**Acceptance Criteria:**
- [ ] Format events with timestamp, type, stage, iteration, summary.
- [ ] Support `--lines N` to show last N events before streaming.
- [ ] Handle concurrent writes gracefully (follow mode like `tail -f`).

#### Feature 5.3: Health Scoring
**Description:** Compute session health from event patterns (see `events_health_score` in events.sh).

**Acceptance Criteria:**
- [ ] `consecutive_errors`: Count recent error events until non-error.
- [ ] `iterations_without_progress`: Count `iteration_complete` events where `plateau_suspected: true` or empty summary.
- [ ] Health score formula: `1.0 - (0.1 * consecutive_errors) - (0.05 * iterations_without_progress)`, clamped to [0, 1].
- [ ] Health label: `"warning"` if score < 0.3, else `"ok"`.
- [ ] Status command displays health label and warnings.

### Hook System (Human-in-the-Loop)

#### Feature 6.1: Hook Points
**Description:** Define points in the execution lifecycle where external code can intercept, inspect, and control flow.

**Hook Points:**
| Hook | Fires When | Can Pause | Can Modify Context |
|------|------------|-----------|-------------------|
| `session_start` | Before first stage begins | Yes | Yes |
| `session_end` | After last stage completes | No | No |
| `stage_start` | Before a stage begins | Yes | Yes |
| `stage_end` | After a stage completes | Yes | Yes (for next stage) |
| `iteration_start` | Before each iteration | Yes | Yes |
| `iteration_end` | After each iteration | Yes | Yes (for next iteration) |
| `parallel_provider_start` | Before provider in parallel block | Yes | Yes |
| `parallel_provider_end` | After provider in parallel block | Yes | Yes |

**Acceptance Criteria:**
- [ ] All hook points emit events with full context (session, stage, iteration, provider).
- [ ] Hooks receive: current state, iteration result (if applicable), accumulated context.
- [ ] Hooks can return: `continue`, `pause`, `abort`, `restart_stage`, `modify_context`.
- [ ] Paused sessions persist state and can be resumed via API or CLI.
- [ ] `modify_context` injects additional text into `${CONTEXT}` for subsequent iterations.

#### Feature 6.2: Hook Registration (SDK)
**Description:** SDK consumers register hooks programmatically before starting a pipeline.

**Acceptance Criteria:**
- [ ] `engine.OnSessionStart(func(ctx *HookContext) HookResult)`
- [ ] `engine.OnIterationEnd(func(ctx *HookContext) HookResult)`
- [ ] Hooks execute synchronously—pipeline waits for hook to return.
- [ ] Multiple hooks per point execute in registration order.
- [ ] Hook errors are logged but don't crash the pipeline (configurable).

**SDK Hook Example:**
```go
engine := pipelines.NewEngine()

// Pause after every 5 iterations for human review
engine.OnIterationEnd(func(ctx *pipelines.HookContext) pipelines.HookResult {
    if ctx.Iteration % 5 == 0 {
        return pipelines.HookResult{
            Action: pipelines.Pause,
            Reason: "Checkpoint: please review progress",
        }
    }
    return pipelines.HookResult{Action: pipelines.Continue}
})

// Inject new context when resumed
engine.OnResume(func(ctx *pipelines.HookContext, input string) pipelines.HookResult {
    return pipelines.HookResult{
        Action: pipelines.ModifyContext,
        Context: fmt.Sprintf("User feedback: %s", input),
    }
})

engine.Run(pipeline, session)
```

#### Feature 6.3: Hook Configuration (YAML)
**Description:** Define hooks in pipeline YAML for CLI/non-SDK usage.

**Acceptance Criteria:**
- [ ] `hooks:` section in pipeline YAML.
- [ ] Hook actions: `pause`, `webhook`, `script`, `confirm`.
- [ ] `pause` action: Stop and wait for `--resume` with optional `--context`.
- [ ] `webhook` action: POST to URL, wait for response, use response as context.
- [ ] `script` action: Run shell script, use stdout as context.
- [ ] `confirm` action: In interactive mode, prompt user; in background mode, pause.

**YAML Hook Example:**
```yaml
name: research-pipeline
hooks:
  stage_end:
    - stage: research          # Only for this stage
      action: confirm
      message: "Research complete. Review findings and approve next stage?"

  iteration_end:
    - stage: refine
      condition: "iteration % 3 == 0"  # Every 3rd iteration
      action: webhook
      url: "https://api.example.com/review"
      timeout: 300  # Wait up to 5 min for response

nodes:
  - id: research
    stage: research-plan
    runs: 5
  - id: refine
    stage: improve-plan
    runs: 10
```

#### Feature 6.4: Pause and Resume
**Description:** Paused pipelines persist state and can be resumed with new context.

**Acceptance Criteria:**
- [ ] Paused state written to `state.json` with `status: paused`, `paused_at`, `pause_reason`.
- [ ] `--resume` CLI flag resumes paused session.
- [ ] `--resume --context "new info"` resumes with injected context.
- [ ] SDK: `engine.Resume(session, context)` resumes programmatically.
- [ ] Paused sessions don't hold locks (allow other sessions to run).
- [ ] Events emitted: `session_paused`, `session_resumed`.

**Pause/Resume Flow:**
```
1. Hook returns Pause → engine writes state, releases lock, exits cleanly
2. User reviews output, decides on feedback
3. User runs: ./agent-pipelines --resume my-session --context "Focus on X, skip Y"
4. Engine loads state, injects context, continues from paused point
```

### Provider Extensibility

#### Feature 7.1: Provider Interface
**Description:** Abstract provider interface allowing multiple implementations.

**Go Interface:**
```go
type Provider interface {
    // Name returns the provider identifier (e.g., "claude", "codex", "e2b")
    Name() string

    // Execute runs the prompt and returns the result
    Execute(ctx context.Context, req ExecuteRequest) (*ExecuteResult, error)

    // Capabilities returns what this provider supports
    Capabilities() ProviderCapabilities

    // Validate checks if the provider is properly configured
    Validate() error
}

type ExecuteRequest struct {
    Prompt       string
    Model        string            // Provider-specific model identifier
    Config       map[string]any    // Provider-specific config (timeout, reasoning effort, etc.)
    WorkDir      string            // Working directory for the agent
    Environment  map[string]string // Environment variables to pass
    StatusPath   string            // Where agent should write status.json
    ResultPath   string            // Where agent should write result.json
}

type ExecuteResult struct {
    Output     string        // Agent's stdout/response
    ExitCode   int           // Process exit code (for CLI providers)
    Duration   time.Duration // Execution time
    TokensUsed *TokenUsage   // Optional token metrics
}

type ProviderCapabilities struct {
    SupportsTools         bool     // Can use MCP tools
    SupportsReasoningCtrl bool     // Has reasoning effort parameter
    SupportedModels       []string // List of valid model identifiers
    RequiresSandbox       bool     // Must run in isolated environment
}
```

**Acceptance Criteria:**
- [ ] All providers implement the `Provider` interface.
- [ ] Engine calls `provider.Validate()` at startup to fail fast on misconfig.
- [ ] Engine passes `ExecuteRequest` with all context needed for execution.
- [ ] Providers handle their own timeout, retry, and cleanup logic.

#### Feature 7.2: Provider Registry
**Description:** Register providers at runtime, allowing custom implementations.

**Acceptance Criteria:**
- [ ] `engine.RegisterProvider(name string, provider Provider)` adds to registry.
- [ ] Built-in providers registered by default: `claude`, `codex`.
- [ ] Stage `provider:` field looks up from registry.
- [ ] Unknown provider name returns clear error with list of available providers.
- [ ] SDK consumers can register before calling `engine.Run()`.

**SDK Registration Example:**
```go
engine := pipelines.NewEngine()

// Register custom E2B provider
engine.RegisterProvider("e2b", &E2BProvider{
    APIKey: os.Getenv("E2B_API_KEY"),
    Template: "claude-code-sandbox",
})

// Register OpenCode for open-source models
engine.RegisterProvider("opencode", &OpenCodeProvider{
    ModelPath: "/models/deepseek-coder",
})

// Now stages can use provider: e2b or provider: opencode
engine.Run(pipeline, session)
```

#### Feature 7.3: Provider Configuration
**Description:** Providers can be configured at multiple levels with clear precedence.

**Configuration Precedence (highest to lowest):**
1. CLI flags (`--provider`, `--model`)
2. Environment variables (`CLAUDE_PIPELINE_PROVIDER`, `CLAUDE_PIPELINE_MODEL`)
3. Stage-level config in `stage.yaml`
4. Pipeline-level config in `pipeline.yaml`
5. Provider defaults

**Acceptance Criteria:**
- [ ] Each level can override provider, model, and provider-specific options.
- [ ] Unknown config keys logged as warnings but don't fail.
- [ ] Provider-specific config passed through in `ExecuteRequest.Config`.

#### Feature 7.4: Sandboxed Providers
**Description:** Some providers require isolated execution environments.

**Acceptance Criteria:**
- [ ] Providers declare `RequiresSandbox: true` in capabilities.
- [ ] Engine ensures sandboxed providers run in isolated environments.
- [ ] For CLI mode: engine can optionally wrap in Docker/E2B if configured.
- [ ] For SDK mode: caller responsible for providing sandboxed environment.
- [ ] Built-in `e2b` provider (future): Spawns E2B sandbox, runs agent inside.

### Testing Infrastructure

#### Feature 8.1: Mock Mode for Testing
**Description:** Support mock execution for integration tests without invoking real providers (see `scripts/lib/mock.sh`).

**Acceptance Criteria:**
- [ ] `MOCK_MODE=true` env var: Replace provider execution with mock responses.
- [ ] `MOCK_FIXTURES_DIR` env var: Path to fixture files for mock responses.
- [ ] Mock response functions: `get_mock_response($iteration)`, `write_mock_status($path, $iteration)`, `write_mock_result($path, $iteration)`.
- [ ] `MOCK_DELAY` env var: Simulated delay between iterations (default: 0).
- [ ] `MOCK_ITERATION`, `MOCK_PROVIDER` env vars: Passed to mock functions for context.
- [ ] Mock mode skips provider CLI checks (allow tests without `claude`/`codex` installed).
- [ ] Engine exports `MOCK_STATUS_FILE`, `MOCK_RESULT_FILE` paths before executing agent for mock to write to.

**Fixture-Based Testing:**
```go
// Go equivalent of mock.sh
type MockConfig struct {
    FixturesDir string            // Path to response fixtures
    Delay       time.Duration     // Simulated execution time
    Responses   map[int]string    // Iteration → response override
}

func (m *MockConfig) Execute(iteration int) (string, error) {
    // Return fixture content or generate mock response
}
```

**Test Helpers:**
- [ ] `NewMockSession(t, fixtures)`: Create isolated test session with fixtures.
- [ ] `AssertIterationCount(t, session, expected)`: Validate iteration count.
- [ ] `AssertStateStatus(t, session, status)`: Validate final state.
- [ ] `AssertEventSequence(t, session, types)`: Validate event types emitted.

---

## Technical Approach

**Package Structure:**
```
# Public SDK packages (importable by external code)
pkg/
├── pipelines/           # Main SDK entry point
│   ├── engine.go        # Engine struct, Run(), Resume()
│   ├── hooks.go         # Hook registration and types
│   ├── options.go       # EngineOptions, functional options pattern
│   └── events.go        # Event channel subscription
├── provider/            # Provider interface and registry
│   ├── interface.go     # Provider interface definition
│   ├── registry.go      # Provider registration
│   ├── claude.go        # Built-in Claude provider
│   └── codex.go         # Built-in Codex provider
└── types/               # Shared types for SDK consumers
    ├── plan.go          # Plan, Node, Stage types
    ├── state.go         # State, History types
    ├── event.go         # Event types
    └── result.go        # Result, HookResult types

# Internal packages (not importable)
cmd/agent-pipelines/     # CLI entry point (cobra)
internal/
├── compile/             # YAML → plan.json compilation
├── context/             # context.json generation, input resolution, parallel_scope handling
├── engine/              # Session lifecycle, stage execution loop (wraps pkg/pipelines)
├── events/              # Append-only JSONL writer with file locking
│   ├── writer.go        # Atomic append with flock
│   ├── reader.go        # JSONL parsing with skip-invalid-lines
│   ├── reconcile.go     # State reconstruction from events
│   └── health.go        # Health scoring algorithm
├── hooks/               # Hook execution and YAML parsing
│   ├── executor.go      # Hook invocation logic
│   ├── yaml.go          # Parse hooks from pipeline YAML
│   └── actions.go       # Built-in actions (pause, webhook, script)
├── judge/               # External judge for judgment termination
│   ├── prompt.go        # Template rendering
│   ├── invoke.go        # Provider shell-out with retry
│   └── parse.go         # JSON stripping and normalization
├── lock/                # Session locking (flock-based)
├── mock/                # Test mock infrastructure
│   ├── provider.go      # Mock provider (replaces real CLI calls)
│   ├── fixtures.go      # Fixture loading and iteration responses
│   └── helpers.go       # Test assertion helpers
├── parallel/            # Goroutine-based parallel block orchestration
├── result/              # result.json parsing and validation
├── state/               # state.json atomic updates, resume logic
├── termination/         # Completion strategies (fixed, judgment, queue)
│   ├── fixed.go
│   ├── judgment.go      # Uses judge package
│   └── queue.go
├── resolve/             # Template variable resolution
└── validate/            # Lint and dry-run validation
```

**Data Flow:**
1. Parse CLI args, resolve pipeline file (check `.claude/pipelines/`, then `scripts/pipelines/`).
2. Compile YAML to `plan.json` (or use cached if fresh).
3. Acquire session lock.
4. Initialize run directory structure and `state.json`.
5. **Fire `session_start` hook** → if paused, exit cleanly.
6. Emit `session_start` event.
7. For each node in `plan.json.nodes[]`:
   - **Fire `stage_start` hook** → if paused, exit cleanly.
   - If `kind: stage`: run iterations with termination checks.
   - If `kind: parallel`: spawn goroutines per provider, wait for all.
   - **Fire `stage_end` hook** → if paused, exit cleanly.
8. Per iteration:
   - **Fire `iteration_start` hook** → if paused, exit cleanly.
   - Generate `context.json` with paths, inputs, limits, commands, **injected hook context**.
   - Resolve prompt template variables.
   - Execute provider via registry lookup, capture result.
   - Read/validate `result.json` (or convert from `status.json`).
   - Emit `iteration_complete` event.
   - Update state history.
   - **Fire `iteration_end` hook** → if paused, exit cleanly.
   - Check termination condition.
9. On completion: emit `session_complete`, release lock.
10. On pause: emit `session_paused`, write paused state, release lock, exit 0.

**SDK Design:**

The SDK exposes a clean Go API for programmatic pipeline execution:

```go
import "github.com/dodo-digital/agent-pipelines/pkg/pipelines"

// Create engine with options
engine := pipelines.NewEngine(
    pipelines.WithWorkDir("/path/to/project"),
    pipelines.WithProvider("claude", claudeProvider),
    pipelines.WithProvider("e2b", e2bProvider),
)

// Register hooks
engine.OnIterationEnd(func(ctx *pipelines.HookContext) pipelines.HookResult {
    if ctx.Iteration % 5 == 0 {
        return pipelines.Pause("Checkpoint review")
    }
    return pipelines.Continue()
})

// Subscribe to events (non-blocking channel)
events := engine.Subscribe()
go func() {
    for event := range events {
        log.Printf("[%s] %s", event.Type, event.Summary)
    }
}()

// Run pipeline
result, err := engine.Run(ctx, pipelines.RunOptions{
    Pipeline: "refine.yaml",  // or inline Plan struct
    Session:  "my-session",
    Context:  "Additional context for agents",
})

// Resume paused session with new context
result, err = engine.Resume(ctx, "my-session", "User feedback: focus on X")
```

**SDK Key Types:**
```go
// Engine is the main entry point
type Engine struct {
    providers  map[string]Provider
    hooks      *HookRegistry
    eventSubs  []chan Event
    workDir    string
}

// HookContext provides full context to hook functions
type HookContext struct {
    Session    string
    Stage      string
    Iteration  int
    Provider   string           // For parallel blocks
    State      *State
    Result     *Result          // For *_end hooks
    Progress   string           // Accumulated progress content
}

// HookResult tells the engine what to do next
type HookResult struct {
    Action   HookAction  // Continue, Pause, Abort, RestartStage, ModifyContext
    Reason   string      // Human-readable reason (for pause/abort)
    Context  string      // Additional context to inject (for ModifyContext)
}

// Event represents a pipeline lifecycle event
type Event struct {
    Type      string    // session_start, iteration_complete, etc.
    Timestamp time.Time
    Session   string
    Cursor    Cursor
    Data      any       // Event-specific payload
}
```

**SDK Design Principles:**
- **Functional options:** Configure engine via `With*` functions for clean API.
- **Channel-based events:** Non-blocking event subscription for real-time monitoring.
- **Context propagation:** All methods accept `context.Context` for cancellation.
- **Zero global state:** Multiple engines can run concurrently with different configs.
- **Provider injection:** Easy to mock providers for testing.

**Key Technical Decisions:**
- **File format preservation:** Output identical `plan.json`, `context.json`, `state.json`, `events.jsonl` to minimize migration friction.
- **Atomic writes:** All stateful files written atomically (write to temp, then rename).
- **Event writer with flock:** Use `syscall.Flock` on Unix, `LockFileEx` on Windows for event append safety.
- **Provider shell-out:** Keep provider integration simple—shell out to CLI. Future: SDK integration.
- **No embedded prompt templates:** Stages reference external `prompt.md` files, just like Bash engine.

**Plan Schema (v1):**
```json
{
  "session": {
    "name": "my-session",
    "inputs": ["/absolute/path/to/file.md"]
  },
  "pipeline": {
    "name": "refine",
    "overrides": {},
    "commands": {}
  },
  "nodes": [
    {
      "id": "plan",
      "kind": "stage",
      "path": "0",
      "stage": "improve-plan",
      "runs": 5,
      "termination": {"type": "judgment", "consensus": 2}
    }
  ],
  "dependencies": {}
}
```

**Context Schema (v3):**
```json
{
  "session": "my-session",
  "pipeline": "refine",
  "stage": {"id": "plan", "index": 0, "template": "improve-plan"},
  "iteration": 1,
  "paths": {
    "session_dir": ".claude/pipeline-runs/my-session",
    "stage_dir": ".claude/pipeline-runs/my-session/stage-00-plan",
    "progress": ".claude/pipeline-runs/my-session/stage-00-plan/progress.md",
    "output": ".claude/pipeline-runs/my-session/stage-00-plan/iterations/001/output.md",
    "status": ".claude/pipeline-runs/my-session/stage-00-plan/iterations/001/status.json",
    "result": ".claude/pipeline-runs/my-session/stage-00-plan/iterations/001/result.json"
  },
  "inputs": {
    "from_initial": [],
    "from_stage": {},
    "from_parallel": {},
    "from_previous_iterations": []
  },
  "limits": {"max_iterations": 25, "remaining_seconds": -1},
  "commands": {},
  "parallel_scope": null
}
```
- `parallel_scope` is set when running inside a parallel block: `{"scope_root": "...", "pipeline_root": "..."}`

**Directory Naming Convention:**
- Stage directories: `stage-{NN}-{id}` where NN is zero-padded 2-digit node index
- Parallel directories: `parallel-{NN}-{id}` where NN is zero-padded 2-digit node index
- Iteration directories: `iterations/{NNN}` where NNN is zero-padded 3-digit iteration number
- Examples: `stage-00-plan`, `parallel-01-refine`, `iterations/001`, `iterations/015`

**Template Resolution Rules:**
- Only simple string substitution; no shell evaluation
- v3 variables: `${CTX}`, `${STATUS}`, `${RESULT}`, `${PROGRESS}`, `${OUTPUT}` resolved from context.json paths
- Deprecated variables (`${SESSION}`, `${SESSION_NAME}`, `${ITERATION}`, `${INDEX}`, `${CONTEXT}`) still supported
- Missing values resolve to empty string; unknown placeholders left unchanged
- Line endings and whitespace in prompt files preserved

**CONTEXT Precedence:**
1. CLI `--context` flag (highest)
2. `CLAUDE_PIPELINE_CONTEXT` env var
3. Stage-level `context:` in stage.yaml
4. Hook `modify_context` appends (newline-separated)

**Commands Precedence:**
1. CLI `--command` flags (highest)
2. Stage-level `commands:` in stage.yaml
3. Pipeline-level `commands:` in pipeline.yaml
4. Defaults (if any)

Merge is key-based: higher precedence replaces the command string for that key; other keys preserved.

**Progress File Hierarchy:**
- Stage-level: `.claude/pipeline-runs/{session}/stage-XX-{name}/progress.md` (preferred)
- Session-level fallback: `.claude/pipeline-runs/{session}/progress-{session}.md` (backward compatibility)
- Context generation checks stage-level first, falls back to session-level if not found.
- Parallel blocks use provider-isolated progress: `parallel-XX-{name}/providers/{provider}/progress.md`.

**Progress File Ownership:**
- **Session-level**: Engine creates with header; agents append findings
- **Stage-level**: Engine creates if stage has `progress: true`; agents append
- **Parallel provider**: Engine creates per-provider file; only that provider appends
- **Write mode**: Always append (never overwrite). Agents use `>> progress.md`
- **On stage complete**: Stage progress is preserved; agents read via `from_previous_iterations`
- **Cross-stage**: Agents can read other stages' progress via explicit `inputs.from`

**Result Schema (v3):**
```json
{
  "summary": "One paragraph describing what happened",
  "work": {
    "items_completed": ["item-1", "item-2"],
    "files_touched": ["src/foo.ts", "src/bar.ts"]
  },
  "artifacts": {
    "outputs": ["Optional list of output descriptions"],
    "paths": ["Optional list of output file paths"]
  },
  "signals": {
    "plateau_suspected": false,  // Hint for judgment termination
    "risk": "low",               // low/medium/high
    "notes": ""                  // Free-form notes
  }
}
```
- `status.json` (legacy v2 format) still supported: `{decision, reason, summary, work, errors}`.
- Engine converts status.json to result.json format internally if needed.

**Error Taxonomy:**
| Error Type | Retryable | Description | Recovery |
|------------|-----------|-------------|----------|
| `provider_timeout` | Yes | Provider CLI didn't respond within timeout | Retry with backoff |
| `provider_crashed` | Yes | Provider CLI exited non-zero without result | Retry once, then fail |
| `provider_missing` | No | Provider CLI not found in PATH | Fail with install guidance |
| `result_invalid` | No | Agent wrote malformed result.json | Fail, log raw output |
| `result_missing` | Yes | Agent completed but didn't write result | Retry once, then fail |
| `lock_contention` | No | Session locked by another process | Fail with guidance |
| `state_corrupt` | No | state.json or events.jsonl unreadable | Fail, suggest manual recovery |
| `signal_interrupt` | No | SIGINT/SIGTERM received | Clean shutdown |
| `iteration_timeout` | Yes | Iteration exceeded max runtime | Retry with shorter context |
| `judge_failed` | Yes | Judge invocation failed | Skip judge, continue |

**Error Handling Strategy:**
1. Retryable errors: Retry up to 2 attempts with exponential backoff
2. Fatal errors: Mark session failed, emit `error` event with type and context
3. All errors: Write to `iterations/NNN/error.json` with full details for debugging
4. Resume guidance: Failed sessions print exact command to resume from failure point

**Session State Machine:**
```
┌─────────┐
│ pending │ (state.json doesn't exist yet)
└────┬────┘
     │ start
     ▼
┌─────────┐   pause    ┌────────┐   resume   ┌─────────┐
│ running │ ─────────► │ paused │ ──────────► │ running │
└────┬────┘            └────┬───┘            └─────────┘
     │                      │
     │ complete             │ abort
     ▼                      ▼
┌───────────┐          ┌─────────┐
│ completed │          │ aborted │
└───────────┘          └─────────┘
     ▲                      ▲
     │                      │
┌────┴────┐            ┌────┴────┐
│ failed  │◄───────────│ running │ (on error)
└─────────┘            └─────────┘
```

**Invalid Transitions (should error):**
- `resume` on `completed`: "Session already completed. Use --force to restart."
- `pause` on `completed`: Already finished
- `running` → `running`: Lock contention (session already active)

**State Schema:**
```json
{
  "session": "auth",
  "type": "ralph",                    // Stage type (for single-stage) or "pipeline"
  "pipeline": "refine.yaml",          // Pipeline file (if multi-stage)
  "status": "running",                // running, completed, failed, paused, aborted
  "iteration": 5,                     // Current iteration (for single-stage)
  "iteration_completed": 4,           // Last fully completed iteration
  "iteration_started": "2025-01-10T10:05:00Z",  // When current iteration began (null if none in progress)
  "started_at": "2025-01-10T10:00:00Z",
  "completed_at": null,               // Set on completion
  "current_stage": "stage-00-plan",   // Current stage directory name (multi-stage)
  "stages": [                         // Completed stages (multi-stage)
    {"name": "plan", "index": 0, "iterations": 5, "completed_at": "..."}
  ],
  "history": [                        // Per-iteration signals for termination
    {"plateau": false, "risk": "low"},
    {"plateau": true, "risk": "low"}
  ],
  "event_offset": 42,                 // Last processed event line (for reconciliation)
  "error": null,                      // Error message if status == "failed"
  "error_type": null                  // Error classification (provider_failed, timeout, etc.)
}
```
- `iteration_started` + `iteration_completed` gap indicates crash during iteration.
- Resume calculates: `resume_from = iteration_completed + 1`.

**Event Cursor Format:**
```json
{
  "node_path": "0",           // Index path in plan.json nodes array (e.g., "0", "1", "2.0" for nested)
  "node_run": 1,              // Which run of the node (for nodes with runs > 1)
  "iteration": 3,             // Iteration number within the run
  "provider": "claude"        // Optional: provider name for parallel block events
}
```
- Used in all events to track position for resume.
- `node_path` matches `plan.json.nodes[N].path`.
- For session-level events (`session_start`, `session_complete`), cursor may be null or derived from state.

**Concurrency Model:**
- Single goroutine for sequential stages.
- Parallel blocks spawn N goroutines (one per provider).
- Shared event writer protected by flock.
- Each provider has isolated state.json in its subdirectory.
- Block waits for all providers via `sync.WaitGroup`.

**Integrations:**
- Provider CLIs (claude, codex) via `os/exec`.
- Optional `bd` CLI for queue termination strategy.
- tmux for background sessions (optional, `--foreground` skips).

**Constraints:**
- No breaking changes to pipeline/stage YAML schema.
- Identical directory structure under `.claude/pipeline-runs/`.
- Must support concurrent sessions with different names safely.

---

## Test Strategy

**Unit Tests:**
- Plan compilation: YAML → plan.json with all node types, termination configs, and overrides.
- Template resolution: All variables (`${CTX}`, `${PROGRESS}`, etc.) resolve correctly.
- Termination strategies: fixed counts, judgment consensus, queue empty detection.
- Event writer: Concurrent appends don't corrupt or lose events.
- State updates: Atomic writes, resume iteration calculation, stage tracking.
- Input resolution: Globs, directories, relative paths → absolute paths.

**Integration Tests (with mock provider):**
- Single-stage pipeline: Run N iterations, verify artifacts.
- Multi-stage pipeline: Chain stages, verify `inputs.from_stage` resolution.
- Parallel block execution: Two mock providers, isolated state, manifest generation.
- Resume scenarios: Crash mid-iteration, resume from correct point.
- Lock contention: Two processes attempting same session.

**E2E Scenarios (with real provider):**
1. `ralph auth 3`: Run 3-iteration fixed loop with Claude, verify all artifacts.
2. `pipeline refine.yaml test`: Run multi-stage pipeline, verify stage-to-stage data flow.
3. Parallel block with Claude + Codex: Both complete, manifest aggregates outputs.
4. Judgment termination: Run until consensus or max iterations.

**Regression Tests:**
- Compare Go engine output artifacts against Bash engine for identical inputs.
- Golden file tests for `plan.json`, `context.json`, `state.json` structure.
- Event sequence validation against expected order.

**Edge Cases:**
- Simultaneous event writes from 4+ parallel providers.
- Crash during iteration (verify `iteration_started` vs `iteration_completed` resume logic).
- Missing provider CLI (graceful error message).
- Windows: Path handling (`\` vs `/`), file locks (no flock), long paths.
- Very long sessions (1000+ iterations): Event file performance.
- Unicode in session names and paths.
- Empty pipeline (zero nodes): Graceful handling.

**Judge Module Tests:**
- Judge returns valid JSON: Parse and use decision.
- Judge returns JSON wrapped in markdown fence: Strip fence and parse.
- Judge returns invalid JSON: Return `{stop: false, reason: "invalid_json"}`, do not crash.
- Judge invocation fails: Retry once, then return `{stop: false, reason: "invoke_failed"}`.
- Judge fails 3+ consecutive times: Skip judge entirely, return `{stop: false, reason: "judge_unreliable"}`.
- Judge prompt template not found: Error with clear message about expected paths.

**Event Reconciliation Tests:**
- Session with events.jsonl but no state.json: Reconstruct state correctly.
- Session with both files but state.json is stale: Use events as source of truth.
- Session with active lock: Skip reconciliation (session is running).
- Events file with corrupted final line: Skip invalid line, process rest.
- Events file with mid-file corruption: Warn and skip invalid lines.

**Parallel Input Resolution Tests:**
- `from_parallel` as string shorthand: Resolve to all providers' latest outputs.
- `from_parallel` as object with provider filter: Resolve to filtered providers only.
- `from_parallel` as array: Resolve each entry independently, return array in context.json.
- Per-provider inputs in object format: Each provider receives its configured inputs.
- Cross-evaluation pattern: Provider A receives Provider B's output and vice versa.
- Array `from_parallel` with mixed stages: Entries from different parallel blocks resolve correctly.
- Provider model override: Object format `model` field overrides stage default.

**Signal Handling Tests:**
- SIGINT during iteration: Wait for completion (up to 30s), then clean exit with lock release.
- SIGTERM during iteration: Same behavior as SIGINT.
- SIGINT during provider execution: Forward signal to child, wait for exit.
- Forced shutdown (double SIGINT): If second signal within 5s, force immediate exit.
- Lock release on signal: Verify lock file removed after signal-triggered exit.
- State consistency: After signal, `iteration_started` is null if iteration didn't complete.

**Hook System Tests:**
- Hook registration: Multiple hooks per point execute in registration order.
- Hook `continue`: Pipeline proceeds normally.
- Hook `pause`: State written with `status: paused`, lock released, exit 0.
- Hook `abort`: Pipeline stops immediately with `status: aborted`.
- Hook `modify_context`: Injected context appears in next iteration's `${CONTEXT}`.
- Hook `restart_stage`: Stage restarts from iteration 1 with modified context.
- Hook condition evaluation: YAML `condition:` expressions evaluated correctly.
- Hook timeout: Webhook hooks respect `timeout:` config.
- Resume after pause: `--resume` loads paused state and continues.
- Resume with context: `--resume --context "..."` injects context on resume.
- Pause during parallel block: All providers complete current iteration before pause.

**SDK Tests:**
- `engine.Run()`: Executes pipeline and returns result.
- `engine.Resume()`: Resumes paused session with context injection.
- `engine.Subscribe()`: Returns channel that receives all events.
- `engine.RegisterProvider()`: Custom provider used when stage specifies it.
- Multiple engines: Two `Engine` instances run concurrently without interference.
- Hook errors: Hook panic is caught and logged, pipeline continues (configurable).
- Context cancellation: `ctx.Done()` triggers graceful shutdown.

---

## Out of Scope (v1)

- **Provider SDK/API integration:** v1 uses CLI shell-out only. Direct API calls are future work.
- **New YAML schema or prompt format changes:** Strict backward compatibility.
- **Frontend UI or web dashboard:** SDK enables this but not included in v1.
- **WebSocket server:** Architecture supports it but not included in v1.
- **Multi-node distributed execution:** Single-machine only.
- **E2B/OpenCode providers:** Provider interface allows these but built-in implementations are future work.
- **Windows support:** Excluded from v1. No Windows binaries, CI, or testing. Future milestone.
- **Smart completion detection:** Engine waits for process exit, not status.json. Agents that hang after writing status.json will timeout. (Known limitation with Codex CLI.)

---

## Open Questions (Resolved)

| Question | Decision |
|----------|----------|
| Go binary vs wrapper? | Go binary implements CLI directly. `scripts/run.sh` optionally delegates to Go binary via `AGENT_PIPELINES_GO=1` env var for gradual migration. |
| Keep `.claude/` layout? | Yes, identical layout. No versioning—this is a drop-in replacement. |
| Built-in or plugin completion strategies? | Built-in only for v1. `fixed`, `judgment`, `queue` compiled into binary. |
| Windows file locking? | Use `golang.org/x/sys/windows` for `LockFileEx`. Fallback to advisory locks if unavailable. |

---

## Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Subtle behavioral differences from Bash engine | High | Medium | Golden file regression tests comparing Go vs Bash output. |
| Windows file locking doesn't behave like Unix flock | Medium | Medium | Test on Windows CI. Document differences. |
| Judge (Haiku) integration for judgment termination | Medium | Low | Shell out to `claude` with Haiku model, same as Bash engine. |
| Large event files cause performance issues | Low | Low | Events are append-only; reads use streaming/tail. |
| Plugin context path resolution differs | Medium | Medium | Test with actual plugin installation. Honor `AGENT_PIPELINES_ROOT` env var. |
| Signal handling race conditions | Medium | Medium | Use Go's signal package with buffered channel; test with signal injection. |
| Child process orphaning on crash | Low | High | Use process groups; implement watchdog for stuck providers. |

---

## Implementation Phases

### Phase 1: Core Engine (MVP)
- CLI parsing and help (cobra)
- Plan compilation (YAML → plan.json)
- Single-stage pipeline execution with fixed termination
- Provider interface and registry
- Claude provider (CLI shell-out)
- State management (init, update, resume)
- Basic event emission
- Public SDK package structure (`pkg/pipelines`, `pkg/provider`, `pkg/types`)

### Phase 2: Full Parity
- All termination strategies (judgment with Haiku judge, queue with bd)
- Multi-stage pipelines with input resolution
- Parallel block execution with isolated state
- Session locking (flock-based)
- Codex provider support
- Event reconciliation for crash recovery
- `status`, `tail`, `list` commands

### Phase 3: SDK & Hooks
- Hook system implementation (all hook points)
- SDK hook registration API (`OnIterationEnd`, etc.)
- YAML hook configuration (`hooks:` section in pipelines)
- Pause/resume with context injection
- Event channel subscription for SDK consumers
- `--resume --context` CLI support
- Plugin context awareness (`AGENT_PIPELINES_ROOT`)
- Migration guide and `AGENT_PIPELINES_GO=1` wrapper mode

### Phase 4: Platform (Future)
- E2B provider (sandboxed agent execution)
- OpenCode provider (open-source models)
- Provider SDK integration (direct API calls instead of CLI)
- WebSocket server for real-time frontends
- MCP server exposing pipelines as tools
- Windows support
- `lint` and `dry-run` commands

---

## Notes

- **Reference implementation:** `scripts/engine.sh` (main loop), `scripts/lib/*.sh` (supporting modules).
- **Related plans:** `docs/plans/loop-architecture-v3.md`, `DEVPLAN.md`.
- **Test fixtures:** Existing `scripts/tests/` can be adapted for Go engine regression testing.
