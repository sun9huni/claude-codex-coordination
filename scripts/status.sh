#!/usr/bin/env bash
# status.sh — read-only per-slice status scan.
# Usage: ./scripts/status.sh           # list slices
#        ./scripts/status.sh <slice>   # scan one slice
#        ./scripts/status.sh all       # scan every slice
#
# Sources of truth:
#   ~/.cursor/plans/*.plan.md         — recent Cursor plans
#   /mnt/data/.../shared/outputs/     — production-like run outputs
#   /home/ubuntu/FKSFold-Boltz_Advancement/  — local git tree
#   /home/ubuntu/arl-threads-coscientist/    — ARL repo

set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CURSOR_PLANS="$HOME/.cursor/plans"
LOCAL_REPO="$ROOT/FKSFold-Boltz_Advancement"
SHARED="/mnt/data/users/ubuntu/workspace/FKSFold-Boltz_Advancement_shared"
ARL_REPO="$ROOT/arl-threads-coscientist"

SLICES="fragmap mmgbsa vav1 aigen-fold-core arl harness fea m-relativity"

today() { date -u +%Y-%m-%d; }

section() { printf '\n=== %s ===\n' "$1"; }

# List N newest matches; each line "<mtime-iso> <path>".
recent_files() {
  local pattern_dir="$1" pattern="$2" n="${3:-5}"
  [ -d "$pattern_dir" ] || return 0
  find "$pattern_dir" -maxdepth 1 -type f -name "$pattern" -printf '%T@ %TY-%Tm-%Td %p\n' 2>/dev/null \
    | sort -rn | head -"$n" | awk '{print $2, $3}'
}

recent_dirs() {
  local pattern_dir="$1" pattern="$2" n="${3:-5}"
  [ -d "$pattern_dir" ] || return 0
  find "$pattern_dir" -maxdepth 1 -type d -name "$pattern" -printf '%T@ %TY-%Tm-%Td %p\n' 2>/dev/null \
    | sort -rn | head -"$n" | awk '{print $2, $3}'
}

slice_fragmap() {
  section "FragMap / 9NFR — $(today)"
  echo "[plans] last 5 fragmap*/target_*/9nfr* plans:"
  recent_files "$CURSOR_PLANS" "fragmap*.plan.md" 5
  recent_files "$CURSOR_PLANS" "target_*.plan.md" 5
  echo
  echo "[outputs] last 5 fragmap_9nfr_* dirs (shared):"
  recent_dirs "$SHARED/outputs" "fragmap_9nfr_*" 5
  echo
  echo "[analysis] last 5 fragmap/9nfr scripts (local):"
  if [ -d "$LOCAL_REPO/analysis" ]; then
    find "$LOCAL_REPO/analysis" -maxdepth 1 -type f \
      \( -name "*fragmap*" -o -name "*9nfr*" \) -printf '%TY-%Tm-%Td %p\n' \
      2>/dev/null | sort -r | head -5
  fi
}

slice_mmgbsa() {
  section "MMGBSA / SLURM — $(today)"
  echo "[outputs] last 5 mmgbsa_* / custom_* dirs (shared):"
  recent_dirs "$SHARED/outputs" "mmgbsa_*" 5
  recent_dirs "$SHARED/outputs" "custom_*" 5
  echo
  echo "[stage counts] per recent MMGBSA dir:"
  if [ -d "$SHARED/outputs" ]; then
    for d in $(find "$SHARED/outputs" -maxdepth 1 -type d -name "mmgbsa_*" \
                 -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -3 | cut -d' ' -f2-); do
      printf '  %s\n' "$(basename "$d")"
      for f in ready_for_mmpbsa_prod.tsv failed_stage.tsv md_done.tsv mmpbsa_done.tsv; do
        if [ -f "$d/$f" ]; then
          # subtract 1 for header if file is non-empty
          n=$(wc -l <"$d/$f" 2>/dev/null || echo 0)
          [ "$n" -gt 0 ] && n=$((n-1))
          printf '    %-30s %s rows\n' "$f" "$n"
        fi
      done
    done
  fi
}

slice_vav1() {
  section "VAV1 ranking — $(today)"
  local L="$LOCAL_REPO/scripts/vav1_ensemble_rank.py"
  local S="$SHARED/scripts/vav1_ensemble_rank.py"
  echo "[divergence] vav1_ensemble_rank.py:"
  [ -f "$L" ] && echo "  local : present  ($(stat -c '%y' "$L" | cut -d' ' -f1))" \
              || echo "  local : MISSING (deleted in worktree)"
  [ -f "$S" ] && echo "  shared: present  ($(stat -c '%y' "$S" | cut -d' ' -f1))" \
              || echo "  shared: MISSING"
  echo
  echo "[configs] *ranking*.yaml (local + shared):"
  for base in "$LOCAL_REPO/configs/vav1_pipeline" "$SHARED/configs/vav1_pipeline"; do
    [ -d "$base" ] || continue
    find "$base" -maxdepth 1 -type f -name '*ranking*.yaml' \
      -printf '%TY-%Tm-%Td %p\n' 2>/dev/null | sort -r | head -5
  done
}

slice_aigen_fold_core() {
  section "AIGEN-Fold core — $(today)"
  if [ -d "$LOCAL_REPO/.git" ]; then
    echo "[git] branch: $(git -C "$LOCAL_REPO" branch --show-current 2>/dev/null)"
    echo "[git] status --short (first 15):"
    git -C "$LOCAL_REPO" status --short 2>/dev/null | head -15
    local total
    total=$(git -C "$LOCAL_REPO" status --short 2>/dev/null | wc -l)
    echo "[git] total dirty entries: $total"
  else
    echo "[git] no .git in $LOCAL_REPO"
  fi
  echo
  echo "[recent edits] last 5 src/analysis files modified:"
  for sub in src analysis; do
    [ -d "$LOCAL_REPO/$sub" ] || continue
    find "$LOCAL_REPO/$sub" -type f -name '*.py' -printf '%TY-%Tm-%Td %p\n' \
      2>/dev/null | sort -r | head -3
  done
}

slice_arl() {
  section "ARL Co-Scientist — $(today)"
  if [ ! -d "$ARL_REPO" ]; then echo "  not present"; return; fi
  echo "[milestones] last 5 PHASE*.md by mtime:"
  find "$ARL_REPO" -maxdepth 1 -type f -name 'PHASE*.md' \
    -printf '%TY-%Tm-%Td %f\n' 2>/dev/null | sort -r | head -5
  echo
  echo "[git] branch: $(git -C "$ARL_REPO" branch --show-current 2>/dev/null || echo 'n/a')"
  local dirty
  dirty=$(git -C "$ARL_REPO" status --short 2>/dev/null | wc -l)
  echo "[git] dirty entries: $dirty"
  echo
  echo "[hint] gate: cd arl-threads-coscientist && make check"
}

slice_harness() {
  section "Harness / .agent tooling — $(today)"
  echo "[contracts] last 5 harness-* contracts:"
  find "$ROOT/.agent/contracts" -maxdepth 1 -type f -name 'harness-*.md' \
    -printf '%TY-%Tm-%Td %f\n' 2>/dev/null | sort -r | head -5
  echo
  echo "[skills] last 5 .claude/skills SKILL.md by mtime:"
  find "$ROOT/.claude/skills" -type f -name 'SKILL.md' \
    -printf '%TY-%Tm-%Td %p\n' 2>/dev/null | sort -r | head -5
  echo
  echo "[skills] last 5 team skills by mtime:"
  find "$ROOT/skills" -type f -name 'SKILL.md' \
    -printf '%TY-%Tm-%Td %p\n' 2>/dev/null | sort -r | head -5
  echo
  echo "[skills] last 5 Codex mirror skills by mtime:"
  find "$ROOT/.codex/skills" -type f -name 'SKILL.md' \
    -printf '%TY-%Tm-%Td %p\n' 2>/dev/null | sort -r | head -5
  echo
  echo "[git] home repo dirty entries: $(git -C "$ROOT" status --short 2>/dev/null | wc -l)"
  echo "[git] last 5 harness commits:"
  git -C "$ROOT" log --oneline -5 --grep='harness' 2>/dev/null | head -5
}

# ── index mode: regenerate CURRENT.md as a DERIVED lab-wide index ─────────────
# Scans every $AGENT_DIR/status/*.md (except README.md), parses the per-slice
# YAML frontmatter (schema in .agent/status/README.md), and renders
# $AGENT_DIR/handoffs/CURRENT.md as a generated index: one table row per slice
# plus a per-slice remaining_actions section. CRITICAL anti-leak property: a
# slice's actions appear ONLY under that slice. Write is atomic (.tmp + mv -f)
# so a parse failure leaves the prior CURRENT.md intact; zero status files is a
# hard error that does NOT clobber an existing CURRENT.md.
#
# AGENT_ROOT seam: default (unset) = the repo's own .agent, matching handoff.sh.
index_mode() {
  local AGENT_DIR="${AGENT_ROOT:-$ROOT/.agent}"
  local status_dir="$AGENT_DIR/status"
  local handoff_dir="$AGENT_DIR/handoffs"
  local current="$handoff_dir/CURRENT.md"

  if [ ! -d "$status_dir" ]; then
    echo "[index] error: status dir not found: $status_dir" >&2
    exit 1
  fi

  # Collect status files (exclude README.md). Sorted for stable ordering.
  local files=()
  local f
  for f in "$status_dir"/*.md; do
    [ -e "$f" ] || continue
    [ "$(basename "$f")" = "README.md" ] && continue
    files+=("$f")
  done

  if [ "${#files[@]}" -eq 0 ]; then
    echo "[index] error: no status files found in $status_dir — refusing to clobber $current" >&2
    exit 1
  fi

  mkdir -p "$handoff_dir"
  local tmp="$current.tmp.$$"

  # Render with python3: robust YAML frontmatter parse (block + flow lists),
  # action truncation, heartbeat-freshness annotation. pyyaml if present,
  # else a minimal built-in frontmatter parser (no hard external dep).
  if AGENT_GENERATOR="scripts/status.sh index" python3 - "$tmp" "${files[@]}" <<'PYEOF'
import datetime
import os
import sys

tmp_path = sys.argv[1]
files = sys.argv[2:]
generator = os.environ.get("AGENT_GENERATOR", "scripts/status.sh index")

try:
    import yaml  # pyyaml, optional

    # Keep ISO timestamps as plain strings (don't let pyyaml coerce heartbeat /
    # last_updated into datetime objects, which would lose the original `...Z`
    # text and break our freshness match). A private SafeLoader subclass with
    # the implicit timestamp + int resolvers dropped leaves scalars as strings.
    class _StrLoader(yaml.SafeLoader):
        pass

    _StrLoader.yaml_implicit_resolvers = {
        ch: [(tag, regexp) for tag, regexp in resolvers
             if tag not in ("tag:yaml.org,2002:timestamp",)]
        for ch, resolvers in yaml.SafeLoader.yaml_implicit_resolvers.items()
    }
except Exception:
    yaml = None
    _StrLoader = None


def split_frontmatter(text):
    """Return (frontmatter_text, body). Frontmatter is the first --- ... --- block."""
    lines = text.splitlines()
    if not lines or lines[0].strip() != "---":
        return "", text
    fm = []
    for i in range(1, len(lines)):
        if lines[i].strip() == "---":
            return "\n".join(fm), "\n".join(lines[i + 1:])
        fm.append(lines[i])
    return "\n".join(fm), ""


def manual_parse(fm_text):
    """Minimal YAML-frontmatter parser: scalars + simple block/flow lists.

    Handles the per-slice schema (status/README.md) without pyyaml:
      key: value          -> scalar (quotes stripped)
      key: []             -> empty list
      key:                -> followed by '  - item' block entries
    """
    data = {}
    lines = fm_text.splitlines()
    i = 0

    def strip_quotes(v):
        v = v.strip()
        if len(v) >= 2 and v[0] == v[-1] and v[0] in ("'", '"'):
            return v[1:-1]
        return v

    def split_flow(inner):
        # Quote-aware comma split for flow lists, so a quoted item containing
        # a comma ("do A, then B") stays one item — matching the pyyaml path.
        items, buf, quote = [], [], None
        for ch in inner:
            if quote:
                if ch == quote:
                    quote = None
                buf.append(ch)
            elif ch in ("'", '"'):
                quote = ch
                buf.append(ch)
            elif ch == ",":
                items.append("".join(buf))
                buf = []
            else:
                buf.append(ch)
        items.append("".join(buf))
        return [strip_quotes(x) for x in items]

    while i < len(lines):
        line = lines[i]
        if not line.strip() or line.lstrip().startswith("#"):
            i += 1
            continue
        if ":" in line and not line.lstrip().startswith("- "):
            key, _, rest = line.partition(":")
            key = key.strip()
            rest = rest.strip()
            if rest == "" :
                # Possible block list following at deeper indent.
                items = []
                j = i + 1
                while j < len(lines):
                    nxt = lines[j]
                    if nxt.strip().startswith("- "):
                        items.append(strip_quotes(nxt.strip()[2:]))
                        j += 1
                    elif nxt.strip() == "":
                        j += 1
                    else:
                        break
                data[key] = items if items else ""
                i = j
                continue
            elif rest in ("[]", "[ ]"):
                data[key] = []
                i += 1
                continue
            elif rest.startswith("[") and rest.endswith("]"):
                inner = rest[1:-1].strip()
                data[key] = split_flow(inner) if inner else []
                i += 1
                continue
            else:
                data[key] = strip_quotes(rest)
                i += 1
                continue
        i += 1
    return data


def parse_frontmatter(text):
    fm_text, _ = split_frontmatter(text)
    if not fm_text.strip():
        return {}
    if yaml is not None:
        try:
            loaded = yaml.load(fm_text, Loader=_StrLoader)
            if isinstance(loaded, dict):
                return loaded
        except Exception:
            pass
    return manual_parse(fm_text)


def as_list(v):
    if v is None or v == "":
        return []
    if isinstance(v, list):
        return [str(x).strip() for x in v if str(x).strip()]
    return [str(v).strip()]


def scalar(v):
    if v is None:
        return ""
    return str(v).strip()


def short_session(sess):
    return sess.split("-", 1)[0] if "-" in sess else sess[:8]


def truncate(s, n=70):
    s = " ".join(s.split())
    return s if len(s) <= n else s[: n - 1] + "…"


def cell(s):
    # Escape pipes (and flatten newlines) so free-text values can never split
    # a Markdown table row into extra columns. Table cells only — the per-slice
    # bullet section below renders raw text and needs no escaping.
    return str(s).replace("|", "\\|").replace("\n", " ")


def heartbeat_fresh(hb):
    """Best-effort: True if hb ISO timestamp is within 30 minutes of now (UTC)."""
    if not hb:
        return None
    s = hb.strip().replace("Z", "").replace("T", " ")
    s = s.split("+")[0].strip()
    for fmt in ("%Y-%m-%d %H:%M:%S", "%Y-%m-%d %H:%M", "%Y-%m-%d"):
        try:
            t = datetime.datetime.strptime(s, fmt)
            # Aware-UTC now, stripped back to naive so the subtraction against
            # the naive strptime result stays type-consistent (utcnow() is
            # deprecated on 3.12+).
            now = datetime.datetime.now(datetime.timezone.utc).replace(tzinfo=None)
            return (now - t).total_seconds() <= 30 * 60
        except ValueError:
            continue
    return None


slices = []
for path in sorted(files):
    name = os.path.splitext(os.path.basename(path))[0]
    try:
        with open(path, "r", encoding="utf-8") as fh:
            text = fh.read()
    except OSError as exc:
        sys.stderr.write("[index] error: cannot read %s: %s\n" % (path, exc))
        sys.exit(1)
    fm = parse_frontmatter(text)
    slices.append(
        {
            "slice": name,
            "owner_session": scalar(fm.get("owner_session")),
            "owner_label": scalar(fm.get("owner_label")),
            "owner_agent": scalar(fm.get("owner_agent")),
            "version": scalar(fm.get("version")),
            "last_updated": scalar(fm.get("last_updated")),
            "heartbeat": scalar(fm.get("heartbeat")),
            "state": scalar(fm.get("state")) or "active",
            "remaining_actions": as_list(fm.get("remaining_actions")),
            "contract_pointers": as_list(fm.get("contract_pointers")),
        }
    )

now_iso = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
out = []
out.append("<!-- GENERATED by `%s` — do not hand-edit." % generator)
out.append("     Edit the per-slice files in .agent/status/<slice>.md instead, then regenerate. -->")
out.append("<!-- generated_at: %s -->" % now_iso)
out.append("")
out.append("# CURRENT — derived lab-wide slice index")
out.append("")
out.append(
    "This file is a DERIVED index of every `.agent/status/<slice>.md`. "
    "Each slice's owner/heartbeat/next-action is sourced from that slice's own "
    "status file; do not hand-edit (see `.agent/status/README.md`)."
)
out.append("")
out.append("| slice | owner | agent | state | last_updated | heartbeat | next action |")
out.append("|---|---|---|---|---|---|---|")

for s in slices:
    sess = s["owner_session"]
    label = s["owner_label"]
    if sess:
        # Owner cell carries the FULL owner_session so a test can grep it.
        if label:
            owner_cell = "%s (%s)" % (label, sess)
        else:
            owner_cell = "%s (%s)" % (short_session(sess), sess)
    else:
        owner_cell = "unclaimed"

    hb = s["heartbeat"]
    fresh = heartbeat_fresh(hb)
    if not hb:
        hb_cell = "—"
    elif fresh is True:
        hb_cell = "live (%s)" % hb
    elif fresh is False:
        hb_cell = hb
    else:
        hb_cell = hb

    actions = s["remaining_actions"]
    next_action = truncate(actions[0]) if actions else "—"

    state = s["state"]
    if state == "active":
        state_cell = "active"
    elif state == "closed":
        state_cell = "🔒 closed"
    elif state == "released":
        state_cell = "📦 released"
    else:
        state_cell = state

    out.append(
        "| %s | %s | %s | %s | %s | %s | %s |"
        % (
            cell(s["slice"]),
            cell(owner_cell),
            cell(s["owner_agent"] or "—"),
            cell(state_cell),
            cell(s["last_updated"] or "—"),
            cell(hb_cell),
            cell(next_action),
        )
    )

out.append("")
out.append("## Per-slice remaining actions")
out.append("")
# CRITICAL anti-leak: each slice's actions are emitted ONLY under that slice.
for s in slices:
    sess = s["owner_session"]
    owner_note = sess if sess else "unclaimed"
    state = s["state"]
    if state == "active":
        state_header = "active"
    elif state == "closed":
        state_header = "🔒 closed"
    elif state == "released":
        state_header = "📦 released"
    else:
        state_header = state
    out.append("### %s — %s" % (s["slice"], state_header))
    out.append("")
    out.append("- owner_session: %s" % owner_note)
    if s["owner_label"]:
        out.append("- owner_label: %s" % s["owner_label"])
    actions = s["remaining_actions"]
    if actions:
        out.append("- remaining_actions:")
        for a in actions:
            out.append("  - %s" % a)
    else:
        out.append("- remaining_actions: (none)")
    if s["contract_pointers"]:
        out.append("- contract_pointers:")
        for c in s["contract_pointers"]:
            out.append("  - %s" % c)
    out.append("")

with open(tmp_path, "w", encoding="utf-8") as fh:
    fh.write("\n".join(out).rstrip("\n") + "\n")
PYEOF
  then
    mv -f "$tmp" "$current"
    echo "[index] wrote: $current (${#files[@]} slices)"
  else
    rm -f "$tmp"
    echo "[index] error: render failed — $current left unchanged" >&2
    exit 1
  fi
}

list_slices() {
  echo "Usage: $0 <slice>"
  echo "Slices:"
  for s in $SLICES; do echo "  - $s"; done
  echo "  - all"
  echo
  echo "Stored summaries: .agent/status/<slice>.md"
}

slice_fea() {
  section "FEA — AIGEN-Fold Experiment Autopilot — $(today)"
  echo "[contracts/plans] last 5 experiment-autopilot files:"
  find "$ROOT/.agent/contracts" "$ROOT/.agent/plans" -maxdepth 1 -type f \
    -name '*experiment-autopilot*' -printf '%TY-%Tm-%Td %p\n' 2>/dev/null \
    | sort -r | head -5
  echo
  echo "[code] last 5 scripts/fea files by mtime:"
  find "$ROOT/scripts/fea" -type f -name '*.py' \
    -printf '%TY-%Tm-%Td %p\n' 2>/dev/null | sort -r | head -5
  echo
  echo "[git] last 5 autopilot/fea commits:"
  git -C "$ROOT" log --oneline -5 --grep='autopilot' 2>/dev/null | head -5
}

main() {
  local arg="${1:-}"
  case "$arg" in
    "" | "-h" | "--help") list_slices ;;
    all)
      slice_fragmap
      slice_mmgbsa
      slice_vav1
      slice_aigen_fold_core
      slice_arl
      slice_harness
      slice_fea
      ;;
    index | --index) index_mode ;;
    fragmap)       slice_fragmap ;;
    mmgbsa)        slice_mmgbsa ;;
    vav1)          slice_vav1 ;;
    aigen-fold-core)  slice_aigen_fold_core ;;
    arl)           slice_arl ;;
    harness)       slice_harness ;;
    fea)           slice_fea ;;
    *) echo "unknown slice: $arg" >&2; list_slices >&2; exit 2 ;;
  esac
}

main "$@"
