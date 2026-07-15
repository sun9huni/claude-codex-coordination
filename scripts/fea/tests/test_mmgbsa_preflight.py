"""Red test for the MMGBSA coupling preflight (Task 1).

Return contract that Task 2 (scripts/fea/mmgbsa_preflight.py) must implement:

    run_coupling_preflight(
        md_length_ns,
        window_ns,
        frame_spacing_ps=100.0,
        n_samples=50,
        dt_ps=0.002,
        coverage_min=0.75,
    ) -> PreflightReport

  PreflightReport (REUSED from scripts.fea.preflight) has:
    - .issues : list of Issue, each with
        .severity in {"error", "warn"}
        .code     : str
        .message  : str
    - .ok property : True iff no error-severity issue is present.

  The arithmetic MUST reuse the committed coupling module
  (scripts.mmgbsa_16gpu_multidir.mmgbsa_coupling) --
  derive_frame_range() to turn (window_ns, frame_spacing_ps, n_samples)
  into (start, end, interval), and coupling_check() to flag a window that
  asks for frames the trajectory does not have. Do NOT reimplement the
  frame math.

  Two NEW error codes Task 2 must emit (neither exists in the committed
  coupling_check, which only catches endframe>traj_frames / invalid start
  and does NOT catch under-sampling):
    - "coupling_undersampled"      : sampling window covers only a small
        fraction (< coverage_min) of the produced trajectory.
    - "coupling_window_exceeds_traj": requested window asks for frames
        beyond the produced trajectory (window longer than MD).

Validation rules exercised here:
    - BUG case      : 20 ns MD, sampling only the first (0,5) ns -> 25%
        coverage < 0.75 -> NOT ok, error code "coupling_undersampled".
    - MATCHED case  : 20 ns MD, sampling full (0,20) ns -> .ok.
    - WINDOW>TRAJ   : 5 ns MD, sampling (0,20) ns -> NOT ok, error code
        "coupling_window_exceeds_traj".

This test MUST fail right now: scripts/fea/mmgbsa_preflight.py does not
exist yet.
"""

from scripts.fea.mmgbsa_preflight import run_coupling_preflight


def _errors(report):
    return [i for i in report.issues if i.severity == "error"]


def _codes(report):
    return [i.code for i in report.issues]


def test_undersampled_window_is_an_error():
    # 20 ns produced (200 frames @ 100 ps), sampling only the first 5 ns
    # (frames 1-50) -> 25% coverage, well under the 0.75 floor.
    report = run_coupling_preflight(20.0, (0.0, 5.0))
    assert report.ok is False, f"expected NOT ok, got: {_codes(report)}"
    errs = _errors(report)
    assert errs, "expected an error-severity issue for under-sampling"
    undersampled = [e for e in errs if e.code == "coupling_undersampled"]
    assert undersampled, (
        f"expected an error with code 'coupling_undersampled'; codes={_codes(report)}"
    )
    msg = " ".join(e.message for e in undersampled)
    assert ("25%" in msg) or ("25 %" in msg) or ("first" in msg and "5" in msg), (
        f"expected the message to mention coverage (e.g. '25%') and/or "
        f"'first'+'5'; got: {msg!r}"
    )


def test_matched_window_is_ok():
    # 20 ns produced, sampling the full (0,20) ns -> 100% coverage, fits.
    report = run_coupling_preflight(20.0, (0.0, 20.0))
    assert report.ok is True, f"expected ok, got errors: {_errors(report)}"


def test_window_exceeding_traj_is_an_error():
    # 5 ns produced (50 frames), but the window asks for (0,20) ns
    # (endframe 200 > 50 frames) -> the window exceeds the trajectory.
    report = run_coupling_preflight(5.0, (0.0, 20.0))
    assert report.ok is False, f"expected NOT ok, got: {_codes(report)}"
    errs = _errors(report)
    assert errs, "expected an error-severity issue for window > trajectory"
    assert any(e.code == "coupling_window_exceeds_traj" for e in errs), (
        f"expected an error with code 'coupling_window_exceeds_traj'; "
        f"codes={_codes(report)}"
    )
