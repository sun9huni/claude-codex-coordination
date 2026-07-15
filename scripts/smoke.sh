#!/usr/bin/env bash
# Smoke check: cheapest signal that the system is not catastrophically broken.
# Runs before verify.sh on big changes, so a 5-second smoke catches what a
# 10-minute test suite would also catch — but faster.
#
# Conventions per-project:
#   - npm:    `npm run smoke --if-present`
#   - python: `python -m <pkg> --smoke` or `pytest -q -m smoke`
#   - shell:  any `scripts/smoke-*.sh`
# This wrapper just routes.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

echo "[smoke] starting in $ROOT"
ran=0

if [ -f package.json ] && command -v npm >/dev/null 2>&1; then
  if npm run | grep -qE '^\s+smoke'; then
    echo "[smoke] npm run smoke"
    npm run smoke
    ran=1
  fi
fi

if command -v pytest >/dev/null 2>&1 && { [ -f pyproject.toml ] || [ -f pytest.ini ] || [ -f setup.cfg ]; }; then
  if pytest --collect-only -q -m smoke >/dev/null 2>&1; then
    echo "[smoke] pytest -m smoke"
    pytest -q -m smoke
    ran=1
  fi
fi

for s in scripts/smoke-*.sh; do
  [ -f "$s" ] || continue
  echo "[smoke] $s"
  bash "$s"
  ran=1
done

if [ "$ran" -eq 0 ]; then
  echo "[smoke] no smoke target detected; defining one is recommended for fast feedback"
fi

echo "[smoke] finished"
