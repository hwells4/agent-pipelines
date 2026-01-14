---
description: Start any pipeline or stage quickly with smart defaults and discovery
---

# /start

The universal pipeline launcher. Discover, select, and start any pipeline or stage with intelligent suggestions.

## Usage

```
/start                      # Interactive - browse and select
/start ralph                # Quick-start a stage by name
/start refine.yaml          # Quick-start a pipeline by name
/start --recent             # Show recently run sessions
/start --popular            # Show most-used stages/pipelines
```

## Interactive Mode

When invoked without arguments, guides you through:

1. **Discovery** - Show available stages and pipelines
2. **Selection** - Pick one, with smart suggestions
3. **Configuration** - Session name, iterations, options
4. **Launch** - Start in tmux with verification

## Quick Start Examples

```bash
# Start a ralph loop
/start "a ralph loop on our auth feature for 25 iterations" or "ralph auth 25"

# Start a refinement pipeline
/start a refinement loop on my-project

# Resume a crashed session
/start resume our auth session

# Start with specific provider
/start ralph auth 25 --provider=codex
```

## Discovery Features

The command discovers and presents:

| Category | Source | Description |
|----------|--------|-------------|
| **Stages** | `scripts/stages/` | Single-stage pipeline types |
| **Pipelines** | `scripts/pipelines/*.yaml` | Multi-stage configurations |
| **Recent** | `.claude/pipeline-runs/` | Sessions run in the last 7 days |
| **Favorites** | `.claude/pipeline-history.json` | Most frequently used (future) |

## Extensibility

Designed for future marketplace integration:

```yaml
# Future: .claude/marketplace/stages/community-stage/
# Future: .claude/marketplace/pipelines/team-workflow.yaml
```

The discovery system will scan additional directories when marketplace is implemented.

## Skill Chain

```
/start
    │
    ▼
┌─────────────────────────┐
│    start skill          │
│                         │
│  1. Discover options    │
│  2. Smart suggestions   │
│  3. Gather config       │
│  4. Validate & launch   │
│                         │
└─────────────────────────┘
```

## Related Commands

| Command | Purpose |
|---------|---------|
| `/sessions` | Manage running sessions (list, monitor, kill) |
| `/ralph` | Quick-start specifically for ralph loops |
| `/refine` | Quick-start specifically for refinement |
| `/pipeline` | Design or edit pipeline configurations |

---

**Invoke the start skill for:** $ARGUMENTS
