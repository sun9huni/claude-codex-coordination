#!/usr/bin/env bash
set -euo pipefail

echo "[verify] starting"

if command -v npm >/dev/null 2>&1 && [ -f package.json ]; then
  echo "[verify] npm format check"
  npm run format:check --if-present

  echo "[verify] npm lint"
  npm run lint --if-present

  echo "[verify] npm typecheck"
  npm run typecheck --if-present

  echo "[verify] npm test"
  npm test --if-present
fi

if command -v pytest >/dev/null 2>&1 && { [ -f pyproject.toml ] || [ -f pytest.ini ] || [ -f setup.cfg ]; }; then
  echo "[verify] pytest"
  pytest -q
fi

echo "[verify] finished"
