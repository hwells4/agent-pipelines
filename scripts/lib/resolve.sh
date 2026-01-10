#!/bin/bash
# Unified Variable Resolution
# Resolves all variables in prompt templates for both loops and pipelines
#
# Variables:
#   ${SESSION} / ${SESSION_NAME}  - Session name
#   ${ITERATION}                  - Current iteration (1-based)
#   ${INDEX}                      - Current run index (0-based)
#   ${PERSPECTIVE}                - Current perspective (for fan-out)
#   ${OUTPUT}                     - Path to write output
#   ${PROGRESS} / ${PROGRESS_FILE} - Path to progress file
#   ${INPUTS.stage-name}          - Outputs from a previous stage
#   ${INPUTS}                     - Shorthand for previous stage outputs

# Resolve all variables in a prompt template
# Usage: resolve_prompt "$template" "$vars_json"
# vars_json: {"session": "x", "iteration": 1, "progress_file": "/path", ...}
resolve_prompt() {
  local template=$1
  local vars_json=$2

  local resolved="$template"

  # Extract variables from JSON
  local session=$(echo "$vars_json" | jq -r '.session // empty')
  local iteration=$(echo "$vars_json" | jq -r '.iteration // empty')
  local index=$(echo "$vars_json" | jq -r '.index // empty')
  local perspective=$(echo "$vars_json" | jq -r '.perspective // empty')
  local output_file=$(echo "$vars_json" | jq -r '.output // empty')
  local progress_file=$(echo "$vars_json" | jq -r '.progress // empty')
  local run_dir=$(echo "$vars_json" | jq -r '.run_dir // empty')
  local stage_idx=$(echo "$vars_json" | jq -r '.stage_idx // "0"')

  # Standard substitutions (bash parameter expansion for multi-line safety)
  resolved="${resolved//\$\{SESSION\}/$session}"
  resolved="${resolved//\$\{SESSION_NAME\}/$session}"
  resolved="${resolved//\$\{ITERATION\}/$iteration}"
  resolved="${resolved//\$\{INDEX\}/$index}"
  resolved="${resolved//\$\{PERSPECTIVE\}/$perspective}"
  resolved="${resolved//\$\{OUTPUT\}/$output_file}"
  resolved="${resolved//\$\{PROGRESS\}/$progress_file}"
  resolved="${resolved//\$\{PROGRESS_FILE\}/$progress_file}"

  # Resolve ${INPUTS.stage-name} references
  while [[ "$resolved" =~ \$\{INPUTS\.([a-zA-Z0-9_-]+)\} ]]; do
    local ref_stage_name="${BASH_REMATCH[1]}"
    local inputs_content=$(resolve_stage_inputs "$run_dir" "$ref_stage_name")
    resolved="${resolved//\$\{INPUTS.$ref_stage_name\}/$inputs_content}"
  done

  # Resolve ${INPUTS} (previous stage shorthand)
  if [[ "$resolved" == *'${INPUTS}'* ]] && [ -n "$run_dir" ]; then
    local prev_inputs=$(resolve_previous_stage_inputs "$run_dir" "$stage_idx")
    resolved="${resolved//\$\{INPUTS\}/$prev_inputs}"
  fi

  echo "$resolved"
}

# Get outputs from a named stage
# Usage: resolve_stage_inputs "$run_dir" "$stage_name"
resolve_stage_inputs() {
  local run_dir=$1
  local stage_name=$2

  if [ -z "$run_dir" ] || [ ! -d "$run_dir" ]; then
    echo "[No run directory]"
    return
  fi

  # Find the stage directory
  local stage_dir=$(find "$run_dir" -maxdepth 1 -type d -name "stage-*-$stage_name" 2>/dev/null | head -1)

  if [ -z "$stage_dir" ] || [ ! -d "$stage_dir" ]; then
    echo "[No outputs found for stage: $stage_name]"
    return
  fi

  # Collect output files (exclude progress.md)
  local output_files=$(find "$stage_dir" -name "*.md" ! -name "progress.md" -type f 2>/dev/null | sort)

  if [ -z "$output_files" ]; then
    echo "[No output files in stage: $stage_name]"
    return
  fi

  # Count files
  local file_count=$(echo "$output_files" | wc -l | tr -d ' ')

  # Single output: return content directly
  if [ "$file_count" -eq 1 ]; then
    cat "$output_files"
    return
  fi

  # Multiple outputs: format with headers
  local result="--- Outputs from stage: $stage_name ---"$'\n'

  for file in $output_files; do
    local filename=$(basename "$file")
    result="${result}"$'\n'"=== $filename ==="$'\n'
    result="${result}$(cat "$file")"$'\n'
  done

  echo "$result"
}

# Get previous stage inputs
# Usage: resolve_previous_stage_inputs "$run_dir" "$current_stage_idx"
resolve_previous_stage_inputs() {
  local run_dir=$1
  local current_idx=$2

  if [ "$current_idx" -le 0 ]; then
    echo ""
    return
  fi

  # Find previous stage directory
  local prev_dir=$(find "$run_dir" -maxdepth 1 -type d -name "stage-${current_idx}-*" 2>/dev/null | head -1)

  if [ -n "$prev_dir" ]; then
    local stage_name=$(basename "$prev_dir" | sed 's/stage-[0-9]*-//')
    resolve_stage_inputs "$run_dir" "$stage_name"
  fi
}

# Load prompt from file and resolve variables
# Usage: load_and_resolve_prompt "$prompt_file" "$vars_json"
load_and_resolve_prompt() {
  local prompt_file=$1
  local vars_json=$2

  if [ ! -f "$prompt_file" ]; then
    echo "Error: Prompt file not found: $prompt_file" >&2
    return 1
  fi

  local template=$(cat "$prompt_file")
  resolve_prompt "$template" "$vars_json"
}
