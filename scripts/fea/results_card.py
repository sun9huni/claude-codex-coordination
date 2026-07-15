"""Results Card schema + serializer for FragMap/FEA post-flight reports.

A ``ResultsCard`` bundles the leakage-guarded gate verdict, the per-cell
failure manifest (``postflight.classify_cells`` output), and free-form
provenance into a single dataclass. ``write_card`` renders it to a Markdown
file with YAML frontmatter under the project scratch area.

Standard library + PyYAML only (PyYAML is already a project dep; see
``scripts/notion_sync.py``). NO network, NO baton writes, NO Notion calls.
"""

from __future__ import annotations

import os
from dataclasses import dataclass, field
from pathlib import Path

import yaml

# Verdict glosses for the "## Verdict" one-liner. Falls back to a generic
# line for any verdict not enumerated here.
_VERDICT_GLOSS = {
    "KILL": "signal does not survive leakage-guarded evaluation; do not pursue.",
    "PROVE": "candidate signal; needs a confirmatory run before acting.",
    "PASS": "signal survives the frozen gates.",
    "INCONCLUSIVE": "insufficient data to decide; gather more.",
}


@dataclass
class ResultsCard:
    """Structured summary of one analyzed FEA/FragMap job directory."""

    job_dir: str
    verdict: str
    slice_name: str = "fragmap"
    gate_rows: list[dict] = field(default_factory=list)
    failure_manifest: dict = field(default_factory=dict)
    provenance: dict = field(default_factory=dict)


def _n_cells(failure_manifest: dict) -> int:
    """Sum of the manifest's per-status counts (0 if absent)."""
    counts = failure_manifest.get("counts", {}) or {}
    return int(sum(counts.values()))


def _gate_table(gate_rows: list[dict]) -> str:
    """Render gate_rows as a small markdown table."""
    header = (
        "| metric | raw_rho | oof_rho | perm_p | verdict |\n"
        "| --- | --- | --- | --- | --- |"
    )
    if not gate_rows:
        return header + "\n| _(none)_ | | | | |"
    lines = [header]
    for row in gate_rows:
        lines.append(
            "| {metric} | {raw_rho} | {oof_rho} | {perm_p} | {verdict} |".format(
                metric=row.get("metric", ""),
                raw_rho=row.get("raw_rho", ""),
                oof_rho=row.get("oof_rho", ""),
                perm_p=row.get("perm_p", ""),
                verdict=row.get("verdict", ""),
            )
        )
    return "\n".join(lines)


def _cells_by_status(failure_manifest: dict, status: str) -> list[str]:
    """Cell names whose classified status matches ``status``."""
    cells = failure_manifest.get("cells", {}) or {}
    return [name for name, st in cells.items() if st == status]


def _manifest_section(failure_manifest: dict) -> str:
    counts = failure_manifest.get("counts", {}) or {}
    lines = ["Counts:"]
    if counts:
        for status, n in counts.items():
            lines.append(f"- {status}: {n}")
    else:
        lines.append("- _(none)_")
    for status in ("silent_fail", "oom", "node_fault"):
        names = _cells_by_status(failure_manifest, status)
        if names:
            lines.append(f"\n{status} cells:")
            lines.extend(f"- {name}" for name in names)
    return "\n".join(lines)


def _provenance_section(provenance: dict) -> str:
    if not provenance:
        return "- _(none)_"
    return "\n".join(f"- **{key}**: {value}" for key, value in provenance.items())


def write_card(card: ResultsCard, out_path=None) -> Path:
    """Serialize ``card`` to a Markdown file with YAML frontmatter.

    If ``out_path`` is None, defaults to
    ``.agent/scratch/fea/<slice>_<basename(job_dir)>_card.md`` (the scratch
    dir is created if missing). Returns the Path written.
    """
    if out_path is None:
        scratch = Path(".agent/scratch/fea")
        scratch.mkdir(parents=True, exist_ok=True)
        basename = os.path.basename(card.job_dir.rstrip("/")) or "job"
        out_path = scratch / f"{card.slice_name}_{basename}_card.md"
    out_path = Path(out_path)

    frontmatter = {
        "slice": card.slice_name,
        "verdict": card.verdict,
        "job_dir": card.job_dir,
        "n_cells": _n_cells(card.failure_manifest),
        "generated_by": card.provenance.get("generated_by", "fea report"),
    }
    fm = yaml.safe_dump(frontmatter, sort_keys=False, default_flow_style=False).strip()

    gloss = _VERDICT_GLOSS.get(card.verdict, "see gate results below.")

    body = "\n".join(
        [
            "---",
            fm,
            "---",
            "",
            "## Verdict",
            "",
            f"**{card.verdict}** — {gloss}",
            "",
            "## Gate results",
            "",
            _gate_table(card.gate_rows),
            "",
            "## Failure manifest",
            "",
            _manifest_section(card.failure_manifest),
            "",
            "## Provenance",
            "",
            _provenance_section(card.provenance),
            "",
        ]
    )

    out_path.write_text(body)
    return out_path
