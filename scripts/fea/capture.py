"""Gated draft generators for FragMap/FEA post-flight capture.

``draft_baton`` produces a *draft* of the slice status baton with the FEA
gate verdict folded into ``remaining_actions`` as a ``DECISION:`` line. It
NEVER writes the live baton — output goes to ``<baton>.fea-draft`` and is
returned as a string for review/apply.

Standard library + the house frontmatter parser only. NO network, NO Notion.
"""

from __future__ import annotations

import datetime
import json
import os
import re
from pathlib import Path

from scripts.notion_sync import _parse_frontmatter


def _replace_scalar(line: str, key: str, value: str) -> str:
    """Replace the value of a ``key: value`` frontmatter scalar line.

    Preserves the leading ``key:`` token (and any leading whitespace);
    swaps only the value portion. If the line is not the named key, returns
    it unchanged.
    """
    m = re.match(rf"^(\s*{re.escape(key)}:\s*)(.*)$", line)
    if not m:
        return line
    return f"{m.group(1)}{value}"


def _first_list_item_line(gate_rows: list[dict], job_dir: str) -> str:
    """Build the new ``DECISION:`` remaining_actions item (incl. indent+quotes).

    Double-quoted to survive the apostrophe/colon-rich neighbours; keeps the
    summary punctuation simple so no embedded double-quotes are needed.
    """
    row = gate_rows[0] if gate_rows else {}
    metric = row.get("metric", "")
    oof_rho = row.get("oof_rho", "")
    perm_p = row.get("perm_p", "")
    raw_rho = row.get("raw_rho", "")
    verdict = row.get("verdict", "")
    summary = (
        f"DECISION: FEA gate verdict {verdict} on {os.path.basename(job_dir)} "
        f"— {metric} oof_rho={oof_rho} perm_p={perm_p} (raw={raw_rho}); "
        f"review fragmap.md.fea-draft & apply."
    )
    return f'  - "{summary}"'


def draft_baton(card, baton_path: str | None = None) -> str:
    """Draft a version-bumped baton with the FEA gate verdict prepended.

    Reads the current ``version`` via the house frontmatter parser, then
    applies TARGETED line edits to the frontmatter block only (version,
    last_updated, heartbeat, and one new first ``remaining_actions`` item).
    Everything else is preserved verbatim. Writes the draft to
    ``<baton_path>.fea-draft`` (never the live baton) and returns the text.
    """
    if baton_path is None:
        baton_path = f".agent/status/{card.slice_name}.md"

    fm = _parse_frontmatter(Path(baton_path))
    current_version = int(fm["version"])

    text = Path(baton_path).read_text(encoding="utf-8")
    lines = text.splitlines(keepends=True)

    # Locate the frontmatter block: first two `---` delimiter lines.
    delim_idxs = [i for i, ln in enumerate(lines) if ln.strip() == "---"]
    fm_start, fm_end = delim_idxs[0], delim_idxs[1]

    today = datetime.date.today().isoformat()
    heartbeat = datetime.datetime.now(datetime.timezone.utc).strftime(
        "%Y-%m-%dT%H:%M:%SZ"
    )
    new_item = _first_list_item_line(card.gate_rows, card.job_dir)

    out: list[str] = []
    for i, line in enumerate(lines):
        if not (fm_start < i < fm_end):
            out.append(line)
            continue

        # Preserve the line ending while editing the content.
        stripped = line.rstrip("\n")
        newline = line[len(stripped) :]

        if re.match(r"^\s*version:\s*", stripped):
            out.append(
                _replace_scalar(stripped, "version", str(current_version + 1)) + newline
            )
        elif re.match(r"^\s*last_updated:\s*", stripped):
            out.append(_replace_scalar(stripped, "last_updated", today) + newline)
        elif re.match(r"^\s*heartbeat:\s*", stripped):
            out.append(_replace_scalar(stripped, "heartbeat", heartbeat) + newline)
        elif re.match(r"^\s*remaining_actions:\s*$", stripped):
            out.append(line)
            out.append(new_item + (newline or "\n"))
        else:
            out.append(line)

    new_text = "".join(out)
    Path(f"{baton_path}.fea-draft").write_text(new_text, encoding="utf-8")
    return new_text


def draft_notion_payload(card, draft_path=None, out_path=None) -> dict:
    """Build a Notion payload dict reflecting the DRAFTED (gated) baton.

    The payload is derived from the ``.fea-draft`` baton — the gated,
    not-yet-applied state — NOT the live baton. If the draft does not yet
    exist, ``draft_baton(card)`` is called first to produce it (it only ever
    writes ``<baton>.fea-draft``, never the live file).

    Design note: ``notion_sync`` exposes ``read_slice`` and ``slice_to_db_row``
    which produce Slices-row dicts, but BOTH read the canonical *live* path
    (``.agent/status/<slice>.md``) and re-run ``_parse_frontmatter`` internally
    — neither accepts an already-parsed dict, and both would read the live
    baton rather than the draft we need. So we deliberately do NOT reuse them
    here and instead build an explicit payload dict from the draft's parsed
    frontmatter. We reuse only the house frontmatter PARSER
    (``_parse_frontmatter``); NO Notion API/MCP/network calls happen here —
    the existing MCP+approval flow performs the real write later.
    """
    if draft_path is None:
        draft_path = f".agent/status/{card.slice_name}.md.fea-draft"

    if not Path(draft_path).exists():
        draft_baton(card)

    fm = _parse_frontmatter(Path(draft_path)) or {}

    version = int(fm["version"]) if fm.get("version") is not None else None
    last_updated = str(fm.get("last_updated") or "")
    remaining_actions = fm.get("remaining_actions") or []
    if not isinstance(remaining_actions, list):
        remaining_actions = []
    headline_action = str(remaining_actions[0]) if remaining_actions else ""

    gate_row = card.gate_rows[0] if card.gate_rows else {}

    payload = {
        "slices_row": {
            "slice": card.slice_name,
            "version": version,
            "last_updated": last_updated,
            "headline_action": headline_action,
            "state_verdict": card.verdict,
        },
        "experiments_row": {
            "slice": card.slice_name,
            "job_dir": card.job_dir,
            "verdict": card.verdict,
            **gate_row,
        },
    }

    if out_path is None:
        scratch = Path(".agent/scratch/fea")
        scratch.mkdir(parents=True, exist_ok=True)
        basename = os.path.basename(card.job_dir.rstrip("/")) or "job"
        out_path = scratch / f"{card.slice_name}_{basename}_notion_payload.json"
    out_path = Path(out_path)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(json.dumps(payload, indent=2), encoding="utf-8")

    return payload
