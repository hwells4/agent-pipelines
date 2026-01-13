#!/bin/bash
# Tests for parallel blocks feature
# Tests validation, directory structure, context generation, and execution

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/test.sh"
source "$SCRIPT_DIR/lib/validate.sh"
source "$SCRIPT_DIR/lib/yaml.sh"

# Helper to create temp directory for tests
create_test_dir() {
  mktemp -d
}

# Helper to cleanup temp directory
cleanup_test_dir() {
  local dir=$1
  [ -d "$dir" ] && rm -rf "$dir"
}

#-------------------------------------------------------------------------------
# Phase 1: Validation Tests
#-------------------------------------------------------------------------------

test_parallel_block_requires_providers() {
  local test_dir=$(create_test_dir)

  # Create pipeline missing providers array
  cat > "$test_dir/pipeline.yaml" << 'EOF'
name: test-missing-providers
stages:
  - name: dual-refine
    parallel:
      stages:
        - name: plan
          stage: improve-plan
EOF

  validate_pipeline_file "$test_dir/pipeline.yaml" "--quiet" 2>/dev/null
  local result=$?

  cleanup_test_dir "$test_dir"
  assert_eq "1" "$result" "Parallel block without providers should fail validation"
}

test_parallel_block_requires_stages() {
  local test_dir=$(create_test_dir)

  # Create pipeline missing stages array
  cat > "$test_dir/pipeline.yaml" << 'EOF'
name: test-missing-stages
stages:
  - name: dual-refine
    parallel:
      providers: [claude, codex]
EOF

  validate_pipeline_file "$test_dir/pipeline.yaml" "--quiet" 2>/dev/null
  local result=$?

  cleanup_test_dir "$test_dir"
  assert_eq "1" "$result" "Parallel block without stages should fail validation"
}

test_parallel_block_rejects_nested() {
  local test_dir=$(create_test_dir)

  # Create pipeline with nested parallel block
  cat > "$test_dir/pipeline.yaml" << 'EOF'
name: test-nested-parallel
stages:
  - name: outer
    parallel:
      providers: [claude]
      stages:
        - name: inner
          parallel:
            providers: [codex]
            stages:
              - name: deep
                stage: improve-plan
EOF

  validate_pipeline_file "$test_dir/pipeline.yaml" "--quiet" 2>/dev/null
  local result=$?

  cleanup_test_dir "$test_dir"
  assert_eq "1" "$result" "Nested parallel blocks should fail validation"
}

test_parallel_stage_no_provider_override() {
  local test_dir=$(create_test_dir)

  # Create pipeline with provider override inside parallel block stage
  cat > "$test_dir/pipeline.yaml" << 'EOF'
name: test-provider-override
stages:
  - name: dual-refine
    parallel:
      providers: [claude, codex]
      stages:
        - name: plan
          stage: improve-plan
          provider: gemini
EOF

  validate_pipeline_file "$test_dir/pipeline.yaml" "--quiet" 2>/dev/null
  local result=$?

  cleanup_test_dir "$test_dir"
  assert_eq "1" "$result" "Provider override inside parallel block should fail validation"
}

test_parallel_block_empty_providers() {
  local test_dir=$(create_test_dir)

  # Create pipeline with empty providers array
  cat > "$test_dir/pipeline.yaml" << 'EOF'
name: test-empty-providers
stages:
  - name: dual-refine
    parallel:
      providers: []
      stages:
        - name: plan
          stage: improve-plan
EOF

  validate_pipeline_file "$test_dir/pipeline.yaml" "--quiet" 2>/dev/null
  local result=$?

  cleanup_test_dir "$test_dir"
  assert_eq "1" "$result" "Empty providers array should fail validation"
}

test_parallel_block_empty_stages() {
  local test_dir=$(create_test_dir)

  # Create pipeline with empty stages array
  cat > "$test_dir/pipeline.yaml" << 'EOF'
name: test-empty-stages
stages:
  - name: dual-refine
    parallel:
      providers: [claude]
      stages: []
EOF

  validate_pipeline_file "$test_dir/pipeline.yaml" "--quiet" 2>/dev/null
  local result=$?

  cleanup_test_dir "$test_dir"
  assert_eq "1" "$result" "Empty stages array should fail validation"
}

test_parallel_block_duplicate_stage_names() {
  local test_dir=$(create_test_dir)

  # Create pipeline with duplicate stage names within block
  cat > "$test_dir/pipeline.yaml" << 'EOF'
name: test-duplicate-names
stages:
  - name: dual-refine
    parallel:
      providers: [claude]
      stages:
        - name: plan
          stage: improve-plan
        - name: plan
          stage: elegance
EOF

  validate_pipeline_file "$test_dir/pipeline.yaml" "--quiet" 2>/dev/null
  local result=$?

  cleanup_test_dir "$test_dir"
  assert_eq "1" "$result" "Duplicate stage names in parallel block should fail validation"
}

test_parallel_block_valid_schema() {
  local test_dir=$(create_test_dir)

  # Create valid pipeline with parallel block
  # Note: We need stage directories to exist for full validation
  mkdir -p "$test_dir/stages/improve-plan"
  cat > "$test_dir/stages/improve-plan/stage.yaml" << 'EOF'
name: improve-plan
termination:
  type: judgment
  consensus: 2
EOF
  cat > "$test_dir/stages/improve-plan/prompt.md" << 'EOF'
Test prompt
EOF

  cat > "$test_dir/pipeline.yaml" << 'EOF'
name: test-valid-parallel
stages:
  - name: dual-refine
    parallel:
      providers: [claude, codex]
      stages:
        - name: plan
          stage: improve-plan
          termination:
            type: fixed
            iterations: 1
        - name: iterate
          stage: improve-plan
          termination:
            type: judgment
            consensus: 2
            max: 5
EOF

  # Override STAGES_DIR for test isolation
  local old_stages_dir="${STAGES_DIR:-}"
  export STAGES_DIR="$test_dir/stages"

  validate_pipeline_file "$test_dir/pipeline.yaml" "--quiet" 2>/dev/null
  local result=$?

  # Restore
  if [ -n "$old_stages_dir" ]; then
    export STAGES_DIR="$old_stages_dir"
  else
    unset STAGES_DIR
  fi

  cleanup_test_dir "$test_dir"
  assert_eq "0" "$result" "Valid parallel block should pass validation"
}

test_from_parallel_validates_stage() {
  local test_dir=$(create_test_dir)

  # Create pipeline with invalid from_parallel reference
  mkdir -p "$test_dir/stages/improve-plan"
  cat > "$test_dir/stages/improve-plan/stage.yaml" << 'EOF'
name: improve-plan
termination:
  type: judgment
EOF
  cat > "$test_dir/stages/improve-plan/prompt.md" << 'EOF'
Test prompt
EOF

  mkdir -p "$test_dir/stages/elegance"
  cat > "$test_dir/stages/elegance/stage.yaml" << 'EOF'
name: elegance
termination:
  type: judgment
EOF
  cat > "$test_dir/stages/elegance/prompt.md" << 'EOF'
Test prompt
EOF

  cat > "$test_dir/pipeline.yaml" << 'EOF'
name: test-invalid-from-parallel
stages:
  - name: dual-refine
    parallel:
      providers: [claude]
      stages:
        - name: plan
          stage: improve-plan
  - name: synthesize
    stage: elegance
    inputs:
      from_parallel: nonexistent
EOF

  local old_stages_dir="${STAGES_DIR:-}"
  export STAGES_DIR="$test_dir/stages"

  validate_pipeline_file "$test_dir/pipeline.yaml" "--quiet" 2>/dev/null
  local result=$?

  if [ -n "$old_stages_dir" ]; then
    export STAGES_DIR="$old_stages_dir"
  else
    unset STAGES_DIR
  fi

  cleanup_test_dir "$test_dir"
  assert_eq "1" "$result" "from_parallel referencing nonexistent stage should fail validation"
}

test_from_parallel_valid_reference() {
  local test_dir=$(create_test_dir)

  # Create pipeline with valid from_parallel reference
  mkdir -p "$test_dir/stages/improve-plan"
  cat > "$test_dir/stages/improve-plan/stage.yaml" << 'EOF'
name: improve-plan
termination:
  type: judgment
EOF
  cat > "$test_dir/stages/improve-plan/prompt.md" << 'EOF'
Test prompt
EOF

  mkdir -p "$test_dir/stages/elegance"
  cat > "$test_dir/stages/elegance/stage.yaml" << 'EOF'
name: elegance
termination:
  type: judgment
EOF
  cat > "$test_dir/stages/elegance/prompt.md" << 'EOF'
Test prompt
EOF

  cat > "$test_dir/pipeline.yaml" << 'EOF'
name: test-valid-from-parallel
stages:
  - name: dual-refine
    parallel:
      providers: [claude]
      stages:
        - name: plan
          stage: improve-plan
        - name: iterate
          stage: improve-plan
  - name: synthesize
    stage: elegance
    inputs:
      from_parallel: iterate
EOF

  local old_stages_dir="${STAGES_DIR:-}"
  export STAGES_DIR="$test_dir/stages"

  validate_pipeline_file "$test_dir/pipeline.yaml" "--quiet" 2>/dev/null
  local result=$?

  if [ -n "$old_stages_dir" ]; then
    export STAGES_DIR="$old_stages_dir"
  else
    unset STAGES_DIR
  fi

  cleanup_test_dir "$test_dir"
  assert_eq "0" "$result" "Valid from_parallel reference should pass validation"
}

#-------------------------------------------------------------------------------
# Phase 2: Directory Structure Tests
#-------------------------------------------------------------------------------

# Test helper: create parallel block directory structure
# Usage: create_parallel_block_dirs "$run_dir" "block-name" "claude codex"
create_parallel_block_dirs() {
  local run_dir=$1
  local block_name=$2
  local providers=$3  # Space-separated list

  local block_dir="$run_dir/$block_name"
  mkdir -p "$block_dir"

  for provider in $providers; do
    mkdir -p "$block_dir/providers/$provider"
  done

  echo "$block_dir"
}

test_parallel_creates_provider_dirs() {
  local test_dir=$(create_test_dir)
  local run_dir="$test_dir/.claude/pipeline-runs/test-session"
  mkdir -p "$run_dir"

  # Source state.sh to use init_parallel_block
  source "$SCRIPT_DIR/lib/state.sh"

  # Initialize a parallel block with two providers
  local block_dir=$(init_parallel_block "$run_dir" 1 "dual-refine" "claude codex")

  # Check block directory was created
  assert_dir_exists "$block_dir" "Block directory should exist"

  # Check provider directories exist
  assert_dir_exists "$block_dir/providers/claude" "Claude provider directory should exist"
  assert_dir_exists "$block_dir/providers/codex" "Codex provider directory should exist"

  cleanup_test_dir "$test_dir"
}

test_parallel_provider_isolation() {
  local test_dir=$(create_test_dir)
  local run_dir="$test_dir/.claude/pipeline-runs/test-session"
  mkdir -p "$run_dir"

  source "$SCRIPT_DIR/lib/state.sh"
  source "$SCRIPT_DIR/lib/progress.sh"

  # Initialize parallel block
  local block_dir=$(init_parallel_block "$run_dir" 1 "dual-refine" "claude codex")

  # Initialize provider state for each provider
  init_provider_state "$block_dir" "claude" "test-session"
  init_provider_state "$block_dir" "codex" "test-session"

  # Each provider should have its own progress file
  assert_file_exists "$block_dir/providers/claude/progress.md" \
    "Claude should have its own progress file"
  assert_file_exists "$block_dir/providers/codex/progress.md" \
    "Codex should have its own progress file"

  # Each provider should have its own state file
  assert_file_exists "$block_dir/providers/claude/state.json" \
    "Claude should have its own state file"
  assert_file_exists "$block_dir/providers/codex/state.json" \
    "Codex should have its own state file"

  cleanup_test_dir "$test_dir"
}

test_parallel_manifest_written() {
  local test_dir=$(create_test_dir)
  local run_dir="$test_dir/.claude/pipeline-runs/test-session"
  mkdir -p "$run_dir"

  source "$SCRIPT_DIR/lib/state.sh"

  # Initialize parallel block
  local block_dir=$(init_parallel_block "$run_dir" 1 "dual-refine" "claude codex")

  # Simulate completed providers with outputs
  mkdir -p "$block_dir/providers/claude/stage-00-plan/iterations/001"
  echo "Claude plan output" > "$block_dir/providers/claude/stage-00-plan/iterations/001/output.md"

  mkdir -p "$block_dir/providers/codex/stage-00-plan/iterations/001"
  echo "Codex plan output" > "$block_dir/providers/codex/stage-00-plan/iterations/001/output.md"

  # Create provider state files with completion info
  cat > "$block_dir/providers/claude/state.json" << 'EOF'
{
  "provider": "claude",
  "status": "complete",
  "stages": [{"name": "plan", "iterations": 1, "termination_reason": "fixed"}]
}
EOF

  cat > "$block_dir/providers/codex/state.json" << 'EOF'
{
  "provider": "codex",
  "status": "complete",
  "stages": [{"name": "plan", "iterations": 1, "termination_reason": "fixed"}]
}
EOF

  # Write manifest
  write_parallel_manifest "$block_dir" "dual-refine" 1 "plan" "claude codex"

  assert_file_exists "$block_dir/manifest.json" \
    "Manifest should be written after block completes"

  cleanup_test_dir "$test_dir"
}

test_parallel_manifest_format() {
  local test_dir=$(create_test_dir)
  local run_dir="$test_dir/.claude/pipeline-runs/test-session"
  mkdir -p "$run_dir"

  source "$SCRIPT_DIR/lib/state.sh"

  # Initialize parallel block
  local block_dir=$(init_parallel_block "$run_dir" 1 "dual-refine" "claude codex")

  # Set up complete provider directories with outputs
  mkdir -p "$block_dir/providers/claude/stage-00-plan/iterations/001"
  echo "Claude plan output" > "$block_dir/providers/claude/stage-00-plan/iterations/001/output.md"
  echo '{"decision": "stop", "reason": "fixed"}' > "$block_dir/providers/claude/stage-00-plan/iterations/001/status.json"

  mkdir -p "$block_dir/providers/codex/stage-00-plan/iterations/001"
  echo "Codex plan output" > "$block_dir/providers/codex/stage-00-plan/iterations/001/output.md"
  echo '{"decision": "stop", "reason": "fixed"}' > "$block_dir/providers/codex/stage-00-plan/iterations/001/status.json"

  # Create provider state files
  cat > "$block_dir/providers/claude/state.json" << 'EOF'
{
  "provider": "claude",
  "status": "complete",
  "stages": [{"name": "plan", "iterations": 1, "termination_reason": "fixed"}]
}
EOF

  cat > "$block_dir/providers/codex/state.json" << 'EOF'
{
  "provider": "codex",
  "status": "complete",
  "stages": [{"name": "plan", "iterations": 1, "termination_reason": "fixed"}]
}
EOF

  # Write manifest
  write_parallel_manifest "$block_dir" "dual-refine" 1 "plan" "claude codex"

  local manifest="$block_dir/manifest.json"

  # Check required fields exist
  assert_json_field_exists "$manifest" ".block.name" "Manifest should have block name"
  assert_json_field "$manifest" ".block.name" "dual-refine" "Block name should be dual-refine"
  assert_json_field_exists "$manifest" ".block.index" "Manifest should have block index"
  assert_json_field_exists "$manifest" ".providers.claude" "Manifest should have claude provider entry"
  assert_json_field_exists "$manifest" ".providers.codex" "Manifest should have codex provider entry"

  cleanup_test_dir "$test_dir"
}

test_parallel_block_naming_auto() {
  local test_dir=$(create_test_dir)
  local run_dir="$test_dir/.claude/pipeline-runs/test-session"
  mkdir -p "$run_dir"

  source "$SCRIPT_DIR/lib/state.sh"

  # Initialize parallel block WITHOUT a name (should auto-generate)
  local block_dir=$(init_parallel_block "$run_dir" 2 "" "claude")

  # Should create parallel-02 directory (index 2, no name)
  assert_dir_exists "$run_dir/parallel-02" "Auto-named block directory should exist"

  cleanup_test_dir "$test_dir"
}

test_parallel_block_naming_custom() {
  local test_dir=$(create_test_dir)
  local run_dir="$test_dir/.claude/pipeline-runs/test-session"
  mkdir -p "$run_dir"

  source "$SCRIPT_DIR/lib/state.sh"

  # Initialize parallel block WITH a name
  local block_dir=$(init_parallel_block "$run_dir" 1 "my-custom-block" "claude")

  # Should create parallel-01-my-custom-block directory
  assert_dir_exists "$run_dir/parallel-01-my-custom-block" "Named block directory should exist"

  cleanup_test_dir "$test_dir"
}

test_parallel_resume_json_written() {
  local test_dir=$(create_test_dir)
  local run_dir="$test_dir/.claude/pipeline-runs/test-session"
  mkdir -p "$run_dir"

  source "$SCRIPT_DIR/lib/state.sh"

  # Initialize parallel block
  local block_dir=$(init_parallel_block "$run_dir" 1 "dual-refine" "claude codex")

  # Initialize provider states
  init_provider_state "$block_dir" "claude" "test-session"
  init_provider_state "$block_dir" "codex" "test-session"

  # Write resume hints
  write_parallel_resume "$block_dir" "claude" 0 1 "running"
  write_parallel_resume "$block_dir" "codex" 0 1 "running"

  assert_file_exists "$block_dir/resume.json" \
    "Resume file should be written for crash recovery"

  # Verify format
  assert_json_field_exists "$block_dir/resume.json" ".claude.status" \
    "Resume should have claude status"
  assert_json_field_exists "$block_dir/resume.json" ".codex.status" \
    "Resume should have codex status"

  cleanup_test_dir "$test_dir"
}

#-------------------------------------------------------------------------------
# Phase 3: Context Generation Tests
#-------------------------------------------------------------------------------

test_context_parallel_scope_generates() {
  local test_dir=$(create_test_dir)
  local run_dir="$test_dir/.claude/pipeline-runs/test-session"
  mkdir -p "$run_dir"

  source "$SCRIPT_DIR/lib/state.sh"
  source "$SCRIPT_DIR/lib/context.sh"

  # Initialize parallel block
  local block_dir=$(init_parallel_block "$run_dir" 1 "dual-refine" "claude codex")

  # Initialize provider states
  init_provider_state "$block_dir" "claude" "test-session"
  init_provider_state "$block_dir" "codex" "test-session"

  # Generate context for stage within a parallel block (for claude provider)
  # Pass parallel_scope in stage_config
  local stage_config=$(jq -n \
    --arg id "plan" \
    --arg name "plan" \
    --argjson index 0 \
    --arg scope_root "$block_dir/providers/claude" \
    --arg pipeline_root "$run_dir" \
    '{
      id: $id,
      name: $name,
      index: $index,
      parallel_scope: {
        scope_root: $scope_root,
        pipeline_root: $pipeline_root
      }
    }')

  local context_file=$(generate_context "test-session" "1" "$stage_config" "$block_dir/providers/claude")

  # Context should be created within the provider's scope
  assert_file_exists "$context_file" "context.json should be generated in provider scope"
  assert_contains "$context_file" "providers/claude" "Context should be under claude provider dir"

  cleanup_test_dir "$test_dir"
}

test_context_parallel_same_provider_only() {
  local test_dir=$(create_test_dir)
  local run_dir="$test_dir/.claude/pipeline-runs/test-session"
  mkdir -p "$run_dir"

  source "$SCRIPT_DIR/lib/state.sh"
  source "$SCRIPT_DIR/lib/context.sh"

  # Initialize parallel block
  local block_dir=$(init_parallel_block "$run_dir" 1 "dual-refine" "claude codex")

  # Initialize provider states
  init_provider_state "$block_dir" "claude" "test-session"
  init_provider_state "$block_dir" "codex" "test-session"

  # Create stage-00-plan outputs for both providers (simulating iteration 1 completion)
  mkdir -p "$block_dir/providers/claude/stage-00-plan/iterations/001"
  echo "Claude plan output" > "$block_dir/providers/claude/stage-00-plan/iterations/001/output.md"

  mkdir -p "$block_dir/providers/codex/stage-00-plan/iterations/001"
  echo "Codex plan output" > "$block_dir/providers/codex/stage-00-plan/iterations/001/output.md"

  # Now generate context for stage-01-iterate for claude (should only see claude's plan)
  # This simulates: inputs: { from: plan }
  local stage_config=$(jq -n \
    --arg id "iterate" \
    --arg name "iterate" \
    --argjson index 1 \
    --arg scope_root "$block_dir/providers/claude" \
    --arg pipeline_root "$run_dir" \
    '{
      id: $id,
      name: $name,
      index: $index,
      inputs: {from: "plan", select: "latest"},
      parallel_scope: {
        scope_root: $scope_root,
        pipeline_root: $pipeline_root
      }
    }')

  local context_file=$(generate_context "test-session" "1" "$stage_config" "$block_dir/providers/claude")

  # Check that from_stage only contains claude's output, not codex's
  local from_stage=$(jq -r '.inputs.from_stage.plan[0] // empty' "$context_file")

  # from_stage should reference claude's plan output
  assert_contains "$from_stage" "/providers/claude/" "Claude's iterate should only see Claude's plan output"
  assert_not_contains "$from_stage" "/providers/codex/" "Claude's iterate should NOT see Codex's output"

  cleanup_test_dir "$test_dir"
}

test_context_from_parallel_latest() {
  local test_dir=$(create_test_dir)
  local run_dir="$test_dir/.claude/pipeline-runs/test-session"
  mkdir -p "$run_dir"

  source "$SCRIPT_DIR/lib/state.sh"
  source "$SCRIPT_DIR/lib/context.sh"

  # Initialize parallel block with completed outputs
  local block_dir=$(init_parallel_block "$run_dir" 1 "dual-refine" "claude codex")

  # Create stage outputs for both providers
  mkdir -p "$block_dir/providers/claude/stage-00-iterate/iterations/001"
  mkdir -p "$block_dir/providers/claude/stage-00-iterate/iterations/002"
  echo "Claude iterate output 1" > "$block_dir/providers/claude/stage-00-iterate/iterations/001/output.md"
  echo "Claude iterate output 2" > "$block_dir/providers/claude/stage-00-iterate/iterations/002/output.md"

  mkdir -p "$block_dir/providers/codex/stage-00-iterate/iterations/001"
  echo "Codex iterate output 1" > "$block_dir/providers/codex/stage-00-iterate/iterations/001/output.md"

  # Create provider state files with completion info
  cat > "$block_dir/providers/claude/state.json" << 'EOF'
{
  "provider": "claude",
  "status": "complete",
  "stages": [{"name": "iterate", "iterations": 2, "termination_reason": "plateau"}]
}
EOF

  cat > "$block_dir/providers/codex/state.json" << 'EOF'
{
  "provider": "codex",
  "status": "complete",
  "stages": [{"name": "iterate", "iterations": 1, "termination_reason": "fixed"}]
}
EOF

  # Write manifest
  write_parallel_manifest "$block_dir" "dual-refine" 1 "iterate" "claude codex"

  # Now create a downstream stage (synthesize) that uses from_parallel
  mkdir -p "$run_dir/stage-02-synthesize/iterations/001"

  local stage_config=$(jq -n \
    --arg id "synthesize" \
    --arg name "synthesize" \
    --argjson index 2 \
    --arg block_dir "$block_dir" \
    '{
      id: $id,
      name: $name,
      index: $index,
      inputs: {
        from_parallel: {
          stage: "iterate",
          block: "dual-refine",
          select: "latest"
        }
      },
      parallel_blocks: {
        "dual-refine": {
          manifest_path: ($block_dir + "/manifest.json")
        }
      }
    }')

  local context_file=$(generate_context "test-session" "1" "$stage_config" "$run_dir")

  # Check that from_parallel has both providers
  assert_json_field_exists "$context_file" ".inputs.from_parallel" "from_parallel should exist"
  assert_json_field_exists "$context_file" ".inputs.from_parallel.providers.claude.output" \
    "Should have claude output"
  assert_json_field_exists "$context_file" ".inputs.from_parallel.providers.codex.output" \
    "Should have codex output"

  cleanup_test_dir "$test_dir"
}

test_context_from_parallel_history() {
  local test_dir=$(create_test_dir)
  local run_dir="$test_dir/.claude/pipeline-runs/test-session"
  mkdir -p "$run_dir"

  source "$SCRIPT_DIR/lib/state.sh"
  source "$SCRIPT_DIR/lib/context.sh"

  # Initialize parallel block with multiple iterations
  local block_dir=$(init_parallel_block "$run_dir" 1 "dual-refine" "claude codex")

  # Create multiple iterations for claude
  mkdir -p "$block_dir/providers/claude/stage-00-iterate/iterations/001"
  mkdir -p "$block_dir/providers/claude/stage-00-iterate/iterations/002"
  mkdir -p "$block_dir/providers/claude/stage-00-iterate/iterations/003"
  echo "Claude iterate 1" > "$block_dir/providers/claude/stage-00-iterate/iterations/001/output.md"
  echo "Claude iterate 2" > "$block_dir/providers/claude/stage-00-iterate/iterations/002/output.md"
  echo "Claude iterate 3" > "$block_dir/providers/claude/stage-00-iterate/iterations/003/output.md"

  mkdir -p "$block_dir/providers/codex/stage-00-iterate/iterations/001"
  mkdir -p "$block_dir/providers/codex/stage-00-iterate/iterations/002"
  echo "Codex iterate 1" > "$block_dir/providers/codex/stage-00-iterate/iterations/001/output.md"
  echo "Codex iterate 2" > "$block_dir/providers/codex/stage-00-iterate/iterations/002/output.md"

  # Create provider state files
  cat > "$block_dir/providers/claude/state.json" << 'EOF'
{
  "provider": "claude",
  "status": "complete",
  "stages": [{"name": "iterate", "iterations": 3, "termination_reason": "plateau"}]
}
EOF

  cat > "$block_dir/providers/codex/state.json" << 'EOF'
{
  "provider": "codex",
  "status": "complete",
  "stages": [{"name": "iterate", "iterations": 2, "termination_reason": "max"}]
}
EOF

  # Write manifest
  write_parallel_manifest "$block_dir" "dual-refine" 1 "iterate" "claude codex"

  # Create downstream stage requesting history
  mkdir -p "$run_dir/stage-02-synthesize/iterations/001"

  local stage_config=$(jq -n \
    --arg id "synthesize" \
    --arg name "synthesize" \
    --argjson index 2 \
    --arg block_dir "$block_dir" \
    '{
      id: $id,
      name: $name,
      index: $index,
      inputs: {
        from_parallel: {
          stage: "iterate",
          block: "dual-refine",
          select: "history"
        }
      },
      parallel_blocks: {
        "dual-refine": {
          manifest_path: ($block_dir + "/manifest.json")
        }
      }
    }')

  local context_file=$(generate_context "test-session" "1" "$stage_config" "$run_dir")

  # Check that history arrays contain multiple entries
  local claude_history_len=$(jq '.inputs.from_parallel.providers.claude.history | length' "$context_file")
  local codex_history_len=$(jq '.inputs.from_parallel.providers.codex.history | length' "$context_file")

  assert_gt "$claude_history_len" 1 "Claude history should contain multiple iterations"
  assert_gt "$codex_history_len" 1 "Codex history should contain multiple iterations"

  cleanup_test_dir "$test_dir"
}

test_block_stage_inputs_can_read_previous_stage() {
  local test_dir=$(create_test_dir)
  local run_dir="$test_dir/.claude/pipeline-runs/test-session"
  mkdir -p "$run_dir"

  source "$SCRIPT_DIR/lib/state.sh"
  source "$SCRIPT_DIR/lib/context.sh"

  # Create a pre-block stage output (setup stage at index 0)
  mkdir -p "$run_dir/stage-00-setup/iterations/001"
  echo "Setup stage output" > "$run_dir/stage-00-setup/iterations/001/output.md"

  # Initialize parallel block at index 1
  local block_dir=$(init_parallel_block "$run_dir" 1 "dual-refine" "claude")
  init_provider_state "$block_dir" "claude" "test-session"

  # Generate context for first stage inside the block, requesting inputs from setup
  # parallel_scope.pipeline_root allows fallback to the main run_dir
  local stage_config=$(jq -n \
    --arg id "plan" \
    --arg name "plan" \
    --argjson index 0 \
    --arg scope_root "$block_dir/providers/claude" \
    --arg pipeline_root "$run_dir" \
    '{
      id: $id,
      name: $name,
      index: $index,
      inputs: {from: "setup", select: "latest"},
      parallel_scope: {
        scope_root: $scope_root,
        pipeline_root: $pipeline_root
      }
    }')

  local context_file=$(generate_context "test-session" "1" "$stage_config" "$block_dir/providers/claude")

  # Check that from_stage includes setup output from the main pipeline dir
  local from_setup=$(jq -r '.inputs.from_stage.setup[0] // empty' "$context_file")

  # Check that the path is non-empty and points to the setup stage
  if [ -n "$from_setup" ]; then
    assert_true "true" "from_setup should not be empty"
  else
    assert_true "false" "from_setup should not be empty"
  fi
  assert_contains "$from_setup" "/stage-00-setup/" "Plan should reference the setup stage output"

  cleanup_test_dir "$test_dir"
}

test_from_parallel_provider_subset() {
  local test_dir=$(create_test_dir)
  local run_dir="$test_dir/.claude/pipeline-runs/test-session"
  mkdir -p "$run_dir"

  source "$SCRIPT_DIR/lib/state.sh"
  source "$SCRIPT_DIR/lib/context.sh"

  # Initialize parallel block with two providers
  local block_dir=$(init_parallel_block "$run_dir" 1 "dual-refine" "claude codex")

  # Create stage outputs for both providers
  mkdir -p "$block_dir/providers/claude/stage-00-iterate/iterations/001"
  echo "Claude output" > "$block_dir/providers/claude/stage-00-iterate/iterations/001/output.md"

  mkdir -p "$block_dir/providers/codex/stage-00-iterate/iterations/001"
  echo "Codex output" > "$block_dir/providers/codex/stage-00-iterate/iterations/001/output.md"

  # Create provider state files
  cat > "$block_dir/providers/claude/state.json" << 'EOF'
{"provider": "claude", "status": "complete", "stages": [{"name": "iterate", "iterations": 1, "termination_reason": "fixed"}]}
EOF

  cat > "$block_dir/providers/codex/state.json" << 'EOF'
{"provider": "codex", "status": "complete", "stages": [{"name": "iterate", "iterations": 1, "termination_reason": "fixed"}]}
EOF

  # Write manifest
  write_parallel_manifest "$block_dir" "dual-refine" 1 "iterate" "claude codex"

  # Create downstream stage requesting only claude
  mkdir -p "$run_dir/stage-02-synthesize/iterations/001"

  local stage_config=$(jq -n \
    --arg id "synthesize" \
    --arg name "synthesize" \
    --argjson index 2 \
    --arg block_dir "$block_dir" \
    '{
      id: $id,
      name: $name,
      index: $index,
      inputs: {
        from_parallel: {
          stage: "iterate",
          block: "dual-refine",
          providers: ["claude"],
          select: "latest"
        }
      },
      parallel_blocks: {
        "dual-refine": {
          manifest_path: ($block_dir + "/manifest.json")
        }
      }
    }')

  local context_file=$(generate_context "test-session" "1" "$stage_config" "$run_dir")

  # Check that only claude is included, not codex
  assert_json_field_exists "$context_file" ".inputs.from_parallel.providers.claude" \
    "Should include claude"

  local codex_entry=$(jq -r '.inputs.from_parallel.providers.codex // "null"' "$context_file")
  assert_eq "null" "$codex_entry" "Should NOT include codex when subset specified"

  cleanup_test_dir "$test_dir"
}

#-------------------------------------------------------------------------------
# Run Tests
#-------------------------------------------------------------------------------

echo "=== Phase 1: Parallel Block Validation Tests ==="
echo ""

run_test "Parallel block requires providers" test_parallel_block_requires_providers
run_test "Parallel block requires stages" test_parallel_block_requires_stages
run_test "Parallel block rejects nested" test_parallel_block_rejects_nested
run_test "Parallel stage no provider override" test_parallel_stage_no_provider_override
run_test "Parallel block empty providers" test_parallel_block_empty_providers
run_test "Parallel block empty stages" test_parallel_block_empty_stages
run_test "Parallel block duplicate stage names" test_parallel_block_duplicate_stage_names
run_test "Parallel block valid schema" test_parallel_block_valid_schema
run_test "from_parallel validates stage reference" test_from_parallel_validates_stage
run_test "from_parallel valid reference" test_from_parallel_valid_reference

echo ""
echo "=== Phase 2: Directory Structure Tests ==="
echo ""

run_test "Parallel creates provider directories" test_parallel_creates_provider_dirs
run_test "Parallel provider isolation" test_parallel_provider_isolation
run_test "Parallel manifest written" test_parallel_manifest_written
run_test "Parallel manifest format" test_parallel_manifest_format
run_test "Parallel block auto-naming" test_parallel_block_naming_auto
run_test "Parallel block custom naming" test_parallel_block_naming_custom
run_test "Parallel resume.json written" test_parallel_resume_json_written

echo ""
echo "=== Phase 3: Context Generation Tests ==="
echo ""

run_test "Context generates in parallel scope" test_context_parallel_scope_generates
run_test "Context parallel same provider only" test_context_parallel_same_provider_only
run_test "Context from_parallel latest" test_context_from_parallel_latest
run_test "Context from_parallel history" test_context_from_parallel_history
run_test "Block stage can read previous stage" test_block_stage_inputs_can_read_previous_stage
run_test "from_parallel provider subset" test_from_parallel_provider_subset

test_summary
