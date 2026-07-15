#!/usr/bin/env bash
# OPTIONAL HOOK: block sbatch submissions unless an active contract exists.
#
# To enable:
#   cp .claude/hooks/optional/pre-bash-slurm-gate.sh .claude/hooks/
#   (then register in .claude/settings.json hooks.PreToolUse[*].hooks[])
#
# "Active" contract = any .md file under .agent/contracts/ modified in
# the last MAX_CONTRACT_AGE_DAYS (excluding _template.md and README.md —
# documentation, not contracts; a fresh checkout's README mtime would
# otherwise satisfy the gate for 7 days). The intent is: long-running
# jobs need a written intention + approval. Adjust
# MAX_CONTRACT_AGE_DAYS for your workflow.
set -uo pipefail

# Script is at .claude/hooks/optional/, so workspace root is three up.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

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

# Strip heredoc and here-string BODIES — they are data, not commands —
# while keeping any commands that follow them. (A naive ${cmd%%<<*}
# would also throw away real commands after the first <<, so a heredoc
# prefix could smuggle an sbatch past the gate.) Fail closed: if
# python3 is missing or errors, scan the raw command instead.
cmd_check=$(python3 -c 'import re,sys; s=sys.stdin.read(); s=re.sub(r"<<-?[ \t]*\\?([\"\x27]?)(\w+)\1([^\n]*\n).*?\n\2", r" \3", s, flags=re.S); s=re.sub(r"<<<\s*(\"[^\"]*\"|\x27[^\x27]*\x27|[^\s;&|]+)", " ", s); print(s)' <<< "$cmd" 2>/dev/null) || cmd_check="$cmd"
[ -n "$cmd_check" ] || cmd_check="$cmd"

ANCHOR='(^|[[:space:]]*\;|\&\&|\|\||\|[[:space:]]|'$'\n'')[[:space:]]*(sudo[[:space:]]+)?'

if [[ "$cmd_check" =~ ${ANCHOR}sbatch[[:space:]] ]]; then
    # --- BEST-EFFORT FragMap preflight advisory (never a gate) ---
    # This emits an ADVISORY only; it must never change the hook's exit
    # code. The contract-check logic below is the sole authority on the
    # verdict (exit 0 or exit 2).
    #
    # CAVEAT: fragmap configs usually ride INSIDE a docker invocation via
    # --fragmap_config and therefore do NOT appear on the sbatch command
    # line we see here. The common case is silence. Absence of a warning
    # does NOT mean the config was validated — this is advisory only.
    {
        fea_candidates=()
        # (a) --fragmap_config <path>  or  --fragmap_config=<path>
        if [[ "$cmd" =~ --fragmap_config[=[:space:]]+([^[:space:]]+) ]]; then
            fea_candidates+=("${BASH_REMATCH[1]}")
        fi
        # (b) any token matching *fragmap*.yaml / *fragmap*.yml
        for tok in $cmd; do
            case "$tok" in
                *fragmap*.yaml|*fragmap*.yml) fea_candidates+=("$tok") ;;
            esac
        done
        for cand in "${fea_candidates[@]:-}"; do
            [ -n "$cand" ] || continue
            [ -f "$cand" ] || continue
            fea_out="$( ( cd "$ROOT" && python -m scripts.fea preflight "$cand" ) 2>&1 || true )"
            if [ -n "${fea_out:-}" ]; then
                while IFS= read -r fea_line; do
                    echo "[fea-preflight] $fea_line" >&2
                done <<< "$fea_out"
            fi
        done
    } || true
    # --- end advisory ---

    contracts_dir="$ROOT/.agent/contracts"
    if [ -d "$contracts_dir" ]; then
        recent=$(find "$contracts_dir" -maxdepth 1 -name '*.md' \
                    ! -name '_template.md' ! -name 'README.md' \
                    -mtime "-${MAX_CONTRACT_AGE_DAYS}" | head -1)
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
