#!/usr/bin/env bash
# PreCompact hook: ensure CURRENT.md content survives context compaction.
#
# When Claude Code compacts a long conversation, summarized context
# loses fine-grained references to the workspace state. By printing
# the CURRENT.md frontmatter + body to stdout here, the compactor sees
# this content as part of the "before-compaction" record and keeps it
# proximate in the summarized form. Non-blocking (exit 0).
#
# This hook does NOT block compaction. To block compaction, return a
# JSON `{"decision": "block", "reason": "..."}` on stdout instead.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
current="$ROOT/.agent/handoffs/CURRENT.md"
[ -f "$current" ] || exit 0

# Emit a tagged block so the post-compaction context can recognize it.
echo "--- PRE-COMPACT: workspace state snapshot ---"
echo "(Source of truth: .agent/handoffs/CURRENT.md, captured before context compaction)"
echo
cat "$current"
echo
echo "--- END PRE-COMPACT ---"

exit 0
