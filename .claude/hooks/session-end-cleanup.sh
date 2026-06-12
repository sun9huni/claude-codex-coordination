#!/usr/bin/env bash
# SessionEnd hook: remove this session's start marker.
#
# The SessionStart hook (Job 1c) writes
# $AGENT_DIR/handoffs/state/session-markers/<session_id>.start so the Stop
# hook can detect "session ended without running handoff.sh". Stop fires
# once per STOP — often several times in one session — so the marker must
# survive every stop and be deleted only when the session truly ends:
# SessionEnd is the single correct deletion point. Markers leaked by
# crashed/killed sessions (where SessionEnd never fires) are swept by the
# >7d prune in session-start-decay-check.sh Job 1c.
#
# Silent on empty/non-JSON stdin (manual hook invocation, tests). Always
# exits 0.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# AGENT_ROOT seam: tests point this at a throwaway fixture .agent; unset = the
# repo's own .agent (resolved from BASH_SOURCE, as in the other hooks).
AGENT_DIR="${AGENT_ROOT:-$ROOT/.agent}"

# Read `session_id` from Claude Code's stdin JSON. select with a tiny timeout
# so we never block waiting for EOF on a connected-but-empty stdin (see
# session-start-decay-check.sh Job 1c).
session_id=""
if [ ! -t 0 ]; then
    session_id=$(python3 -c 'import json, select, sys
if select.select([sys.stdin], [], [], 0.05)[0]:
    try:
        d = json.load(sys.stdin)
        print(d.get("session_id", ""))
    except Exception:
        pass' 2>/dev/null || echo "")
fi

if [ -n "$session_id" ]; then
    rm -f "$AGENT_DIR/handoffs/state/session-markers/$session_id.start" 2>/dev/null || true
fi

exit 0
