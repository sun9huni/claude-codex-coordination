#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOOLS_DIR="$ROOT/.agent/tools"
INVENTORY="$TOOLS_DIR/inventory.md"

echo "[tool-audit] starting"

if [ ! -f "$INVENTORY" ]; then
  echo "[tool-audit] missing inventory: $INVENTORY" >&2
  exit 1
fi

echo "[tool-audit] review:"
echo "  - $TOOLS_DIR/inventory.md"
echo "  - $TOOLS_DIR/context-budget.md"
echo "  - $TOOLS_DIR/mcp-policy.md"
echo "  - $TOOLS_DIR/audit-log.md"

if grep -qi "TBD" "$INVENTORY"; then
  echo "[tool-audit] inventory has TBD entries"
fi

required_sections=(
  "## Side-Effect Classes"
  "## Disabled Runtime Surfaces"
)

for section in "${required_sections[@]}"; do
  if ! grep -Fq "$section" "$INVENTORY"; then
    echo "[tool-audit] missing required section: $section" >&2
    exit 1
  fi
done

required_classes=(
  "read-only-local"
  "local-write"
  "external-network"
  "credential-bearing"
  "scheduler-daemon"
  "messaging-notification"
  "production-facing"
  "destructive-infra"
)

for class in "${required_classes[@]}"; do
  if ! grep -Fq "\`$class\`" "$INVENTORY"; then
    echo "[tool-audit] missing side-effect class: $class" >&2
    exit 1
  fi
done

if grep -Fq "Hermes Agent runtime" "$INVENTORY"; then
  if ! grep -Fq "gateway, cron, messaging" "$INVENTORY"; then
    echo "[tool-audit] Hermes runtime row exists but disabled surfaces are not documented" >&2
    exit 1
  fi
fi

echo "[tool-audit] finished"
