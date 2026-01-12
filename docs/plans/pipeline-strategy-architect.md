# Plan: Pipeline Strategy Architect Sub-Agent

> "Let the specialist design the pipeline, then let another confirm and build."

## Overview

Add a specialized **Pipeline Strategy Architect** sub-agent to the pipeline builder workflow. This agent is trained intimately on pipeline strategy—how pipelines are built, how inputs/outputs operate, how stages flow together. It maintains dedicated context for pipeline structuring, separate from user interview and implementation concerns.

## Problem Statement

Currently the pipeline builder workflow handles everything in one context:
1. User interview (gathering requirements)
2. Pipeline strategy (designing stage flow)
3. Implementation (writing YAML/prompts)

This creates context pressure and mixes concerns. Pipeline strategy is a specialized skill that benefits from focused context.

## Proposed Architecture

```
┌─────────────────┐     ┌──────────────────────┐     ┌─────────────────┐
│  Interview      │────▶│  Strategy Architect  │────▶│  Builder Agent  │
│  Agent          │     │  (specialized)       │     │                 │
│                 │     │                      │     │                 │
│  - Gathers reqs │     │  - Pipeline design   │     │  - Confirms     │
│  - User context │     │  - Stage flow        │     │  - Writes YAML  │
│  - Goals/scope  │     │  - I/O mapping       │     │  - Writes prompts│
└─────────────────┘     │  - Completion strats │     └─────────────────┘
                        └──────────────────────┘
                                  │
                                  ▼
                        ┌──────────────────────┐
                        │  Pipeline Proposal   │
                        │                      │
                        │  - Stage definitions │
                        │  - Flow diagram      │
                        │  - Rationale         │
                        │  - Trade-offs        │
                        └──────────────────────┘
```

## Strategy Architect Responsibilities

The sub-agent specializes in:

### Pipeline Design Patterns
- Single-stage vs multi-stage decisions
- Stage sequencing and dependencies
- When to use each completion strategy (beads-empty, plateau, fixed-n, all-items)

### Input/Output Flow
- How `${INPUTS}` flows between stages
- Named stage outputs (`${INPUTS.stage-name}`)
- Progress file accumulation patterns

### Completion Strategy Selection
| Pattern | When to Use |
|---------|-------------|
| `beads-empty` | Task-driven work, external completion signal |
| `plateau` | Refinement, consensus-based stopping |
| `fixed-n` | Exploration, time-boxed ideation |
| `all-items` | Batch processing, list iteration |

### Trade-off Analysis
- Iteration count vs quality
- Stage granularity vs context overhead
- Fresh context per iteration vs accumulated state

## Workflow Integration

### Current Flow
```
User Interview → Design & Build (combined)
```

### Proposed Flow
```
User Interview → Strategy Architect → Proposal Review → Build
```

### Handoff Protocol

**Interview → Architect handoff:**
```yaml
requirements:
  goal: "What user wants to accomplish"
  constraints: "Iteration limits, time bounds, etc."
  completion_signal: "How we know it's done"
  context_needs: "What context accumulates"
```

**Architect → Builder handoff:**
```yaml
proposal:
  name: "pipeline-name"
  stages: [...]
  rationale: "Why this design"
  alternatives_considered: [...]
  trade_offs: [...]
```

## Implementation Steps

1. **Create architect reference doc** (`skills/pipeline-builder/references/architect-guide.md`)
   - Pipeline design patterns
   - Completion strategy decision tree
   - I/O flow patterns
   - Common anti-patterns

2. **Create architect prompt template** (`skills/pipeline-builder/workflows/strategy-architect.md`)
   - Focused system prompt for pipeline design
   - Structured output format for proposals
   - Rationale requirements

3. **Update pipeline-builder workflow**
   - Add interview → architect handoff
   - Add proposal review step
   - Add architect → builder handoff

4. **Add proposal format**
   - Stage definitions with explanations
   - ASCII flow diagram
   - Rationale section
   - Alternative approaches considered

## Benefits

1. **Specialized Context**: Architect agent loads only pipeline design knowledge, not user interview history or implementation details

2. **Better Proposals**: Focused context produces more thoughtful pipeline designs with clear rationale

3. **Cleaner Handoffs**: Structured proposal format ensures nothing lost between agents

4. **Reviewable Artifacts**: Proposals become documentation for why pipelines were designed a certain way

## Open Questions

- [ ] Should architect have access to existing pipeline examples? (probably yes)
- [ ] How much of the interview context does architect need? (summary vs full)
- [ ] Should proposals be saved as artifacts? (probably yes, for iteration)
- [ ] Does the builder need to confirm with user before implementing? (probably yes)

## Status

**Deferred** - To be implemented after unified pipeline engine architecture is complete.
