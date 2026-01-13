#!/bin/bash
# Tests for stage transition iteration counter reset
#
# Bug context: When transitioning from stage N to stage N+1, iteration_completed
# was not being reset, causing stale values that break resume functionality.
#
# If a crash occurred between stages, resume would calculate the wrong
# starting iteration because iteration_completed contained the value from
# the previous stage.
#
# See: docs/bug-investigation-2026-01-12-state-transition.md

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/test.sh"
source "$SCRIPT_DIR/lib/state.sh"

#-------------------------------------------------------------------------------
# Test: reset_iteration_counters function exists and works
#-------------------------------------------------------------------------------
test_reset_iteration_counters_function() {
  local test_dir=$(mktemp -d)
  local state_file="$test_dir/state.json"

  # Create state with non-zero iteration counters
  cat > "$state_file" << 'EOF'
{
  "session": "test-session",
  "type": "pipeline",
  "status": "running",
  "iteration": 5,
  "iteration_completed": 4,
  "iteration_started": "2026-01-12T10:00:00Z"
}
EOF

  # Reset counters
  reset_iteration_counters "$state_file"

  # Verify all counters are reset
  local iteration=$(jq -r '.iteration' "$state_file")
  local completed=$(jq -r '.iteration_completed' "$state_file")
  local started=$(jq -r '.iteration_started' "$state_file")

  assert_eq "0" "$iteration" "iteration should be reset to 0"
  assert_eq "0" "$completed" "iteration_completed should be reset to 0"
  assert_eq "null" "$started" "iteration_started should be reset to null"

  rm -rf "$test_dir"
}

#-------------------------------------------------------------------------------
# Test: Stale iteration_completed doesn't affect resume calculation after reset
#-------------------------------------------------------------------------------
test_reset_fixes_resume_calculation() {
  local test_dir=$(mktemp -d)
  local state_file="$test_dir/state.json"

  # Simulate state after stage 2 completed but before stage 3 ran any iterations
  # This is the bug state: iteration_completed is stale from stage 2
  cat > "$state_file" << 'EOF'
{
  "session": "test-session",
  "type": "pipeline",
  "status": "running",
  "current_stage": 3,
  "iteration": 1,
  "iteration_completed": 1,
  "iteration_started": null,
  "stages": [
    {"index": 0, "name": "stage-0", "status": "complete"},
    {"index": 1, "name": "stage-1", "status": "complete"},
    {"index": 2, "name": "stage-2", "status": "complete"},
    {"index": 3, "name": "stage-3", "status": "running"}
  ]
}
EOF

  # Without fix: get_resume_iteration would return 2 (wrong!)
  local before_reset=$(get_resume_iteration "$state_file")
  assert_eq "2" "$before_reset" "Before reset: resume iteration should be 2 (the bug)"

  # Apply fix: reset iteration counters
  reset_iteration_counters "$state_file"

  # After fix: get_resume_iteration should return 1 (correct!)
  local after_reset=$(get_resume_iteration "$state_file")
  assert_eq "1" "$after_reset" "After reset: resume iteration should be 1 (correct)"

  rm -rf "$test_dir"
}

#-------------------------------------------------------------------------------
# Test: Reset preserves other state fields
#-------------------------------------------------------------------------------
test_reset_preserves_other_state() {
  local test_dir=$(mktemp -d)
  local state_file="$test_dir/state.json"

  # Create state with various fields
  cat > "$state_file" << 'EOF'
{
  "session": "test-session",
  "type": "pipeline",
  "status": "running",
  "current_stage": 2,
  "iteration": 3,
  "iteration_completed": 2,
  "iteration_started": "2026-01-12T10:00:00Z",
  "started_at": "2026-01-12T09:00:00Z",
  "stages": [
    {"index": 0, "name": "stage-0", "status": "complete"},
    {"index": 1, "name": "stage-1", "status": "complete"},
    {"index": 2, "name": "stage-2", "status": "running"}
  ],
  "history": [
    {"iteration": 1, "stage": "stage-0", "decision": "stop"},
    {"iteration": 2, "stage": "stage-1", "decision": "stop"}
  ]
}
EOF

  # Reset counters
  reset_iteration_counters "$state_file"

  # Verify other fields are preserved
  local session=$(jq -r '.session' "$state_file")
  local type=$(jq -r '.type' "$state_file")
  local status=$(jq -r '.status' "$state_file")
  local current_stage=$(jq -r '.current_stage' "$state_file")
  local started_at=$(jq -r '.started_at' "$state_file")
  local stages_len=$(jq '.stages | length' "$state_file")
  local history_len=$(jq '.history | length' "$state_file")

  assert_eq "test-session" "$session" "session should be preserved"
  assert_eq "pipeline" "$type" "type should be preserved"
  assert_eq "running" "$status" "status should be preserved"
  assert_eq "2" "$current_stage" "current_stage should be preserved"
  assert_eq "2026-01-12T09:00:00Z" "$started_at" "started_at should be preserved"
  assert_eq "3" "$stages_len" "stages array should be preserved"
  assert_eq "2" "$history_len" "history array should be preserved"

  rm -rf "$test_dir"
}

#-------------------------------------------------------------------------------
# Test: Simulated crash between stages scenario
#-------------------------------------------------------------------------------
test_crash_between_stages_scenario() {
  local test_dir=$(mktemp -d)
  local state_file="$test_dir/state.json"

  # Step 1: Stage 2 completes with iteration_completed=1
  cat > "$state_file" << 'EOF'
{
  "session": "parallel-providers",
  "type": "pipeline",
  "status": "running",
  "current_stage": 2,
  "iteration": 1,
  "iteration_completed": 1,
  "iteration_started": null,
  "stages": [
    {"index": 0, "name": "plan-tdd", "status": "complete"},
    {"index": 1, "name": "elegance", "status": "complete"},
    {"index": 2, "name": "create-beads", "status": "complete"}
  ],
  "history": [
    {"iteration": 1, "stage": "plan-tdd", "decision": "stop"},
    {"iteration": 2, "stage": "plan-tdd", "decision": "stop"},
    {"iteration": 1, "stage": "elegance", "decision": "stop"},
    {"iteration": 1, "stage": "create-beads", "decision": "stop"}
  ]
}
EOF

  # Step 2: Stage 3 starts (this is where the bug would occur)
  # Simulate what update_stage does
  jq '.stages += [{"index": 3, "name": "refine-beads", "status": "running"}] | .current_stage = 3' \
    "$state_file" > "$state_file.tmp" && mv "$state_file.tmp" "$state_file"

  # At this point, without fix:
  # - current_stage = 3 (new stage started)
  # - iteration_completed = 1 (STALE from stage 2!)

  local stale_completed=$(jq -r '.iteration_completed' "$state_file")
  assert_eq "1" "$stale_completed" "Before reset: iteration_completed is stale"

  # Step 3: Crash happens before first iteration of stage 3
  # (Simulated by not running any iterations)

  # Step 4: On resume, without fix:
  local bad_resume=$(get_resume_iteration "$state_file")
  assert_eq "2" "$bad_resume" "Without fix: resume would start at iteration 2 (wrong!)"

  # Step 5: Apply the fix
  reset_iteration_counters "$state_file"

  # Step 6: Correct resume calculation
  local good_resume=$(get_resume_iteration "$state_file")
  assert_eq "1" "$good_resume" "With fix: resume correctly starts at iteration 1"

  rm -rf "$test_dir"
}

#-------------------------------------------------------------------------------
# Run All Tests
#-------------------------------------------------------------------------------

run_test "reset_iteration_counters function works" test_reset_iteration_counters_function
run_test "Reset fixes resume calculation" test_reset_fixes_resume_calculation
run_test "Reset preserves other state fields" test_reset_preserves_other_state
run_test "Crash between stages scenario" test_crash_between_stages_scenario

test_summary
