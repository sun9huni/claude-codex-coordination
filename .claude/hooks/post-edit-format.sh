#!/usr/bin/env bash
# PostToolUse hook: auto-format Python files after Edit/Write/MultiEdit.
#
# Runs `ruff format` on the touched file. ruff auto-detects nearby
# pyproject.toml so per-project style settings are honored. If ruff
# is not installed in any known path the hook silently skips —
# productive hooks should NOT block successful tool calls.
#
# Stderr is shown to Claude so it knows the file was reformatted
# (useful before the next Read).
set -uo pipefail

# Silent skip if jq missing — this is a productive hook, not a security
# gate; degrading gracefully is correct here.
command -v jq >/dev/null 2>&1 || exit 0

input=$(cat)
tool_name=$(jq -r '.tool_name // ""' <<<"$input")

# Only react to file-mutating tools.
case "$tool_name" in
    Edit|Write|MultiEdit) ;;
    *) exit 0 ;;
esac

file_path=$(jq -r '.tool_input.file_path // ""' <<<"$input")
[ -n "$file_path" ] && [ -f "$file_path" ] || exit 0

# Only Python (extend here as you add formatters).
case "$file_path" in
    *.py) ;;
    *) exit 0 ;;
esac

# Skip ephemera (tmp / scratch / handoff state).
case "$file_path" in
    /tmp/*|/var/tmp/*) exit 0 ;;
    */.agent/scratch/*) exit 0 ;;
    */.agent/handoffs/state/*) exit 0 ;;
esac

# Find ruff (prefer workspace conda env, then any conda env, then PATH).
ruff_bin=""
for cand in \
    /home/ubuntu/miniconda3/envs/arl-py313/bin/ruff \
    /home/ubuntu/miniconda3/envs/BindCraft/bin/ruff \
    /home/ubuntu/miniconda3/bin/ruff \
    "$(command -v ruff 2>/dev/null || true)"; do
    if [ -n "$cand" ] && [ -x "$cand" ]; then
        ruff_bin="$cand"
        break
    fi
done

[ -z "$ruff_bin" ] && exit 0

# Format. Compare hash before/after to know if anything changed.
# Portable sha256: GNU coreutils sha256sum first, BSD shasum -a 256 fallback.
file_hash() {
    sha256sum "$1" 2>/dev/null | awk '{print $1}' \
        || shasum -a 256 "$1" 2>/dev/null | awk '{print $1}' \
        || echo "?"
}

before=$(file_hash "$file_path")
"$ruff_bin" format --quiet "$file_path" >/dev/null 2>&1 || exit 0
after=$(file_hash "$file_path")

if [ "$before" != "$after" ] && [ "$before" != "?" ]; then
    echo "[auto-format] ruff format -> $file_path" >&2
fi

exit 0
