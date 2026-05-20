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
CURRENT="$ROOT/.agent/handoffs/CURRENT.md"

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

for f in "$ROOT"/.agent/status/*.md; do
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

# ---------- Job 2: bootstrap context injection (stdout JSON) ----------
[ -f "$CURRENT" ] || exit 0   # nothing to inject if no CURRENT.md

# Parse minimal yaml frontmatter (awk; no PyYAML dependency).
fm_get() {
    awk -v key="$1" '
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
    ' "$CURRENT"
}

owner=$(fm_get owner_agent)
slice=$(fm_get active_slice)
version=$(fm_get version)
last_updated=$(fm_get last_updated)

remaining_block=$(awk '
    /^---$/ { in_fm = !in_fm; next }
    in_fm && /^remaining_actions:/ { in_list = 1; next }
    in_fm && in_list {
        if (/^[A-Za-z_][A-Za-z0-9_-]*:/) { in_list = 0; next }
        if (/^[[:space:]]*-[[:space:]]/) print
    }
' "$CURRENT")

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
[workspace bootstrap] claude-codex-coordination conventions are active. Do NOT rely on chat history; .agent/handoffs/CURRENT.md is the source of truth.

Active state (from CURRENT.md frontmatter):
  owner_agent: ${owner:-?}
  active_slice: ${slice:-?}
  version: ${version:-?}
  last_updated: ${last_updated:-?}
  remaining_actions:
${remaining_block:-  (none recorded)}

Session-start ritual (every session, in order):
  1. Re-read .agent/handoffs/CURRENT.md (yaml frontmatter + markdown body).
  2. Identify active_slice; read .agent/status/<slice>.md, or run the project's status helper if static is stale.
  3. Drill down to .agent/projects/<slice>-harness.md only if needed.
  If owner_agent ≠ you, follow .agent/handoffs/takeover-prompt.md steps 4-7.

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
