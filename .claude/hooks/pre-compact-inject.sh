#!/usr/bin/env bash
# PreCompact hook: carry FRESH workspace state through context compaction.
#
# When Claude Code compacts a long conversation, summarized context loses
# fine-grained references to the workspace state. Printing the CURRENT.md
# frontmatter + body to stdout here keeps that content proximate in the
# summarized form.
#
# Root-cause note: the derived index (CURRENT.md) only refreshes when someone
# runs `status.sh index`. If a long session edited batons but never regenerated
# it, a plain `cat CURRENT.md` would inject STALE state into the compacted
# context. So we (1) regenerate the index first (a pure transform from the
# slice files), (2) inject the now-fresh CURRENT.md, and (3) append any
# baton<->reality drift so the post-compaction agent fixes the batons instead
# of trusting a frozen snapshot.
#
# Non-blocking (exit 0). To block compaction, emit a JSON
# `{"decision": "block", "reason": "..."}` on stdout instead.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
AGENT_DIR="${AGENT_ROOT:-$ROOT/.agent}"
current="$AGENT_DIR/handoffs/CURRENT.md"

# (1) refresh the derived index before snapshotting — best-effort, never fatal.
if [ -f "$ROOT/scripts/status.sh" ]; then
  bash "$ROOT/scripts/status.sh" index >/dev/null 2>&1 || true
fi

[ -f "$current" ] || exit 0

# (2) emit a tagged block so the post-compaction context recognizes it.
echo "--- PRE-COMPACT: workspace state snapshot ---"
echo "(Source of truth: .agent/handoffs/CURRENT.md, regenerated immediately before compaction)"
echo
cat "$current"
echo
echo "--- END PRE-COMPACT ---"

# (3) surface baton<->reality drift so the compacted agent updates the batons.
if [ -x "$ROOT/scripts/baton-drift.sh" ]; then
  drift="$(bash "$ROOT/scripts/baton-drift.sh" 2>/dev/null || true)"
  if [ -n "$drift" ]; then
    echo
    echo "--- BATON DRIFT (the snapshot above may lag reality — fix these batons) ---"
    printf '%s\n' "$drift"
  fi
fi

exit 0
