#!/usr/bin/env bash
# status.sh — read-only slice status: index + discovery scan.
#
# Two modes, both driven entirely by the per-slice status files under
# $AGENT_DIR/status/*.md (no hardcoded slice names, no external paths):
#
#   ./scripts/status.sh            # discovery scan: list every slice + summary
#   ./scripts/status.sh <slice>    # one slice's status-file summary
#   ./scripts/status.sh index      # regenerate the derived CURRENT.md index
#
# A "slice" is just a `$AGENT_DIR/status/<slice>.md` file (README.md excluded).
# The discovery scan enumerates those files and prints each slice's name plus
# its `last_updated`, `heartbeat`, and first `remaining_actions` entry, parsed
# from the YAML frontmatter (schema in .agent/status/README.md).

set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# AGENT_ROOT seam: default (unset) = the repo's own .agent, matching handoff.sh.
AGENT_DIR="${AGENT_ROOT:-$ROOT/.agent}"

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
                data[key] = [strip_quotes(x) for x in inner.split(",")] if inner else []
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


def heartbeat_fresh(hb):
    """Best-effort: True if hb ISO timestamp is within 30 minutes of now (UTC)."""
    if not hb:
        return None
    s = hb.strip().replace("Z", "").replace("T", " ")
    s = s.split("+")[0].strip()
    for fmt in ("%Y-%m-%d %H:%M:%S", "%Y-%m-%d %H:%M", "%Y-%m-%d"):
        try:
            t = datetime.datetime.strptime(s, fmt)
            now = datetime.datetime.utcnow()
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
            "remaining_actions": as_list(fm.get("remaining_actions")),
            "contract_pointers": as_list(fm.get("contract_pointers")),
        }
    )

now_iso = datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ")
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
out.append("| slice | owner | agent | last_updated | heartbeat | next action |")
out.append("|---|---|---|---|---|---|")

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

    out.append(
        "| %s | %s | %s | %s | %s | %s |"
        % (
            s["slice"],
            owner_cell,
            s["owner_agent"] or "—",
            s["last_updated"] or "—",
            hb_cell,
            next_action,
        )
    )

out.append("")
out.append("## Per-slice remaining actions")
out.append("")
# CRITICAL anti-leak: each slice's actions are emitted ONLY under that slice.
for s in slices:
    sess = s["owner_session"]
    owner_note = sess if sess else "unclaimed"
    out.append("### %s" % s["slice"])
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

# ── frontmatter field extractor ───────────────────────────────────────────────
# Pull a single scalar field, or the first `remaining_actions` list entry, from
# a status file's YAML frontmatter. Pure awk so the discovery scan needs no
# python. `field` is a key name, or the special token `first_action`.
fm_field() {
  local file="$1" field="$2"
  awk -v want="$field" '
    NR == 1 && $0 ~ /^---[[:space:]]*$/ { infm = 1; next }
    infm && $0 ~ /^---[[:space:]]*$/    { exit }
    !infm { next }

    # Special: first item of the remaining_actions block list.
    want == "first_action" {
      if ($0 ~ /^remaining_actions[[:space:]]*:/) { inact = 1; next }
      if (inact) {
        if ($0 ~ /^[[:space:]]*-[[:space:]]/) {
          line = $0
          sub(/^[[:space:]]*-[[:space:]]*/, "", line)
          gsub(/^["'\'']|["'\'']$/, "", line)
          print line
          exit
        }
        if ($0 ~ /^[^[:space:]]/) { exit }   # next key — no items found
      }
      next
    }

    # Scalar key: value
    $0 ~ ("^" want "[[:space:]]*:") {
      line = $0
      sub(/^[^:]*:[[:space:]]*/, "", line)
      gsub(/^["'\'']|["'\'']$/, "", line)
      print line
      exit
    }
  ' "$file"
}

# Print a one-slice summary block from its status file.
scan_one() {
  local slice="$1"
  local status_dir="$AGENT_DIR/status"
  local file="$status_dir/$slice.md"
  if [ ! -f "$file" ]; then
    echo "unknown slice: $slice (no $file)" >&2
    list_slices >&2
    exit 2
  fi
  local lu hb act
  lu="$(fm_field "$file" last_updated)"
  hb="$(fm_field "$file" heartbeat)"
  act="$(fm_field "$file" first_action)"
  echo "=== $slice ==="
  echo "  last_updated : ${lu:-—}"
  echo "  heartbeat    : ${hb:-—}"
  echo "  next action  : ${act:-—}"
  echo "  status file  : $file"
}

# Discovery scan: enumerate every $AGENT_DIR/status/*.md (except README.md) and
# print a per-slice summary. No hardcoded slice names.
list_slices() {
  local status_dir="$AGENT_DIR/status"
  if [ ! -d "$status_dir" ]; then
    echo "[scan] error: status dir not found: $status_dir" >&2
    exit 1
  fi
  echo "Slices (from $status_dir):"
  echo
  local f any=0
  for f in "$status_dir"/*.md; do
    [ -e "$f" ] || continue
    [ "$(basename "$f")" = "README.md" ] && continue
    any=1
    local slice
    slice="$(basename "$f" .md)"
    scan_one "$slice"
    echo
  done
  if [ "$any" -eq 0 ]; then
    echo "  (no status files found)"
  fi
  echo "Index view: $0 index  →  regenerates $AGENT_DIR/handoffs/CURRENT.md"
}

main() {
  local arg="${1:-}"
  case "$arg" in
    "" | "-h" | "--help") list_slices ;;
    index | --index)      index_mode ;;
    *)                    scan_one "$arg" ;;
  esac
}

main "$@"
