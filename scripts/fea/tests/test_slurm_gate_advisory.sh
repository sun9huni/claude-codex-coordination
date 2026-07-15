#!/usr/bin/env bash
# Regression test: the Task-6 FragMap preflight advisory must NEVER change
# the slurm-gate hook's exit code. The contract-check is the sole authority
# on the verdict (exit 0 = allowed, exit 2 = blocked).
#
# Run:  cd /home/ubuntu && bash scripts/fea/tests/test_slurm_gate_advisory.sh
set -uo pipefail

HOOK=/home/ubuntu/.claude/hooks/pre-bash-slurm-gate.sh
ROOT=/home/ubuntu
BADCFG=scripts/fea/tests/fixtures/preflight/bad_feature_mode.yaml

fails=0
pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1"; fails=$((fails + 1)); }

# --- Assertion 1: non-sbatch command is a no-op (exit 0, empty out/err) ---
out1="$( ( cd "$ROOT" && echo '{"tool_name":"Bash","tool_input":{"command":"ls -la"}}' | bash "$HOOK" ) 2>/tmp/sga_err1 )"
rc1=$?
err1="$(cat /tmp/sga_err1)"
if [ "$rc1" -eq 0 ] && [ -z "$out1" ] && [ -z "$err1" ]; then
    pass "1 non-sbatch command is a no-op (exit 0, empty stdout/stderr)"
else
    fail "1 non-sbatch no-op: rc=$rc1 stdout='$out1' stderr='$err1'"
fi
rm -f /tmp/sga_err1

# --- Assertion 2: advisory fires but does NOT block (recent contract present) ---
# Self-contained: build an ISOLATED tmp ROOT replicating the hook's layout
# (hook computes ROOT three dirs up from itself), with a FRESH contract whose
# mtime is now (so it counts as recent), so the test is not date-coupled on the
# real repo's contracts. The bad fixture is referenced by ABSOLUTE path so the
# advisory's `[ -f ]` check passes from any cwd, and PYTHONPATH=/home/ubuntu
# lets `python -m scripts.fea preflight` import from the real repo while ROOT
# stays the tmp dir.
tmproot2="$(mktemp -d)"
cleanup2() { rm -rf "$tmproot2"; }
trap cleanup2 EXIT
mkdir -p "$tmproot2/.claude/hooks" "$tmproot2/.agent/contracts"
cp "$HOOK" "$tmproot2/.claude/hooks/pre-bash-slurm-gate.sh"
printf 'recent\n' > "$tmproot2/.agent/contracts/test-contract.md"   # fresh mtime => recent
ABSBAD=/home/ubuntu/scripts/fea/tests/fixtures/preflight/bad_feature_mode.yaml
cmd2="sbatch run.sh --fragmap_config $ABSBAD"
payload2="$(jq -nc --arg c "$cmd2" '{tool_name:"Bash",tool_input:{command:$c}}')"
out2="$( ( cd "$tmproot2" && PYTHONPATH=/home/ubuntu printf '%s' "$payload2" | PYTHONPATH=/home/ubuntu bash "$tmproot2/.claude/hooks/pre-bash-slurm-gate.sh" ) 2>/tmp/sga_err2 )"
rc2=$?
err2="$(cat /tmp/sga_err2)"
if [ "$rc2" -eq 0 ] \
   && grep -q '\[fea-preflight\]' /tmp/sga_err2 \
   && { grep -qi 'forbidden' /tmp/sga_err2 || grep -qi 'feature' /tmp/sga_err2; }; then
    pass "2 advisory fires but does not block (exit 0, [fea-preflight] + forbidden/feature)"
else
    fail "2 advisory non-blocking: rc=$rc2 stderr='$err2'"
fi
rm -f /tmp/sga_err2

# --- Assertion 3: advisory never flips a BLOCK verdict ---
# Replicate the hook's ROOT layout (three dirs up from the script) inside a
# tmp dir with an EMPTY .agent/contracts/ (no recent contract) so the gate
# must BLOCK. scripts.fea won't import under the tmp ROOT; the advisory must
# swallow that and the block must still happen.
tmproot="$(mktemp -d)"
cleanup() { rm -rf "$tmproot" "$tmproot2"; }
trap cleanup EXIT
mkdir -p "$tmproot/.claude/hooks" "$tmproot/.agent/contracts"
cp "$HOOK" "$tmproot/.claude/hooks/pre-bash-slurm-gate.sh"
cmd3="sbatch run.sh --fragmap_config $BADCFG"
payload3="$(jq -nc --arg c "$cmd3" '{tool_name:"Bash",tool_input:{command:$c}}')"
out3="$( ( cd "$tmproot" && printf '%s' "$payload3" | bash "$tmproot/.claude/hooks/pre-bash-slurm-gate.sh" ) 2>/tmp/sga_err3 )"
rc3=$?
err3="$(cat /tmp/sga_err3)"
if [ "$rc3" -eq 2 ]; then
    pass "3 advisory never flips BLOCK (empty contracts -> exit 2)"
else
    fail "3 expected BLOCK exit 2, got rc=$rc3 stderr='$err3'"
fi
rm -f /tmp/sga_err3

if [ "$fails" -eq 0 ]; then
    echo "ALL PASS"
    exit 0
fi
echo "$fails assertion(s) failed"
exit 1
