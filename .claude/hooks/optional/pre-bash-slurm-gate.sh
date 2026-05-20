#!/usr/bin/env bash
# OPTIONAL HOOK: block sbatch submissions unless an active contract exists.
#
# To enable:
#   cp .claude/hooks/optional/pre-bash-slurm-gate.sh .claude/hooks/
#   (then register in .claude/settings.json hooks.PreToolUse[*].hooks[])
#
# "Active" contract = any .md file under .agent/contracts/ modified in
# the last MAX_CONTRACT_AGE_DAYS (excluding _template.md). The intent
# is: long-running jobs need a written intention + approval. Adjust
# MAX_CONTRACT_AGE_DAYS for your workflow.
set -uo pipefail

# Script is at .claude/hooks/optional/, so workspace root is three up.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"

# === Customize ===
MAX_CONTRACT_AGE_DAYS=7
# =================

# Fail-closed if jq is missing.
if ! command -v jq >/dev/null 2>&1; then
    {
        echo "BLOCKED: jq is required by this hook but is not on PATH."
        echo "Install jq or remove this hook from .claude/settings.json."
    } >&2
    exit 2
fi

input=$(cat)
tool_name=$(jq -r '.tool_name // ""' <<< "$input")
[ "$tool_name" = "Bash" ] || exit 0

cmd=$(jq -r '.tool_input.command // ""' <<< "$input")
cmd_check="${cmd%%<<*}"

ANCHOR='(^|[[:space:]]*\;|\&\&|\|\||\|[[:space:]]|'$'\n'')[[:space:]]*(sudo[[:space:]]+)?'

if [[ "$cmd_check" =~ ${ANCHOR}sbatch[[:space:]] ]]; then
    contracts_dir="$ROOT/.agent/contracts"
    if [ -d "$contracts_dir" ]; then
        recent=$(find "$contracts_dir" -maxdepth 1 -name '*.md' \
                    ! -name '_template.md' -mtime "-${MAX_CONTRACT_AGE_DAYS}" | head -1)
        if [ -n "$recent" ]; then
            exit 0
        fi
    fi
    {
        echo "BLOCKED: SLURM submission (sbatch) requires an active contract."
        echo "No contract modified in the last ${MAX_CONTRACT_AGE_DAYS} days under .agent/contracts/."
        echo "Create one from .agent/contracts/_template.md describing scope,"
        echo "resources, success criteria, and approval, then retry."
        echo "Detected command: $cmd"
    } >&2
    exit 2
fi

exit 0
