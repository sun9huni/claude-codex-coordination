#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "usage: $0 <ssh-alias> <remote-repo-path>" >&2
  exit 2
fi

HOST="$1"
REMOTE_REPO="$2"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "[remote-bootstrap] host=$HOST repo=$REMOTE_REPO"

ssh "$HOST" "cd '$REMOTE_REPO' && pwd && uname -a && git status --short && git rev-parse --abbrev-ref HEAD"

ssh "$HOST" "cd '$REMOTE_REPO' && mkdir -p .agent/checklists .agent/contracts .agent/delegation .agent/evals .agent/handoffs/state .agent/handoffs/archive .agent/knowledge/wiki .agent/qa .agent/remote .agent/skills .agent/tools scripts"

rsync -av \
  "$ROOT/AGENTS.md.example" \
  "$ROOT/.agent/PLANS.md" \
  "$ROOT/.agent/checklists/change-discipline.md" \
  "$ROOT/.agent/checklists/knowledge-layer.md" \
  "$ROOT/.agent/contracts/_template.md" \
  "$ROOT/.agent/delegation/policy.md" \
  "$ROOT/.agent/delegation/log.md" \
  "$ROOT/.agent/evals/eval-plan.md" \
  "$ROOT/.agent/evals/dataset.jsonl" \
  "$ROOT/.agent/evals/failure-taxonomy.md" \
  "$ROOT/.agent/evals/judge-calibration.md" \
  "$ROOT/.agent/evals/criteria-drift.md" \
  "$ROOT/.agent/knowledge/README.md" \
  "$ROOT/.agent/knowledge/wiki/index.md" \
  "$ROOT/.agent/knowledge/wiki/hada-upgrades.md" \
  "$ROOT/.agent/knowledge/provenance.md" \
  "$ROOT/.agent/qa/browser-checklist.md" \
  "$ROOT/.agent/remote/hosts.example.md" \
  "$ROOT/.agent/remote/policies.md" \
  "$ROOT/.agent/remote/runbook.md" \
  "$ROOT/.agent/remote/bootstrap-log.md" \
  "$ROOT/.agent/skills/registry.md" \
  "$ROOT/.agent/skills/sync-policy.md" \
  "$ROOT/.agent/skills/selection.md" \
  "$ROOT/.agent/tools/inventory.md" \
  "$ROOT/.agent/tools/context-budget.md" \
  "$ROOT/.agent/tools/mcp-policy.md" \
  "$ROOT/.agent/tools/audit-log.md" \
  "$ROOT/scripts/verify.sh.example" \
  "$ROOT/scripts/browser-check.sh.example" \
  "$ROOT/scripts/eval.sh.example" \
  "$ROOT/scripts/knowledge-build.sh.example" \
  "$ROOT/scripts/remote-verify.sh.example" \
  "$ROOT/scripts/skills-sync.sh.example" \
  "$ROOT/scripts/tool-audit.sh.example" \
  "$ROOT/scripts/handoff.sh.example" \
  "$ROOT/.agent/handoffs/CURRENT.md" \
  "$ROOT/.agent/handoffs/takeover-prompt.md" \
  "$ROOT/.agent/handoffs/handoff.md" \
  "$ROOT/.agent/handoffs/README.md" \
  "$HOST:$REMOTE_REPO/.agent/bootstrap-import/"

rsync -av "$ROOT/skills/" "$HOST:$REMOTE_REPO/skills/"

ssh "$HOST" "cd '$REMOTE_REPO' && test -f AGENTS.md || cp .agent/bootstrap-import/AGENTS.md.example AGENTS.md"
ssh "$HOST" "cd '$REMOTE_REPO' && cp -n .agent/bootstrap-import/PLANS.md .agent/PLANS.md || true"
ssh "$HOST" "cd '$REMOTE_REPO' && cp -n .agent/bootstrap-import/_template.md .agent/contracts/_template.md || true"
ssh "$HOST" "cd '$REMOTE_REPO' && cp -n .agent/bootstrap-import/policy.md .agent/delegation/policy.md || true"
ssh "$HOST" "cd '$REMOTE_REPO' && cp -n .agent/bootstrap-import/log.md .agent/delegation/log.md || true"
ssh "$HOST" "cd '$REMOTE_REPO' && cp -n .agent/bootstrap-import/eval-plan.md .agent/evals/eval-plan.md || true"
ssh "$HOST" "cd '$REMOTE_REPO' && cp -n .agent/bootstrap-import/dataset.jsonl .agent/evals/dataset.jsonl || true"
ssh "$HOST" "cd '$REMOTE_REPO' && cp -n .agent/bootstrap-import/failure-taxonomy.md .agent/evals/failure-taxonomy.md || true"
ssh "$HOST" "cd '$REMOTE_REPO' && cp -n .agent/bootstrap-import/judge-calibration.md .agent/evals/judge-calibration.md || true"
ssh "$HOST" "cd '$REMOTE_REPO' && cp -n .agent/bootstrap-import/criteria-drift.md .agent/evals/criteria-drift.md || true"
ssh "$HOST" "cd '$REMOTE_REPO' && cp -n .agent/bootstrap-import/change-discipline.md .agent/checklists/change-discipline.md || true"
ssh "$HOST" "cd '$REMOTE_REPO' && cp -n .agent/bootstrap-import/knowledge-layer.md .agent/checklists/knowledge-layer.md || true"
ssh "$HOST" "cd '$REMOTE_REPO' && cp -n .agent/bootstrap-import/README.md .agent/knowledge/README.md || true"
ssh "$HOST" "cd '$REMOTE_REPO' && cp -n .agent/bootstrap-import/index.md .agent/knowledge/wiki/index.md || true"
ssh "$HOST" "cd '$REMOTE_REPO' && cp -n .agent/bootstrap-import/hada-upgrades.md .agent/knowledge/wiki/hada-upgrades.md || true"
ssh "$HOST" "cd '$REMOTE_REPO' && cp -n .agent/bootstrap-import/provenance.md .agent/knowledge/provenance.md || true"
ssh "$HOST" "cd '$REMOTE_REPO' && cp -n .agent/bootstrap-import/browser-checklist.md .agent/qa/browser-checklist.md || true"
ssh "$HOST" "cd '$REMOTE_REPO' && cp -n .agent/bootstrap-import/policies.md .agent/remote/policies.md || true"
ssh "$HOST" "cd '$REMOTE_REPO' && cp -n .agent/bootstrap-import/runbook.md .agent/remote/runbook.md || true"
ssh "$HOST" "cd '$REMOTE_REPO' && cp -n .agent/bootstrap-import/bootstrap-log.md .agent/remote/bootstrap-log.md || true"
ssh "$HOST" "cd '$REMOTE_REPO' && cp -n .agent/bootstrap-import/registry.md .agent/skills/registry.md || true"
ssh "$HOST" "cd '$REMOTE_REPO' && cp -n .agent/bootstrap-import/sync-policy.md .agent/skills/sync-policy.md || true"
ssh "$HOST" "cd '$REMOTE_REPO' && cp -n .agent/bootstrap-import/selection.md .agent/skills/selection.md || true"
ssh "$HOST" "cd '$REMOTE_REPO' && cp -n .agent/bootstrap-import/inventory.md .agent/tools/inventory.md || true"
ssh "$HOST" "cd '$REMOTE_REPO' && cp -n .agent/bootstrap-import/context-budget.md .agent/tools/context-budget.md || true"
ssh "$HOST" "cd '$REMOTE_REPO' && cp -n .agent/bootstrap-import/mcp-policy.md .agent/tools/mcp-policy.md || true"
ssh "$HOST" "cd '$REMOTE_REPO' && cp -n .agent/bootstrap-import/audit-log.md .agent/tools/audit-log.md || true"
ssh "$HOST" "cd '$REMOTE_REPO' && cp -n .agent/bootstrap-import/verify.sh.example scripts/verify.sh || true"
ssh "$HOST" "cd '$REMOTE_REPO' && cp -n .agent/bootstrap-import/browser-check.sh.example scripts/browser-check.sh || true"
ssh "$HOST" "cd '$REMOTE_REPO' && cp -n .agent/bootstrap-import/eval.sh.example scripts/eval.sh || true"
ssh "$HOST" "cd '$REMOTE_REPO' && cp -n .agent/bootstrap-import/knowledge-build.sh.example scripts/knowledge-build.sh || true"
ssh "$HOST" "cd '$REMOTE_REPO' && cp -n .agent/bootstrap-import/remote-verify.sh.example scripts/remote-verify.sh || true"
ssh "$HOST" "cd '$REMOTE_REPO' && cp -n .agent/bootstrap-import/skills-sync.sh.example scripts/skills-sync.sh || true"
ssh "$HOST" "cd '$REMOTE_REPO' && cp -n .agent/bootstrap-import/tool-audit.sh.example scripts/tool-audit.sh || true"
ssh "$HOST" "cd '$REMOTE_REPO' && cp -n .agent/bootstrap-import/handoff.sh.example scripts/handoff.sh || true"
ssh "$HOST" "cd '$REMOTE_REPO' && cp -n .agent/bootstrap-import/CURRENT.md .agent/handoffs/CURRENT.md || true"
ssh "$HOST" "cd '$REMOTE_REPO' && cp -n .agent/bootstrap-import/takeover-prompt.md .agent/handoffs/takeover-prompt.md || true"
ssh "$HOST" "cd '$REMOTE_REPO' && cp -n .agent/bootstrap-import/handoff.md .agent/handoffs/handoff.md || true"
ssh "$HOST" "cd '$REMOTE_REPO' && cp -n .agent/bootstrap-import/README.md .agent/handoffs/README.md || true"
ssh "$HOST" "cd '$REMOTE_REPO' && chmod +x scripts/verify.sh scripts/browser-check.sh scripts/eval.sh scripts/knowledge-build.sh scripts/remote-verify.sh scripts/skills-sync.sh scripts/tool-audit.sh scripts/handoff.sh 2>/dev/null || true"

echo "[remote-bootstrap] finished"
