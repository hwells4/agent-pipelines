#!/bin/bash
# Status management tests - verify v3 status.json handling works

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/test.sh"
source "$SCRIPT_DIR/lib/status.sh"

#-------------------------------------------------------------------------------
# validate_status Tests
#-------------------------------------------------------------------------------

test_validate_status_missing_file() {
  local test_dir=$(mktemp -d)
  local status_file="$test_dir/nonexistent.json"

  validate_status "$status_file" 2>/dev/null
  local result=$?

  assert_eq "1" "$result" "Returns 1 for missing file"

  rm -rf "$test_dir"
}

test_validate_status_invalid_json() {
  local test_dir=$(mktemp -d)
  local status_file="$test_dir/status.json"

  echo "not valid json {" > "$status_file"

  validate_status "$status_file" 2>/dev/null
  local result=$?

  assert_eq "1" "$result" "Returns 1 for invalid JSON"

  rm -rf "$test_dir"
}

test_validate_status_missing_decision() {
  local test_dir=$(mktemp -d)
  local status_file="$test_dir/status.json"

  echo '{"reason": "test"}' > "$status_file"

  validate_status "$status_file" 2>/dev/null
  local result=$?

  assert_eq "1" "$result" "Returns 1 when decision field missing"

  rm -rf "$test_dir"
}

test_validate_status_invalid_decision() {
  local test_dir=$(mktemp -d)
  local status_file="$test_dir/status.json"

  echo '{"decision": "invalid"}' > "$status_file"

  validate_status "$status_file" 2>/dev/null
  local result=$?

  assert_eq "1" "$result" "Returns 1 for invalid decision value"

  rm -rf "$test_dir"
}

test_validate_status_continue() {
  local test_dir=$(mktemp -d)
  local status_file="$test_dir/status.json"

  echo '{"decision": "continue", "reason": "work remains"}' > "$status_file"

  validate_status "$status_file" 2>/dev/null
  local result=$?

  assert_eq "0" "$result" "Returns 0 for decision=continue"

  rm -rf "$test_dir"
}

test_validate_status_stop() {
  local test_dir=$(mktemp -d)
  local status_file="$test_dir/status.json"

  echo '{"decision": "stop", "reason": "plateau reached"}' > "$status_file"

  validate_status "$status_file" 2>/dev/null
  local result=$?

  assert_eq "0" "$result" "Returns 0 for decision=stop"

  rm -rf "$test_dir"
}

test_validate_status_error() {
  local test_dir=$(mktemp -d)
  local status_file="$test_dir/status.json"

  echo '{"decision": "error", "reason": "something broke"}' > "$status_file"

  validate_status "$status_file" 2>/dev/null
  local result=$?

  assert_eq "0" "$result" "Returns 0 for decision=error"

  rm -rf "$test_dir"
}

#-------------------------------------------------------------------------------
# get_status_decision Tests
#-------------------------------------------------------------------------------

test_get_decision_missing_file() {
  local decision=$(get_status_decision "/nonexistent/path.json")
  assert_eq "continue" "$decision" "Returns 'continue' for missing file"
}

test_get_decision_continue() {
  local test_dir=$(mktemp -d)
  local status_file="$test_dir/status.json"

  echo '{"decision": "continue"}' > "$status_file"

  local decision=$(get_status_decision "$status_file")
  assert_eq "continue" "$decision" "Returns 'continue' from file"

  rm -rf "$test_dir"
}

test_get_decision_stop() {
  local test_dir=$(mktemp -d)
  local status_file="$test_dir/status.json"

  echo '{"decision": "stop"}' > "$status_file"

  local decision=$(get_status_decision "$status_file")
  assert_eq "stop" "$decision" "Returns 'stop' from file"

  rm -rf "$test_dir"
}

test_get_decision_error() {
  local test_dir=$(mktemp -d)
  local status_file="$test_dir/status.json"

  echo '{"decision": "error"}' > "$status_file"

  local decision=$(get_status_decision "$status_file")
  assert_eq "error" "$decision" "Returns 'error' from file"

  rm -rf "$test_dir"
}

#-------------------------------------------------------------------------------
# get_status_reason Tests
#-------------------------------------------------------------------------------

test_get_reason_missing_file() {
  local reason=$(get_status_reason "/nonexistent/path.json")
  assert_eq "" "$reason" "Returns empty string for missing file"
}

test_get_reason_present() {
  local test_dir=$(mktemp -d)
  local status_file="$test_dir/status.json"

  echo '{"decision": "stop", "reason": "No more improvements possible"}' > "$status_file"

  local reason=$(get_status_reason "$status_file")
  assert_eq "No more improvements possible" "$reason" "Returns reason from file"

  rm -rf "$test_dir"
}

test_get_reason_missing_field() {
  local test_dir=$(mktemp -d)
  local status_file="$test_dir/status.json"

  echo '{"decision": "continue"}' > "$status_file"

  local reason=$(get_status_reason "$status_file")
  assert_eq "" "$reason" "Returns empty string when reason field missing"

  rm -rf "$test_dir"
}

#-------------------------------------------------------------------------------
# get_status_summary Tests
#-------------------------------------------------------------------------------

test_get_summary_present() {
  local test_dir=$(mktemp -d)
  local status_file="$test_dir/status.json"

  echo '{"decision": "continue", "summary": "Fixed 3 bugs"}' > "$status_file"

  local summary=$(get_status_summary "$status_file")
  assert_eq "Fixed 3 bugs" "$summary" "Returns summary from file"

  rm -rf "$test_dir"
}

#-------------------------------------------------------------------------------
# get_status_files Tests
#-------------------------------------------------------------------------------

test_get_files_present() {
  local test_dir=$(mktemp -d)
  local status_file="$test_dir/status.json"

  echo '{"decision": "continue", "work": {"files_touched": ["a.js", "b.ts"]}}' > "$status_file"

  local files=$(get_status_files "$status_file")
  assert_eq '["a.js","b.ts"]' "$files" "Returns files_touched array"

  rm -rf "$test_dir"
}

test_get_files_missing() {
  local test_dir=$(mktemp -d)
  local status_file="$test_dir/status.json"

  echo '{"decision": "continue"}' > "$status_file"

  local files=$(get_status_files "$status_file")
  assert_eq "[]" "$files" "Returns empty array when files_touched missing"

  rm -rf "$test_dir"
}

#-------------------------------------------------------------------------------
# get_status_items Tests
#-------------------------------------------------------------------------------

test_get_items_present() {
  local test_dir=$(mktemp -d)
  local status_file="$test_dir/status.json"

  echo '{"decision": "continue", "work": {"items_completed": ["beads-001", "beads-002"]}}' > "$status_file"

  local items=$(get_status_items "$status_file")
  assert_eq '["beads-001","beads-002"]' "$items" "Returns items_completed array"

  rm -rf "$test_dir"
}

#-------------------------------------------------------------------------------
# get_status_errors Tests
#-------------------------------------------------------------------------------

test_get_errors_present() {
  local test_dir=$(mktemp -d)
  local status_file="$test_dir/status.json"

  echo '{"decision": "error", "errors": ["Connection failed", "Timeout"]}' > "$status_file"

  local errors=$(get_status_errors "$status_file")
  assert_eq '["Connection failed","Timeout"]' "$errors" "Returns errors array"

  rm -rf "$test_dir"
}

test_get_errors_missing() {
  local test_dir=$(mktemp -d)
  local status_file="$test_dir/status.json"

  echo '{"decision": "continue"}' > "$status_file"

  local errors=$(get_status_errors "$status_file")
  assert_eq "[]" "$errors" "Returns empty array when errors missing"

  rm -rf "$test_dir"
}

#-------------------------------------------------------------------------------
# create_error_status Tests
#-------------------------------------------------------------------------------

test_create_error_status() {
  local test_dir=$(mktemp -d)
  local status_file="$test_dir/status.json"

  create_error_status "$status_file" "Agent crashed unexpectedly"

  assert_file_exists "$status_file" "Status file created"
  assert_json_field "$status_file" ".decision" "error" "decision is 'error'"
  assert_json_field "$status_file" ".reason" "Agent crashed unexpectedly" "reason matches"
  assert_json_field_exists "$status_file" ".timestamp" "timestamp exists"
  assert_json_field_exists "$status_file" ".errors" "errors array exists"

  rm -rf "$test_dir"
}

test_create_error_status_creates_directory() {
  local test_dir=$(mktemp -d)
  local status_file="$test_dir/nested/dir/status.json"

  create_error_status "$status_file" "Test error"

  assert_file_exists "$status_file" "Status file created in nested directory"

  rm -rf "$test_dir"
}

#-------------------------------------------------------------------------------
# create_default_status Tests
#-------------------------------------------------------------------------------

test_create_default_status() {
  local test_dir=$(mktemp -d)
  local status_file="$test_dir/status.json"

  create_default_status "$status_file" "Iteration completed normally"

  assert_file_exists "$status_file" "Status file created"
  assert_json_field "$status_file" ".decision" "continue" "decision is 'continue'"
  assert_json_field "$status_file" ".summary" "Iteration completed normally" "summary matches"

  rm -rf "$test_dir"
}

#-------------------------------------------------------------------------------
# legacy_output_to_status Tests
#-------------------------------------------------------------------------------

test_legacy_output_plateau_true() {
  local test_dir=$(mktemp -d)
  local status_file="$test_dir/status.json"

  local output="Some output
PLATEAU: true
REASONING: No more improvements needed"

  legacy_output_to_status "$output" "$status_file" "plateau:PLATEAU reasoning:REASONING"

  assert_file_exists "$status_file" "Status file created"
  assert_json_field "$status_file" ".decision" "stop" "PLATEAU: true converts to decision: stop"
  assert_json_field "$status_file" ".reason" " No more improvements needed" "REASONING becomes reason"
  assert_json_field "$status_file" "._legacy" "true" "_legacy flag set"

  rm -rf "$test_dir"
}

test_legacy_output_plateau_false() {
  local test_dir=$(mktemp -d)
  local status_file="$test_dir/status.json"

  local output="Some output
PLATEAU: false
REASONING: More work to do"

  legacy_output_to_status "$output" "$status_file" "plateau:PLATEAU reasoning:REASONING"

  assert_json_field "$status_file" ".decision" "continue" "PLATEAU: false converts to decision: continue"

  rm -rf "$test_dir"
}

test_legacy_output_plateau_yes() {
  local test_dir=$(mktemp -d)
  local status_file="$test_dir/status.json"

  local output="PLATEAU: yes
REASONING: Done"

  legacy_output_to_status "$output" "$status_file" ""

  assert_json_field "$status_file" ".decision" "stop" "PLATEAU: yes converts to decision: stop"

  rm -rf "$test_dir"
}

#-------------------------------------------------------------------------------
# status_to_history_json Tests
#-------------------------------------------------------------------------------

test_status_to_history_json() {
  local test_dir=$(mktemp -d)
  local status_file="$test_dir/status.json"

  cat > "$status_file" << 'EOF'
{
  "decision": "continue",
  "reason": "More work needed",
  "summary": "Fixed 2 bugs",
  "work": {
    "items_completed": ["beads-001"],
    "files_touched": ["src/app.ts"]
  },
  "errors": []
}
EOF

  local history=$(status_to_history_json "$status_file")

  # Parse JSON to verify structure (jq whitespace varies by version/platform)
  local decision=$(echo "$history" | jq -r '.decision')
  local reason=$(echo "$history" | jq -r '.reason')
  local items=$(echo "$history" | jq -c '.items_completed')

  assert_eq "continue" "$decision" "History contains decision"
  assert_eq "More work needed" "$reason" "History contains reason"
  assert_eq '["beads-001"]' "$items" "History contains items_completed"

  rm -rf "$test_dir"
}

test_status_to_history_json_missing_file() {
  local history=$(status_to_history_json "/nonexistent.json")

  # Parse JSON to verify (jq whitespace varies by version/platform)
  local decision=$(echo "$history" | jq -r '.decision')
  assert_eq "continue" "$decision" "Missing file returns default continue"
}

#-------------------------------------------------------------------------------
# Run Tests
#-------------------------------------------------------------------------------

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  Status.sh Tests (v3)"
echo "═══════════════════════════════════════════════════════════════"
echo ""

run_test "validate_status: missing file" test_validate_status_missing_file
run_test "validate_status: invalid JSON" test_validate_status_invalid_json
run_test "validate_status: missing decision" test_validate_status_missing_decision
run_test "validate_status: invalid decision" test_validate_status_invalid_decision
run_test "validate_status: continue" test_validate_status_continue
run_test "validate_status: stop" test_validate_status_stop
run_test "validate_status: error" test_validate_status_error

run_test "get_status_decision: missing file" test_get_decision_missing_file
run_test "get_status_decision: continue" test_get_decision_continue
run_test "get_status_decision: stop" test_get_decision_stop
run_test "get_status_decision: error" test_get_decision_error

run_test "get_status_reason: missing file" test_get_reason_missing_file
run_test "get_status_reason: present" test_get_reason_present
run_test "get_status_reason: missing field" test_get_reason_missing_field

run_test "get_status_summary: present" test_get_summary_present

run_test "get_status_files: present" test_get_files_present
run_test "get_status_files: missing" test_get_files_missing

run_test "get_status_items: present" test_get_items_present

run_test "get_status_errors: present" test_get_errors_present
run_test "get_status_errors: missing" test_get_errors_missing

run_test "create_error_status: basic" test_create_error_status
run_test "create_error_status: creates directory" test_create_error_status_creates_directory

run_test "create_default_status: basic" test_create_default_status

run_test "legacy_output_to_status: PLATEAU true" test_legacy_output_plateau_true
run_test "legacy_output_to_status: PLATEAU false" test_legacy_output_plateau_false
run_test "legacy_output_to_status: PLATEAU yes" test_legacy_output_plateau_yes

run_test "status_to_history_json: full status" test_status_to_history_json
run_test "status_to_history_json: missing file" test_status_to_history_json_missing_file

test_summary
