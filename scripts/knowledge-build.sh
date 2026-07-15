#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KNOWLEDGE_DIR="$ROOT/.agent/knowledge"
RAW_DIR="$KNOWLEDGE_DIR/raw"
WIKI_DIR="$KNOWLEDGE_DIR/wiki"

mkdir -p "$RAW_DIR" "$WIKI_DIR" "$KNOWLEDGE_DIR/graphify-out"

echo "[knowledge-build] starting"

if command -v graphify >/dev/null 2>&1; then
  echo "[knowledge-build] graphify found"
  (
    cd "$KNOWLEDGE_DIR"
    graphify "$RAW_DIR" --wiki --no-viz
  )
else
  echo "[knowledge-build] graphify not found"
  echo "[knowledge-build] update $WIKI_DIR and $KNOWLEDGE_DIR/provenance.md manually from $RAW_DIR"
fi

echo "[knowledge-build] check:"
echo "  - $KNOWLEDGE_DIR/graphify-out/GRAPH_REPORT.md"
echo "  - $WIKI_DIR/index.md"
echo "  - $KNOWLEDGE_DIR/provenance.md"

echo "[knowledge-build] finished"
