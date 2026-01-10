#!/bin/bash
# Unified Progress File Management
# Handles progress accumulation for loops and pipeline stages

# Initialize progress file
# Usage: init_progress "$session" "$run_dir"
init_progress() {
  local session=$1
  local run_dir=${2:-"$PROJECT_ROOT/.claude/loop-progress"}

  mkdir -p "$run_dir"
  local progress_file="$run_dir/progress-${session}.md"

  if [ ! -f "$progress_file" ]; then
    cat > "$progress_file" << EOF
# Progress: $session

Verify: (none)

## Codebase Patterns
(Add patterns discovered during implementation here)

---

EOF
  fi

  echo "$progress_file"
}

# Initialize stage-specific progress file (for pipelines)
# Usage: init_stage_progress "$stage_dir"
init_stage_progress() {
  local stage_dir=$1

  mkdir -p "$stage_dir"
  local progress_file="$stage_dir/progress.md"

  if [ ! -f "$progress_file" ]; then
    echo "# Stage Progress" > "$progress_file"
    echo "" >> "$progress_file"
    echo "---" >> "$progress_file"
  fi

  echo "$progress_file"
}

# Append to progress file
# Usage: append_progress "$progress_file" "$content"
append_progress() {
  local progress_file=$1
  local content=$2

  echo "$content" >> "$progress_file"
  echo "---" >> "$progress_file"
  echo "" >> "$progress_file"
}
