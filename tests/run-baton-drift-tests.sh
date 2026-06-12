#!/usr/bin/env bash
# run-baton-drift-tests.sh — behavioral coverage for scripts/baton-drift.sh.
#
# baton-drift.sh is invoked best-effort by the SessionStart and PreCompact
# hooks, but until this suite only `bash -n` ever touched it. These
# assertions pin down the heartbeat-age path (B) — the only path that runs
# on the test machines. Path (A), scheduler drift, is gated on `sacct`
# being on PATH and is deliberately NOT covered: mocking SLURM is out of
# scope for a minimal harness.
#
# Same hermetic pattern as run-harness-lifecycle.sh:
#   - Throwaway fixture .agent tree under $TMP, named by AGENT_ROOT.
#   - The PRODUCTION script is exercised in place; baton-drift.sh reads
#     status/ from AGENT_ROOT, so it never touches the live .agent tree.
#
# Asserted behavior (baton-drift.sh must exit 0 in EVERY case):
#   1. Fresh heartbeat            -> no output.
#   2. 3-day-old heartbeat        -> "[<slice>] STALE" line; the fresh
#                                    slice next to it is NOT named.
#   3. --stale-days override      -> 5 silences the 3d-old baton; 1 still
#                                    flags it (fresh stays unflagged).
#   4. README.md in status/       -> excluded even with a stale heartbeat.
#   5. Empty / missing heartbeat  -> silent (unclaimed batons skipped).
#
# Conventions match run-harness-lifecycle.sh:
#   - POSIX-friendly bash (3.2-safe), python3 OK, no new deps.
#   - Each assertion prints exactly one line: "assertion N: PASS|FAIL — <desc>".
#   - A failing/erroring production call is caught and counted as FAIL — never
#     a harness crash. All 5 always run.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DRIFT_SH="$REPO_ROOT/scripts/baton-drift.sh"

FAILS=0
pass() { printf 'assertion %s: PASS — %s\n' "$1" "$2"; }
fail() { printf 'assertion %s: FAIL — %s\n' "$1" "$2"; FAILS=$((FAILS + 1)); }

# ── Fixture ──────────────────────────────────────────────────────────────────
TMP="$(mktemp -d "${TMPDIR:-/tmp}/baton-drift.XXXXXX")"
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

# Fixture .agent tree named by AGENT_ROOT — baton-drift.sh only READS
# $AGENT_ROOT/status, so no sandbox repo / symlinks are needed here.
AGENT_ROOT="$TMP/.agent"
export AGENT_ROOT
STATUS_DIR="$AGENT_ROOT/status"
mkdir -p "$STATUS_DIR"

# Deterministic UUID for fixture sessions.
S1="11111111-1111-4111-8111-111111111111"

NOW_ISO="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
THREE_DAYS_AGO_ISO="$(date -u -d '3 days ago' +%Y-%m-%dT%H:%M:%SZ 2>/dev/null \
    || date -u -v-3d +%Y-%m-%dT%H:%M:%SZ 2>/dev/null \
    || python3 -c 'import datetime;print((datetime.datetime.now(datetime.timezone.utc)-datetime.timedelta(days=3)).strftime("%Y-%m-%dT%H:%M:%SZ"))')"
TODAY_ISO="$(date -u +%Y-%m-%d)"

# write_slice_fixture <slice-file> <owner_session> <heartbeat-iso> <version> <state-line-or-empty>
# Same shape as run-harness-lifecycle.sh. An empty heartbeat-iso writes a
# bare `heartbeat:` (unclaimed); the literal token OMIT drops the line.
write_slice_fixture() {
    local f="$1" sess="$2" hb="$3" ver="$4" state_line="$5"
    {
        echo "---"
        echo "owner_session: $sess"
        echo "owner_label: \"\""
        echo "owner_agent: claude"
        echo "version: $ver"
        echo "last_updated: $TODAY_ISO"
        [ "$hb" != "OMIT" ] && echo "heartbeat: $hb"
        [ -n "$state_line" ] && echo "$state_line"
        echo "remaining_actions:"
        echo "  - Pilot drift task for $(basename "$f" .md)"
        echo "contract_pointers: []"
        echo "---"
        echo "# Fixture slice status"
        echo
        echo "Synthetic per-slice status used only by tests/run-baton-drift-tests.sh."
    } > "$f"
}

# run_drift [args...] — invoke the production script against the fixture.
# Captures stdout in $drift_out and the exit code in $drift_rc.
run_drift() {
    drift_out="$(AGENT_ROOT="$AGENT_ROOT" bash "$DRIFT_SH" "$@" 2>/dev/null)"
    drift_rc=$?
}

reset_fixture() { rm -f "$STATUS_DIR"/*.md; }

# ── Assertion 1: fresh heartbeat -> no output ────────────────────────────────
reset_fixture
write_slice_fixture "$STATUS_DIR/slice-fresh.md" "$S1" "$NOW_ISO" 3 "state: active"
run_drift

if [ "$drift_rc" -eq 0 ] && [ -z "$drift_out" ]; then
    pass 1 "fresh heartbeat produces no output (rc=0)"
else
    fail 1 "fresh heartbeat should be silent (rc=$drift_rc out='$drift_out')"
fi

# ── Assertion 2: 3d-old heartbeat -> STALE line, fresh slice not named ───────
write_slice_fixture "$STATUS_DIR/slice-stale.md" "$S1" "$THREE_DAYS_AGO_ISO" 3 "state: active"
run_drift

stale_named=0; fresh_named=0
case "$drift_out" in *"[slice-stale] STALE"*) stale_named=1 ;; esac
case "$drift_out" in *slice-fresh*) fresh_named=1 ;; esac

if [ "$drift_rc" -eq 0 ] && [ "$stale_named" -eq 1 ] && [ "$fresh_named" -eq 0 ]; then
    pass 2 "3d-old heartbeat flagged '[slice-stale] STALE'; fresh slice not named (rc=0)"
else
    fail 2 "expected STALE for slice-stale only (rc=$drift_rc stale_named=$stale_named fresh_named=$fresh_named out='$drift_out')"
fi

# ── Assertion 3: --stale-days override honored both ways ─────────────────────
# Same fixture as assertion 2. Raising the threshold to 5 silences the
# 3d-old baton; lowering it to 1 still flags it (fresh is 0d -> unflagged).
run_drift --stale-days 5
rc_5=$drift_rc; out_5="$drift_out"
run_drift --stale-days 1
rc_1=$drift_rc; out_1="$drift_out"

stale_at_1=0; fresh_at_1=0
case "$out_1" in *"[slice-stale] STALE"*) stale_at_1=1 ;; esac
case "$out_1" in *slice-fresh*) fresh_at_1=1 ;; esac

if [ "$rc_5" -eq 0 ] && [ -z "$out_5" ] \
    && [ "$rc_1" -eq 0 ] && [ "$stale_at_1" -eq 1 ] && [ "$fresh_at_1" -eq 0 ]; then
    pass 3 "--stale-days honored: 5 silences the 3d-old baton, 1 still flags it"
else
    fail 3 "--stale-days override broken (rc5=$rc_5 out5='$out_5' rc1=$rc_1 stale@1=$stale_at_1 fresh@1=$fresh_at_1)"
fi

# ── Assertion 4: README.md in status/ is excluded ────────────────────────────
# A stale heartbeat inside README.md must NOT be reported — only real
# per-slice batons count.
reset_fixture
write_slice_fixture "$STATUS_DIR/README.md" "$S1" "$THREE_DAYS_AGO_ISO" 3 "state: active"
write_slice_fixture "$STATUS_DIR/slice-fresh.md" "$S1" "$NOW_ISO" 3 "state: active"
run_drift

if [ "$drift_rc" -eq 0 ] && [ -z "$drift_out" ]; then
    pass 4 "README.md excluded even with a stale heartbeat (rc=0)"
else
    fail 4 "README.md should be skipped (rc=$drift_rc out='$drift_out')"
fi

# ── Assertion 5: empty / missing heartbeat -> silent ─────────────────────────
# Unclaimed batons (bare `heartbeat:` value, or no heartbeat line at all)
# must not produce drift findings.
reset_fixture
write_slice_fixture "$STATUS_DIR/slice-unclaimed.md" "" "" 0 ""
write_slice_fixture "$STATUS_DIR/slice-no-hb.md" "" "OMIT" 0 ""
run_drift

if [ "$drift_rc" -eq 0 ] && [ -z "$drift_out" ]; then
    pass 5 "empty and missing heartbeat batons are silent (rc=0)"
else
    fail 5 "unclaimed batons should be silent (rc=$drift_rc out='$drift_out')"
fi

# ── Verdict ──────────────────────────────────────────────────────────────────
echo
if [ "$FAILS" -eq 0 ]; then
    echo "baton-drift: 5/5 GREEN"
    exit 0
else
    echo "baton-drift: $FAILS/5 FAIL"
    exit 1
fi
