#!/usr/bin/env bash
# watch_cron.sh — headless periodic proactive watch (FEA Stage-2, C2).
#
# Runs ONE scan, refreshes the findings marker, and logs error-severity findings
# so that BETWEEN sessions the marker reflects current reality (dead jobs, full
# disk branches) instead of a stale last-session snapshot. The next session
# surfaces it automatically via baton-drift.sh branch (C).
#
# Headless-safe by construction:
#   - explicit PATH (cron's PATH is minimal; sacct/df live in /bin)
#   - system python3 (watch.py is stdlib-only — no conda env needed)
#   - liveness via sacct/df only, never a file mtime (mergerfs-stale lesson)
# Read-only / advisory: it NEVER scancel/sbatch/resubmits. Fully reversible —
# remove the crontab line to stop it (see the install recipe in the slice baton).
#
# Intended crontab line (every 15 min):
#   */15 * * * * /home/ubuntu/scripts/fea/watch_cron.sh >/dev/null 2>&1

export PATH="/usr/local/bin:/usr/bin:/bin"
ROOT="/home/ubuntu"
PY="/usr/bin/python3"
STATE="$ROOT/.agent/handoffs/state"
LOG="$STATE/fea-watch.log"

cd "$ROOT" 2>/dev/null || exit 0
mkdir -p "$STATE" 2>/dev/null

out="$(timeout 90 "$PY" - <<'PYEOF' 2>/dev/null
import sys

sys.path.insert(0, "/home/ubuntu")
from scripts.fea import watch

rep = watch.scan_once(job_ids=watch.read_watch_list())
watch.write_marker(rep)  # overwrite-semantics: self-clears when clean
for f in rep.findings:
    if f.severity == "error":
        print(f"[{f.code}] {f.subject}: {f.message}")
PYEOF
)"

ts="$(date -u +%FT%TZ 2>/dev/null || echo unknown)"
if [ -n "$out" ]; then
  # Sparse log (only fires on error findings); keep the tail bounded.
  while IFS= read -r line; do
    echo "$ts $line"
  done <<< "$out" >> "$LOG"
  tail -n 200 "$LOG" > "$LOG.tmp" 2>/dev/null && mv -f "$LOG.tmp" "$LOG"
  # cron mails stdout to the user if an MTA is configured; the marker + log are
  # the durable surfaces regardless.
  echo "$out"
fi
exit 0
