"""CLI entry point for the FragMap Experiment Autopilot (FEA).

The ``report`` subcommand wires the Stage-3 pipeline from
``scripts/fea/postflight.py`` + ``scripts/fea/results_card.py``. The
``capture`` subcommand reads a results card and emits gated DRAFTS only
(baton draft + Notion payload JSON) — it never writes the live baton or
calls Notion.
"""

import argparse
import os
from pathlib import Path

import numpy as np
import pandas as pd
import yaml

from scripts.fea import (
    capture,
    fksfold_preflight,
    mmgbsa_preflight,
    postflight,
    preflight,
    results_card,
    watch,
)


def _cmd_report(args) -> int:
    job_dir = args.job_dir
    metric = args.metric

    # 1. Per-cell failure manifest.
    manifest = postflight.classify_cells(job_dir)

    # 2. Per-cell metrics (silent-fail cells already dropped). ~125 rows.
    df = postflight.load_metrics(job_dir, args.baseline_csv)

    # 3. Activity labels: DC50 tsv (tab-separated).
    y_df = pd.read_csv(args.y_csv, sep="\t")
    y_df = y_df.rename(columns={"compound_id": "compound"})
    y_df = y_df[["compound", "dc50_nM"]].dropna()
    y_df["log_dc50"] = np.log10(y_df["dc50_nM"])

    # 4. SMILES for scaffold blocking.
    smi_df = pd.read_csv(args.smiles_csv)
    smi_df = smi_df[["compound", "SMILES"]].dropna()

    # 5. Inner-join metrics + activity + smiles. ~84 rows.
    merged = df.merge(y_df, on="compound", how="inner").merge(
        smi_df, on="compound", how="inner"
    )

    # 6. Scaffold groups.
    groups = postflight.murcko_scaffolds(merged.SMILES)

    # 7. Scaffold-blocked leakage-guarded gate.
    res = postflight.run_gates(
        merged[metric].values,
        merged.log_dc50.values,
        groups,
        n_perm=args.n_perm,
    )

    # 8-9. Build the results card.
    gate_rows = [{"metric": metric, **res}]
    card = results_card.ResultsCard(
        job_dir=str(job_dir),
        verdict=res["verdict"],
        gate_rows=gate_rows,
        failure_manifest=manifest,
        provenance={
            "oracle": "induced-fit-inverted-signal-20260601",
            "generated_by": "fea report",
            "inputs": {
                "baseline_csv": args.baseline_csv,
                "y_csv": args.y_csv,
                "smiles_csv": args.smiles_csv,
            },
            "n_joined": len(merged),
        },
    )

    # 10. Serialize.
    path = results_card.write_card(card, out_path=args.out_card)

    # 11. Print path + 5-line summary.
    print(f"card: {path}")
    print(f"verdict:  {res['verdict']}")
    print(f"raw_rho:  {res['raw_rho']:.4f}")
    print(f"oof_rho:  {res['oof_rho']:.4f}")
    print(f"perm_p:   {res['perm_p']:.4f}")
    print(f"n joined: {len(merged)}")
    print(f"manifest: {manifest['counts']}")
    return 0


def _parse_card_frontmatter(text: str) -> dict:
    """Parse the YAML frontmatter block between the first two ``---`` lines."""
    lines = text.splitlines()
    delim_idxs = [i for i, ln in enumerate(lines) if ln.strip() == "---"]
    if len(delim_idxs) < 2:
        return {}
    block = "\n".join(lines[delim_idxs[0] + 1 : delim_idxs[1]])
    return yaml.safe_load(block) or {}


def _coerce(value: str):
    """Best-effort float coercion; leave the string as-is on failure."""
    try:
        return float(value)
    except (TypeError, ValueError):
        return value


def _parse_first_gate_row(text: str) -> dict | None:
    """Recover the first data row of the ``## Gate results`` markdown table.

    Returns a gate_rows-style dict, or ``None`` if there is no data row.
    """
    cols = ["metric", "raw_rho", "oof_rho", "perm_p", "verdict"]
    lines = text.splitlines()
    header_idx = None
    for i, ln in enumerate(lines):
        cells = [c.strip() for c in ln.strip().strip("|").split("|")]
        if cells == cols:
            header_idx = i
            break
    if header_idx is None:
        return None

    for ln in lines[header_idx + 1 :]:
        stripped = ln.strip()
        if not stripped.startswith("|"):
            break
        cells = [c.strip() for c in stripped.strip("|").split("|")]
        # Skip the separator row (e.g. | --- | --- | ...).
        if all(set(c) <= {"-", ":"} and c for c in cells):
            continue
        # Skip the placeholder "none" row.
        if cells and cells[0] == "_(none)_":
            continue
        if len(cells) < len(cols):
            continue
        return {
            "metric": cells[0],
            "raw_rho": _coerce(cells[1]),
            "oof_rho": _coerce(cells[2]),
            "perm_p": _coerce(cells[3]),
            "verdict": cells[4],
        }
    return None


def _cmd_capture(args) -> int:
    text = Path(args.card).read_text(encoding="utf-8")

    fm = _parse_card_frontmatter(text)
    slice_name = fm.get("slice")
    verdict = fm.get("verdict")
    job_dir = fm.get("job_dir")

    row = _parse_first_gate_row(text)
    gate_rows = [row] if row is not None else []

    card_obj = results_card.ResultsCard(
        job_dir=job_dir,
        verdict=verdict,
        slice_name=slice_name,
        gate_rows=gate_rows,
    )

    capture.draft_baton(card_obj)
    capture.draft_notion_payload(card_obj)

    baton_draft = f".agent/status/{slice_name}.md.fea-draft"
    scratch = Path(".agent/scratch/fea")
    basename = os.path.basename(str(job_dir).rstrip("/")) or "job"
    payload_path = scratch / f"{slice_name}_{basename}_notion_payload.json"

    print(f"baton draft:   {baton_draft}")
    print(f"notion payload: {payload_path}")
    print(
        "DRAFTS ONLY — review and approve to apply; "
        "no live baton or Notion write was performed."
    )
    return 0


def _cmd_watch(args) -> int:
    if args.clear:
        watch.clear_marker()
        print("watch marker cleared")
        return 0

    job_ids = list(args.job or [])
    if args.jobs_file:
        job_ids.extend(watch.read_watch_list(args.jobs_file))
    if not job_ids:
        # fall back to the default watch-list marker if it exists
        job_ids = watch.read_watch_list()

    report = watch.scan_once(
        job_ids=job_ids,
        disk_paths=args.disk_path or None,
        warn_pct=args.warn_pct,
        crit_pct=args.crit_pct,
    )

    if args.write_marker:
        watch.write_marker(report)

    if not report.findings:
        print("✓ watch clean")
        return 0

    for f in report.findings:
        glyph = "✗" if f.severity == "error" else "⚠"
        label = "error" if f.severity == "error" else "warn "
        print(f"{glyph} {label} [{f.code}] {f.subject}: {f.message}")

    if not report.ok:
        return 1
    if args.strict:
        return 1
    return 0


def _cmd_preflight(args) -> int:
    report = preflight.run_preflight(args.config, input_yaml=args.input_yaml)

    if not report.issues:
        print("✓ preflight clean")
        return 0

    has_error = False
    has_any = False
    for issue in report.issues:
        has_any = True
        if issue.severity == "error":
            has_error = True
            print(f"✗ error  [{issue.code}] {issue.message}")
        else:
            print(f"⚠ warn  [{issue.code}] {issue.message}")

    if has_error:
        return 1
    if args.strict and has_any:
        return 1
    return 0


def _cmd_preflight_mmgbsa(args) -> int:
    report = mmgbsa_preflight.run_coupling_preflight(
        args.md_length_ns,
        tuple(args.window),
        frame_spacing_ps=args.frame_spacing,
        n_samples=args.n_samples,
        dt_ps=args.dt,
        coverage_min=args.coverage_min,
    )

    if not report.issues:
        print("✓ preflight clean")
        return 0

    has_error = False
    has_any = False
    for issue in report.issues:
        has_any = True
        if issue.severity == "error":
            has_error = True
            print(f"✗ error  [{issue.code}] {issue.message}")
        else:
            print(f"⚠ warn  [{issue.code}] {issue.message}")

    if has_error:
        return 1
    if args.strict and has_any:
        return 1
    return 0


def _cmd_preflight_fksfold(args) -> int:
    report = fksfold_preflight.run_anchor_preflight(
        args.cif,
        args.chain,
        args.w400_index,
        expected=args.expected,
    )

    if not report.issues:
        print("✓ preflight clean")
        return 0

    has_error = False
    has_any = False
    for issue in report.issues:
        has_any = True
        if issue.severity == "error":
            has_error = True
            print(f"✗ error  [{issue.code}] {issue.message}")
        else:
            print(f"⚠ warn  [{issue.code}] {issue.message}")

    if has_error:
        return 1
    if args.strict and has_any:
        return 1
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(
        prog="python -m scripts.fea",
        description="FragMap Experiment Autopilot (Phase 1 WIP).",
    )
    subparsers = parser.add_subparsers(dest="command", required=True)

    report = subparsers.add_parser(
        "report", help="Build a results card from a finished run."
    )
    report.add_argument("job_dir", help="AB job directory with VAV1_* cell subdirs.")
    report.add_argument(
        "--baseline-csv",
        required=True,
        help="norm143 baseline CSV for load_metrics.",
    )
    report.add_argument(
        "--y-csv",
        required=True,
        help="DC50 tsv (cols compound_id, dc50_nM; tab-separated).",
    )
    report.add_argument(
        "--smiles-csv",
        required=True,
        help="ligand_position_features.csv (cols compound, SMILES).",
    )
    report.add_argument(
        "--metric",
        default="vav1_rigid_body_offset",
        help="Structure metric to gate against activity.",
    )
    report.add_argument(
        "--n-perm",
        type=int,
        default=1000,
        help="Permutation-null draws for the gate.",
    )
    report.add_argument(
        "--out-card",
        default=None,
        help="Where to write the results card (default: scratch path).",
    )
    report.set_defaults(func=_cmd_report)

    capture_parser = subparsers.add_parser(
        "capture",
        help="Emit gated DRAFTS (baton + Notion payload) from a results card.",
    )
    capture_parser.add_argument(
        "card", help="Path to a results-card markdown file from `fea report`."
    )
    capture_parser.set_defaults(func=_cmd_capture)

    watch_parser = subparsers.add_parser(
        "watch",
        help="Advisory failure-signature monitor over live runs (read-only).",
    )
    watch_parser.add_argument(
        "--once",
        action="store_true",
        help="Run one scan and exit (the only mode in v1).",
    )
    watch_parser.add_argument(
        "--job",
        action="append",
        metavar="ID",
        help="A SLURM job id to death-check (repeatable).",
    )
    watch_parser.add_argument(
        "--jobs-file",
        default=None,
        help="File of job ids to death-check (one per line; '#' comments ok).",
    )
    watch_parser.add_argument(
        "--disk-path",
        action="append",
        metavar="PATH",
        help="Override the disk paths to check (repeatable; "
        "default: mounted /mnt/kfs* branches + /home/ubuntu).",
    )
    watch_parser.add_argument(
        "--warn-pct",
        type=int,
        default=85,
        help="Disk use%% at/over which to warn (default 85).",
    )
    watch_parser.add_argument(
        "--crit-pct",
        type=int,
        default=95,
        help="Disk use%% at/over which to error (default 95).",
    )
    watch_parser.add_argument(
        "--write-marker",
        action="store_true",
        help="Overwrite .agent/handoffs/state/proactive-watch-findings with "
        "the current findings (self-clears when none remain).",
    )
    watch_parser.add_argument(
        "--clear",
        action="store_true",
        help="Remove the findings marker and exit.",
    )
    watch_parser.add_argument(
        "--strict",
        action="store_true",
        help="Exit non-zero on any finding (default: only on error-severity).",
    )
    watch_parser.set_defaults(func=_cmd_watch)

    preflight_parser = subparsers.add_parser(
        "preflight",
        help="Validate a fragmap_conditioning config before launch.",
    )
    preflight_parser.add_argument(
        "config", help="Path to a fragmap_conditioning config YAML."
    )
    preflight_parser.add_argument(
        "--input-yaml",
        default=None,
        help="Optional input YAML for the VAV1 pocket audit.",
    )
    preflight_parser.add_argument(
        "--strict",
        action="store_true",
        help="Treat any issue (warn or error) as a failure.",
    )
    preflight_parser.set_defaults(func=_cmd_preflight)

    preflight_mmgbsa_parser = subparsers.add_parser(
        "preflight-mmgbsa",
        help="Validate MD-length / Stage-3 sampling coupling before launch.",
    )
    preflight_mmgbsa_parser.add_argument(
        "--md-length-ns",
        required=True,
        type=float,
        help="Stage-2 MD trajectory length in ns.",
    )
    preflight_mmgbsa_parser.add_argument(
        "--window",
        required=True,
        nargs=2,
        type=float,
        metavar=("A", "B"),
        help="Stage-3 sampling window (start end) in ns.",
    )
    preflight_mmgbsa_parser.add_argument(
        "--frame-spacing",
        type=float,
        default=100.0,
        help="Trajectory frame spacing in ps.",
    )
    preflight_mmgbsa_parser.add_argument(
        "--n-samples",
        type=int,
        default=50,
        help="Number of frames to sample in the window.",
    )
    preflight_mmgbsa_parser.add_argument(
        "--dt",
        type=float,
        default=0.002,
        help="MD integration timestep in ps.",
    )
    preflight_mmgbsa_parser.add_argument(
        "--coverage-min",
        type=float,
        default=0.75,
        help="Minimum trajectory coverage fraction before flagging undersampling.",
    )
    preflight_mmgbsa_parser.add_argument(
        "--strict",
        action="store_true",
        help="Treat any issue (warn or error) as a failure.",
    )
    preflight_mmgbsa_parser.set_defaults(func=_cmd_preflight_mmgbsa)

    preflight_fksfold_parser = subparsers.add_parser(
        "preflight-fksfold",
        help="Validate the FKSFold W400 anchor residue in a CIF before launch.",
    )
    preflight_fksfold_parser.add_argument(
        "--cif",
        required=True,
        help="Path to the CIF to check.",
    )
    preflight_fksfold_parser.add_argument(
        "--chain",
        default="B",
        help="Chain to parse for the anchor check.",
    )
    preflight_fksfold_parser.add_argument(
        "--w400-index",
        required=True,
        type=int,
        help="1-based sequence position of the W400 anchor residue.",
    )
    preflight_fksfold_parser.add_argument(
        "--expected",
        default="W",
        help="Expected one-letter code at the anchor position.",
    )
    preflight_fksfold_parser.add_argument(
        "--strict",
        action="store_true",
        help="Treat any issue (warn or error) as a failure.",
    )
    preflight_fksfold_parser.set_defaults(func=_cmd_preflight_fksfold)

    parsed = parser.parse_args()
    return parsed.func(parsed)


if __name__ == "__main__":
    raise SystemExit(main())
