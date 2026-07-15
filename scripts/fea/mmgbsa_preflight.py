"""MMGBSA MD-length / Stage-3-sampling coupling preflight.

Validates that the Stage-3 ``gmx_MMPBSA`` sampling window is compatible with
the trajectory produced by Stage-2 MD, BEFORE launch. All frame arithmetic is
REUSED from the committed single-source coupling module
(``scripts/mmgbsa_16gpu_multidir/mmgbsa_coupling.py``):
``derive_frame_range`` turns a sampling window into gb.in (start, end, interval)
and ``coupling_check`` flags a window that asks for frames the trajectory does
not have. This module never reimplements that math and never touches
``run_mmpbsa.py``.

On top of the committed ``coupling_check`` (which only catches
``endframe > traj_frames`` / invalid start), this preflight adds a NEW coverage
guard — ``coupling_undersampled`` — for a window that fits the trajectory but
samples too small a fraction of it to give a converged deltaG ranking.
"""

from __future__ import annotations

import contextlib
import os
import sys
from pathlib import Path

from scripts.fea.preflight import Issue, PreflightReport

# The mmgbsa_16gpu_multidir tree is not a package, so add its dir to sys.path
# and import by module name (mirrors how postflight.py imports activity_eval_gates).
_COUPLING_DIR = Path(
    "/home/ubuntu/FKSFold-Boltz_Advancement/scripts/mmgbsa_16gpu_multidir"
)
if str(_COUPLING_DIR) not in sys.path:
    sys.path.insert(0, str(_COUPLING_DIR))
import mmgbsa_coupling  # noqa: E402


def run_coupling_preflight(
    md_length_ns,
    window_ns,
    frame_spacing_ps=100.0,
    n_samples=50,
    dt_ps=0.002,
    coverage_min=0.75,
) -> PreflightReport:
    """Preflight the MD-length / Stage-3-sampling coupling.

    Returns a PreflightReport whose issues flag (a) a sampling window that
    exceeds the produced trajectory and (b) a window that fits but covers too
    small a fraction of it to be converged.
    """
    issues: list[Issue] = []

    traj_frames = round(md_length_ns * 1000.0 / frame_spacing_ps)
    start, end, interval = mmgbsa_coupling.derive_frame_range(
        window_ns, frame_spacing_ps, n_samples
    )

    # --- window > trajectory (REUSED committed check) ---
    with open(os.devnull, "w") as _devnull, contextlib.redirect_stderr(_devnull):
        rc = mmgbsa_coupling.coupling_check(traj_frames, start, end, interval)
    window_exceeds = rc != 0
    if window_exceeds:
        issues.append(
            Issue(
                "error",
                "coupling_window_exceeds_traj",
                f"sampling window (frames {start}-{end}) exceeds the "
                f"{traj_frames}-frame trajectory from {md_length_ns}ns MD",
            )
        )

    # --- coverage guard (NEW; not in committed coupling_check) ---
    # Skip when the window already exceeds the traj, to avoid double-faulting
    # the 5ns/(0,20) case.
    if not window_exceeds and md_length_ns > 0:
        a_ns, b_ns = window_ns
        coverage = (b_ns - a_ns) / md_length_ns
        if b_ns < md_length_ns and coverage < coverage_min:
            pct = round(coverage * 100)
            issues.append(
                Issue(
                    "error",
                    "coupling_undersampled",
                    f"sampling window {window_ns}ns covers only {pct}% of the "
                    f"{md_length_ns}ns trajectory (first-{b_ns:g}ns) -- "
                    f"under-converged, corrupts deltaG ranking; "
                    f"use a full-traj window",
                )
            )

    return PreflightReport(issues)
