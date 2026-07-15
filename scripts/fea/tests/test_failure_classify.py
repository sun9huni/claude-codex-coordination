"""Red test for per-cell failure classification (Task 2).

Return contract for `classify_cells(job_dir)` that Task 3 must implement:
  Returns a dict with at least:
    - "counts": mapping status -> int (count of cells in that status)
    - "cells":  mapping cell-name (e.g. "VAV1_101") -> status
  Status values are drawn from:
    {"success", "silent_fail", "oom", "node_fault", "unknown"}

Classification rules (per cell, mirroring the real fragmap job layout
  <job>/VAV1_<id>/boltz_results_<...>/predictions/<...>/<name>_model_0.pdb):
    success     -> a non-empty *_model_0.pdb exists
    silent_fail -> predictions/ subtree exists but the *_model_0.pdb is missing
    oom         -> no PDB, and a *.log under the cell contains "ran out of memory"
    node_fault  -> no PDB, and a *.log under the cell contains "early_nvt_hang"
    unknown     -> none of the above

This test MUST fail right now: scripts/fea/postflight.py does not exist yet.
"""

from pathlib import Path

from scripts.fea.postflight import classify_cells

FIXTURE_JOB = Path(__file__).resolve().parent / "fixtures" / "fixture_job"


def test_classify_cells_counts_four_classes():
    manifest = classify_cells(FIXTURE_JOB)

    assert manifest["counts"]["success"] == 1
    assert manifest["counts"]["silent_fail"] == 1
    assert manifest["counts"]["oom"] == 1
    assert manifest["counts"]["node_fault"] == 1
