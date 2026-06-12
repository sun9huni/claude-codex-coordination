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

# Fail-closed if jq is missing — without it we cannot reliably parse
# the hook input JSON, so the hook would silently let everything pass.
if ! command -v jq >/dev/null 2>&1; then
    {
        echo "BLOCKED: jq is required by this hook but is not on PATH."
        echo "Install jq or remove this hook from .claude/settings.json."
    } >&2
    exit 2
fi

input=$(cat)
[ "$(jq -r '.tool_name // ""' <<< "$input")" = "Bash" ] || exit 0
cmd=$(jq -r '.tool_input.command // ""' <<< "$input")

# Strip heredoc and here-string BODIES — they are data, not commands —
# while keeping any commands that follow them. (A naive ${cmd%%<<*}
# would also throw away real commands after the first <<, so a heredoc
# prefix could smuggle `rm -rf /data` past the gate.) Fail closed: if
# python3 is missing or errors, scan the raw command instead.
cmd_check=$(python3 -c 'import re,sys; s=sys.stdin.read(); s=re.sub(r"<<-?[ \t]*\\?([\"\x27]?)(\w+)\1([^\n]*\n).*?\n\2", r" \3", s, flags=re.S); s=re.sub(r"<<<\s*(\"[^\"]*\"|\x27[^\x27]*\x27|[^\s;&|]+)", " ", s); print(s)' <<< "$cmd" 2>/dev/null) || cmd_check="$cmd"
[ -n "$cmd_check" ] || cmd_check="$cmd"

# Strip quote characters so quoted flags (rm "-rf") cannot dodge the
# flag matching below. Done AFTER heredoc stripping so the quoted
# delimiter form <<'EOF' is still recognized above.
cmd_check=${cmd_check//\"/}
cmd_check=${cmd_check//\'/}

# Anchor: token at start of a sub-command, with optional sudo prefix
# and/or leading VAR=value environment assignments.
ANCHOR='(^|[[:space:]]*\;|\&\&|\|\||\|[[:space:]]|'$'\n'')[[:space:]]*((sudo[[:space:]]+)?([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+)*)'

# git global options that take an argument and may precede the
# subcommand: -C <path> (run in another dir) and -c <key>=<val>
# (one-shot config). Without this, `git -C /repo push --force` would
# slip past every git pattern below.
GOPT='(-[cC][[:space:]]+[^[:space:]]+[[:space:]]+)*'

# One or more flag tokens between `rm` and its first path argument,
# covering combined (-rf) and split (-r -f) forms alike.
RM_FLAGS='((-[a-zA-Z]+[[:space:]]+)+)'

# Confirm both a recursive and a force flag appear in a matched rm
# region. Takes the region by value: every [[ =~ ]] clobbers
# BASH_REMATCH, so the caller cannot re-test the capture in a chain.
rm_rf_in_region() {
    local region="$1"
    [[ "$region" =~ (^|[[:space:]])-[a-zA-Z]*[rR] ]] || return 1
    [[ "$region" =~ (^|[[:space:]])-[a-zA-Z]*[fF] ]] || return 1
    return 0
}

reason=""

if [[ "$cmd_check" =~ ${ANCHOR}rm[[:space:]]+${RM_FLAGS}${SHARED_PATHS_REGEX} ]] \
    && rm_rf_in_region "${BASH_REMATCH[0]}"; then
    reason="rm -rf on shared storage"
elif [[ "$cmd_check" =~ ${ANCHOR}rm[[:space:]]+${RM_FLAGS}([^[:space:]]*/)?\.(agent|claude|codex|git)([[:space:]]|/|$) ]] \
    && rm_rf_in_region "${BASH_REMATCH[0]}"; then
    reason="rm -rf on a harness/config directory (.agent, .claude, .codex, .git)"
elif [[ "$cmd_check" =~ ${ANCHOR}git[[:space:]]+${GOPT}push[[:space:]] ]] && \
     [[ "$cmd_check" =~ ${ANCHOR}git[[:space:]]+${GOPT}push[[:space:]].*(--force([[:space:]]|=|$)|[[:space:]]-f([[:space:]]|$)) ]]; then
    reason="git push --force"
elif [[ "$cmd_check" =~ ${ANCHOR}git[[:space:]]+${GOPT}reset[[:space:]]+--hard[[:space:]]+(origin|upstream)/ ]]; then
    reason="git reset --hard against a remote ref"
elif [[ "$cmd_check" =~ ${ANCHOR}git[[:space:]]+${GOPT}branch[[:space:]]+-D([[:space:]]|$) ]]; then
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
