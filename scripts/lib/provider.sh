#!/bin/bash
# Provider abstraction for agent execution
# Supports: Claude Code, Codex (OpenAI)

# Check if a provider CLI is available
# Usage: check_provider "$provider"
check_provider() {
  local provider=$1
  case "$provider" in
    claude|claude-code|anthropic)
      if ! command -v claude &>/dev/null; then
        echo "Error: Claude CLI not found. Install with: npm install -g @anthropic-ai/claude-code" >&2
        return 1
      fi
      ;;
    codex|openai)
      if ! command -v codex &>/dev/null; then
        echo "Error: Codex CLI not found. Install with: npm install -g @openai/codex" >&2
        return 1
      fi
      ;;
    *)
      echo "Error: Unknown provider: $provider" >&2
      return 1
      ;;
  esac
  return 0
}

# Execute Claude with a prompt
# Usage: execute_claude "$prompt" "$model" "$output_file"
execute_claude() {
  local prompt=$1
  local model=${2:-"opus"}
  local output_file=$3

  # Normalize model names
  case "$model" in
    opus|claude-opus|opus-4|opus-4.5) model="opus" ;;
    sonnet|claude-sonnet|sonnet-4) model="sonnet" ;;
    haiku|claude-haiku) model="haiku" ;;
  esac

  if [ -n "$output_file" ]; then
    printf '%s' "$prompt" | claude --model "$model" --dangerously-skip-permissions 2>&1 | tee "$output_file"
  else
    printf '%s' "$prompt" | claude --model "$model" --dangerously-skip-permissions 2>&1
  fi
}

# Execute Codex with a prompt
# Usage: execute_codex "$prompt" "$model" "$output_file"
# Model: gpt-5.2-codex (default), gpt-5-codex, o3, etc.
# Reasoning effort: minimal, low, medium, high (default: high)
# Configure via env vars: CODEX_MODEL, CODEX_REASONING_EFFORT
execute_codex() {
  local prompt=$1
  local model=${2:-"${CODEX_MODEL:-gpt-5.2-codex}"}
  local output_file=$3
  local reasoning=${CODEX_REASONING_EFFORT:-"high"}

  if [ -n "$output_file" ]; then
    codex exec \
      --dangerously-bypass-approvals-and-sandbox \
      -m "$model" \
      -c "model_reasoning_effort=\"$reasoning\"" \
      "$prompt" 2>&1 | tee "$output_file"
  else
    codex exec \
      --dangerously-bypass-approvals-and-sandbox \
      -m "$model" \
      -c "model_reasoning_effort=\"$reasoning\"" \
      "$prompt" 2>&1
  fi
}

# Execute an agent with provider abstraction
# Usage: execute_agent "$provider" "$prompt" "$model" "$output_file"
execute_agent() {
  local provider=$1
  local prompt=$2
  local model=$3
  local output_file=$4

  case "$provider" in
    claude|claude-code|anthropic)
      execute_claude "$prompt" "$model" "$output_file"
      ;;
    codex|openai)
      execute_codex "$prompt" "$model" "$output_file"
      ;;
    *)
      echo "Error: Unknown provider: $provider" >&2
      return 1
      ;;
  esac
}
