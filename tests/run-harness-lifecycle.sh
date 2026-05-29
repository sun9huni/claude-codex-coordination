#!/usr/bin/env bash
# run-harness-lifecycle.sh — RED baseline for the per-slice lifecycle work.
#
# Defines "green" for the harness-lifecycle plan. Every behavior asserted
# here is intentionally NOT implemented yet, so a clean run today must
# print 4 assertions, ALL FAIL, and exit non-zero. As each later task
# lands, the matching assertion flips to PASS.
#
# Same hermetic pattern as run-harness-concurrency.sh:
#   - Throwaway sandbox repo at $TMP/repo whose .agent IS the fixture.
#   - Production scripts/hooks SYMLINKed into the sandbox so we exercise
#     the real files but they cannot reach the live /home/ubuntu/.agent.
#   - AGENT_ROOT env var points at the fixture .agent tree.
#
# ─────────────────────────────────────────────────────────────────────────────
# TEST-SEAM CONTRACT (lifecycle tasks MUST implement these verbatim)
# ─────────────────────────────────────────────────────────────────────────────
#   A1 handoff.sh --release <slice>:
#        Clears owner_session, owner_label, heartbeat and sets state: released
#        in the per-slice frontmatter. (Today: flag unsupported.)
#
#   A2 state field semantics on claim:
#        - A baton with NO `state:` field, after a normal claim, has
#          state: active in its frontmatter.
#        - A baton already at state: released keeps state: released after a
#          subsequent claim (a claim does NOT auto-flip released -> active).
#
#   A3 handoff.sh auto-commit:
#        On a clean git fixture whose only untracked files are exactly
#          .agent/contracts/<slice>-foo-YYYYMMDD.md
#          .agent/plans/<slice>-foo-YYYYMMDD.md
#        `handoff.sh claude <slice>` creates EXACTLY one new commit whose
#        message starts "<slice>:" and includes those two files.
#        If the working tree has an UNRELATED dirty tracked file, the same
#        run does NOT auto-commit and prints one warning line to stderr.
#        In both cases handoff.sh still exits 0.
#
#   A4 Stop hook missed-handoff warning:
#        Given $AGENT_ROOT/handoffs/state/session-markers/<sid>.start with
#        the current epoch AND a slice baton whose owner_session=<sid> and
#        heartbeat=24h-ago, invoking the Stop hook with session_id=<sid>
#        must print
#           [handoff-check] session ended without running handoff.sh for slice 'slice-1'
#        to stderr.
#
# Conventions match run-harness-concurrency.sh:
#   - POSIX-friendly bash, python3 OK, no new deps.
#   - Each assertion prints exactly one line: "assertion N: PASS|FAIL — <desc>".
#   - A failing/erroring production call is caught and counted as FAIL — never
#     a harness crash. All 4 always run.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

FAILS=0
pass() { printf 'assertion %s: PASS — %s\n' "$1" "$2"; }
fail() { printf 'assertion %s: FAIL — %s\n' "$1" "$2"; FAILS=$((FAILS + 1)); }

# ── Fixture ──────────────────────────────────────────────────────────────────
TMP="$(mktemp -d "${TMPDIR:-/tmp}/harness-lifecycle.XXXXXX")"
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

# Sandbox repo root with SYMLINKed production scripts/hooks.
SANDBOX="$TMP/repo"
mkdir -p "$SANDBOX/scripts" "$SANDBOX/.claude/hooks"
ln -s "$REPO_ROOT/scripts/handoff.sh"                          "$SANDBOX/scripts/handoff.sh"
ln -s "$REPO_ROOT/scripts/status.sh"                           "$SANDBOX/scripts/status.sh"
ln -s "$REPO_ROOT/.claude/hooks/session-start-decay-check.sh"  "$SANDBOX/.claude/hooks/session-start-decay-check.sh"
ln -s "$REPO_ROOT/.claude/hooks/stop-handoff-check.sh"         "$SANDBOX/.claude/hooks/stop-handoff-check.sh"

HANDOFF_SH="$SANDBOX/scripts/handoff.sh"
STOP_HOOK="$SANDBOX/.claude/hooks/stop-handoff-check.sh"

# Fixture .agent lives inside the sandbox repo AND is named by AGENT_ROOT.
AGENT_ROOT="$SANDBOX/.agent"
export AGENT_ROOT
mkdir -p "$AGENT_ROOT/status" "$AGENT_ROOT/handoffs/state/session-markers"

# Deterministic UUIDs for fixture sessions.
S1="11111111-1111-4111-8111-111111111111"
S2="22222222-2222-4222-8222-222222222222"

NOW_ISO="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
DAY_AGO_ISO="$(date -u -d '24 hours ago' +%Y-%m-%dT%H:%M:%SZ 2>/dev/null \
            || date -u -v-24H +%Y-%m-%dT%H:%M:%SZ 2>/dev/null \
            || python3 -c 'import datetime;print((datetime.datetime.utcnow()-datetime.timedelta(hours=24)).strftime("%Y-%m-%dT%H:%M:%SZ"))')"
TODAY_ISO="$(date -u +%Y-%m-%d)"
TODAY_COMPACT="$(date -u +%Y%m%d)"

SLICE_ACTION_A="Pilot lifecycle task A for slice-1"
SLICE_ACTION_B="Pilot lifecycle task B for slice-1"

# write_slice_fixture <slice-file> <owner_session> <heartbeat-iso> <version> <state-line-or-empty>
write_slice_fixture() {
    local f="$1" sess="$2" hb="$3" ver="$4" state_line="$5"
    {
        echo "---"
        echo "owner_session: $sess"
        echo "owner_label: \"\""
        echo "owner_agent: claude"
        echo "version: $ver"
        echo "last_updated: $TODAY_ISO"
        echo "heartbeat: $hb"
        [ -n "$state_line" ] && echo "$state_line"
        echo "remaining_actions:"
        echo "  - $SLICE_ACTION_A"
        echo "  - $SLICE_ACTION_B"
        echo "contract_pointers:"
        echo "  - .agent/contracts/slice-1-foo-${TODAY_COMPACT}.md"
        echo "---"
        echo "# Fixture slice status"
        echo
        echo "Synthetic per-slice status used only by tests/run-harness-lifecycle.sh."
    } > "$f"
}

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
    ' "$1" 2>/dev/null
}

# ── Assertion 1: handoff.sh --release <slice> ────────────────────────────────
# Start from a claimed baton (S1, fresh heartbeat, state: active). After
# `handoff.sh --release slice-1`, owner_session / owner_label / heartbeat
# must be empty and the frontmatter must carry `state: released`.
write_slice_fixture "$AGENT_ROOT/status/slice-1.md" "$S1" "$NOW_ISO" 4 "state: active"

AGENT_ROOT="$AGENT_ROOT" OWNER_SESSION="$S1" OWNER_LABEL="claude-A" \
    bash "$HANDOFF_SH" --release slice-1 >/dev/null 2>&1 || true

a1_owner="$(fm_get "$AGENT_ROOT/status/slice-1.md" owner_session)"
a1_label="$(fm_get "$AGENT_ROOT/status/slice-1.md" owner_label)"
a1_hb="$(fm_get "$AGENT_ROOT/status/slice-1.md" heartbeat)"
a1_state="$(fm_get "$AGENT_ROOT/status/slice-1.md" state)"

if [ -z "$a1_owner" ] && [ -z "$a1_label" ] && [ -z "$a1_hb" ] && [ "$a1_state" = "released" ]; then
    pass 1 "--release clears owner_session/owner_label/heartbeat and sets state: released"
else
    fail 1 "--release did not clear owner fields and set state: released (owner='$a1_owner' label='$a1_label' hb='$a1_hb' state='$a1_state')"
fi

# ── Assertion 2: state field semantics on claim ──────────────────────────────
# Sub-case A: baton with NO `state:` field. After a claim, frontmatter must
#             have `state: active`.
# Sub-case B: baton already at `state: released`. After a subsequent claim,
#             state must STILL be `released` (claim does not auto-flip).
write_slice_fixture "$AGENT_ROOT/status/slice-1.md" "" "" 0 ""
AGENT_ROOT="$AGENT_ROOT" OWNER_SESSION="$S1" OWNER_LABEL="claude-A" \
    bash "$HANDOFF_SH" claude slice-1 >/dev/null 2>&1 || true
a2_state_after_first_claim="$(fm_get "$AGENT_ROOT/status/slice-1.md" state)"

write_slice_fixture "$AGENT_ROOT/status/slice-1.md" "" "" 0 "state: released"
AGENT_ROOT="$AGENT_ROOT" OWNER_SESSION="$S2" OWNER_LABEL="claude-B" \
    bash "$HANDOFF_SH" claude slice-1 >/dev/null 2>&1 || true
a2_state_after_released_claim="$(fm_get "$AGENT_ROOT/status/slice-1.md" state)"

if [ "$a2_state_after_first_claim" = "active" ] \
    && [ "$a2_state_after_released_claim" = "released" ]; then
    pass 2 "claim writes state: active when absent; preserves state: released across reclaim"
else
    fail 2 "claim did not set state: active when absent (got '$a2_state_after_first_claim'), or did not preserve state: released across reclaim (got '$a2_state_after_released_claim')"
fi

# ── Assertion 3: handoff.sh auto-commit on contract+plan untracked pair ──────
# Sub-case A: clean tree with ONLY two untracked files (contract + plan for
#             this slice). Expect exactly one new commit whose message starts
#             "slice-1:" AND includes both files. Handoff exits 0.
# Sub-case B: dirty tracked file present. No new commit. One warning line on
#             stderr. Handoff still exits 0.

# Build a real git repo at $SANDBOX.
(
    cd "$SANDBOX" || exit 1
    git init -q
    git config user.email "lifecycle-test@example.invalid"
    git config user.name  "lifecycle-test"
    # Seed: commit the slice fixture so we have an initial commit and a
    # tracked file to dirty in sub-case B. The fixture also lets later
    # handoffs find slice-1.md.
    write_slice_fixture ".agent/status/slice-1.md" "" "" 0 ""
    echo "seed" > SEED_FILE.txt
    git add .agent/status/slice-1.md SEED_FILE.txt
    git commit -q -m "seed: initial fixture"
) || true

# Sub-case A — clean tree + two untracked .agent files.
contract_rel=".agent/contracts/slice-1-foo-${TODAY_COMPACT}.md"
plan_rel=".agent/plans/slice-1-foo-${TODAY_COMPACT}.md"
mkdir -p "$SANDBOX/.agent/contracts" "$SANDBOX/.agent/plans"
echo "# contract slice-1 foo" > "$SANDBOX/$contract_rel"
echo "# plan slice-1 foo"     > "$SANDBOX/$plan_rel"

commits_before_a=$(git -C "$SANDBOX" rev-list --count HEAD 2>/dev/null); commits_before_a=${commits_before_a:-0}
AGENT_ROOT="$AGENT_ROOT" OWNER_SESSION="$S1" OWNER_LABEL="claude-A" \
    bash "$HANDOFF_SH" claude slice-1 >/dev/null 2>&1
a3_rc_clean=$?
commits_after_a=$(git -C "$SANDBOX" rev-list --count HEAD 2>/dev/null); commits_after_a=${commits_after_a:-0}
new_commit_msg="$(git -C "$SANDBOX" log -1 --pretty=%s 2>/dev/null || true)"
new_commit_files="$(git -C "$SANDBOX" show --name-only --pretty='' HEAD 2>/dev/null || true)"

clean_ok=0
if [ "$a3_rc_clean" -eq 0 ] \
    && [ "$((commits_after_a - commits_before_a))" -eq 1 ] \
    && [[ "$new_commit_msg" == slice-1:* ]] \
    && grep -qF "$contract_rel" <<<"$new_commit_files" \
    && grep -qF "$plan_rel"     <<<"$new_commit_files"; then
    clean_ok=1
fi

# Sub-case B — dirty unrelated tracked file blocks auto-commit.
# Modify the tracked SEED_FILE.txt (and stage it) to count as dirty tracked.
echo "extra" >> "$SANDBOX/SEED_FILE.txt"
git -C "$SANDBOX" add SEED_FILE.txt >/dev/null 2>&1 || true

# Add a fresh pair of untracked .agent files (different name so we know it is
# the auto-commit code path we're inhibiting, not "nothing to commit").
contract_rel2=".agent/contracts/slice-1-bar-${TODAY_COMPACT}.md"
plan_rel2=".agent/plans/slice-1-bar-${TODAY_COMPACT}.md"
echo "# contract slice-1 bar" > "$SANDBOX/$contract_rel2"
echo "# plan slice-1 bar"     > "$SANDBOX/$plan_rel2"

commits_before_b=$(git -C "$SANDBOX" rev-list --count HEAD 2>/dev/null); commits_before_b=${commits_before_b:-0}
err_log_b="$TMP/handoff-dirty.err"
AGENT_ROOT="$AGENT_ROOT" OWNER_SESSION="$S1" OWNER_LABEL="claude-A" \
    bash "$HANDOFF_SH" claude slice-1 >/dev/null 2>"$err_log_b"
a3_rc_dirty=$?
commits_after_b=$(git -C "$SANDBOX" rev-list --count HEAD 2>/dev/null); commits_after_b=${commits_after_b:-0}
warn_lines=$(grep -cE 'auto.?commit|dirty|skip' "$err_log_b" 2>/dev/null)
warn_lines=${warn_lines:-0}

dirty_ok=0
if [ "$a3_rc_dirty" -eq 0 ] \
    && [ "$((commits_after_b - commits_before_b))" -eq 0 ] \
    && [ "$warn_lines" -ge 1 ]; then
    dirty_ok=1
fi

if [ "$clean_ok" -eq 1 ] && [ "$dirty_ok" -eq 1 ]; then
    pass 3 "auto-commit: clean tree -> 1 commit 'slice-1:' incl. contract+plan; dirty tracked -> no commit + stderr warning; rc=0 both"
else
    fail 3 "auto-commit: clean-tree path (ok=$clean_ok rc=$a3_rc_clean delta=$((commits_after_a-commits_before_a)) msg='$new_commit_msg') or dirty-tree path (ok=$dirty_ok rc=$a3_rc_dirty delta=$((commits_after_b-commits_before_b)) warn=$warn_lines) did not match contract"
fi

# ── Assertion 4: Stop hook missed-handoff warning ────────────────────────────
# Seed a session-marker dated NOW, a slice-1 baton whose owner_session matches
# the marker session AND whose heartbeat is 24h old. Invoke the Stop hook with
# session_id=<sid> on stdin. Expect the exact warning line on stderr.
SID="$S1"
NOW_EPOCH="$(date -u +%s)"
mkdir -p "$AGENT_ROOT/handoffs/state/session-markers"
echo "$NOW_EPOCH" > "$AGENT_ROOT/handoffs/state/session-markers/$SID.start"

write_slice_fixture "$AGENT_ROOT/status/slice-1.md" "$SID" "$DAY_AGO_ISO" 4 "state: active"

a4_out="$(
    echo "{\"session_id\":\"$SID\"}" \
        | AGENT_ROOT="$AGENT_ROOT" OWNER_SESSION="$SID" \
          bash "$STOP_HOOK" 2>&1 >/dev/null || true
)"

# Combine stderr+stdout capture above (1>/dev/null keeps only stderr in a4_out).
expected_line="[handoff-check] session ended without running handoff.sh for slice 'slice-1'"
if grep -qF "$expected_line" <<<"$a4_out"; then
    pass 4 "Stop hook prints missed-handoff warning for slice-1 when marker is fresh and heartbeat is 24h old"
else
    fail 4 "Stop hook did not print expected missed-handoff line for slice-1"
fi

# ── Verdict ──────────────────────────────────────────────────────────────────
echo
if [ "$FAILS" -eq 0 ]; then
    echo "lifecycle: 4/4 GREEN"
    exit 0
else
    echo "lifecycle: $FAILS/4 FAIL"
    exit 1
fi
