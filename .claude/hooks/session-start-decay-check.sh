#!/usr/bin/env bash
# SessionStart hook: two jobs.
#
# Job 1 — stderr WARNINGS (non-blocking):
#   stale CURRENT.md (>24h), stale .agent/status/<slice>.md (>7d),
#   and project_* memory regression detection.
#
# Job 2 — stdout JSON: emit hookSpecificOutput.additionalContext so
#   the workspace bootstrap (current state + ritual + skill / agent /
#   gate inventory + memory policy) is injected directly into the
#   session context, instead of relying on CLAUDE.md being re-read
#   every session.
#
# Always exits 0.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
AGENT_DIR="${AGENT_ROOT:-$ROOT/.agent}"
CURRENT="$AGENT_DIR/handoffs/CURRENT.md"

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

# Detect which skills + optional hooks are actually present so the
# bootstrap reflects this deployment, not the template default.
list_present_skills() {
    local found=()
    for d in "$ROOT"/.claude/skills/*/; do
        [ -d "$d" ] || continue
        name=$(basename "$d")
        [ -f "$d/SKILL.md" ] && found+=("/$name")
    done
    echo "${found[*]}"
}
present_skills=$(list_present_skills)

# Approval-gate inventory: enumerate which PreToolUse Bash gates
# are actually wired (present in .claude/hooks/, not just optional/).
gate_lines=()
[ -f "$ROOT/.claude/hooks/pre-bash-slurm-gate.sh" ] && \
    gate_lines+=("  sbatch (without an active contract in .agent/contracts/)")
[ -f "$ROOT/.claude/hooks/pre-bash-db-gate.sh" ] && \
    gate_lines+=("  psql ... DROP TABLE / TRUNCATE / ALTER TABLE")
[ -f "$ROOT/.claude/hooks/pre-bash-destructive-gate.sh" ] && \
    gate_lines+=("  rm -rf on shared / harness dirs, git push --force, git reset --hard origin/*, git branch -D")

gate_text="(none enabled)"
if [ ${#gate_lines[@]} -gt 0 ]; then
    gate_text=$(printf '%s\n' "${gate_lines[@]}")
fi

# Productive PostToolUse hook (post-edit-format) present?
productive_line=""
if [ -x "$ROOT/.claude/hooks/post-edit-format.sh" ]; then
    productive_line="Productive hook: post-edit-format runs on Edit/Write (formatter detected at hook invocation time)."
fi

# Build bootstrap payload.
bootstrap=$(cat <<EOF
[workspace bootstrap] per-slice .agent/status/<slice>.md files are authoritative; CURRENT.md is their derived index. Do NOT rely on chat history.

${active_state}

Session-start ritual (every session, in order):
  1. Read the .agent/handoffs/CURRENT.md index (which session owns which slice).
  2. Identify your slice; read its .agent/status/<slice>.md frontmatter (owner_session/heartbeat/remaining_actions), or run ./scripts/status.sh <slice> if stale.
  3. Drill down to .agent/projects/<slice>-harness.md only if needed.
  If the slice is owned by another live session (fresh heartbeat, different owner_session), follow .agent/handoffs/takeover-prompt.md steps 4-7.

Available slash skills (detected in this deployment):
  ${present_skills:-(none — populate .claude/skills/)}

Subagents (.claude/agents/): invoke with the Agent tool, subagent_type=<name>.

Auto-blocked Bash commands (PreToolUse hooks present in this deployment):
${gate_text}

${productive_line}

Memory policy:
  auto-memory = user_profile + feedback_* + reference_* only.
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
