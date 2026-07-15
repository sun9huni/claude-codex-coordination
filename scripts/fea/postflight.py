"""Post-flight analysis for FragMap/FEA cell jobs.

Currently provides per-cell failure classification: given a job directory
containing ``VAV1_<id>`` cell subdirectories (each laid out as
``<job>/VAV1_<id>/boltz_results_<...>/predictions/<...>/<name>_model_0.pdb``),
classify each cell into one of:

    success     -> a non-empty ``*_model_0.pdb`` exists under the cell
    oom         -> no PDB, and a ``*.log`` contains "ran out of memory"
    node_fault  -> no PDB, and a ``*.log`` contains "early_nvt_hang"
    silent_fail -> no PDB and no fault signature, but a ``predictions/``
                   subtree exists
    unknown     -> none of the above

Log-signature checks (oom/node_fault) take precedence over the generic
silent_fail rule, since faulted cells can also leave an empty
``predictions/`` subtree behind.

Standard library only (pathlib + builtins); no third-party dependencies.
"""

from __future__ import annotations

import argparse
import subprocess
import sys
import tempfile
from pathlib import Path

import numpy as np
import pandas as pd
from scipy import stats

# Frozen leakage-guarded evaluation gates. The analysis tree is not a package,
# so add the foundation dir to sys.path and import by module name (mirrors how
# analysis/induced_fit_inverted_signal_20260601/inverted_signal_test.py does it).
_FOUNDATION = Path("/home/ubuntu/FKSFold-Boltz_Advancement/analysis/foundation")
if str(_FOUNDATION) not in sys.path:
    sys.path.insert(0, str(_FOUNDATION))
import activity_eval_gates as _gates  # noqa: E402

_STATUSES = ("success", "silent_fail", "oom", "node_fault", "unknown")

# Battery script that computes the per-cell structural/confidence metrics.
# We delegate ALL metric math to it; this module only orchestrates + filters.
_EVAL_SCRIPT = Path(
    "/home/ubuntu/FKSFold-Boltz_Advancement/analysis/fragmap_spectral_discriminator"
    "/src/eval_ab_139batch.py"
)


def _has_model_pdb(cell_dir: Path) -> bool:
    """True if a non-empty ``*_model_0.pdb`` exists anywhere under the cell."""
    for pdb in cell_dir.glob("boltz_results_*/predictions/*/*_model_0.pdb"):
        if pdb.is_file() and pdb.stat().st_size > 0:
            return True
    return False


def _log_signature(cell_dir: Path) -> str | None:
    """Scan ``*.log`` files; return 'oom'/'node_fault' if a marker is found."""
    for log in cell_dir.rglob("*.log"):
        if not log.is_file():
            continue
        try:
            text = log.read_text(errors="replace")
        except OSError:
            continue
        if "ran out of memory" in text:
            return "oom"
        if "early_nvt_hang" in text:
            return "node_fault"
    return None


def _classify_cell(cell_dir: Path) -> str:
    if _has_model_pdb(cell_dir):
        return "success"
    sig = _log_signature(cell_dir)
    if sig is not None:
        return sig
    if any(cell_dir.glob("boltz_results_*/predictions")):
        return "silent_fail"
    return "unknown"


def classify_cells(job_dir) -> dict:
    """Classify every ``VAV1_*`` cell under ``job_dir``.

    Returns a dict with:
        - "counts": plain dict mapping status -> number of cells
        - "cells":  plain dict mapping cell-name -> status
    """
    job_dir = Path(job_dir)
    cells: dict[str, str] = {}
    counts: dict[str, int] = {}

    for cell_dir in sorted(job_dir.glob("VAV1_*")):
        if not cell_dir.is_dir():
            continue
        status = _classify_cell(cell_dir)
        cells[cell_dir.name] = status
        counts[status] = counts.get(status, 0) + 1

    return {"counts": counts, "cells": cells}


def load_metrics(job_dir, baseline_csv, out_csv=None) -> "pd.DataFrame":
    """Run the per-cell metrics battery and return its output as a DataFrame.

    Invokes the existing ``eval_ab_139batch.py`` script (which does all the
    structural/confidence metric math) via subprocess, reads its per-cell
    ``--out-csv`` into pandas, then drops rows for any cell that
    ``classify_cells(job_dir)`` flags as ``silent_fail``.

    Args:
        job_dir:      AB job directory containing ``VAV1_*`` cell subdirs.
        baseline_csv: norm143_full baseline CSV the battery joins against.
        out_csv:      where the battery writes the per-cell CSV. If ``None``,
                      a temp path is used (and cleaned up after reading).

    Returns:
        DataFrame of per-cell metrics, minus silent-fail cells.
    """
    job_dir = Path(job_dir)

    tmp_paired = None
    own_out = out_csv is None
    if own_out:
        out_handle = tempfile.NamedTemporaryFile(
            prefix="fea_metrics_", suffix=".csv", delete=False
        )
        out_handle.close()
        out_csv = out_handle.name
    # eval_ab_139batch.py requires --paired-csv too; we don't consume it here,
    # so always route it to a throwaway temp file.
    paired_handle = tempfile.NamedTemporaryFile(
        prefix="fea_paired_", suffix=".csv", delete=False
    )
    paired_handle.close()
    tmp_paired = paired_handle.name

    cmd = [
        sys.executable,
        str(_EVAL_SCRIPT),
        "--ab-dir",
        str(job_dir),
        "--baseline-csv",
        str(baseline_csv),
        "--out-csv",
        str(out_csv),
        "--paired-csv",
        str(tmp_paired),
    ]
    try:
        subprocess.run(cmd, check=True)
        df = pd.read_csv(out_csv)
    finally:
        Path(tmp_paired).unlink(missing_ok=True)
        if own_out:
            Path(out_csv).unlink(missing_ok=True)

    # Drop cells the failure classifier flagged as silent_fail. The CSV's
    # cell id lives in the "compound" column (e.g. "VAV1_101").
    manifest = classify_cells(job_dir)
    silent = {
        cell for cell, status in manifest["cells"].items() if status == "silent_fail"
    }
    if silent and "compound" in df.columns:
        df = df[~df["compound"].isin(silent)].reset_index(drop=True)

    return df


# ======================================================================
# Scaffold-blocked activity gate (delegates ALL stats to the frozen
# activity_eval_gates library — no new statistical method here).
# ======================================================================
def murcko_scaffolds(smiles_iterable) -> list[str]:
    """One scaffold-group label per input SMILES.

    Thin pass-through to the frozen ``activity_eval_gates.murcko_scaffolds``,
    which returns the Bemis-Murcko scaffold SMILES per molecule (via rdkit's
    ``MurckoScaffold.GetScaffoldForMol``) and assigns a unique ``__solo_<i>``
    label to unparseable / scaffold-less molecules so they are never merged.
    Reused verbatim so reproduction matches the induced-fit-inverted study.
    """
    return list(_gates.murcko_scaffolds(list(smiles_iterable)))


def run_gates(metric, y, groups, n_perm=1000, seed=None) -> dict:
    """Scaffold-blocked leakage-guarded gate for a structure metric vs activity.

    The pooled Spearman is reported ONLY as the "would-mislead" contrast; the
    verdict is driven solely by the scaffold-blocked out-of-fold prediction and
    its grouped permutation null. ``groups`` is required — there is no
    pooled-only path.

    Returns a dict with raw_rho, oof_rho, perm_p, verdict, n, n_groups.
    """
    if groups is None:
        raise ValueError("groups required; no pooled-only path")

    metric = np.asarray(metric, float)
    y = np.asarray(y, float)
    groups = np.asarray(groups)
    if not (len(metric) == len(y) == len(groups)):
        raise ValueError("metric, y, groups must have matching length")

    seed = _gates.DEFAULT_SEED if seed is None else seed

    # Pooled Spearman — reported as the misleading contrast, never the verdict.
    raw_rho = stats.spearmanr(metric, y).correlation

    X = metric.reshape(-1, 1)

    # Scaffold-blocked out-of-fold prediction (GroupKFold ElasticNet).
    oof = _gates.grouped_oof_predict(X, y, groups, kind="enet")
    oof_rho = stats.spearmanr(oof, y).correlation

    # Two-sided grouped permutation null of |oof_rho|. Freeze the ENet
    # hyperparams once so the null uses the same model class (frozen-lib idiom).
    fast_enet = _gates.freeze_enet_hyperparams(X, y)
    perm = _gates.permutation_null(
        X,
        y,
        groups,
        kind="enet",
        obs=abs(oof_rho),
        n_perm=n_perm,
        fast_enet=fast_enet,
        rng=np.random.default_rng(seed),
    )
    perm_p = perm["p_value_two_sided"]

    verdict = "KILL" if perm_p >= 0.05 else "PROVE"

    return {
        "raw_rho": float(raw_rho),
        "oof_rho": float(oof_rho),
        "perm_p": float(perm_p),
        "verdict": verdict,
        "n": int(len(y)),
        "n_groups": int(len(np.unique(groups))),
    }


def main() -> int:
    parser = argparse.ArgumentParser(
        prog="python -m scripts.fea.postflight",
        description="FragMap/FEA post-flight: classify cells and load metrics.",
    )
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument(
        "--classify-only",
        metavar="JOB_DIR",
        help="Classify cells under JOB_DIR and print the status counts.",
    )
    group.add_argument(
        "--metrics-only",
        metavar="JOB_DIR",
        help="Run the metrics battery over JOB_DIR and print the DataFrame.",
    )
    parser.add_argument(
        "--baseline-csv",
        help="Baseline CSV (required with --metrics-only).",
    )
    parser.add_argument(
        "--out-csv",
        help="Optional path for the battery's per-cell CSV (--metrics-only).",
    )
    args = parser.parse_args()

    if args.classify_only:
        manifest = classify_cells(args.classify_only)
        print(f"counts: {manifest['counts']}")
        print(f"cells:  {len(manifest['cells'])}")
        return 0

    if not args.baseline_csv:
        parser.error("--metrics-only requires --baseline-csv")
    df = load_metrics(args.metrics_only, args.baseline_csv, out_csv=args.out_csv)
    print(df.head().to_string())
    print(f"\nrows: {len(df)}")
    print(f"columns: {list(df.columns)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
