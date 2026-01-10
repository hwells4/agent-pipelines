#!/bin/bash
# Output Parsing Utilities
# Extracts structured data from Claude's output

# Parse a key:value from output
# Usage: parse_output "$output" "CHANGES"
parse_output() {
  local output=$1
  local key=$2

  echo "$output" | grep -E "^${key}:" | head -1 | cut -d: -f2- | sed 's/^[[:space:]]*//'
}

# Parse multiple keys into JSON object
# Usage: parse_outputs_to_json "$output" "changes:CHANGES" "summary:SUMMARY"
parse_outputs_to_json() {
  local output=$1
  shift

  local json="{"
  local first=true

  for mapping in "$@"; do
    local json_key="${mapping%%:*}"
    local output_key="${mapping#*:}"
    local value=$(parse_output "$output" "$output_key")

    if [ -n "$value" ]; then
      if [ "$first" = true ]; then
        first=false
      else
        json="$json,"
      fi
      # Escape quotes and backslashes in value
      value=$(echo "$value" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g')
      json="$json\"$json_key\":\"$value\""
    fi
  done

  json="$json}"
  echo "$json"
}
