"""Red test for the FKSFold anchor-residue preflight (Task 1).

Return contract that Task 2 (scripts/fea/fksfold_preflight.py) must implement:

    verify_anchor_residues(
        residues,            # list[tuple[int, str]] of (author_resi, one_letter)
        w400_idx,            # 1-based SEQUENCE position the anchor should sit at
        expected="W",        # the expected one-letter code (tryptophan)
    ) -> list[Issue]

  - residues: list of (author_resi:int, one_letter:str). Positions are
    1-based by LIST POSITION -- residues[0] is sequence position 1, so the
    residue at 1-based position `i` is residues[i - 1]. The author_resi
    component is carried for reporting only; the lookup uses list position.
  - w400_idx: the 1-based sequence position where the W400 anchor
    (a tryptophan) is expected to sit.
  - Returns list[Issue] (from scripts.fea.preflight). Issue has
    .severity in {"error", "warn"}, .code, and .message. Empty list = OK.

  Rules (in order):
    * if w400_idx < 1 or w400_idx > len(residues):
        -> [Issue("error", "anchor_out_of_range", msg naming w400_idx and len)]
    * elif residues[w400_idx - 1][1] != expected:
        -> [Issue("error", "anchor_not_tryptophan",
                  msg naming the found letter, the position, and expected)]
    * else:
        -> []

  The two NEW error codes Task 2 must emit:
    - "anchor_out_of_range"    : w400_idx outside [1, len(residues)].
    - "anchor_not_tryptophan"  : residue at the anchor position is not the
        expected one-letter code.

This test MUST fail right now: scripts/fea/fksfold_preflight.py does not
exist yet.
"""

import os

import pytest

from scripts.fea.fksfold_preflight import (
    run_anchor_preflight,
    verify_anchor_residues,
)


def _errors(issues):
    return [i for i in issues if i.severity == "error"]


def _codes(issues):
    return [i.code for i in issues]


# Small synthetic residue list: 1-based position -> one-letter code.
#   pos 1=M, 2=A, 3=W, 4=G, 5=K, 6=L, 7=F
_RESIDUES = [
    (101, "M"),
    (102, "A"),
    (103, "W"),
    (104, "G"),
    (105, "K"),
    (106, "L"),
    (107, "F"),
]


def test_tryptophan_at_anchor_is_ok():
    # Position 3 is "W" -> no issues.
    issues = verify_anchor_residues(_RESIDUES, 3)
    assert issues == [], f"expected no issues, got: {_codes(issues)}"


def test_non_tryptophan_at_anchor_is_an_error():
    # Position 4 is "G", not "W" -> one anchor_not_tryptophan error.
    issues = verify_anchor_residues(_RESIDUES, 4)
    errs = _errors(issues)
    assert errs, "expected an error-severity issue for a non-tryptophan anchor"
    wrong = [e for e in errs if e.code == "anchor_not_tryptophan"]
    assert wrong, (
        f"expected an error with code 'anchor_not_tryptophan'; codes={_codes(issues)}"
    )
    msg = " ".join(e.message for e in wrong)
    assert "G" in msg, (
        f"expected the message to name the found letter 'G'; got: {msg!r}"
    )
    assert "4" in msg, f"expected the message to name the position 4; got: {msg!r}"


def test_anchor_index_beyond_length_is_an_error():
    # len(residues) == 7; position 99 is out of range -> anchor_out_of_range.
    issues = verify_anchor_residues(_RESIDUES, 99)
    errs = _errors(issues)
    assert errs, "expected an error-severity issue for an out-of-range anchor"
    assert any(e.code == "anchor_out_of_range" for e in errs), (
        f"expected an error with code 'anchor_out_of_range'; codes={_codes(issues)}"
    )


# --- Integration test against the REAL held-out CIF -------------------------
# Skips cleanly when Bio.PDB or the CIF is unavailable, so the suite never
# fails spuriously on a machine without the tooling/data.

_HELDOUT_CIF = "/home/ubuntu/FKSFold-Boltz_Advancement/examples/heldout/9NGT.cif"


def test_run_anchor_preflight_on_real_heldout_cif():
    pytest.importorskip("Bio")  # skip if Bio.PDB absent
    if not os.path.exists(_HELDOUT_CIF):
        pytest.skip("held-out CIF not present")

    # The production bug: author index 355 on 9NGT chain B is NOT a tryptophan
    # (empirically it is 'L'), so the preflight must reject it.
    bug_report = run_anchor_preflight(_HELDOUT_CIF, "B", 355)
    # If the CIF tooling could not run (e.g. _parse_heldout import failed),
    # skip rather than fail -- this test is the real-data check.
    bug_codes = _codes(bug_report.issues)
    if "anchor_check_unavailable" in bug_codes:
        msgs = " ".join(i.message for i in bug_report.issues)
        pytest.skip(f"CIF anchor tooling unavailable: {msgs}")

    assert bug_report.ok is False, (
        f"expected anchor 355 to be rejected; codes={bug_codes}"
    )
    assert "anchor_not_tryptophan" in bug_codes or "anchor_out_of_range" in bug_codes, (
        f"expected 'anchor_not_tryptophan' or 'anchor_out_of_range'; codes={bug_codes}"
    )

    # The re-derived index 321 maps to W (per STAGEB_RECIPE) -> OK.
    good_report = run_anchor_preflight(_HELDOUT_CIF, "B", 321)
    assert good_report.ok is True, (
        f"expected anchor 321 to pass; codes={_codes(good_report.issues)}"
    )
