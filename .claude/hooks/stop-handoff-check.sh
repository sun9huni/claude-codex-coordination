#!/usr/bin/env bash
# Stop hook: warn if CURRENT.md is stale OR its yaml frontmatter is invalid.
# Non-blocking (always exit 0). Stderr is shown to Claude.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
current="$ROOT/.agent/handoffs/CURRENT.md"
[ -f "$current" ] || exit 0

# Portable mtime: GNU stat → BSD stat → Python fallback.
file_mtime() {
    stat -c %Y "$1" 2>/dev/null \
        || stat -f %m "$1" 2>/dev/null \
        || python3 -c "import os,sys; print(int(os.path.getmtime(sys.argv[1])))" "$1" 2>/dev/null \
        || echo ""
}

now=$(date +%s)
m=$(file_mtime "$current")
if [ -z "$m" ]; then
    # Can't read mtime — skip the stale-time check silently. The schema
    # check below still runs.
    age_min=0
else
    age_min=$(( (now - m) / 60 ))
fi

if [ "$age_min" -gt 60 ]; then
    {
        echo "[handoff-check] CURRENT.md was not updated in ${age_min}min."
        echo "Before stopping, update .agent/handoffs/CURRENT.md (or invoke /handoff)"
        echo "so the next agent can resume from files, not chat history."
    } >&2
fi

# Detect "agent forgot to bump version since last handoff snapshot".
# handoff.sh increments .agent/handoffs/CURRENT.md `version` and records
# `current_version` in state/latest/meta.txt. If they match at Stop time,
# either /handoff was never called this session OR no real changes were
# made. Both worth warning about.
latest_meta="$ROOT/.agent/handoffs/state/latest/meta.txt"
if [ -f "$latest_meta" ]; then
    snap_version=$(awk -F': *' '/^current_version:/ { print $2 }' "$latest_meta" | tr -d '[:space:]')
    fm_version=$(awk '
        /^---$/ { in_fm = !in_fm; next }
        in_fm && /^version:/ { print $2; exit }
    ' "$current" | tr -d '[:space:]')
    if [ -n "${snap_version:-}" ] && [ -n "${fm_version:-}" ] && [ "$snap_version" = "$fm_version" ]; then
        {
            echo "[handoff-check] CURRENT.md version ($fm_version) has not changed since the last snapshot."
            echo "Run /handoff or ./scripts/handoff.sh <agent> to record this session's state."
        } >&2
    fi
fi

# Schema validation of the yaml frontmatter.
#
# Customize: VALID_SLICES below is the set of slice names your project
# uses. Stop hook warns if active_slice is outside the set. Add your
# slices as you create them under .agent/status/ and the WORKFLOW.md
# §1 routing table.
python3 - "$current" <<'PY' 2>&1 1>&2 || true
import sys, re, datetime
try:
    import yaml
except ImportError:
    sys.exit(0)  # yaml not installed; skip rather than fail noisily.

# === Customize for your project ===
VALID_SLICES = set()   # e.g. {"backend", "frontend", "ml-pipeline"} — fill as you add slices.
VALID_AGENTS = {"claude", "codex", "cursor", "human"}
MAX_AGE_DAYS = 7
# ==================================

path = sys.argv[1]
text = open(path).read()
m = re.match(r'\A---\s*\n(.*?)\n---\s*\n', text, re.DOTALL)
if not m:
    print(f"[handoff-check] CURRENT.md missing yaml frontmatter. Add schema_version: 1 block at top.", file=sys.stderr)
    sys.exit(0)

try:
    fm = yaml.safe_load(m.group(1)) or {}
except yaml.YAMLError as e:
    print(f"[handoff-check] CURRENT.md frontmatter is invalid YAML: {e}", file=sys.stderr)
    sys.exit(0)

errs = []
required = ["owner_agent", "last_updated", "active_slice", "remaining_actions"]
for k in required:
    if k not in fm:
        errs.append(f"missing required field: {k}")

if "owner_agent" in fm and str(fm["owner_agent"]).strip() not in VALID_AGENTS:
    errs.append(f"owner_agent must be one of {sorted(VALID_AGENTS)} (got: {fm['owner_agent']!r})")

if VALID_SLICES and "active_slice" in fm:
    slc = str(fm["active_slice"]).strip()
    if slc not in VALID_SLICES:
        errs.append(f"active_slice not in {sorted(VALID_SLICES)} (got: {slc!r}). Add it here once you define it.")

if "remaining_actions" in fm:
    ra = fm["remaining_actions"]
    if not isinstance(ra, list):
        errs.append("remaining_actions must be a list")
    elif not (1 <= len(ra) <= 3):
        errs.append(f"remaining_actions must have 1-3 items (got: {len(ra)})")

if "last_updated" in fm:
    try:
        d = fm["last_updated"]
        if isinstance(d, str):
            d = datetime.date.fromisoformat(d)
        age = (datetime.date.today() - d).days
        if age > MAX_AGE_DAYS:
            errs.append(f"last_updated is {age} days old (>{MAX_AGE_DAYS}d). Refresh it before handoff.")
    except (ValueError, TypeError):
        errs.append(f"last_updated not a valid ISO date: {fm.get('last_updated')!r}")

if errs:
    print("[handoff-check] CURRENT.md frontmatter validation:", file=sys.stderr)
    for e in errs:
        print(f"  - {e}", file=sys.stderr)
PY

exit 0
