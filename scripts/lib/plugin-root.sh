#!/bin/bash
# Discover the agent-pipelines root directory
# Works both in-repo and when running as a plugin
#
# Usage:
#   source scripts/lib/plugin-root.sh
#   echo $AGENT_PIPELINES_ROOT
#
# Or:
#   ROOT=$(./scripts/lib/plugin-root.sh)

# Priority order:
# 1. CLAUDE_PLUGIN_ROOT (set by Claude Code when running as plugin)
# 2. Script location detection (for in-repo usage)
# 3. Check known plugin cache locations

discover_plugin_root() {
  # 1. Plugin runtime - CLAUDE_PLUGIN_ROOT is set
  if [ -n "${CLAUDE_PLUGIN_ROOT:-}" ]; then
    echo "$CLAUDE_PLUGIN_ROOT"
    return 0
  fi

  # 2. Script location detection (when sourced or run from repo)
  local script_dir
  if [ -n "${BASH_SOURCE[0]:-}" ]; then
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  elif [ -n "$0" ]; then
    script_dir="$(cd "$(dirname "$0")" && pwd)"
  fi

  if [ -n "$script_dir" ]; then
    # Go up from scripts/lib/ to root
    local potential_root="$(cd "$script_dir/../.." && pwd)"
    if [ -f "$potential_root/CLAUDE.md" ] && [ -d "$potential_root/scripts/stages" ]; then
      echo "$potential_root"
      return 0
    fi
  fi

  # 3. Check common plugin cache locations
  local cache_paths=(
    "$HOME/.claude/plugins/cache/dodo-digital/agent-pipelines"
    "$HOME/.claude/plugins/cache/hwells4/agent-pipelines"
  )

  for cache_path in "${cache_paths[@]}"; do
    if [ -d "$cache_path" ]; then
      # Find the latest version
      local latest=$(ls -1 "$cache_path" 2>/dev/null | sort -V | tail -1)
      if [ -n "$latest" ] && [ -d "$cache_path/$latest" ]; then
        echo "$cache_path/$latest"
        return 0
      fi
    fi
  done

  # 4. Last resort - check current directory
  if [ -f "./CLAUDE.md" ] && [ -d "./scripts/stages" ]; then
    pwd
    return 0
  fi

  # Failed to discover
  echo ""
  return 1
}

# Export when sourced
AGENT_PIPELINES_ROOT=$(discover_plugin_root)
export AGENT_PIPELINES_ROOT

# Output when run directly
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  if [ -n "$AGENT_PIPELINES_ROOT" ]; then
    echo "$AGENT_PIPELINES_ROOT"
  else
    echo "ERROR: Could not discover agent-pipelines root" >&2
    exit 1
  fi
fi
