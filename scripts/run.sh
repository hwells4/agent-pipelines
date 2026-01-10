#!/bin/bash
# Unified Entry Point
# Usage: run.sh <loop|pipeline> <type_or_file> [session] [max_iterations]
#
# Examples:
#   ./run.sh stage work auth 25        # Run work stage for 'auth' session
#   ./run.sh stage improve-plan planning 10  # Run improve-plan stage
#   ./run.sh pipeline full-refine.yaml myproject  # Run multi-stage pipeline

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -z "$1" ]; then
  echo "Usage: run.sh <loop|pipeline> <type_or_file> [session] [max_iterations]"
  echo ""
  echo "Modes:"
  echo "  loop <type> [session] [max]  - Run a loop"
  echo "  pipeline <file> [session]     - Run a multi-stage pipeline"
  echo ""
  echo "Available loops:"
  for dir in "$SCRIPT_DIR"/loops/*/; do
    [ -d "$dir" ] || continue
    name=$(basename "$dir")
    desc=$(grep "^description:" "$dir/loop.yaml" 2>/dev/null | cut -d: -f2- | sed 's/^[[:space:]]*//')
    echo "  $name - $desc"
  done
  echo ""
  echo "Available pipelines:"
  for f in "$SCRIPT_DIR"/pipelines/*.yaml; do
    [ -f "$f" ] || continue
    name=$(basename "$f" .yaml)
    desc=$(grep "^description:" "$f" 2>/dev/null | cut -d: -f2- | sed 's/^[[:space:]]*//')
    echo "  $name - $desc"
  done
  exit 1
fi

exec "$SCRIPT_DIR/engine.sh" "$@"
