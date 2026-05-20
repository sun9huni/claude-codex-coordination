#!/usr/bin/env bash
# Block clearly destructive Bash commands without explicit user approval.
# Reads PreToolUse JSON from stdin. Exit 2 = block.
#
# Matching policy: each pattern is anchored to look like a real command
# invocation (start-of-string or after ; && || | newline) and heredoc
# bodies are stripped first. This avoids false positives from text in
# commit messages or documentation that happens to contain phrases like
# "git push --force".
#
# Customize the SHARED_PATHS_REGEX below for paths in your environment
# whose deletion would be hard to recover from (network mounts, object
# storage mountpoints, data lakes, etc.).
set -uo pipefail

# === Customize for your environment ===
# Regex matching the start of paths that must not be `rm -rf`'d.
SHARED_PATHS_REGEX='(/mnt/|/shared/|/data/|/srv/)'
# ======================================

input=$(cat)
[ "$(jq -r '.tool_name // ""' <<< "$input")" = "Bash" ] || exit 0
cmd=$(jq -r '.tool_input.command // ""' <<< "$input")

# Strip heredoc body — anything after `<<` is data, not commands.
cmd_check="${cmd%%<<*}"

# Anchor: token at start of a sub-command, optional sudo prefix.
ANCHOR='(^|[[:space:]]*\;|\&\&|\|\||\|[[:space:]]|'$'\n'')[[:space:]]*(sudo[[:space:]]+)?'

reason=""

if [[ "$cmd_check" =~ ${ANCHOR}rm[[:space:]]+(-[rRfFvVi]*[rR][rRfFvVi]*[fF][rRfFvVi]*|-[rRfFvVi]*[fF][rRfFvVi]*[rR][rRfFvVi]*)[[:space:]]+${SHARED_PATHS_REGEX} ]]; then
    reason="rm -rf on shared storage"
elif [[ "$cmd_check" =~ ${ANCHOR}rm[[:space:]]+(-[rRfFvVi]*[rR][rRfFvVi]*[fF][rRfFvVi]*|-[rRfFvVi]*[fF][rRfFvVi]*[rR][rRfFvVi]*)[[:space:]]+/?\.(agent|claude|codex|git)([[:space:]]|/|$) ]]; then
    reason="rm -rf on a harness/config directory (.agent, .claude, .codex, .git)"
elif [[ "$cmd_check" =~ ${ANCHOR}git[[:space:]]+push[[:space:]] ]] && \
     [[ "$cmd_check" =~ ${ANCHOR}git[[:space:]]+push[[:space:]].*(--force([[:space:]]|=|$)|[[:space:]]-f([[:space:]]|$)) ]]; then
    reason="git push --force"
elif [[ "$cmd_check" =~ ${ANCHOR}git[[:space:]]+reset[[:space:]]+--hard[[:space:]]+(origin|upstream)/ ]]; then
    reason="git reset --hard against a remote ref"
elif [[ "$cmd_check" =~ ${ANCHOR}git[[:space:]]+branch[[:space:]]+-D([[:space:]]|$) ]]; then
    reason="git branch -D (force delete)"
fi

if [ -n "$reason" ]; then
    {
        echo "BLOCKED: destructive operation — ${reason}"
        echo "If this is intentional, ask the user for explicit approval first."
        echo "Detected command: $cmd"
    } >&2
    exit 2
fi

exit 0
