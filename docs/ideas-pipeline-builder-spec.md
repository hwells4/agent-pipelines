# Ideas from pipeline-builder-spec - Iteration 1

> Focus: Ideas to improve the pipeline-builder skills and the experience of creating custom pipelines

---

### 1. Stage Catalog with Live Preview

**Problem:** Users creating pipelines must understand what existing stages do by reading YAML and prompt files. There's no quick way to browse available stages, see examples of their output, or understand their tradeoffs.

**Solution:** Build a stage catalog accessible via `/pipeline catalog`:
- Interactive list showing all stages in `scripts/loops/`
- For each stage: description, termination strategy, model recommendation
- "Example output" showing a real iteration result from that stage
- Recommendation tags: "good for planning", "high-quality output", "fast"
- Can be invoked mid-conversation: "Show me stages that use judgment termination"

**Why now:** The pipeline-builder spec introduces automatic stage selection by the architecture agent. That agent needs a rich understanding of stage capabilities to recommend well. A catalog becomes the source of truth for both humans and agents.

---

### 2. Prompt Composability via Template Includes

**Problem:** The pipeline-builder creates stage prompts from scratch, leading to inconsistency. Every new stage reinvents the "read context" and "write status" patterns. Copy-paste errors accumulate. Best practices diverge.

**Solution:** Add template includes for common patterns:
```markdown
# My Custom Stage

${include:preamble/autonomy-grant.md}

## Your Mission
[Custom content here]

${include:patterns/read-context.md}
${include:patterns/write-status.md}
```
Include library in `scripts/lib/templates/`:
- `autonomy-grant.md` - "This is not a checklist task..." paragraph
- `read-context.md` - Standard cat/jq commands
- `write-status.md` - JSON schema and decision guide
- `subagent-guidance.md` - When and how to spawn subagents

**Why now:** The Stage Creator Agent in the spec will generate many prompts. Includes ensure consistency without requiring the agent to memorize boilerplate. Humans benefit equally when hand-crafting stages.

---

### 3. Pipeline Visualization Command

**Problem:** Multi-stage pipelines are defined in YAML but understanding the flow requires mental parsing. Users can't quickly see: stage order, data flow between stages, estimated iteration counts, or cost implications.

**Solution:** Add `./scripts/run.sh viz {pipeline}` that generates:
- ASCII art showing stage sequence and data flow
- Annotations with iteration counts and models per stage
- Estimated token usage range (min/max based on history)
- Dependency arrows showing `inputs.from` relationships
```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│  improve-plan   │────▶│  refine-beads   │────▶│    elegance     │
│  5 iters, opus  │     │  5 iters, opus  │     │  3 iters, opus  │
│  ~50k tokens    │     │  ~40k tokens    │     │  ~30k tokens    │
└─────────────────┘     └─────────────────┘     └─────────────────┘
```

**Why now:** The pipeline-builder spec introduces complex multi-stage architectures. Visualization bridges the gap between YAML configuration and human understanding. Critical for reviewing architecture agent recommendations.

---

### 4. Confidence Scoring for Architecture Recommendations

**Problem:** The architecture agent returns a recommendation, but users don't know how confident it is. Was this the obvious choice or a toss-up between three options? Should the user ask clarifying questions or trust it?

**Solution:** Add confidence scoring to architecture agent output:
```yaml
recommendation:
  confidence: 0.85  # 0-1 scale
  confidence_breakdown:
    termination_strategy: 0.95  # Very clear this should be judgment
    stage_count: 0.70           # Could be 2 or 3 stages
    model_selection: 0.90       # Opus clearly needed
  areas_of_uncertainty:
    - "Unclear if refine-beads should run before or after elegance"
    - "User's tolerance for cost vs quality tradeoff unknown"
```
Display to user: "I'm 85% confident in this architecture. Key uncertainty: stage ordering."

**Why now:** The spec positions the architecture agent as mandatory before confirmation. Confidence scoring helps users decide whether to accept immediately or probe further. Transparent AI decision-making builds trust.

---

### 5. Stage A/B Testing Framework

**Problem:** Users can't empirically compare different stage configurations. Does 3-consensus outperform 2-consensus? Is Sonnet good enough for this task? Currently: guess and hope.

**Solution:** Add A/B testing support:
```bash
./scripts/run.sh ab-test \
  --config-a "elegance-3consensus.yaml" \
  --config-b "elegance-2consensus.yaml" \
  --trials 5 \
  --session-prefix "elegance-ab"
```
- Runs both configurations N times with identical inputs
- Records: iterations-to-complete, token usage, output quality (via LLM eval)
- Generates comparison report with statistical significance
- Stores results in `.claude/ab-tests/` for future reference

**Why now:** The pipeline-builder empowers users to create custom stages with arbitrary configurations. Without measurement, they can't optimize. A/B testing turns pipeline design from art into science.

---
