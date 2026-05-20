#!/usr/bin/env bash
# Status line: shows current model, active slice, CURRENT.md owner /
# version / age. Receives session info as JSON on stdin.
#
# Registered in .claude/settings.json under `statusLine`.
#
# Customize by editing the format string below.
set -uo pipefail

input=$(cat 2>/dev/null || echo '{}')

# Parse session info (defensive: tolerate missing fields).
model="?"
ctx_pct="?"
cwd="?"
if command -v jq >/dev/null 2>&1; then
    model=$(echo "$input" | jq -r '.model.display_name // .model.id // "?"' 2>/dev/null || echo "?")
    ctx_pct=$(echo "$input" | jq -r '.context_window.used_percentage // 0' 2>/dev/null | cut -d. -f1 || echo "?")
    cwd=$(echo "$input" | jq -r '.cwd // .workspace.current_dir // "?"' 2>/dev/null || echo "?")
fi

# Find CURRENT.md by walking up from cwd until we hit one (or root).
current=""
dir="$cwd"
while [ -n "$dir" ] && [ "$dir" != "/" ]; do
    if [ -f "$dir/.agent/handoffs/CURRENT.md" ]; then
        current="$dir/.agent/handoffs/CURRENT.md"
        break
    fi
    dir=$(dirname "$dir")
done

# Defaults if no CURRENT.md found.
owner="?"
slice="?"
version="?"
age_str="?"

if [ -n "$current" ] && [ -f "$current" ]; then
    owner=$(awk '/^---$/ { in_fm=!in_fm; next } in_fm && /^owner_agent:/ { print $2; exit }' "$current" 2>/dev/null || echo "?")
    slice=$(awk '/^---$/ { in_fm=!in_fm; next } in_fm && /^active_slice:/ { print $2; exit }' "$current" 2>/dev/null || echo "?")
    version=$(awk '/^---$/ { in_fm=!in_fm; next } in_fm && /^version:/ { print $2; exit }' "$current" 2>/dev/null || echo "?")

    # Portable mtime
    mtime=$(
        stat -c %Y "$current" 2>/dev/null \
            || stat -f %m "$current" 2>/dev/null \
            || python3 -c "import os,sys; print(int(os.path.getmtime(sys.argv[1])))" "$current" 2>/dev/null \
            || echo ""
    )
    if [ -n "$mtime" ]; then
        now=$(date +%s)
        age_min=$(( (now - mtime) / 60 ))
        if [ "$age_min" -lt 60 ]; then
            age_str="${age_min}m"
        elif [ "$age_min" -lt 1440 ]; then
            age_str="$((age_min / 60))h"
        else
            age_str="$((age_min / 1440))d"
        fi
    fi
fi

# Single-line output. Customize the format below.
printf '[%s] slice=%s owner=%s v%s age=%s ctx=%s%%' \
    "$model" "$slice" "$owner" "$version" "$age_str" "$ctx_pct"
