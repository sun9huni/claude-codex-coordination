#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EVAL_DIR="$ROOT/.agent/evals"
DATASET="$EVAL_DIR/dataset.jsonl"

echo "[eval] starting"

if [ ! -f "$DATASET" ]; then
  echo "[eval] missing dataset: $DATASET" >&2
  exit 1
fi

CASES="$(grep -cve '^[[:space:]]*$' "$DATASET" || true)"
echo "[eval] cases=$CASES"

if [ "$CASES" -eq 0 ]; then
  echo "[eval] dataset is empty" >&2
  exit 1
fi

echo "[eval] review:"
echo "  - $EVAL_DIR/eval-plan.md"
echo "  - $EVAL_DIR/failure-taxonomy.md"
echo "  - $EVAL_DIR/judge-calibration.md"
echo "  - $EVAL_DIR/criteria-drift.md"

echo "[eval] no project-specific runner configured"
echo "[eval] add deterministic checks or a project eval runner here"

echo "[eval] finished"
