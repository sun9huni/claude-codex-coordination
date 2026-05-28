#!/usr/bin/env bash
# run-harness-concurrency.sh — v0.4.0 per-slice concurrency regression test.
#
# The template ALREADY implements the per-slice model, so this is a GREEN
# regression test: it prints 5 assertions over handoff.sh per-slice mode,
# status.sh index, and the two hooks, and ALL must PASS.
#
# ─────────────────────────────────────────────────────────────────────────────
# TEST-SEAM CONTRACT (the per-slice scripts/hooks implement these verbatim)
# ─────────────────────────────────────────────────────────────────────────────
# The test never touches the live /home/ubuntu/.agent. Production scripts and
# hooks honor an env var:
#
#   AGENT_ROOT   Path to the .agent tree to operate on. Default (unset) = the
#                repo's own .agent (resolved from BASH_SOURCE, as today). When
#                set, ALL of handoff.sh / status.sh / the two hooks read and
#                write under "$AGENT_ROOT/..." instead of the repo .agent.
#
# Per-assertion interface assumptions (see the SUMMARY block printed at the end
# and the report for the canonical list):
#
#   A1 handoff.sh   ./scripts/handoff.sh <next-agent> <slice>     [AGENT_ROOT, OWNER_SESSION/OWNER_LABEL env]
#                   writes only "$AGENT_ROOT/status/<slice>.md" (owner fields +
#                   heartbeat + version bump). Two different slices must NOT
#                   clobber each other's remaining_actions.
#   A2 status.sh    ./scripts/status.sh index                     [AGENT_ROOT]
#   A4              writes "$AGENT_ROOT/handoffs/CURRENT.md" as a DERIVED index:
#                   one table row per slice with its owner_session, sourced from
#                   that slice's own status file (no cross-slice action leakage).
#   A3 hook         .claude/hooks/session-start-decay-check.sh     [AGENT_ROOT, ENTERING_SLICE env]
#                   when ENTERING_SLICE names a slice whose status frontmatter
#                   has a FRESH heartbeat under a DIFFERENT owner_session than
#                   the current session, prints a "live claim" warning. STALE
#                   heartbeat (or same owner) => no warning.
#   A5 hook         .claude/hooks/stop-handoff-check.sh            [AGENT_ROOT, ENTERING_SLICE env]
#                   validates the per-slice status file under $AGENT_ROOT using
#                   the per-slice schema; on a valid, placeholder-free fixture it
#                   exits 0 AND echoes a confirmation line naming the validated
#                   file (so the test can prove the AGENT_ROOT seam was used).
#
# Conventions:
#   - POSIX-friendly bash, no new external deps (python3/pyyaml may be used).
#   - Every assertion prints exactly one line: "assertion N: PASS|FAIL — <desc>".
#     Later tasks verify with: grep 'assertion N' <output>.
#   - A failing/erroring production call is caught (|| true) and counted as a
#     FAIL for that assertion — never a harness crash. All 5 always run.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

FAILS=0
pass() { printf 'assertion %s: PASS — %s\n' "$1" "$2"; }
fail() { printf 'assertion %s: FAIL — %s\n' "$1" "$2"; FAILS=$((FAILS + 1)); }

# ── Fixture ──────────────────────────────────────────────────────────────────
TMP="$(mktemp -d "${TMPDIR:-/tmp}/harness-concurrency.XXXXXX")"
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

# Sandbox repo root. We SYMLINK the real production scripts/hooks into a
# throwaway repo whose .agent IS the fixture. Two reasons:
#   1. We still exercise the REAL files, so each later task's edits are tested.
#   2. Today's scripts derive their root from BASH_SOURCE/.. (they do not yet
#      honor AGENT_ROOT). Running them via the sandbox path makes that derived
#      root land inside the fixture — so a NON-compliant script can never reach
#      or mutate the live /home/ubuntu/.agent. The test stays hermetic at every
#      stage of the migration. AGENT_ROOT (below) is the seam the per-slice
#      scripts/hooks add; the sandbox root is belt-and-suspenders so the
#      regression test is clean.
SANDBOX="$TMP/repo"
mkdir -p "$SANDBOX/scripts" "$SANDBOX/.claude/hooks"
ln -s "$REPO_ROOT/scripts/handoff.sh"                      "$SANDBOX/scripts/handoff.sh"
ln -s "$REPO_ROOT/scripts/status.sh"                       "$SANDBOX/scripts/status.sh"
ln -s "$REPO_ROOT/.claude/hooks/session-start-decay-check.sh" "$SANDBOX/.claude/hooks/session-start-decay-check.sh"
ln -s "$REPO_ROOT/.claude/hooks/stop-handoff-check.sh"     "$SANDBOX/.claude/hooks/stop-handoff-check.sh"

HANDOFF_SH="$SANDBOX/scripts/handoff.sh"
STATUS_SH="$SANDBOX/scripts/status.sh"
SESSION_START_HOOK="$SANDBOX/.claude/hooks/session-start-decay-check.sh"
STOP_HOOK="$SANDBOX/.claude/hooks/stop-handoff-check.sh"

# The fixture .agent lives inside the sandbox repo AND is named by AGENT_ROOT.
AGENT_ROOT="$SANDBOX/.agent"
export AGENT_ROOT
mkdir -p "$AGENT_ROOT/status" "$AGENT_ROOT/handoffs"

S1="11111111-1111-4111-8111-111111111111"   # session that owns slice-1
S2="22222222-2222-4222-8222-222222222222"   # session that owns slice-2
S3="33333333-3333-4333-8333-333333333333"   # a third, unrelated session

NOW_ISO="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
STALE_ISO="$(date -u -d '60 minutes ago' +%Y-%m-%dT%H:%M:%SZ 2>/dev/null \
            || date -u -v-60M +%Y-%m-%dT%H:%M:%SZ 2>/dev/null \
            || python3 -c 'import datetime;print((datetime.datetime.utcnow()-datetime.timedelta(minutes=60)).strftime("%Y-%m-%dT%H:%M:%SZ"))')"
TODAY_ISO="$(date -u +%Y-%m-%d)"

# Distinct, slice-specific remaining_actions so we can detect clobber/leak.
S1_ACTION_A="slice-1 remaining action alpha"
S1_ACTION_B="slice-1 remaining action beta"
S2_ACTION_A="slice-2 remaining action alpha"
S2_ACTION_B="slice-2 remaining action beta"

# write_slice_fixture <slice-file> <owner_session> <heartbeat-iso> <version> <action1> <action2> <contract>
write_slice_fixture() {
    local f="$1" sess="$2" hb="$3" ver="$4" a1="$5" a2="$6" contract="$7"
    cat > "$f" <<EOF
---
owner_session: $sess
owner_label: ""
owner_agent: claude
version: $ver
last_updated: $TODAY_ISO
heartbeat: $hb
remaining_actions:
  - $a1
  - $a2
contract_pointers:
  - $contract
---
# Fixture slice status

Synthetic per-slice status used only by tests/run-harness-concurrency.sh.
EOF
}

# Initial state for assertion 1: both slices UNOWNED (empty owner_session,
# version 0, no heartbeat). A correct handoff.sh must take ownership and bump
# version/heartbeat on the named slice only.
write_slice_fixture "$AGENT_ROOT/status/slice-1.md" "" "" 0 \
    "$S1_ACTION_A" "$S1_ACTION_B" \
    ".agent/contracts/slice-1-example-20260527.md"
write_slice_fixture "$AGENT_ROOT/status/slice-2.md" "" "" 0 \
    "$S2_ACTION_A" "$S2_ACTION_B" \
    ".agent/contracts/slice-2-example-20260527.md"

# Read one frontmatter scalar from a status file (awk, no PyYAML needed).
fm_get() {
    awk -v key="$2" '
        /^---$/ { in_fm = !in_fm; next }
        in_fm {
            if (match($0, "^" key ":[[:space:]]*")) {
                v = substr($0, RLENGTH + 1)
                gsub(/^[[:space:]]*"|"[[:space:]]*$/, "", v)
                gsub(/^[[:space:]]+|[[:space:]]+$/, "", v)
                print v; exit
            }
        }
    ' "$1"
}

# ── Assertion 1: lost-update 0 (Task 5) ──────────────────────────────────────
# session-1 writes slice-1 (owner S1), session-2 writes slice-2 (owner S2), via
# handoff.sh with AGENT_ROOT + slice arg + owner identity. After both, each
# status file must still carry its OWN distinct remaining_actions.
a1_run() {
    AGENT_ROOT="$AGENT_ROOT" OWNER_SESSION="$S1" OWNER_LABEL="claude-A" \
        bash "$HANDOFF_SH" claude slice-1 >/dev/null 2>&1 || true
    AGENT_ROOT="$AGENT_ROOT" OWNER_SESSION="$S2" OWNER_LABEL="claude-B" \
        bash "$HANDOFF_SH" codex slice-2 >/dev/null 2>&1 || true

    local s1 s2 s1_v s2_v
    s1="$(cat "$AGENT_ROOT/status/slice-1.md" 2>/dev/null || true)"
    s2="$(cat "$AGENT_ROOT/status/slice-2.md" 2>/dev/null || true)"
    s1_v="$(fm_get "$AGENT_ROOT/status/slice-1.md" version)"
    s2_v="$(fm_get "$AGENT_ROOT/status/slice-2.md" version)"

    # (a) handoff actually wrote each slice file: ownership taken (S1/S2),
    #     version bumped above the seeded 0, heartbeat now non-empty.
    # (b) no clobber: each file keeps its OWN actions; neither bleeds the
    #     other's action text.
    [ "$(fm_get "$AGENT_ROOT/status/slice-1.md" owner_session)" = "$S1" ] \
        && [ "$(fm_get "$AGENT_ROOT/status/slice-2.md" owner_session)" = "$S2" ] \
        && [ "${s1_v:-0}" -gt 0 ] 2>/dev/null \
        && [ "${s2_v:-0}" -gt 0 ] 2>/dev/null \
        && [ -n "$(fm_get "$AGENT_ROOT/status/slice-1.md" heartbeat)" ] \
        && [ -n "$(fm_get "$AGENT_ROOT/status/slice-2.md" heartbeat)" ] \
        && grep -qF "$S1_ACTION_A" <<<"$s1" \
        && grep -qF "$S2_ACTION_A" <<<"$s2" \
        && ! grep -qF "$S2_ACTION_A" <<<"$s1" \
        && ! grep -qF "$S1_ACTION_A" <<<"$s2"
}
if a1_run; then
    pass 1 "lost-update 0: slice-1(S1) and slice-2(S2) both retain distinct remaining_actions after concurrent handoff"
else
    fail 1 "lost-update 0: handoff.sh did not preserve per-slice owner/actions for both slice-1(S1) and slice-2(S2)"
fi

# ── Assertion 2: index regen with two distinct owners (Task 6) ────────────────
# status.sh index mode writes $AGENT_ROOT/handoffs/CURRENT.md with a table that
# has TWO distinct owner_session rows (slice-1->S1, slice-2->S2).
CURRENT_IDX="$AGENT_ROOT/handoffs/CURRENT.md"
rm -f "$CURRENT_IDX"
AGENT_ROOT="$AGENT_ROOT" bash "$STATUS_SH" index >/dev/null 2>&1 \
    || AGENT_ROOT="$AGENT_ROOT" bash "$STATUS_SH" --index >/dev/null 2>&1 \
    || true
idx_content="$(cat "$CURRENT_IDX" 2>/dev/null || true)"
if [ -n "$idx_content" ] \
    && grep -q '|' <<<"$idx_content" \
    && grep -qF "$S1" <<<"$idx_content" \
    && grep -qF "$S2" <<<"$idx_content"; then
    pass 2 "index regen: status.sh index wrote CURRENT.md table with both owner_session S1 (slice-1) and S2 (slice-2)"
else
    fail 2 "index regen: status.sh index did not write a CURRENT.md table containing both owner_session S1 and S2"
fi

# ── Assertion 3: live-claim warning, fresh vs stale heartbeat (Task 7) ────────
# SessionStart hook with ENTERING_SLICE=slice-1. FRESH heartbeat under S1 while
# the current session is S3 => "live claim" warning. STALE heartbeat => none.
CLAIM_MARKER='live claim|claimed|already (owned|held|active)'

# Fresh slice-1 owned by S1, current session is S3 -> expect a claim warning.
write_slice_fixture "$AGENT_ROOT/status/slice-1.md" "$S1" "$NOW_ISO" 4 \
    "$S1_ACTION_A" "$S1_ACTION_B" \
    ".agent/contracts/slice-1-example-20260527.md"
fresh_out="$( AGENT_ROOT="$AGENT_ROOT" ENTERING_SLICE="slice-1" OWNER_SESSION="$S3" \
              bash "$SESSION_START_HOOK" 2>&1 || true )"

# Stale slice-1 (60 min old) -> NO claim warning even though session differs.
write_slice_fixture "$AGENT_ROOT/status/slice-1.md" "$S1" "$STALE_ISO" 4 \
    "$S1_ACTION_A" "$S1_ACTION_B" \
    ".agent/contracts/slice-1-example-20260527.md"
stale_out="$( AGENT_ROOT="$AGENT_ROOT" ENTERING_SLICE="slice-1" OWNER_SESSION="$S3" \
              bash "$SESSION_START_HOOK" 2>&1 || true )"

if grep -qiE "$CLAIM_MARKER" <<<"$fresh_out" \
    && ! grep -qiE "$CLAIM_MARKER" <<<"$stale_out"; then
    pass 3 "claim warning: fresh heartbeat under S1 vs current S3 warns; stale (60m) heartbeat does not"
else
    fail 3 "claim warning: SessionStart hook did not warn on fresh-foreign-owner heartbeat (and stay silent on stale)"
fi

# Restore both slices to fresh, owned, placeholder-free fixtures for the
# index (A4) and Stop (A5) assertions: slice-1->S1, slice-2->S2.
write_slice_fixture "$AGENT_ROOT/status/slice-1.md" "$S1" "$NOW_ISO" 4 \
    "$S1_ACTION_A" "$S1_ACTION_B" \
    ".agent/contracts/slice-1-example-20260527.md"
write_slice_fixture "$AGENT_ROOT/status/slice-2.md" "$S2" "$NOW_ISO" 4 \
    "$S2_ACTION_A" "$S2_ACTION_B" \
    ".agent/contracts/slice-2-example-20260527.md"

# ── Assertion 4: no cross-slice action leak in the index (Task 6/9) ───────────
# After index regen, the slice-1 row/section must contain none of slice-2's
# action text. (May go green as soon as the index exists — acceptable.)
rm -f "$CURRENT_IDX"
AGENT_ROOT="$AGENT_ROOT" bash "$STATUS_SH" index >/dev/null 2>&1 \
    || AGENT_ROOT="$AGENT_ROOT" bash "$STATUS_SH" --index >/dev/null 2>&1 \
    || true
if [ -f "$CURRENT_IDX" ]; then
    # Lines that mention slice-1 must not also carry a slice-2 action string.
    s1_lines="$(grep -i 'slice-1' "$CURRENT_IDX" 2>/dev/null || true)"
    if [ -n "$s1_lines" ] \
        && ! grep -qF "$S2_ACTION_A" <<<"$s1_lines" \
        && ! grep -qF "$S2_ACTION_B" <<<"$s1_lines"; then
        pass 4 "no leak: slice-1 row/section of CURRENT.md contains no slice-2 action text"
    else
        fail 4 "no leak: slice-1 row/section of CURRENT.md is absent or contains slice-2 action text"
    fi
else
    fail 4 "no leak: CURRENT.md index was not produced, so per-slice separation cannot be confirmed"
fi

# ── Assertion 5: backward-compat Stop validates per-slice fixture (Task 8) ────
# Stop hook with AGENT_ROOT + a single fully-populated, placeholder-free slice.
# Green = exits 0 AND confirms it validated the fixture file under AGENT_ROOT
# (so we know the seam was honored, not the live repo CURRENT.md).
stop_slice="slice-2"
stop_out="$( AGENT_ROOT="$AGENT_ROOT" ENTERING_SLICE="$stop_slice" OWNER_SESSION="$S2" \
             bash "$STOP_HOOK" 2>&1 )"
stop_rc=$?
# It must reference the validated per-slice file (absolute fixture path OR a
# relative "status/<slice>.md" mention) — proof the AGENT_ROOT seam was used,
# not the live repo CURRENT.md — and emit no schema-violation line about it.
if [ "$stop_rc" -eq 0 ] \
    && { grep -qF "$AGENT_ROOT/status/$stop_slice.md" <<<"$stop_out" \
         || grep -qE "status/$stop_slice\.md" <<<"$stop_out"; } \
    && ! grep -qE '\[handoff-check\].*(missing|invalid|must|not a valid|placeholder)' <<<"$stop_out"; then
    pass 5 "backward-compat Stop: validated $stop_slice.md under AGENT_ROOT and exited 0 with no schema violations"
else
    fail 5 "backward-compat Stop: hook did not validate the per-slice fixture under AGENT_ROOT and exit 0 cleanly (rc=$stop_rc)"
fi

# ── Verdict ──────────────────────────────────────────────────────────────────
echo
if [ "$FAILS" -eq 0 ]; then
    echo "harness-concurrency: 5/5 GREEN"
    exit 0
else
    echo "harness-concurrency: $FAILS/5 FAIL"
    exit 1
fi
