#!/bin/bash
set -e

# Loop Agent - Archive completed PRD
# Archives current prd.json + progress.txt, then clears for next run

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ARCHIVE_DIR="$SCRIPT_DIR/archive"

# Get archive name from argument or use timestamp
if [ -n "$1" ]; then
  ARCHIVE_NAME="$1"
else
  ARCHIVE_NAME=$(date +%Y-%m-%d-%H%M)
fi

# Check if there's anything to archive
if [ ! -f "$SCRIPT_DIR/prd.json" ] && [ ! -f "$SCRIPT_DIR/progress.txt" ]; then
  echo "Nothing to archive (no prd.json or progress.txt found)"
  exit 1
fi

# Create archive subfolder
ARCHIVE_PATH="$ARCHIVE_DIR/$ARCHIVE_NAME"
mkdir -p "$ARCHIVE_PATH"

echo "Archiving current loop state to: $ARCHIVE_NAME"

# Move files to archive
[ -f "$SCRIPT_DIR/prd.json" ] && mv "$SCRIPT_DIR/prd.json" "$ARCHIVE_PATH/"
[ -f "$SCRIPT_DIR/progress.txt" ] && mv "$SCRIPT_DIR/progress.txt" "$ARCHIVE_PATH/"
[ -f "$SCRIPT_DIR/prompt.md" ] && cp "$SCRIPT_DIR/prompt.md" "$ARCHIVE_PATH/"

echo ""
echo "Archived:"
ls -la "$ARCHIVE_PATH/"

echo ""
echo "Ready for new PRD. Create prd.json to start."
