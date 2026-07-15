"""Red test (Task 5) — scaffold-blocked gate reproduces the induced-fit-inverted KILL.

This pins the reproduction oracle from
``.agent/contracts/fragmap-induced-fit-inverted-signal-20260601.md``:
the placement↔potency inversion looks promising at the raw pooled level
(Spearman(vav1_rigid_body_offset, logDC50) = -0.305) but collapses under
Murcko-scaffold-blocked out-of-fold prediction (OOF rho = -0.117, perm
p = 0.694) -> KILL. Full cohort n=84.

CONTRACT that Task 6 must implement in ``scripts/fea/postflight.py``
(this test fails today on the missing imports — that is intended):

    murcko_scaffolds(smiles_iterable) -> list[str]
        One scaffold-group label per input SMILES, the Murcko/Bemis
        *generic* scaffold SMILES via rdkit. Usable directly as
        GroupKFold ``groups``. Unparseable / scaffold-less molecules must
        get a unique solo label (never silently merged into one group).

    run_gates(metric, y, groups, n_perm=1000, seed=...) -> dict
        Keys (at least):
          "raw_rho":  float  pooled Spearman(metric, y). Reported ONLY as
                      the "would-mislead" contrast — it is NOT used for the
                      verdict.
          "oof_rho":  float  Spearman of scaffold-blocked
                      grouped_oof_predict(metric, y, groups) vs y.
          "perm_p":   float  two-sided permutation p of |oof_rho| under the
                      SAME grouped scheme (groups never split across
                      train/eval).
          "verdict":  "KILL" | "PROVE"  -> KILL when the OOF fails to beat
                      the permutation band (perm_p >= 0.05).
        ``groups`` is REQUIRED: ``run_gates(metric, y, None)`` must raise
        (ValueError / TypeError). There is NO pooled-only path — the whole
        point of the gate is that pooled rho is not trusted.

The numeric battery delegates to the frozen library
``analysis/foundation/activity_eval_gates.py`` (grouped_oof_predict,
permutation_null, murcko_scaffolds, …) — no method-shopping.
"""

from pathlib import Path

import pandas as pd
import pytest

from scripts.fea.postflight import murcko_scaffolds, run_gates

FIXTURE = Path(__file__).resolve().parent / "fixtures" / "induced_fit_cohort.csv"


def _load():
    df = pd.read_csv(FIXTURE)
    # rename to a convenient attribute for the test body
    df = df.rename(columns={"vav1_rigid_body_offset": "offset"})
    return df


def test_scaffold_blocked_gate_reproduces_kill():
    df = _load()
    assert len(df) == 84  # full induced-fit cohort

    groups = murcko_scaffolds(df.SMILES)
    res = run_gates(df.offset.values, df.log_dc50.values, groups, n_perm=200)

    # raw pooled rho looks promising (the "would-mislead" contrast)
    assert res["raw_rho"] == pytest.approx(-0.305, abs=0.03)
    # scaffold-blocked OOF collapses toward zero
    assert res["oof_rho"] == pytest.approx(-0.117, abs=0.06)
    # indistinguishable from the permutation band
    assert res["perm_p"] > 0.3
    # frozen pre-registered verdict
    assert res["verdict"] == "KILL"


def test_run_gates_requires_groups():
    df = _load()
    with pytest.raises((ValueError, TypeError)):
        run_gates(df.offset.values, df.log_dc50.values, None)
