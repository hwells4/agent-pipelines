# /pipeline

Intelligent router for pipeline design, creation, and editing.

## Usage

```
/pipeline                 # Interactive - routes based on intent
/pipeline edit            # Jump to pipeline-editor skill
/pipeline create [spec]   # Jump to pipeline-creator with spec
```

## Routing Logic

When invoked, intelligently route to the appropriate skill:

| Intent | Skill | Trigger Phrases |
|--------|-------|-----------------|
| Build new | `pipeline-designer` | "build", "create", "new", "I want to..." |
| Edit existing | `pipeline-editor` | "edit", "modify", "change", "update" |
| Create from spec | `pipeline-creator` | "create [path]", has spec file |

### Subcommand Shortcuts

| Subcommand | Routes To |
|------------|-----------|
| `/pipeline` | Ask intent → route |
| `/pipeline edit` | `pipeline-editor` directly |
| `/pipeline create [spec]` | `pipeline-creator` with spec |

## How to Route

### No Subcommand

Ask what they want:

```json
{
  "questions": [{
    "question": "What would you like to do with pipelines?",
    "header": "Intent",
    "options": [
      {"label": "Build New", "description": "Design and create a new pipeline"},
      {"label": "Edit Existing", "description": "Modify an existing stage or pipeline"},
      {"label": "Learn", "description": "Ask questions about the pipeline system"}
    ],
    "multiSelect": false
  }]
}
```

Then invoke the appropriate skill:

| Response | Action |
|----------|--------|
| "Build New" | Invoke `pipeline-designer` skill |
| "Edit Existing" | Invoke `pipeline-editor` skill |
| "Learn" | Invoke `pipeline-designer` skill (has questions workflow) |

### With `edit` Subcommand

Directly invoke `pipeline-editor` skill.

### With `create [spec]` Subcommand

Directly invoke `pipeline-creator` skill with the spec path.

## Skill Chain

For building new pipelines, the full chain is:

```
/pipeline
    │
    ▼
┌─────────────────────────┐
│   pipeline-designer     │
│                         │
│  1. Understand intent   │
│  2. Spawn arch agent    │
│  3. Present & confirm   │
│                         │
└───────────┬─────────────┘
            │ On "yes"
            ▼
┌─────────────────────────┐
│   pipeline-creator      │
│                         │
│  1. Create new stages   │
│  2. Assemble pipeline   │
│  3. Validate & present  │
│                         │
└─────────────────────────┘
            │
            ▼
    Ready-to-run command
```

For editing, it's direct:

```
/pipeline edit
    │
    ▼
┌─────────────────────────┐
│   pipeline-editor       │
│                         │
│  1. Identify target     │
│  2. Load current config │
│  3. Collect changes     │
│  4. Apply & validate    │
│                         │
└─────────────────────────┘
```

## Examples

### Build a New Pipeline

```
User: /pipeline

Claude: What would you like to do with pipelines?
        [Build New] [Edit Existing] [Learn]

User: Build New

Claude: [Invokes pipeline-designer skill]
        What problem are you trying to solve?

User: I want to review code until it's elegant.

Claude: [Spawns architecture agent]
        Here's my recommendation...
        [Shows architecture]
        Does this look right? [Yes, build it] [No, adjust]

User: Yes, build it

Claude: [Invokes pipeline-creator skill]
        [Creates files, validates]

        Pipeline created!
        Run it: ./scripts/run.sh elegance-review my-branch 10
```

### Edit an Existing Stage

```
User: /pipeline edit

Claude: [Invokes pipeline-editor skill]
        What do you want to edit?
        [Stage] [Pipeline]

User: Stage

Claude: Which stage?
        [work] [improve-plan] [elegance] ...

User: elegance

Claude: [Shows current config]
        What would you like to change?
        [Termination] [Iterations] [Model] [Prompt]
```

### Quick Edit via Natural Language

```
User: Change the elegance stage to use opus

Claude: [Detects edit intent, invokes pipeline-editor]
        [Makes change, validates]

        Updated elegance stage to use opus.
```

## Skill References

| Skill | Purpose | File |
|-------|---------|------|
| pipeline-designer | Design new pipeline architectures | `skills/pipeline-designer/SKILL.md` |
| pipeline-editor | Edit existing configurations | `skills/pipeline-editor/SKILL.md` |
| pipeline-creator | Create files from specs | `skills/pipeline-creator/SKILL.md` |

## Related Commands

| Command | Purpose |
|---------|---------|
| `/loop-agents:sessions` | Run and manage pipeline sessions |
| `/work` | Quick-start work pipelines |
| `/refine` | Quick-start refinement pipelines |
