#!/bin/bash
# Tests for failure handling and resume - Phase 5 (Fail Fast)
#
# Tests the v3 failure state with:
# - Structured error object (type, message, timestamp)
# - resume_from field for recovery
# - get_resume_iteration and reset_for_resume functions

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/test.sh"
source "$SCRIPT_DIR/lib/state.sh"

#-------------------------------------------------------------------------------
# Failure State Tests
#-------------------------------------------------------------------------------

test_mark_failed_sets_status() {
  local tmp=$(create_test_dir)
  local state_file="$tmp/state.json"
  echo '{"session":"test","iteration":3,"iteration_completed":2}' > "$state_file"

  mark_failed "$state_file" "Test error"
  local status=$(jq -r '.status' "$state_file")

  assert_eq "failed" "$status" "mark_failed sets status=failed"
  cleanup_test_dir "$tmp"
}

test_mark_failed_includes_error_details() {
  local tmp=$(create_test_dir)
  local state_file="$tmp/state.json"
  echo '{"session":"test","iteration":3,"iteration_completed":2}' > "$state_file"

  mark_failed "$state_file" "API timeout" "timeout"
  local error_type=$(jq -r '.error.type' "$state_file")
  local error_msg=$(jq -r '.error.message' "$state_file")

  assert_eq "timeout" "$error_type" "mark_failed includes error type"
  assert_eq "API timeout" "$error_msg" "mark_failed includes error message"
  cleanup_test_dir "$tmp"
}

test_mark_failed_default_error_type() {
  local tmp=$(create_test_dir)
  local state_file="$tmp/state.json"
  echo '{"session":"test","iteration":3,"iteration_completed":2}' > "$state_file"

  mark_failed "$state_file" "Some error"
  local error_type=$(jq -r '.error.type' "$state_file")

  assert_eq "unknown" "$error_type" "mark_failed defaults error.type to 'unknown'"
  cleanup_test_dir "$tmp"
}

test_mark_failed_includes_timestamp() {
  local tmp=$(create_test_dir)
  local state_file="$tmp/state.json"
  echo '{"session":"test","iteration":3,"iteration_completed":2}' > "$state_file"

  mark_failed "$state_file" "Test error"
  local error_timestamp=$(jq -r '.error.timestamp' "$state_file")
  local failed_at=$(jq -r '.failed_at' "$state_file")

  # Should have ISO 8601 format: YYYY-MM-DDTHH:MM:SSZ
  assert_contains "$error_timestamp" "T" "error.timestamp has ISO 8601 format"
  assert_contains "$failed_at" "T" "failed_at has ISO 8601 format"
  cleanup_test_dir "$tmp"
}

test_mark_failed_sets_resume_from() {
  local tmp=$(create_test_dir)
  local state_file="$tmp/state.json"
  echo '{"session":"test","iteration":5,"iteration_completed":4}' > "$state_file"

  mark_failed "$state_file" "Crash"
  local resume_from=$(jq -r '.resume_from' "$state_file")

  assert_eq "5" "$resume_from" "resume_from = iteration_completed + 1"
  cleanup_test_dir "$tmp"
}

test_mark_failed_resume_from_first_iteration() {
  local tmp=$(create_test_dir)
  local state_file="$tmp/state.json"
  echo '{"session":"test","iteration":1,"iteration_completed":0}' > "$state_file"

  mark_failed "$state_file" "Failed on first iteration"
  local resume_from=$(jq -r '.resume_from' "$state_file")

  assert_eq "1" "$resume_from" "resume_from = 1 when no iterations completed"
  cleanup_test_dir "$tmp"
}

#-------------------------------------------------------------------------------
# Get Resume Iteration Tests
#-------------------------------------------------------------------------------

test_get_resume_iteration() {
  local tmp=$(create_test_dir)
  local state_file="$tmp/state.json"
  echo '{"session":"test","iteration":5,"iteration_completed":4}' > "$state_file"

  local resume=$(get_resume_iteration "$state_file")
  assert_eq "5" "$resume" "get_resume_iteration returns completed + 1"
  cleanup_test_dir "$tmp"
}

test_get_resume_iteration_no_completed() {
  local tmp=$(create_test_dir)
  local state_file="$tmp/state.json"
  echo '{"session":"test","iteration":1}' > "$state_file"

  local resume=$(get_resume_iteration "$state_file")
  assert_eq "1" "$resume" "get_resume_iteration defaults to 1 when no completed iterations"
  cleanup_test_dir "$tmp"
}

test_get_resume_iteration_nonexistent_file() {
  local resume=$(get_resume_iteration "/nonexistent/state.json")
  assert_eq "1" "$resume" "get_resume_iteration returns 1 for nonexistent file"
}

#-------------------------------------------------------------------------------
# Reset For Resume Tests
#-------------------------------------------------------------------------------

test_reset_for_resume_clears_error() {
  local tmp=$(create_test_dir)
  local state_file="$tmp/state.json"
  echo '{"status":"failed","error":{"message":"old error","type":"timeout"},"failed_at":"2025-01-01T00:00:00Z"}' > "$state_file"

  reset_for_resume "$state_file"
  local status=$(jq -r '.status' "$state_file")
  local has_error=$(jq 'has("error")' "$state_file")
  local has_failed_at=$(jq 'has("failed_at")' "$state_file")

  assert_eq "running" "$status" "reset_for_resume sets status=running"
  assert_eq "false" "$has_error" "reset_for_resume removes error object"
  assert_eq "false" "$has_failed_at" "reset_for_resume removes failed_at"
  cleanup_test_dir "$tmp"
}

test_reset_for_resume_sets_resumed_at() {
  local tmp=$(create_test_dir)
  local state_file="$tmp/state.json"
  echo '{"status":"failed","error":{"message":"old error"}}' > "$state_file"

  reset_for_resume "$state_file"
  local resumed_at=$(jq -r '.resumed_at' "$state_file")

  assert_contains "$resumed_at" "T" "reset_for_resume sets resumed_at with ISO 8601 timestamp"
  cleanup_test_dir "$tmp"
}

test_reset_for_resume_clears_iteration_started() {
  local tmp=$(create_test_dir)
  local state_file="$tmp/state.json"
  echo '{"status":"failed","iteration_started":"2025-01-01T00:00:00Z"}' > "$state_file"

  reset_for_resume "$state_file"
  local iteration_started=$(jq -r '.iteration_started' "$state_file")

  assert_eq "null" "$iteration_started" "reset_for_resume clears iteration_started"
  cleanup_test_dir "$tmp"
}

test_reset_for_resume_preserves_history() {
  local tmp=$(create_test_dir)
  local state_file="$tmp/state.json"
  echo '{"status":"failed","history":[{"iteration":1},{"iteration":2}],"iteration_completed":2}' > "$state_file"

  reset_for_resume "$state_file"
  local history_len=$(jq '.history | length' "$state_file")
  local iter_completed=$(jq -r '.iteration_completed' "$state_file")

  assert_eq "2" "$history_len" "reset_for_resume preserves history"
  assert_eq "2" "$iter_completed" "reset_for_resume preserves iteration_completed"
  cleanup_test_dir "$tmp"
}

test_reset_for_resume_preserves_resume_from() {
  local tmp=$(create_test_dir)
  local state_file="$tmp/state.json"
  echo '{"status":"failed","resume_from":5,"iteration_completed":4}' > "$state_file"

  reset_for_resume "$state_file"
  local resume_from=$(jq -r '.resume_from' "$state_file")

  assert_eq "5" "$resume_from" "reset_for_resume preserves resume_from for audit trail"
  cleanup_test_dir "$tmp"
}

#-------------------------------------------------------------------------------
# Error Type Classification Tests
#-------------------------------------------------------------------------------

test_error_types() {
  local tmp=$(create_test_dir)

  # Test various error types
  local error_types=("timeout" "exit_code" "missing_status" "unknown")

  for error_type in "${error_types[@]}"; do
    local state_file="$tmp/state-$error_type.json"
    echo '{"session":"test","iteration":1,"iteration_completed":0}' > "$state_file"
    mark_failed "$state_file" "Test error" "$error_type"
    local actual_type=$(jq -r '.error.type' "$state_file")
    assert_eq "$error_type" "$actual_type" "mark_failed accepts error type: $error_type"
  done

  cleanup_test_dir "$tmp"
}

#-------------------------------------------------------------------------------
# Run Tests
#-------------------------------------------------------------------------------

echo ""
echo "Testing: Phase 5 - Failure Handling"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

run_test "mark_failed sets status" test_mark_failed_sets_status
run_test "mark_failed includes error details" test_mark_failed_includes_error_details
run_test "mark_failed default error type" test_mark_failed_default_error_type
run_test "mark_failed includes timestamp" test_mark_failed_includes_timestamp
run_test "mark_failed sets resume_from" test_mark_failed_sets_resume_from
run_test "mark_failed resume_from first iteration" test_mark_failed_resume_from_first_iteration

run_test "get_resume_iteration" test_get_resume_iteration
run_test "get_resume_iteration no completed" test_get_resume_iteration_no_completed
run_test "get_resume_iteration nonexistent file" test_get_resume_iteration_nonexistent_file

run_test "reset_for_resume clears error" test_reset_for_resume_clears_error
run_test "reset_for_resume sets resumed_at" test_reset_for_resume_sets_resumed_at
run_test "reset_for_resume clears iteration_started" test_reset_for_resume_clears_iteration_started
run_test "reset_for_resume preserves history" test_reset_for_resume_preserves_history
run_test "reset_for_resume preserves resume_from" test_reset_for_resume_preserves_resume_from

run_test "Error type classification" test_error_types

test_summary
