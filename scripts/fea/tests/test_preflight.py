"""Red test for the FragMap preflight validator (Task 1).

Return contract that Task 2 (scripts/fea/preflight.py) must implement:

    run_preflight(config_path, input_yaml=None) -> PreflightReport

  PreflightReport has:
    - .issues : list of objects, each with
        .severity in {"error", "warn"}
        .code     : str
        .message  : str
    - .ok property : True iff no error-severity issue is present.

Validation rules exercised here:
    - mode "feature" is forbidden -> an error-severity issue citing "feature".
    - fragmap_npz must point at an existing file -> an error-severity issue
      citing the missing NPZ path when it does not exist.
    - a fully valid cluster_then_grid config with existing real paths -> .ok.

This test MUST fail right now: scripts/fea/preflight.py does not exist yet.
"""

from pathlib import Path

from scripts.fea.preflight import run_preflight

FIXTURES = Path(__file__).resolve().parent / "fixtures" / "preflight"
GOOD = FIXTURES / "good_cluster_then_grid.yaml"
BAD_FEATURE_MODE = FIXTURES / "bad_feature_mode.yaml"
BAD_MISSING_NPZ = FIXTURES / "bad_missing_npz.yaml"
INPUT_POCKET_OK = FIXTURES / "input_pocket_ok.yaml"
INPUT_POCKET_BAD = FIXTURES / "input_pocket_bad.yaml"

# Canonical VAV1 pocket ground truth (1-based seq) the audit must compare
# against. The historical bug used a shifted set {14..19}.
POCKET_GT = {16, 17, 18, 19, 20}


def _errors(report):
    return [i for i in report.issues if i.severity == "error"]


def test_good_config_is_ok():
    report = run_preflight(GOOD)
    assert report.ok is True, f"expected ok, got errors: {_errors(report)}"


def test_feature_mode_is_an_error():
    report = run_preflight(BAD_FEATURE_MODE)
    assert report.ok is False
    errs = _errors(report)
    assert errs, "expected an error-severity issue for forbidden mode"
    assert any("feature" in (e.code + e.message) for e in errs), (
        "expected an error citing the forbidden mode 'feature'"
    )


def test_missing_npz_is_an_error():
    report = run_preflight(BAD_MISSING_NPZ)
    assert report.ok is False
    errs = _errors(report)
    assert errs, "expected an error-severity issue for missing NPZ"
    assert any("/mnt/data/does/not/exist_maps.npz" in e.message for e in errs), (
        "expected an error citing the missing NPZ path"
    )


def _codes(report):
    return [i.code for i in report.issues]


def test_pocket_residues_match_gt_produces_no_mismatch():
    # input_pocket_ok has chain B contacts = {16,17,18,19,20} == POCKET_GT,
    # so the audit must NOT flag a pocket_residue_mismatch.
    report = run_preflight(GOOD, input_yaml=INPUT_POCKET_OK)
    assert "pocket_residue_mismatch" not in _codes(report), (
        f"unexpected pocket_residue_mismatch for matching pocket; "
        f"codes={_codes(report)}"
    )


def test_pocket_residues_shifted_produces_mismatch():
    # input_pocket_bad has chain B contacts = {14..19} (the historical
    # off-by-one/shifted bug), which differs from POCKET_GT {16..20}.
    report = run_preflight(GOOD, input_yaml=INPUT_POCKET_BAD)
    mismatches = [i for i in report.issues if i.code == "pocket_residue_mismatch"]
    assert mismatches, (
        f"expected a pocket_residue_mismatch issue for shifted pocket; "
        f"codes={_codes(report)}"
    )
    msg = " ".join(i.message for i in mismatches)
    assert ("14" in msg) or ("15" in msg), (
        f"expected the message to name the offending residues (14 and/or 15); "
        f"got: {msg!r}"
    )
