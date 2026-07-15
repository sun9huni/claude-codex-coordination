#!/usr/bin/env bash
# Produce a review packet for the current diff. Does NOT post anywhere.
# Output goes to .agent/handoffs/state/review-<timestamp>.md so a reviewer
# (human or another agent) can read a single file and decide.
#
# Usage: ./scripts/review.sh [base-ref]
#   base-ref defaults to origin/main if it exists, else HEAD~1.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

BASE="${1:-}"
if [ -z "$BASE" ]; then
  if git rev-parse --verify origin/main >/dev/null 2>&1; then
    BASE="origin/main"
  else
    BASE="HEAD~1"
  fi
fi

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "[review] not a git repo: $ROOT" >&2
  exit 1
fi

stamp="$(date -u +%Y%m%dT%H%M%SZ)"
OUT_DIR=".agent/handoffs/state"
mkdir -p "$OUT_DIR"
OUT="$OUT_DIR/review-$stamp.md"

{
  echo "# Review packet"
  echo ""
  echo "- generated: $stamp"
  echo "- base: $BASE"
  echo "- head: $(git rev-parse --short HEAD)"
  echo "- branch: $(git rev-parse --abbrev-ref HEAD)"
  echo ""
  echo "## Files changed"
  echo ""
  echo '```'
  git --no-pager diff --stat "$BASE"...HEAD
  echo '```'
  echo ""
  echo "## Commits"
  echo ""
  echo '```'
  git --no-pager log --oneline "$BASE"..HEAD
  echo '```'
  echo ""
  echo "## Contract pointers"
  echo ""
  ls -1 .agent/contracts/ 2>/dev/null | sed 's/^/- /'
  echo ""
  echo "## Diff"
  echo ""
  echo '```diff'
  git --no-pager diff "$BASE"...HEAD
  echo '```'
} > "$OUT"

echo "[review] wrote $OUT"
echo "[review] open with: cat $OUT"
