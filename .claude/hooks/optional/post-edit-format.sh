#!/usr/bin/env bash
# OPTIONAL HOOK: auto-format files after Edit/Write/MultiEdit.
#
# To enable:
#   cp .claude/hooks/optional/post-edit-format.sh .claude/hooks/
#   (then register in .claude/settings.json hooks.PostToolUse[*].hooks[]
#    with matcher "Edit|Write|MultiEdit")
#
# Default behavior: format .py files via `ruff format` (if installed).
# Extend the case statements below for other languages.
#
# This is the first PRODUCTIVE hook (vs the defensive PreToolUse
# gates). It mutates the file after the tool call to keep style
# consistent. Always exits 0 — productivity should never block.
set -uo pipefail

# Silent skip if jq missing — this is a productive hook, not a gate;
# degrading gracefully is correct here.
command -v jq >/dev/null 2>&1 || exit 0

input=$(cat)
tool_name=$(jq -r '.tool_name // ""' <<<"$input")
case "$tool_name" in
    Edit|Write|MultiEdit) ;;
    *) exit 0 ;;
esac

file_path=$(jq -r '.tool_input.file_path // ""' <<<"$input")
[ -n "$file_path" ] && [ -f "$file_path" ] || exit 0

# Skip ephemera (tmp / scratch / handoff state). Extend this list
# for your environment.
case "$file_path" in
    /tmp/*|/var/tmp/*) exit 0 ;;
    */.agent/scratch/*) exit 0 ;;
    */.agent/handoffs/state/*) exit 0 ;;
esac

# Find a formatter. Workspace customization point: add your env's
# preferred formatter paths here.
find_bin() {
    local name="$1"
    for cand in "$@"; do
        if [ -n "$cand" ] && [ -x "$cand" ]; then
            echo "$cand"
            return 0
        fi
    done
    command -v "$name" 2>/dev/null
}

# Portable sha256 for "did anything change" check.
file_hash() {
    sha256sum "$1" 2>/dev/null | awk '{print $1}' \
        || shasum -a 256 "$1" 2>/dev/null | awk '{print $1}' \
        || echo "?"
}

format_with() {
    local bin="$1" file="$2"
    local before after
    before=$(file_hash "$file")
    "$bin" format --quiet "$file" >/dev/null 2>&1 || return 1
    after=$(file_hash "$file")
    if [ "$before" != "$after" ] && [ "$before" != "?" ]; then
        echo "[auto-format] $(basename "$bin") format -> $file" >&2
    fi
}

case "$file_path" in
    *.py)
        # === Customize the search path for your environment ===
        ruff_bin=$(find_bin ruff \
            "$HOME/.local/bin/ruff" \
            /usr/local/bin/ruff)
        # ======================================================
        [ -n "$ruff_bin" ] && format_with "$ruff_bin" "$file_path"
        ;;
    *.js|*.jsx|*.ts|*.tsx|*.json|*.md|*.yaml|*.yml)
        # Prettier is optional — only formats if installed.
        prettier_bin=$(find_bin prettier "$HOME/.local/bin/prettier")
        if [ -n "$prettier_bin" ]; then
            before=$(file_hash "$file_path")
            "$prettier_bin" --write "$file_path" >/dev/null 2>&1 || exit 0
            after=$(file_hash "$file_path")
            if [ "$before" != "$after" ]; then
                echo "[auto-format] prettier -> $file_path" >&2
            fi
        fi
        ;;
    *.sh|*.bash)
        shfmt_bin=$(find_bin shfmt "$HOME/go/bin/shfmt")
        if [ -n "$shfmt_bin" ]; then
            before=$(file_hash "$file_path")
            "$shfmt_bin" -w "$file_path" >/dev/null 2>&1 || exit 0
            after=$(file_hash "$file_path")
            if [ "$before" != "$after" ]; then
                echo "[auto-format] shfmt -> $file_path" >&2
            fi
        fi
        ;;
esac

exit 0
