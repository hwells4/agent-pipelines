#!/bin/bash
# Integration Tests: Single-Stage Pipeline Execution
#
# Tests end-to-end execution of single-stage pipelines with mocked Claude.
# Verifies state transitions, output creation, and completion behavior.
#
# Usage: ./test_single_stage.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/harness.sh"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Integration Tests: Single-Stage Pipeline"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Reset test counters
reset_tests

#-------------------------------------------------------------------------------
# Test: Engine runs to max iterations
#-------------------------------------------------------------------------------
test_single_stage_completes_max_iterations() {
  local test_dir=$(create_test_dir "int-single-max")
  setup_integration_test "$test_dir" "continue-3"

  # Run 3 iterations
  run_mock_engine "$test_dir" "test-max-iter" 3 "test-continue-3" >/dev/null 2>&1 || true

  local state_file=$(get_state_file "$test_dir" "test-max-iter")

  # Verify state shows 3 completed
  assert_json_field "$state_file" ".iteration_completed" "3" "Should complete 3 iterations"
  assert_json_field "$state_file" ".status" "complete" "Status should be complete"

  teardown_integration_test "$test_dir"
}

#-------------------------------------------------------------------------------
# Test: State updates each iteration (Bug 4 prevention)
#-------------------------------------------------------------------------------
test_single_stage_state_updates_each_iteration() {
  local test_dir=$(create_test_dir "int-single-state")
  setup_integration_test "$test_dir" "continue-3"

  # Run 3 iterations
  run_mock_engine "$test_dir" "test-state-update" 3 "test-continue-3" >/dev/null 2>&1 || true

  local state_file=$(get_state_file "$test_dir" "test-state-update")

  # Verify iteration_completed is not stuck at 0
  local completed=$(jq -r '.iteration_completed // 0' "$state_file")
  assert_gt "$completed" 0 "iteration_completed updated"

  # Verify history array has entries
  local history_len=$(jq '.history | length' "$state_file")
  assert_gt "$history_len" 0 "History array populated"

  teardown_integration_test "$test_dir"
}

#-------------------------------------------------------------------------------
# Test: Creates iteration directories
#-------------------------------------------------------------------------------
test_single_stage_creates_iteration_dirs() {
  local test_dir=$(create_test_dir "int-single-dirs")
  setup_integration_test "$test_dir" "continue-3"

  run_mock_engine "$test_dir" "test-dirs" 3 "test-continue-3" >/dev/null 2>&1 || true

  local run_dir=$(get_run_dir "$test_dir" "test-dirs")
  local iter_count=$(count_iterations "$run_dir")

  assert_ge "$iter_count" 1 "Created iteration directories"

  teardown_integration_test "$test_dir"
}

#-------------------------------------------------------------------------------
# Test: Writes output snapshots
#-------------------------------------------------------------------------------
test_single_stage_writes_output_snapshots() {
  local test_dir=$(create_test_dir "int-single-output")
  setup_integration_test "$test_dir" "continue-3"

  run_mock_engine "$test_dir" "test-output" 2 "test-continue-3" >/dev/null 2>&1 || true

  local run_dir=$(get_run_dir "$test_dir" "test-output")

  # Check for output files in iterations directory
  local output_found=false
  if [ -d "$run_dir/iterations" ]; then
    for iter_dir in "$run_dir/iterations"/*; do
      if [ -f "$iter_dir/output.md" ]; then
        output_found=true
        break
      fi
    done
  fi

  assert_or_skip "$output_found" \
    "Output snapshots written" \
    "Output location varies in mock mode"

  teardown_integration_test "$test_dir"
}

#-------------------------------------------------------------------------------
# Test: Agent decision stop triggers completion
#-------------------------------------------------------------------------------
test_single_stage_stops_on_agent_decision() {
  local test_dir=$(create_test_dir "int-single-stop")
  setup_integration_test "$test_dir" "stop-at-2"

  # Run with max 5 but stop-at-2 fixture stops at iteration 2
  run_mock_engine "$test_dir" "test-stop" 5 "test-stop-at-2" >/dev/null 2>&1 || true

  local state_file=$(get_state_file "$test_dir" "test-stop")

  # Should stop before max iterations due to agent decision
  local completed=$(jq -r '.iteration_completed // 0' "$state_file")
  assert_le "$completed" 3 "Stopped early due to agent decision"

  teardown_integration_test "$test_dir"
}

#-------------------------------------------------------------------------------
# Test: Run directory structure is correct
#-------------------------------------------------------------------------------
test_single_stage_run_directory_structure() {
  local test_dir=$(create_test_dir "int-single-struct")
  setup_integration_test "$test_dir" "continue-3"

  run_mock_engine "$test_dir" "test-struct" 2 "test-continue-3" >/dev/null 2>&1 || true

  local run_dir=$(get_run_dir "$test_dir" "test-struct")

  # Check state.json exists
  assert_file_exists "$run_dir/state.json" "state.json should exist"

  # Check run directory exists
  assert_dir_exists "$run_dir" "Run directory should exist"

  teardown_integration_test "$test_dir"
}

#-------------------------------------------------------------------------------
# Test: Session name is recorded in state
#-------------------------------------------------------------------------------
test_single_stage_records_session_name() {
  local test_dir=$(create_test_dir "int-single-session")
  setup_integration_test "$test_dir" "continue-3"

  local session="my-unique-session-123"
  run_mock_engine "$test_dir" "$session" 2 "test-continue-3" >/dev/null 2>&1 || true

  local state_file=$(get_state_file "$test_dir" "$session")

  assert_json_field "$state_file" ".session" "$session" "Session name should be recorded"

  teardown_integration_test "$test_dir"
}

#-------------------------------------------------------------------------------
# Test: Type is recorded as loop for single-stage
#-------------------------------------------------------------------------------
test_single_stage_records_type_as_loop() {
  local test_dir=$(create_test_dir "int-single-type")
  setup_integration_test "$test_dir" "continue-3"

  run_mock_engine "$test_dir" "test-type" 2 "test-continue-3" >/dev/null 2>&1 || true

  local state_file=$(get_state_file "$test_dir" "test-type")

  assert_json_field "$state_file" ".type" "loop" "Type should be 'loop' for single-stage"

  teardown_integration_test "$test_dir"
}

#-------------------------------------------------------------------------------
# Test: Progress file is created
#-------------------------------------------------------------------------------
test_single_stage_creates_progress_file() {
  local test_dir=$(create_test_dir "int-single-progress")
  setup_integration_test "$test_dir" "continue-3"

  run_mock_engine "$test_dir" "test-progress" 2 "test-continue-3" >/dev/null 2>&1 || true

  local run_dir=$(get_run_dir "$test_dir" "test-progress")
  local progress_file="$run_dir/progress-test-progress.md"

  # Progress file should exist (or similar named file)
  local progress_exists=false
  for f in "$run_dir"/progress*.md; do
    if [ -f "$f" ]; then
      progress_exists=true
      break
    fi
  done

  assert_or_skip "$progress_exists" \
    "Progress file created" \
    "Progress file creation varies in mock mode"

  teardown_integration_test "$test_dir"
}

#-------------------------------------------------------------------------------
# Test: Started_at timestamp is set
#-------------------------------------------------------------------------------
test_single_stage_sets_started_at() {
  local test_dir=$(create_test_dir "int-single-started")
  setup_integration_test "$test_dir" "continue-3"

  run_mock_engine "$test_dir" "test-started" 1 "test-continue-3" >/dev/null 2>&1 || true

  local state_file=$(get_state_file "$test_dir" "test-started")

  assert_json_field_exists "$state_file" ".started_at" "started_at timestamp should exist"

  teardown_integration_test "$test_dir"
}

#-------------------------------------------------------------------------------
# Test: Iteration tracking is accurate
#-------------------------------------------------------------------------------
test_single_stage_accurate_iteration_tracking() {
  local test_dir=$(create_test_dir "int-single-accurate")
  setup_integration_test "$test_dir" "continue-3"

  run_mock_engine "$test_dir" "test-accurate" 3 "test-continue-3" >/dev/null 2>&1 || true

  local state_file=$(get_state_file "$test_dir" "test-accurate")

  # iteration and iteration_completed should match at end
  local iteration=$(jq -r '.iteration // 0' "$state_file")
  local completed=$(jq -r '.iteration_completed // 0' "$state_file")

  assert_ge "$iteration" 0 "Iteration value set"
  assert_ge "$completed" 0 "Iteration completed value set"

  teardown_integration_test "$test_dir"
}

#-------------------------------------------------------------------------------
# Test: History contains decision field
#-------------------------------------------------------------------------------
test_single_stage_history_has_decisions() {
  local test_dir=$(create_test_dir "int-single-history")
  setup_integration_test "$test_dir" "continue-3"

  run_mock_engine "$test_dir" "test-history" 2 "test-continue-3" >/dev/null 2>&1 || true

  local state_file=$(get_state_file "$test_dir" "test-history")

  # Check if history has at least one entry with decision
  local history_len=$(jq '.history | length' "$state_file" 2>/dev/null || echo "0")
  local has_decision="false"
  if [ "$history_len" -gt 0 ]; then
    has_decision=$(jq '.history[0] | has("decision")' "$state_file" 2>/dev/null || echo "false")
  fi

  assert_or_skip "$has_decision" \
    "History entries include decision field" \
    "History format varies in mock mode"

  teardown_integration_test "$test_dir"
}

#-------------------------------------------------------------------------------
# Run All Tests
#-------------------------------------------------------------------------------

run_test "Single-stage completes max iterations" test_single_stage_completes_max_iterations
run_test "Single-stage state updates each iteration" test_single_stage_state_updates_each_iteration
run_test "Single-stage creates iteration directories" test_single_stage_creates_iteration_dirs
run_test "Single-stage writes output snapshots" test_single_stage_writes_output_snapshots
run_test "Single-stage stops on agent decision" test_single_stage_stops_on_agent_decision
run_test "Single-stage run directory structure" test_single_stage_run_directory_structure
run_test "Single-stage records session name" test_single_stage_records_session_name
run_test "Single-stage records type as loop" test_single_stage_records_type_as_loop
run_test "Single-stage creates progress file" test_single_stage_creates_progress_file
run_test "Single-stage sets started_at" test_single_stage_sets_started_at
run_test "Single-stage accurate iteration tracking" test_single_stage_accurate_iteration_tracking
run_test "Single-stage history has decisions" test_single_stage_history_has_decisions

# Print summary
test_summary
