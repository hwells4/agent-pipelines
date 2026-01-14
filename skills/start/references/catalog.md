# Pipeline Catalog Reference

Quick reference for all available stages and pipelines with their characteristics.

## Stages

### Work Stages

| Stage | Description | Termination | Default Max |
|-------|-------------|-------------|-------------|
| **ralph** | Work through beads queue | Fixed | 25 |
| **work** | Alternative work implementation | Fixed | 25 |

### Planning Stages

| Stage | Description | Termination | Consensus |
|-------|-------------|-------------|-----------|
| **improve-plan** | Iterative plan refinement | Judgment | 2 |
| **research-plan** | Research-driven planning | Judgment | 2 |
| **tdd-plan-refine** | TDD-focused planning | Judgment | 2 |

### Task Stages

| Stage | Description | Termination | Consensus |
|-------|-------------|-------------|-----------|
| **refine-tasks** | Refine beads/tasks | Judgment | 2 |
| **tdd-create-beads** | Create beads from TDD plan | Judgment | 2 |

### Review Stages

| Stage | Description | Termination | Consensus |
|-------|-------------|-------------|-----------|
| **elegance** | Code elegance review | Judgment | 2 |
| **code-review** | General code review | Judgment | 2 |
| **test-review** | Test quality review | Judgment | 2 |

### Discovery Stages

| Stage | Description | Termination | Default Max |
|-------|-------------|-------------|-------------|
| **bug-discovery** | Find bugs with fresh eyes | Fixed | 8 |
| **bug-triage** | Triage and prioritize bugs | Judgment | 5 |
| **idea-wizard** | Generate improvement ideas | Fixed | 5 |
| **idea-wizard-loom** | Loom-style ideation | Fixed | 5 |
| **test-scanner** | Find test coverage gaps | Judgment | 5 |

### Documentation Stages

| Stage | Description | Termination | Consensus |
|-------|-------------|-------------|-----------|
| **readme-sync** | Sync README with codebase | Judgment | 2 |
| **doc-updater** | Update documentation | Judgment | 2 |

### Testing Stages

| Stage | Description | Termination | Consensus |
|-------|-------------|-------------|-----------|
| **test-analyzer** | Analyze test quality | Judgment | 2 |
| **test-planner** | Plan test strategy | Judgment | 2 |
| **tdd-work** | TDD implementation | Fixed | 25 |
| **robot-mode** | CLI agent-friendliness audit | Fixed | 3 |

## Pipelines

### Refinement Pipelines

| Pipeline | Stages | Total Iterations |
|----------|--------|------------------|
| **quick-refine.yaml** | improve-plan(3) → refine-tasks(3) | 6 max |
| **refine.yaml** | improve-plan(5) → refine-tasks(5) | 10 max |
| **deep-refine.yaml** | improve-plan(8) → refine-tasks(8) | 16 max |
| **design-refine.yaml** | improve-plan(5) → elegance(5) | 10 max |

### Discovery Pipelines

| Pipeline | Stages | Description |
|----------|--------|-------------|
| **ideate.yaml** | idea-wizard(5) | Generate improvement ideas |
| **bug-hunt.yaml** | bug-discovery(8) → bug-triage(5) → refine-tasks(3) → ralph(25) | Full bug hunting |
| **test-gap-discovery.yaml** | test-scanner(5) → test-planner(3) | Find and plan test gaps |

### TDD Pipelines

| Pipeline | Stages | Description |
|----------|--------|-------------|
| **tdd-implement.yaml** | tdd-plan-refine(5) → tdd-create-beads(3) → tdd-work(25) | Full TDD flow |
| **queue-provider-tdd.yaml** | Parallel claude+codex TDD | Multi-provider TDD |

## Selection Guidance

### By Goal

| I want to... | Recommended |
|--------------|-------------|
| Implement beads tasks | `ralph` |
| Refine a plan | `refine.yaml` or `improve-plan` |
| Find bugs | `bug-hunt.yaml` or `bug-discovery` |
| Generate ideas | `ideate.yaml` |
| Review code quality | `elegance` |
| Improve test coverage | `test-gap-discovery.yaml` |
| Do TDD | `tdd-implement.yaml` |

### By Time Available

| Time | Recommended |
|------|-------------|
| < 30 min | Single stage with 5-10 iterations |
| 30-60 min | `quick-refine.yaml` or 25-iteration stage |
| 1-2 hours | `refine.yaml` or `deep-refine.yaml` |
| Extended | `bug-hunt.yaml` or multi-stage custom |

## Provider Compatibility

All stages support both Claude and Codex providers:

```bash
# Claude (default)
./scripts/run.sh ralph auth 25

# Codex
./scripts/run.sh ralph auth 25 --provider=codex

# Specific model
./scripts/run.sh ralph auth 25 --model=opus
./scripts/run.sh ralph auth 25 --provider=codex --model=o3
```

## Future: Marketplace Categories

When marketplace is implemented:

```
.claude/marketplace/
├── stages/
│   ├── community/
│   │   └── security-audit/
│   └── team/
│       └── our-custom-review/
└── pipelines/
    ├── community/
    │   └── full-security-scan.yaml
    └── team/
        └── release-prep.yaml
```

Categories will include:
- **Official** - Maintained by agent-pipelines team
- **Community** - Community-contributed
- **Team** - Organization-specific
- **Personal** - User's custom configurations
