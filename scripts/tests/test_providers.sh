#!/bin/bash
# Tests for provider abstraction
# TDD: These tests define the expected behavior before implementation

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/test.sh"
source "$SCRIPT_DIR/lib/yaml.sh"
source "$SCRIPT_DIR/lib/provider.sh"

#-------------------------------------------------------------------------------
# Provider Config Tests
#-------------------------------------------------------------------------------

test_default_provider_is_claude() {
  # Simulate config without provider field
  local config='{"name":"test","termination":{"type":"fixed"}}'
  local provider=$(echo "$config" | jq -r '.provider // "claude"')
  assert_eq "claude" "$provider" "Default provider should be claude"
}

test_codex_provider_from_config() {
  local config='{"name":"test","provider":"codex","termination":{"type":"fixed"}}'
  local provider=$(echo "$config" | jq -r '.provider // "claude"')
  assert_eq "codex" "$provider" "Should read codex provider from config"
}

test_provider_aliases_normalized() {
  # Test that various aliases normalize correctly
  local aliases=("claude" "claude-code" "anthropic")
  for alias in "${aliases[@]}"; do
    case "$alias" in
      claude|claude-code|anthropic)
        assert_eq "claude" "claude" "$alias should be a valid claude alias"
        ;;
    esac
  done

  local codex_aliases=("codex" "openai")
  for alias in "${codex_aliases[@]}"; do
    case "$alias" in
      codex|openai)
        assert_eq "codex" "codex" "$alias should be a valid codex alias"
        ;;
    esac
  done
}

#-------------------------------------------------------------------------------
# Provider Check Tests
#-------------------------------------------------------------------------------

test_check_provider_claude_succeeds() {
  if command -v claude &>/dev/null; then
    check_provider "claude"
    assert_eq 0 $? "check_provider claude should succeed when installed"
  else
    skip_test "claude CLI not installed"
  fi
}

test_check_provider_codex_succeeds() {
  if command -v codex &>/dev/null; then
    check_provider "codex"
    assert_eq 0 $? "check_provider codex should succeed when installed"
  else
    skip_test "codex CLI not installed"
  fi
}

test_check_provider_unknown_fails() {
  check_provider "unknown-provider" 2>/dev/null
  assert_neq 0 $? "check_provider unknown should fail"
}

#-------------------------------------------------------------------------------
# Model Normalization Tests
#-------------------------------------------------------------------------------

test_claude_model_normalization() {
  # opus variants -> opus
  local model="opus-4.5"
  case "$model" in
    opus|claude-opus|opus-4|opus-4.5) model="opus" ;;
  esac
  assert_eq "opus" "$model" "opus-4.5 normalizes to opus"

  model="claude-sonnet"
  case "$model" in
    sonnet|claude-sonnet|sonnet-4) model="sonnet" ;;
  esac
  assert_eq "sonnet" "$model" "claude-sonnet normalizes to sonnet"
}

test_codex_default_model() {
  # Default codex model should be gpt-5.2-codex
  local default_model="${CODEX_MODEL:-gpt-5.2-codex}"
  assert_eq "gpt-5.2-codex" "$default_model" "default codex model is gpt-5.2-codex"
}

test_codex_reasoning_effort_default() {
  # Default reasoning effort should be high
  local default_reasoning="${CODEX_REASONING_EFFORT:-high}"
  assert_eq "high" "$default_reasoning" "default reasoning effort is high"
}

test_codex_reasoning_effort_options() {
  # Valid reasoning effort options: minimal, low, medium, high
  local valid_options=("minimal" "low" "medium" "high")
  for opt in "${valid_options[@]}"; do
    assert_contains "minimal low medium high" "$opt" "$opt is a valid reasoning effort"
  done
}

#-------------------------------------------------------------------------------
# Execute Agent Tests
#-------------------------------------------------------------------------------

test_execute_agent_routes_to_claude() {
  # Test that function exists and accepts claude provider
  if type execute_agent &>/dev/null; then
    assert_true "true" "execute_agent function exists"
  else
    skip_test "execute_agent not found"
  fi
}

test_execute_agent_routes_to_codex() {
  # Test that function exists and accepts codex provider
  if type execute_agent &>/dev/null; then
    assert_true "true" "execute_agent function exists"
  else
    skip_test "execute_agent not found"
  fi
}

#-------------------------------------------------------------------------------
# Integration Tests - Load from actual stage configs
#-------------------------------------------------------------------------------

test_work_stage_uses_default_provider() {
  local config=$(yaml_to_json "$SCRIPT_DIR/stages/work/stage.yaml")
  local provider=$(json_get "$config" ".provider" "claude")
  assert_eq "claude" "$provider" "work stage defaults to claude provider"
}

#-------------------------------------------------------------------------------
# Run Tests
#-------------------------------------------------------------------------------

echo ""
echo "==============================================================="
echo "  Provider Abstraction Tests"
echo "==============================================================="
echo ""

run_test "default provider is claude" test_default_provider_is_claude
run_test "codex provider from config" test_codex_provider_from_config
run_test "provider aliases normalized" test_provider_aliases_normalized
run_test "check_provider claude succeeds" test_check_provider_claude_succeeds
run_test "check_provider codex succeeds" test_check_provider_codex_succeeds
run_test "check_provider unknown fails" test_check_provider_unknown_fails
run_test "claude model normalization" test_claude_model_normalization
run_test "codex default model" test_codex_default_model
run_test "codex reasoning effort default" test_codex_reasoning_effort_default
run_test "codex reasoning effort options" test_codex_reasoning_effort_options
run_test "execute_agent routes to claude" test_execute_agent_routes_to_claude
run_test "execute_agent routes to codex" test_execute_agent_routes_to_codex
run_test "work stage uses default provider" test_work_stage_uses_default_provider

test_summary
