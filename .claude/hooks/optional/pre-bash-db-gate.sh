#!/usr/bin/env bash
# OPTIONAL HOOK: block psql DDL (DROP/TRUNCATE/ALTER TABLE).
#
# To enable:
#   cp .claude/hooks/optional/pre-bash-db-gate.sh .claude/hooks/
#   (then register in .claude/settings.json hooks.PreToolUse[*].hooks[])
#
# Matches DDL inside psql invocations that look like real commands
# (anchor at start-of-subcommand). Heredoc bodies are stripped first so
# commit messages and documentation containing these keywords are safe.
#
# For other databases (mysql, mongo, sqlite), copy this script and
# adjust the binary name and DDL regex.
set -uo pipefail

# Fail-closed if jq is missing.
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

# Strip heredoc and here-string BODIES while keeping any commands that
# follow them (a naive ${cmd%%<<*} would discard those too, letting a
# heredoc prefix smuggle DDL past the gate). Fail closed: if python3
# is missing or errors, scan the raw command instead.
cmd_check=$(python3 -c 'import re,sys; s=sys.stdin.read(); s=re.sub(r"<<-?[ \t]*\\?([\"\x27]?)(\w+)\1([^\n]*\n).*?\n\2", r" \3", s, flags=re.S); s=re.sub(r"<<<\s*(\"[^\"]*\"|\x27[^\x27]*\x27|[^\s;&|]+)", " ", s); print(s)' <<< "$cmd" 2>/dev/null) || cmd_check="$cmd"
[ -n "$cmd_check" ] || cmd_check="$cmd"

# === Customize ===
DB_BINARY_REGEX='psql'   # change for mysql/mongo/etc.
DDL_REGEX='(DROP[[:space:]]+(TABLE|DATABASE|SCHEMA|INDEX|VIEW|COLUMN)|TRUNCATE[[:space:]]+(TABLE|ONLY)|ALTER[[:space:]]+TABLE)'
# =================

ANCHOR='(^|[[:space:]]*\;|\&\&|\|\||\|[[:space:]]|'$'\n'')[[:space:]]*(sudo[[:space:]]+)?'

if [[ "$cmd_check" =~ ${ANCHOR}${DB_BINARY_REGEX}[[:space:]] ]]; then
    # SQL keywords are case-insensitive, so match the DDL list that way
    # too ("drop table" is as destructive as "DROP TABLE"). The binary
    # anchor match above stays case-sensitive — it has already run by
    # the time nocasematch is set.
    shopt -s nocasematch
    if [[ "$cmd_check" =~ $DDL_REGEX ]]; then
        shopt -u nocasematch
        {
            echo "BLOCKED: ${DB_BINARY_REGEX} DDL statement detected."
            echo "Approval required per AGENTS.md gates (DB schema changes)."
            echo "Detected command: $cmd"
        } >&2
        exit 2
    fi
    shopt -u nocasematch
fi

exit 0
