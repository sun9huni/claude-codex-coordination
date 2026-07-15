#!/usr/bin/env bash
# SessionStart hook: two jobs.
#
# Job 1 — stderr WARNINGS (non-blocking):
#   stale CURRENT.md (>24h), stale .agent/status/<slice>.md (>7d),
#   and project_* memory regression detection.
#
# Job 2 — stdout JSON: emit hookSpecificOutput.additionalContext so
#   workspace bootstrap (current state + ritual + skills inventory +
#   approval gates) is injected directly into the session, eliminating
#   reliance on CLAUDE.md being re-read every session.
#
# Always exits 0 — informational + bootstrap, never blocking.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# AGENT_ROOT seam: all .agent reads go under $AGENT_DIR. Default (unset) =
# the repo's own .agent, matching handoff.sh / status.sh.
AGENT_DIR="${AGENT_ROOT:-$ROOT/.agent}"
CURRENT="$AGENT_DIR/handoffs/CURRENT.md"

# ---------- FRESHNESS (root-cause fix) ----------
# The derived index (CURRENT.md) only refreshes when someone runs
# `status.sh index`. Sessions that edited batons but skipped that left the
# index — and the Notion view derived from it — frozen (e.g. a slice showed a
# job RUNNING days after it COMPLETED). So regenerate the index from the slice
# files FIRST (the bootstrap + staleness checks below then reflect the latest
# batons), and surface baton<->reality drift to stderr. Pure/read-only,
# best-effort, never blocks. Skip the mutation under a test seam (AGENT_ROOT set).
if [ -z "${AGENT_ROOT:-}" ]; then
    if [ -f "$ROOT/scripts/status.sh" ]; then
        bash "$ROOT/scripts/status.sh" index >/dev/null 2>&1 || true
    fi
    if [ -x "$ROOT/scripts/baton-drift.sh" ]; then
        _drift="$(bash "$ROOT/scripts/baton-drift.sh" 2>/dev/null || true)"
        if [ -n "$_drift" ]; then
            echo "[session-start] ⚠️ baton drift — update the baton before trusting it (a job may have finished / heartbeat is stale):" >&2
            printf '%s\n' "$_drift" | sed 's/^/  /' >&2
        fi
    fi
fi

# ---------- Portable mtime (GNU → BSD → Python) ----------
file_mtime() {
    stat -c %Y "$1" 2>/dev/null \
        || stat -f %m "$1" 2>/dev/null \
        || python3 -c "import os,sys; print(int(os.path.getmtime(sys.argv[1])))" "$1" 2>/dev/null \
        || echo ""
}

# ---------- Job 1: decay warnings (stderr) ----------
now=$(date +%s)
warnings=()

if [ -f "$CURRENT" ]; then
    m=$(file_mtime "$CURRENT")
    if [ -n "$m" ]; then
        age_h=$(( (now - m) / 3600 ))
        if [ "$age_h" -gt 24 ]; then
            warnings+=("CURRENT.md is ${age_h}h old (>24h). Recheck handoff state before acting.")
        fi
    fi
fi

for f in "$AGENT_DIR"/status/*.md; do
    [ -f "$f" ] || continue
    name=$(basename "$f")
    [ "$name" = "README.md" ] && continue
    m=$(file_mtime "$f")
    if [ -n "$m" ]; then
        age_d=$(( (now - m) / 86400 ))
        if [ "$age_d" -gt 7 ]; then
            warnings+=("${name} is ${age_d}d old. Consider refreshing it.")
        fi
    fi
done

memory_root="$HOME/.claude/projects"
if [ -d "$memory_root" ]; then
    leak=$(find "$memory_root" -maxdepth 3 -name 'project_*.md' 2>/dev/null | head -1 || true)
    if [ -n "$leak" ]; then
        warnings+=("Memory leak: $(basename "$leak") in auto-memory. Project state belongs in .agent/, not auto-memory.")
    fi
fi

if [ ${#warnings[@]} -gt 0 ]; then
    printf '[decay-check] %s\n' "${warnings[@]}" >&2
fi

# ---------- Job 1b: live-claim check (stderr) ----------
# When entering a named slice, warn if that slice's per-slice status carries a
# FRESH heartbeat (<=30 min) under a DIFFERENT owner_session than this session.
# Stale heartbeat or same/empty owner => silent (takeover is allowed).
# When ENTERING_SLICE is unset/empty (the normal live session-start case) this
# does NOTHING — the live harness invokes the hook with no ENTERING_SLICE.
claim_fm_get() {
    awk -v key="$2" '
        /^---$/ { in_fm = !in_fm; next }
        in_fm {
            if (match($0, "^" key ":[[:space:]]*")) {
                v = substr($0, RLENGTH + 1)
                gsub(/^[[:space:]]*"|"[[:space:]]*$/, "", v)
                gsub(/^[[:space:]]+|[[:space:]]+$/, "", v)
                print v; exit
            }
        }
    ' "$1"
}

# Parse an ISO-8601 UTC timestamp to epoch seconds (GNU date -> python3).
iso_to_epoch() {
    date -u -d "$1" +%s 2>/dev/null \
        || python3 -c "import datetime,sys; print(int(datetime.datetime.strptime(sys.argv[1],'%Y-%m-%dT%H:%M:%SZ').replace(tzinfo=datetime.timezone.utc).timestamp()))" "$1" 2>/dev/null \
        || echo ""
}

if [ -n "${ENTERING_SLICE:-}" ]; then
    claim_file="$AGENT_DIR/status/${ENTERING_SLICE}.md"
    if [ -f "$claim_file" ]; then
        claim_owner=$(claim_fm_get "$claim_file" owner_session)
        claim_hb=$(claim_fm_get "$claim_file" heartbeat)
        cur_sess="${OWNER_SESSION:-}"
        if [ -n "$claim_owner" ] && [ -n "$claim_hb" ] && [ "$claim_owner" != "$cur_sess" ]; then
            hb_epoch=$(iso_to_epoch "$claim_hb")
            if [ -n "$hb_epoch" ]; then
                age_s=$(( now - hb_epoch ))
                if [ "$age_s" -lt 0 ]; then age_s=0; fi
                if [ "$age_s" -le 1800 ]; then
                    age_m=$(( age_s / 60 ))
                    printf "[claim-check] live claim: slice '%s' is claimed by owner_session %s (heartbeat %dm ago). Coordinate or pick another slice.\n" \
                        "$ENTERING_SLICE" "$claim_owner" "$age_m" >&2
                fi
            fi
        fi
    fi
fi

# ---------- Job 1c: per-session marker (for Stop hook missed-handoff check) ----------
# Reads `session_id` from Claude Code's stdin JSON; writes the session start
# epoch under $AGENT_DIR/handoffs/state/session-markers/<session_id>.start.
# The Stop hook uses this marker to detect "session ended without running
# handoff.sh". Silent on empty/non-JSON stdin (manual hook invocation, tests).
# Lifecycle: the SessionEnd hook (session-end-cleanup.sh) removes the marker
# when the session truly ends; the prune below sweeps markers leaked by
# crashed/killed sessions where SessionEnd never fired.
session_id=""
if [ ! -t 0 ]; then
    # stdin is connected to a pipe/file — try to read JSON. Use select with
    # a tiny timeout so the hook never blocks waiting for EOF on a connected-
    # but-empty stdin (e.g. when invoked from a parent shell that inherits
    # its own non-terminal stdin without piping anything in — common in
    # `bash test.sh` invocations and CI runners).
    session_id=$(python3 -c 'import json, select, sys
if select.select([sys.stdin], [], [], 0.05)[0]:
    try:
        d = json.load(sys.stdin)
        print(d.get("session_id", ""))
    except Exception:
        pass' 2>/dev/null || echo "")
fi
markers_dir="$AGENT_DIR/handoffs/state/session-markers"
if [ -n "$session_id" ]; then
    mkdir -p "$markers_dir" 2>/dev/null || true
    printf '%s\n' "$(date +%s)" > "$markers_dir/$session_id.start" 2>/dev/null || true
fi
# Prune markers older than 7 days (BSD and GNU find both support
# -mtime/-delete). Best-effort, never fatal.
if [ -d "$markers_dir" ]; then
    find "$markers_dir" -name '*.start' -type f -mtime +7 -delete 2>/dev/null || true
fi

# ---------- Job 2: bootstrap context injection (stdout JSON) ----------
[ -f "$CURRENT" ] || exit 0   # nothing to inject if no CURRENT.md

# Parse one minimal yaml frontmatter scalar from a status file (awk, no
# PyYAML dependency). $1 = file, $2 = key.
fm_get() {
    awk -v key="$2" '
        /^---$/ { in_fm = !in_fm; next }
        in_fm {
            if (match($0, "^" key ":[[:space:]]*")) {
                v = substr($0, RLENGTH + 1)
                gsub(/^[[:space:]]*"|"[[:space:]]*$/, "", v)
                gsub(/^[[:space:]]+|[[:space:]]+$/, "", v)
                print v
                exit
            }
        }
    ' "$1"
}

# First remaining_actions item from a status file (or empty).
first_action() {
    awk '
        /^---$/ { in_fm = !in_fm; next }
        in_fm && /^remaining_actions:/ { in_list = 1; next }
        in_fm && in_list {
            if (/^[A-Za-z_][A-Za-z0-9_-]*:/) { exit }
            if (/^[[:space:]]*-[[:space:]]/) {
                v = $0
                sub(/^[[:space:]]*-[[:space:]]*/, "", v)
                print v; exit
            }
        }
    ' "$1"
}

# Active state is sourced from the PER-SLICE status frontmatter (the
# authority), NOT from CURRENT.md scalars — robust to both old-format and
# index-format CURRENT.md. List every slice with a non-empty owner_session
# as "slice / owner / last_updated / first remaining_action". If none are
# claimed, list the slices and note that none is currently claimed.
active_block=""
all_slices=""
for sf in "$AGENT_DIR"/status/*.md; do
    [ -f "$sf" ] || continue
    sname=$(basename "$sf" .md)
    [ "$sname" = "README" ] && continue
    all_slices="${all_slices:+$all_slices, }$sname"
    s_owner=$(fm_get "$sf" owner_session)
    [ -n "$s_owner" ] || continue
    s_label=$(fm_get "$sf" owner_label)
    s_updated=$(fm_get "$sf" last_updated)
    s_action=$(first_action "$sf")
    active_block="${active_block}  ${sname} / ${s_label:-$s_owner} / ${s_updated:-?} / ${s_action:-(no remaining_actions)}
"
done
if [ -n "$active_block" ]; then
    active_state="Active state (per-slice status frontmatter — owned/in-flight slices):
${active_block%$'\n'}"
else
    active_state="Active state (per-slice status frontmatter): no slice currently owned.
  Known slices: ${all_slices:-(none)}"
fi

# notion-sync-pending: a prior handoff dropped a marker but did not refresh
# Notion (MCP-only). Surface it so THIS (MCP-capable) session auto-applies it.
pending_block=""
ns_marker="$AGENT_DIR/handoffs/state/notion-sync-pending"
if [ -s "$ns_marker" ]; then
    ns_slices=$(awk '{print $1}' "$ns_marker" 2>/dev/null | sort -u | paste -sd' ' - 2>/dev/null || true)
    pending_block=$(cat <<PB

⚠️ NOTION SYNC PENDING: ${ns_slices}
  A prior handoff updated these slices' batons but did NOT refresh Notion (the
  write path is MCP-only). As part of THIS session start, apply the sync now:
    1. ./scripts/notion_sync.py --emit-apply-plan <slice>   (resolves HOME+ROW page_ids + preflight, one block)
    2. apply HOME via MCP replace_content + the ROW via update_properties (page_ids are in the plan)
    3. ./scripts/notion_sync.py --stamp-home-applied   (clears the marker)
PB
)
fi

# notion-project-pending: a slice handoff also flags its project hub for re-render.
np_marker="$AGENT_DIR/handoffs/state/notion-project-pending"
if [ -s "$np_marker" ]; then
    np_projects=$(awk '{print $1}' "$np_marker" 2>/dev/null | sort -u | paste -sd' ' - 2>/dev/null || true)
    pending_block=$(cat <<PB
${pending_block}

⚠️ NOTION PROJECT HUB PENDING: ${np_projects}
  A handoff changed a slice in these project hubs; re-render each (slice statuses
  are pulled live from batons at render time):
    1. ./scripts/notion_sync.py --emit-project-plan <project>
    2. apply via MCP replace_content (page_id is in the plan)
    3. ./scripts/notion_sync.py --stamp-project-applied <project>   (clears the marker)
PB
)
fi

# Build the bootstrap payload.
bootstrap=$(cat <<EOF
[workspace bootstrap] /home/ubuntu conventions are active. Do NOT rely on chat history; per-slice .agent/status/<slice>.md files are authoritative (CURRENT.md is their derived index).
${pending_block}

${active_state}

Session-start ritual (every session, in order):
  1. Read the .agent/handoffs/CURRENT.md index (which session owns which slice).
  2. Identify your slice; read its .agent/status/<slice>.md frontmatter (owner_session/heartbeat/remaining_actions), or run ./scripts/status.sh <slice> if stale.
  3. Drill down to .agent/projects/<slice>-harness.md only if needed.
  If the slice is owned by another live session (fresh heartbeat, different owner_session), follow .agent/handoffs/takeover-prompt.md steps 4-7.

Available slash skills (all native):
  Process:    /handoff   /slice-status   /contract-check   /route
  Expertise:  /code-review   /refactor-simplify   /test-gen   /debug

Subagents (Agent tool):
  slurm-status (haiku, read-only HPC inspector)
  fragmap-diagnose (opus, zero-compute diagnostician)
  mmgbsa-stage-check (opus, stage gate)

Auto-blocked Bash commands (PreToolUse hooks):
  sbatch (without active contract under .agent/contracts/, last 7 days)
  psql ... DROP TABLE / TRUNCATE / ALTER TABLE
  rm -rf on /mnt/data*, .agent, .claude, .codex, .git
  git push --force / -f / git reset --hard origin/.../upstream/... / git branch -D

Productive hook: Edit/Write on *.py → ruff format auto-runs (skip lists: /tmp, .agent/scratch, .agent/handoffs/state).

Memory policy:
  auto-memory (~/.claude/projects/<workspace>/memory) = user_profile + feedback_* + reference_* only.
  Project state lives in .agent/, NEVER duplicated to auto-memory.

When in doubt: /route "<one-liner about your work>" to find the right slice + harness.
EOF
)

# Emit JSON via python3 (avoids quoting hell).
python3 - "$bootstrap" <<'PY' 2>/dev/null || true
import json, sys
ctx = sys.argv[1]
print(json.dumps({
    "hookSpecificOutput": {
        "hookEventName": "SessionStart",
        "additionalContext": ctx
    }
}))
PY

exit 0
