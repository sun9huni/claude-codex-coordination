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
cmd_check="${cmd%%<<*}"

# === Customize ===
DB_BINARY_REGEX='psql'   # change for mysql/mongo/etc.
DDL_REGEX='(DROP[[:space:]]+(TABLE|DATABASE|SCHEMA|INDEX|VIEW|COLUMN)|TRUNCATE[[:space:]]+(TABLE|ONLY)|ALTER[[:space:]]+TABLE)'
# =================

ANCHOR='(^|[[:space:]]*\;|\&\&|\|\||\|[[:space:]]|'$'\n'')[[:space:]]*(sudo[[:space:]]+)?'

if [[ "$cmd_check" =~ ${ANCHOR}${DB_BINARY_REGEX}[[:space:]] ]]; then
    if [[ "$cmd_check" =~ $DDL_REGEX ]]; then
        {
            echo "BLOCKED: ${DB_BINARY_REGEX} DDL statement detected."
            echo "Approval required per AGENTS.md gates (DB schema changes)."
            echo "Detected command: $cmd"
        } >&2
        exit 2
    fi
fi

exit 0
