#!/usr/bin/env bash
# Warn about stale workspace state at session start. Always exits 0
# (non-blocking, informational only). Stderr is shown to Claude.
set -uo pipefail

# Resolve workspace root from script location (portable).
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Portable mtime in seconds-since-epoch: try GNU stat, then BSD stat,
# then Python as the universal fallback. Returns empty on total failure.
file_mtime() {
    stat -c %Y "$1" 2>/dev/null \
        || stat -f %m "$1" 2>/dev/null \
        || python3 -c "import os,sys; print(int(os.path.getmtime(sys.argv[1])))" "$1" 2>/dev/null \
        || echo ""
}

now=$(date +%s)
warnings=()

current="$ROOT/.agent/handoffs/CURRENT.md"
if [ -f "$current" ]; then
    m=$(file_mtime "$current")
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

# Detect auto-memory project_* regression (claude-code only).
# Auto-memory path is derived from the workspace name; we check the
# most common patterns.
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

exit 0
