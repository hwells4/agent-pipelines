#!/bin/bash
# Unified YAML Parser
# Converts YAML to JSON for easy querying with jq

# Convert YAML file to JSON
# Usage: yaml_to_json "file.yaml"
yaml_to_json() {
  local file=$1

  if [ ! -f "$file" ]; then
    echo "{}"
    return 1
  fi

  if command -v yq &>/dev/null; then
    yq -o=json "$file"
  elif python3 -c "import yaml" &>/dev/null 2>&1; then
    python3 -c "
import sys, json, yaml
with open('$file') as f:
    print(json.dumps(yaml.safe_load(f)))
"
  else
    echo "Error: Need yq or python3 with PyYAML" >&2
    return 1
  fi
}

# Query a JSON value using jq
# Usage: json_get "$json" ".key" "default"
json_get() {
  local json=$1
  local path=$2
  local default=${3:-""}

  local value=$(echo "$json" | jq -r "$path // empty" 2>/dev/null)

  if [ -z "$value" ] || [ "$value" = "null" ]; then
    echo "$default"
  else
    echo "$value"
  fi
}

# Get array length
# Usage: json_array_len "$json" ".stages"
json_array_len() {
  local json=$1
  local path=$2

  echo "$json" | jq -r "$path | length" 2>/dev/null || echo "0"
}

# Get array as newline-separated values
# Usage: json_array "$json" ".perspectives[]"
json_array() {
  local json=$1
  local path=$2

  echo "$json" | jq -r "$path" 2>/dev/null
}
