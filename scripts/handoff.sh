#!/usr/bin/env bash
# Generate a handoff snapshot so the next agent (Claude / Codex / Cursor /
# human) can take over without trusting chat history.
#
# Usage: ./scripts/handoff.sh <next-agent>
#   next-agent: free-form label, e.g. claude, codex, cursor, human
#
# Concurrency model:
#   - Acquires an exclusive flock on .agent/handoffs/OWNER.lock for the
#     duration of the run so two handoffs cannot interleave snapshots.
#   - Increments .agent/handoffs/CURRENT.md frontmatter `version` (used
#     by Stop hook to detect "agent forgot to update CURRENT.md").
#   - Writes a fresh snapshot under .agent/handoffs/state/sessions/
#     <YYYY-MM-DD-HHMMSS-UTC>-<agent>/ and re-points the symlink
#     .agent/handoffs/state/latest at it.
#   - CURRENT.md edits use a .tmp + atomic rename (mv -f) helper at
#     scripts/_atomic_write_current.sh — agents should call that, or
#     just use the Edit tool while holding the lock.
#
# Files written under state/sessions/<run>/:
#   git-status.txt      `git status --short` (empty if not a git repo)
#   git-log.txt         last 10 commits, oneline
#   diff.patch          working tree vs HEAD
#   diff-staged.patch   staged diff
#   meta.txt            timestamp, agent, version, host, root
#
# Does NOT auto-edit CURRENT.md beyond bumping the `version` field.
# The outgoing agent fills in the rest by hand (or via /handoff).

set -euo pipefail

if [ "$#" -lt 1 ]; then
  echo "usage: $0 <next-agent>" >&2
  exit 2
fi

NEXT_AGENT="$1"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HANDOFF_DIR="$ROOT/.agent/handoffs"
STATE_DIR="$HANDOFF_DIR/state"
SESSIONS_DIR="$STATE_DIR/sessions"
LOCK="$HANDOFF_DIR/OWNER.lock"
CURRENT="$HANDOFF_DIR/CURRENT.md"

mkdir -p "$SESSIONS_DIR"

if [ ! -f "$CURRENT" ]; then
  echo "[handoff] error: $CURRENT missing. Create it from the template first." >&2
  exit 1
fi

# Acquire the lock for the duration of the snapshot + version bump.
# fd 200 holds it; trap releases on exit.
exec 200>>"$LOCK"
if ! flock -w 30 -x 200; then
  echo "[handoff] error: could not acquire OWNER.lock within 30s — another handoff is running." >&2
  exit 1
fi

stamp_iso="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
stamp_dir="$(date -u +%Y-%m-%d-%H%M%S)"
run_dir="$SESSIONS_DIR/${stamp_dir}-${NEXT_AGENT}"
mkdir -p "$run_dir"
echo "[handoff] next-agent=$NEXT_AGENT at $stamp_iso  →  $(realpath --relative-to="$ROOT" "$run_dir")"

# === Bump version in CURRENT.md frontmatter ===
# Read current version (default 0 if absent).
current_version="$(awk '
  /^---$/ { in_fm=!in_fm; next }
  in_fm && /^version:/ { print $2; exit }
' "$CURRENT")"
current_version=${current_version:-0}
new_version=$((current_version + 1))

# Atomic frontmatter version bump: write to .tmp then mv -f.
tmp="$CURRENT.tmp.$$"
if grep -qE '^version:' "$CURRENT"; then
  awk -v v="$new_version" '
    /^---$/ { fm_count++ }
    fm_count==1 && /^version:/ { print "version: " v; next }
    { print }
  ' "$CURRENT" > "$tmp"
else
  # Insert version: line just before the closing --- of the first frontmatter block.
  awk -v v="$new_version" '
    /^---$/ { fm_count++; if (fm_count==2) { print "version: " v } }
    { print }
  ' "$CURRENT" > "$tmp"
fi
mv -f "$tmp" "$CURRENT"

# === Snapshot git state ===
is_git=0
if git -C "$ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  is_git=1
fi

if [ "$is_git" -eq 1 ]; then
  git -C "$ROOT" status --short                  > "$run_dir/git-status.txt"
  git -C "$ROOT" --no-pager log -n 10 --oneline  > "$run_dir/git-log.txt"
  git -C "$ROOT" --no-pager diff           > "$run_dir/diff.patch"        || true
  git -C "$ROOT" --no-pager diff --cached  > "$run_dir/diff-staged.patch" || true
else
  : > "$run_dir/git-status.txt"
  echo "(workspace is not a git repo: $ROOT)" > "$run_dir/git-log.txt"
  : > "$run_dir/diff.patch"
  : > "$run_dir/diff-staged.patch"
fi

if [ ! -f "$run_dir/session-note.md" ]; then
  cat > "$run_dir/session-note.md" <<'NOTE'
# Session note

Free-form notes from the outgoing agent. Anything that does not fit
in CURRENT.md but the next agent should know.
NOTE
fi

cat > "$run_dir/meta.txt" <<META
generated_at:    $stamp_iso
next_agent:      $NEXT_AGENT
current_version: $new_version
prev_version:    $current_version
root:            $ROOT
host:            $(hostname)
user:            $(id -un)
is_git:          $is_git
META

# Re-point latest -> this run.
ln -sfn "sessions/${stamp_dir}-${NEXT_AGENT}" "$STATE_DIR/latest"

# === Snapshot rotation: keep most recent 20 sessions ===
# Older ones can still be examined manually under .agent/handoffs/state/sessions/.
keep=20
total=$(find "$SESSIONS_DIR" -maxdepth 1 -mindepth 1 -type d | wc -l)
if [ "$total" -gt "$keep" ]; then
  find "$SESSIONS_DIR" -maxdepth 1 -mindepth 1 -type d \
    -printf '%T@ %p\n' 2>/dev/null \
    | sort -n \
    | head -n $((total - keep)) \
    | awk '{ $1=""; sub(/^ +/, ""); print }' \
    | while read -r old; do
        # NB: we are inside our own flock; this prune is safe.
        rm -rf "$old"
      done
fi

# === Stale-CURRENT warning: complain if any <...> placeholders remain ===
if grep -nE '<[^>]+>' "$CURRENT" >/dev/null; then
  echo "[handoff] warning: CURRENT.md still contains <placeholder> fields:" >&2
  grep -nE '<[^>]+>' "$CURRENT" | sed 's/^/  /' >&2
  echo "[handoff] fill them in before ending the session." >&2
fi

echo "[handoff] wrote:"
ls -1 "$run_dir"
echo "[handoff] CURRENT.md version bumped: $current_version -> $new_version"
echo "[handoff] latest -> $(readlink "$STATE_DIR/latest")"
echo
echo "[handoff] next steps for the incoming agent:"
echo "  1. read .agent/handoffs/CURRENT.md (frontmatter + body)"
echo "  2. read .agent/handoffs/takeover-prompt.md if owner_agent != you"
echo "  3. cross-check state/latest/diff.patch and state/latest/git-status.txt"
echo "[handoff] done"

# Lock released on EXIT.
