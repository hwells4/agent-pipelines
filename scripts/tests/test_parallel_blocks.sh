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

test_summary
