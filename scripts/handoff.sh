#!/usr/bin/env bash
# Generate a handoff snapshot so the next agent (Claude / Codex / Cursor /
# human) can take over without trusting chat history.
#
# Usage: ./scripts/handoff.sh <next-agent>
#   next-agent: free-form label, e.g. claude, codex, cursor, human
#
# Writes under .agent/handoffs/state/:
#   git-status.txt   (`git status --short` if workspace is a git repo)
#   git-log.txt      (last 10 commits, oneline)
#   diff.patch       (`git diff` working tree vs HEAD)
#   diff-staged.patch (`git diff --cached`)
#   session-note.md  (free-form notes; created empty if missing)
#   meta.txt         (timestamps, host, agent label)
#
# Does NOT auto-edit CURRENT.md. The outgoing agent must update that
# by hand (or via the /handoff skill).

set -euo pipefail

if [ "$#" -lt 1 ]; then
  echo "usage: $0 <next-agent>" >&2
  exit 2
fi

NEXT_AGENT="$1"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HANDOFF_DIR="$ROOT/.agent/handoffs"
STATE_DIR="$HANDOFF_DIR/state"
CURRENT="$HANDOFF_DIR/CURRENT.md"

mkdir -p "$STATE_DIR"

stamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "[handoff] next-agent=$NEXT_AGENT at $stamp"

if [ ! -f "$CURRENT" ]; then
  echo "[handoff] error: $CURRENT missing. Create it from the template first." >&2
  exit 1
fi

is_git=0
if git -C "$ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  is_git=1
fi

if [ "$is_git" -eq 1 ]; then
  git -C "$ROOT" status --short                  > "$STATE_DIR/git-status.txt"
  git -C "$ROOT" --no-pager log -n 10 --oneline  > "$STATE_DIR/git-log.txt"
  git -C "$ROOT" --no-pager diff           > "$STATE_DIR/diff.patch"        || true
  git -C "$ROOT" --no-pager diff --cached  > "$STATE_DIR/diff-staged.patch" || true
else
  : > "$STATE_DIR/git-status.txt"
  echo "(workspace is not a git repo: $ROOT)" > "$STATE_DIR/git-log.txt"
  : > "$STATE_DIR/diff.patch"
  : > "$STATE_DIR/diff-staged.patch"
fi

if [ ! -f "$STATE_DIR/session-note.md" ]; then
  cat > "$STATE_DIR/session-note.md" <<'NOTE'
# Session note

Free-form notes from the outgoing agent. Anything that does not fit
in CURRENT.md but the next agent should know. Delete this file after
the handoff is consumed.
NOTE
fi

cat > "$STATE_DIR/meta.txt" <<META
generated_at: $stamp
next_agent:   $NEXT_AGENT
root:         $ROOT
host:         $(hostname)
user:         $(id -un)
is_git:       $is_git
META

# Stale-CURRENT warning: complain if any <...> placeholders remain.
if grep -nE '<[^>]+>' "$CURRENT" >/dev/null; then
  echo "[handoff] warning: CURRENT.md still contains <placeholder> fields:" >&2
  grep -nE '<[^>]+>' "$CURRENT" | sed 's/^/  /' >&2
  echo "[handoff] fill them in before ending the session." >&2
fi

echo "[handoff] wrote:"
ls -1 "$STATE_DIR"

echo "[handoff] next steps for the incoming agent:"
echo "  1. read .agent/handoffs/CURRENT.md (frontmatter + body)"
echo "  2. read .agent/handoffs/takeover-prompt.md if owner_agent != you"
echo "  3. cross-check state/diff.patch and state/git-status.txt"
echo "[handoff] done"
