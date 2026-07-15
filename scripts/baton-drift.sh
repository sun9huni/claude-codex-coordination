#!/usr/bin/env bash
# baton-drift.sh — detect drift between per-slice batons and live reality.
#
# The batons (.agent/status/<slice>.md) are static prose, refreshed only by an
# explicit /handoff. Two ways they silently go stale:
#   (A) scheduler drift — a baton asserts a job is RUNNING / IN FLIGHT, but the
#       batch scheduler says that job is already terminal (COMPLETED/FAILED/...).
#       Only attempted when `sacct` (SLURM) is on PATH; skipped everywhere else.
#   (B) heartbeat age — the baton's heartbeat is older than a threshold, so its
#       prose may lag work that happened since (e.g. jobs finished, commits made).
#
# Read-only, best-effort, FAST, never exits non-zero. Prints one finding per
# line to stdout (empty output == no drift). The SessionStart / PreCompact
# hooks and handoff.sh surface this so the agent refreshes the baton instead of
# trusting a frozen snapshot.
#
# Portability: (B) heartbeat-age works on any POSIX bash. (A) uses an
# associative-array cache to avoid re-querying a job id, so it is gated on
# bash >= 4 AND `sacct` present — on macOS bash 3.2 (no sacct) it is simply a
# no-op, and the script still reports heartbeat drift.
#
# Usage: scripts/baton-drift.sh [--stale-days N]   (default N=2)
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
status_dir="${AGENT_ROOT:-$ROOT/.agent}/status"
[ -d "$status_dir" ] || exit 0

STALE_DAYS=2
[ "${1:-}" = "--stale-days" ] && [ -n "${2:-}" ] && STALE_DAYS="$2"

now_epoch="$(date -u +%s 2>/dev/null || echo 0)"

# Parse an ISO-8601 UTC timestamp to epoch seconds (GNU date -> python3),
# matching session-start-decay-check.sh so heartbeat drift works on macOS/BSD.
iso_to_epoch() {
  date -u -d "$1" +%s 2>/dev/null \
    || python3 -c "import datetime,sys; print(int(datetime.datetime.strptime(sys.argv[1],'%Y-%m-%dT%H:%M:%SZ').replace(tzinfo=datetime.timezone.utc).timestamp()))" "$1" 2>/dev/null \
    || echo 0
}

# Scheduler drift (A) needs both `sacct` and bash 4+ (for the dedup cache).
sched_drift=0
if command -v sacct >/dev/null 2>&1 && [ "${BASH_VERSINFO[0]:-0}" -ge 4 ]; then
  sched_drift=1
  # bounded sacct: cache state per job id so we never query the same id twice
  declare -A JOB_STATE
fi

job_state() {
  local jid="$1"
  [ -n "${JOB_STATE[$jid]:-}" ] && { printf '%s' "${JOB_STATE[$jid]}"; return; }
  local st=""
  st="$(timeout 4 sacct -j "$jid" -X -n -o State 2>/dev/null | head -1 | tr -d ' ' | sed 's/+$//')"
  JOB_STATE[$jid]="$st"
  printf '%s' "$st"
}

for f in "$status_dir"/*.md; do
  [ -f "$f" ] || continue
  base="$(basename "$f")"; [ "$base" = "README.md" ] && continue
  slice="${base%.md}"

  # ---- (A) scheduler drift: only look at lines that assert in-flight ---------
  if [ "$sched_drift" -eq 1 ]; then
    # job ids the baton ALREADY records as finished (appear on a line with a
    # completion marker). A RUNNING mention of such an id is just history, not
    # drift — so suppress it. Only flag jobs whose completion is UNRECORDED.
    ack_done=" "
    while IFS= read -r line; do
      while read -r jid; do
        [ -n "$jid" ] && ack_done="$ack_done$jid "
      done < <(printf '%s\n' "$line" | grep -oiE '(jobs?|array|job_id)[^0-9]{0,5}[0-9]{3,7}' | grep -oE '[0-9]{3,7}')
    done < <(grep -iE 'DONE|COMPLETED|완료|✅|KILL|무효|FAILED|CANCELL?ED' "$f" 2>/dev/null)
    # collect job ids that appear NEXT TO a running-assertion, deduped
    seen_ids=" "
    while IFS= read -r line; do
      # job ids = digits following job/jobs/array/job_id (3-7 digits)
      while read -r jid; do
        [ -z "$jid" ] && continue
        case "$seen_ids" in *" $jid "*) continue ;; esac
        seen_ids="$seen_ids$jid "
        # baton already records this job as finished elsewhere → not drift.
        case "$ack_done" in *" $jid "*) continue ;; esac
        st="$(job_state "$jid")"
        case "$st" in
          COMPLETED|FAILED|CANCELLED|TIMEOUT|OUT_OF_MEMORY|NODE_FAIL)
            echo "[$slice] DRIFT: baton asserts RUNNING/IN-FLIGHT but job $jid is $st — update the baton (re-run /handoff or ./scripts/status.sh $slice)"
            ;;
        esac
      done < <(printf '%s\n' "$line" | grep -oiE '(jobs?|array|job_id)[^0-9]{0,5}[0-9]{3,7}' | grep -oE '[0-9]{3,7}')
    done < <(grep -iE 'RUNNING|IN[ -]?FLIGHT|진행 중|in flight' "$f" 2>/dev/null)
  fi

  # ---- (B) heartbeat age ----------------------------------------------------
  hb="$(grep -m1 -E '^heartbeat:' "$f" 2>/dev/null | sed -E 's/^heartbeat:[[:space:]]*//; s/["'\'']//g')"
  # skip unclaimed/empty heartbeats
  if [ -n "$hb" ] && [ "$now_epoch" -gt 0 ]; then
    hb_epoch="$(iso_to_epoch "$hb")"
    if [ "$hb_epoch" -gt 0 ]; then
      age_days=$(( (now_epoch - hb_epoch) / 86400 ))
      if [ "$age_days" -ge "$STALE_DAYS" ]; then
        echo "[$slice] STALE: heartbeat ${age_days}d old (${hb}) — re-scan with ./scripts/status.sh $slice before trusting it"
      fi
    fi
  fi
done

# ---- (C) proactive watch: dead jobs + full disk branches ------------------
# Advisory snapshot from the FEA Stage-2 watch (scripts/fea/watch.py). Read-only,
# never actuates. Disk is always probed (per mergerfs branch); jobs are
# death-checked only when .agent/handoffs/state/fea-watched-jobs lists ids, so a
# session with nothing in flight pays only a fast df. watch.py is stdlib-only and
# imported directly (NOT `-m scripts.fea`, which would pull in pandas/numpy).
if command -v python3 >/dev/null 2>&1; then
  ( cd "$ROOT" && timeout 15 python3 - <<'PYEOF' 2>/dev/null
try:
    from scripts.fea import watch
    rep = watch.scan_once(job_ids=watch.read_watch_list())
    for f in rep.findings:
        glyph = "✗" if f.severity == "error" else "⚠"
        print(f"[watch] {glyph} [{f.code}] {f.subject}: {f.message}")
except Exception:
    pass
PYEOF
  ) || true
fi

# ---- (D) cross-slice dependency edges --------------------------------------
# Resolve any `depends_on:` edges declared in batons (scripts/baton-deps.py).
# Read-only: reports DEP-BLOCKED (upstream file not yet committed) or DEP-READY
# (committed+clean → downstream can proceed). Multi-repo aware (the workspace
# nests separate git repos). stdlib-only python; never actuates.
if command -v python3 >/dev/null 2>&1; then
  ( cd "$ROOT" && timeout 20 python3 scripts/baton-deps.py 2>/dev/null ) || true
fi

exit 0
