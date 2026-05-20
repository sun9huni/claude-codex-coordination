#!/usr/bin/env bash
# Hook test runner. Exits non-zero if any test fails.
#
# Each test feeds a golden JSON fixture into a hook and checks the exit
# code. Used by .github/workflows/test.yml on Linux + macOS.

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOKS="$ROOT/.claude/hooks"
FIX="$ROOT/tests/fixtures"

PASS=0
FAIL=0

run() {
    local name="$1" expect="$2" hook="$3" fixture="$4"
    local got out
    out=$(bash "$hook" < "$fixture" 2>&1)
    got=$?
    if [ "$got" = "$expect" ]; then
        printf "PASS  %-40s exit=%s\n" "$name" "$got"
        PASS=$((PASS + 1))
    else
        printf "FAIL  %-40s expected=%s actual=%s\n" "$name" "$expect" "$got"
        printf "      output: %s\n" "$out"
        FAIL=$((FAIL + 1))
    fi
}

# -------- destructive gate --------
run "destructive: rm -f single file"        0 "$HOOKS/pre-bash-destructive-gate.sh" "$FIX/rm-f-single.json"
run "destructive: rm -rf /mnt/data"         2 "$HOOKS/pre-bash-destructive-gate.sh" "$FIX/rm-rf-mnt-data.json"
run "destructive: rm -rf .agent"            2 "$HOOKS/pre-bash-destructive-gate.sh" "$FIX/rm-rf-dot-agent.json"
run "destructive: git push --force"         2 "$HOOKS/pre-bash-destructive-gate.sh" "$FIX/git-push-force.json"
run "destructive: git push (normal)"        0 "$HOOKS/pre-bash-destructive-gate.sh" "$FIX/git-push-normal.json"
run "destructive: rm in commit message"     0 "$HOOKS/pre-bash-destructive-gate.sh" "$FIX/commit-with-rm-message.json"
run "destructive: non-Bash skip"            0 "$HOOKS/pre-bash-destructive-gate.sh" "$FIX/non-bash.json"

# -------- slurm gate (optional) --------
# Only run if a recent contract is available; the test creates one to ensure pass case works.
mkdir -p "$ROOT/.agent/contracts"
touch "$ROOT/.agent/contracts/test-contract.md"
run "slurm: sbatch with active contract"    0 "$HOOKS/optional/pre-bash-slurm-gate.sh" "$FIX/sbatch.json"
rm "$ROOT/.agent/contracts/test-contract.md"

# -------- db gate (optional) --------
run "db: psql DROP TABLE"                   2 "$HOOKS/optional/pre-bash-db-gate.sh" "$FIX/psql-drop.json"
run "db: psql SELECT"                       0 "$HOOKS/optional/pre-bash-db-gate.sh" "$FIX/psql-select.json"
run "db: psql DROP in commit msg"           0 "$HOOKS/optional/pre-bash-db-gate.sh" "$FIX/commit-with-drop-message.json"

# -------- session-start decay (live) --------
# Always exits 0 (non-blocking). We just check it runs cleanly.
run "session-start: decay check exits 0"    0 "$HOOKS/session-start-decay-check.sh" "$FIX/empty.json"

# -------- stop hook (live) --------
run "stop: exits 0"                         0 "$HOOKS/stop-handoff-check.sh" "$FIX/empty.json"

echo ""
echo "==========================================="
echo "PASS: $PASS    FAIL: $FAIL"
[ "$FAIL" = 0 ] && exit 0 || exit 1
