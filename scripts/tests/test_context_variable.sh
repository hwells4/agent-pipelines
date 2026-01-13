#!/bin/bash
# Tests for ${CONTEXT} variable resolution

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/test.sh"
source "$SCRIPT_DIR/lib/resolve.sh"

#-------------------------------------------------------------------------------
# Context Variable Resolution Tests
#-------------------------------------------------------------------------------

test_context_variable_substitution() {
  local template='Hello ${CONTEXT} world'
  local vars='{"context": "beautiful"}'

  local result=$(resolve_prompt "$template" "$vars")

  assert_eq "Hello beautiful world" "$result" "Context variable is substituted"
}

test_context_variable_empty() {
  local template='Hello ${CONTEXT} world'
  local vars='{"context": ""}'

  local result=$(resolve_prompt "$template" "$vars")

  assert_eq "Hello  world" "$result" "Empty context results in empty string"
}

test_context_variable_missing() {
  local template='Hello ${CONTEXT} world'
  local vars='{}'

  local result=$(resolve_prompt "$template" "$vars")

  assert_eq "Hello  world" "$result" "Missing context results in empty string"
}

test_context_variable_multiline() {
  local template='# Stage

${CONTEXT}

## Instructions'

  local context='Focus on auth module.
Create beads for issues.'
  local vars=$(jq -n --arg ctx "$context" '{context: $ctx}')

  local result=$(resolve_prompt "$template" "$vars")

  assert_contains "$result" "Focus on auth module" "Multiline context first line preserved"
  assert_contains "$result" "Create beads for issues" "Multiline context second line preserved"
  assert_contains "$result" "# Stage" "Template header preserved"
  assert_contains "$result" "## Instructions" "Template footer preserved"
}

test_context_with_other_variables() {
  local template='Session: ${SESSION_NAME}
Context: ${CONTEXT}
Iteration: ${ITERATION}'

  local vars='{"session": "my-session", "iteration": "5", "context": "Focus on API"}'

  local result=$(resolve_prompt "$template" "$vars")

  assert_contains "$result" "Session: my-session" "Session variable resolved"
  assert_contains "$result" "Context: Focus on API" "Context variable resolved"
  assert_contains "$result" "Iteration: 5" "Iteration variable resolved"
}

test_context_no_placeholder_in_template() {
  local template='Hello world without context placeholder'
  local vars='{"context": "This should not appear"}'

  local result=$(resolve_prompt "$template" "$vars")

  assert_eq "Hello world without context placeholder" "$result" "Context ignored when no placeholder"
  assert_not_contains "$result" "This should not appear" "Unused context not injected"
}

test_context_special_characters() {
  local template='${CONTEXT}'
  local vars='{"context": "Test with $pecial and <characters>"}'

  local result=$(resolve_prompt "$template" "$vars")

  assert_contains "$result" '$pecial' "Dollar sign preserved"
  assert_contains "$result" '<characters>' "Angle brackets preserved"
  assert_contains "$result" "Test with" "Basic text preserved"
}

#-------------------------------------------------------------------------------
# Run Tests
#-------------------------------------------------------------------------------

echo ""
echo "==============================================================="
echo "  Context Variable Tests"
echo "==============================================================="
echo ""

run_test "context variable substitution" test_context_variable_substitution
run_test "context variable empty" test_context_variable_empty
run_test "context variable missing" test_context_variable_missing
run_test "context variable multiline" test_context_variable_multiline
run_test "context with other variables" test_context_with_other_variables
run_test "no placeholder in template" test_context_no_placeholder_in_template
run_test "context special characters" test_context_special_characters

test_summary
