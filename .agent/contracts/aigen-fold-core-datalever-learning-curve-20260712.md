---
status: done
slice: aigen-fold-core
topic: datalever-learning-curve
date: 2026-07-12
owner: claude
approved_by: sunghoon.kim (2026-07-12, "승인")
requested: 2026-07-12
cross_slice: []
triggers_matched:
  - "ranking semantics — evaluates VAV1 DC50 ranking-model variants (learning curve, held-out
    OOF, censoring reconciliation, bridge_span_mean ablation) on the 505-compound set; same
    trigger class as v12-sar-data-integration / 3body-mgoff-features (both took contracts)"
  - "4+ files — learning-curve script, OOF-on-117 eval, censoring-reconciled re-eval,
    bridge_span_mean-on-505 extractor+eval, results doc"
---

# aigen-fold-core — data-is-the-lever diagnostic: fixed-test learning curve + held-out-117 OOF + censoring reconcile + bridge_span_mean-on-505 (all zero-GPU)

## Purpose

The v1.2 SAR data-integration experiment (388→505) returned a flat cross-scaffold result, but
adversarial verification (wf_8820cfdd-c99, 5 lenses) established that this flat number is a REAL
null yet nearly UNINFORMATIVE about the standing "same-assay data is the lever" hypothesis:
- the cross test is underpowered ~5-10x (MDE ρ≈0.09-0.13 vs an expected +30%-data effect of
  ~+0.008-0.025 — an order of magnitude below the detection floor), and
- `cv_large_scaffold`'s ≥5-member rule structurally excludes 92 of the 117 new compounds from
  the cross universe (only 25 enter, 21 of them an atypical boron/BN-isostere 1000nM-capped
  series), so "flat cross" is a foregone conclusion computed on a tiny unrepresentative slice.

The correct diagnostic is the SLOPE of a learning curve (test-rho vs n_train), not another
single data point — and it is entirely ZERO-GPU because all 505 features (poolMSD + ligand) and
117 docked poses are already extracted and schema-verified. This contract runs that diagnostic
plus three verification-driven cleanups, to produce a decision-grade answer: is structure-as-
feature TAPPED at achievable same-assay data scales (→ stop spending on volume, pivot the
modeling target), or is data STILL the lever (→ justify a larger 2-5x same-assay campaign)?

## Current State

- 505-compound assets, all present + schema-verified (v12-sar-data-integration contract, done):
  `phase4/Zpool_388.csv` + `phase8/Zpool_117.csv` (poolMSD, identical columns);
  `phase2/ligand_features.csv` + `phase8/ligand_features_117.csv` (ligand "L", identical
  columns); `phase8/vav1_dataset_505_folds.csv` (joint scaffold-CV folds); labels in
  `phase0/vav1_dataset_final.csv` (388) + `phase0/vav1_dataset_sar20260701_new.csv` (117).
- 117 docked ternary poses at `/mnt/kfs2/.../vav1_sar117_dock_20260712/<CODE>_<cid>/stage2_seed*_model_0.pdb`
  (chain A=CRBN/B=VAV1/C=glue, schema-verified) — the source bridge_span_mean needs.
- Reusable machinery (all unmodified): `phase2/rank_harness.py` (build_matrix, CV_SCHEMES,
  oof), `phase4/sweep.py` (oof_pairwise "aware", feature_registry, oof_regressor for gbdt),
  `phase6/eval_pretrain.py` (rho_ci, paired_boot_on_overlap), `phase7/extract_features.py`
  (the bridge_span_mean / 3-body hypergraph extractor for the 388).
- v1.1 shipped model spec: CROSS champion = L+poolMSD pairwise ("aware"), 0.5584; WITHIN
  champion = ligand-gbdt on L, 0.545 (NOT poolMSD-pairwise — a v1.2-eval reporting gap the
  verification flagged).
- Verification artifacts: results in the workflow transcript; the v1.2 results doc
  `phase8/results_v8.md` (this contract's re-report will supersede its cross-prose numbers).

## Assumptions And Questions

- assumptions: the already-extracted 505 features are correct (independently re-verified in the
  adversarial pass — identity 0/117 descriptor mismatches, latent regime byte-identical); the
  phase7 bridge_span_mean extractor generalizes to the 117 poses (same chain schema, same
  extractor — to be verified, not assumed).
- open questions this contract ANSWERS: (Q1) does test-rho keep rising with n_train through
  388→505, or plateau? (Q2) how well does the model predict the NEW 117 specifically (held-out
  OOF on them — the v1.2 eval never measured this at all)? (Q3) does reconciling the censoring
  cap change the within-scaffold delta materially? (Q4) does bridge_span_mean still add cross-
  scaffold headroom at n=505 as it did at n=388 (+0.028, nested-CV-confirmed)?
- tradeoffs: a fixed-test learning curve trades some train-set size at the low-n end for a clean
  slope on a constant test set (kills the fold-repartition confound the verification flagged —
  cross GroupKFold went 12→14 groups when the 25 new in-universe compounds were added).

## Constraints

- allowed: new scripts + outputs under `.agent/scratch/vav1_degrad_head/phase9/`; reuse
  `phase2/rank_harness.py`, `phase4/sweep.py`, `phase6/eval_pretrain.py`,
  `phase7/extract_features.py` UNMODIFIED (import/call only); read the existing 388/117 feature
  CSVs + 505 fold table + 117 pose PDBs.
- forbidden: any SLURM/GPU (this is strictly zero-GPU — all inputs already exist); modifying any
  phase0-8 artifact, `phase3/v1/*.joblib`, `v1_model_card.md`, or engine files; re-docking or
  re-extracting latents; making the v1.2 ship/no-ship decision (still out of scope — this
  contract produces the diagnostic the decision will rest on, not the decision).
- external: none (fully local, CPU/sklearn/numpy/rdkit only).

## Non-Goals

- Any GPU work, re-docking, or new latent extraction — everything needed is on disk.
- Replacing v1.1 as the shipped model, or committing to a data campaign / modeling-target pivot
  — this contract DELIVERS the go/no-go evidence; the resource-allocation call is the user's,
  made after this report.
- Wet-lab resolution of the standing curation caveats (AIG22071 A/B discordant DC50, 3
  non-canonical-warhead compounds) — carried forward as caveats, not resolved.
- New engineered features beyond re-testing the already-validated bridge_span_mean (no fresh
  feature search — that would be a separate contract).
- Any REST API / semantic-object-layer change.

## Done When

- **Learning curve (Q1)**: `phase9/learning_curve.py` — fixed-test-set curve for BOTH regimes.
  Cross: hold the cross-scaffold test set fixed, train the v1.1 cross spec (L+poolMSD "aware"
  pairwise) on nested scaffold-disjoint subsets (n_train ≈ 100/200/300/388/full-available),
  plot test-rho vs n_train with bootstrap CIs. Within: same idea across the full 505 (where
  resolution is good). Verify: a curve (rho vs n_train, ≥4 points, each with CI) written to a
  CSV + a one-line slope verdict (plateaued near 388-505 vs still-rising, with the numeric
  slope of the last segment).
- **Held-out OOF on the 117 (Q2)**: report cross- and within-scaffold rho computed SPECIFICALLY
  on the 117 new compounds (train on 388, predict the 117; and/or the 117's OOF slice from the
  505 run). Verify: an explicit rho(117) number with CI + n — the metric the v1.2 eval omitted.
- **Censoring reconcile (Q3)**: `phase9/eval_reconciled.py` — rebuild pairs under ONE cap
  convention (document which; the 24 new 1000nM-capped compounds are uncensored under the 388's
  10000nM rule), re-run the paired A-vs-B deltas, AND evaluate the ACTUAL shipped within
  champion (ligand-gbdt, not poolMSD-pairwise), AND report the corrected A-on-shared-135 cross
  number (0.5235, vs the 0.5524-on-160 the v1.2 prose quoted). Verify: a corrected comparison
  table with the cap convention stated inline.
- **bridge_span_mean-on-505 (Q4)**: `phase9/bridge_on_505.py` — extract bridge_span_mean for
  the 117 from their docked poses via the phase7 extractor (unmodified), combine with the 388's
  existing values, test L+poolMSD+bridge_span_mean vs L+poolMSD cross-scaffold on 505 with
  paired-bootstrap Δ. Verify: a Δ with CI; states whether the +0.028 388-headroom survives at
  n=505.
- **Report + close**: `phase9/results_v9.md` states all four answers, the overall data-lever
  verdict (tapped vs still-a-lever, with the slope as the primary evidence), and the recommended
  next resource allocation as an OBSERVATION (not a decision). Baton updated; contract → done.

## Implementation Steps

1. `phase9/data_505.py` (thin shared loader): assemble the 505 feature matrix (L+poolMSD) +
   label table (logDC50, scaffold, fold from `vav1_dataset_505_folds.csv`, censored per-source)
   once, importable by the other phase9 scripts. verify: 505 rows, columns match v1.2's eval.
2. `phase9/learning_curve.py` (Q1): fixed-test nested-subset curve, both regimes, CIs + slope
   verdict CSV. verify: curve CSV with ≥4 (n_train, rho, ci_lo, ci_hi) rows per regime.
3. `phase9/eval_reconciled.py` (Q2+Q3): held-out-117 OOF + single-cap-reconciled paired deltas +
   shipped within champion (ligand-gbdt) + corrected A-on-135. verify: comparison table printed.
4. `phase9/bridge_on_505.py` (Q4): extract bridge_span_mean for 117 (phase7 extractor on the
   pose PDBs), 505 ablation vs poolMSD, paired Δ. verify: Δ + CI printed; 117 extraction row
   count = 117 (or logged fewer).
5. `phase9/results_v9.md` + baton + contract done. verify: doc has all four answers + slope
   verdict + next-allocation observation; scripts reproducible.

## Resource budget

- CPU only, zero GPU. sklearn/numpy/rdkit/gemmi. Learning curve is the heaviest (nested
  refits × bootstrap) but still minutes-to-low-tens-of-minutes. No SLURM.

## Risks

- regression risk: none — additive scratch under phase9/, no existing artifact touched.
- integration risk: the phase7 bridge_span_mean extractor was written against the 388 pose
  layout; the 117 poses live in a differently-named dir — the extractor may need a path arg
  (allowed: a thin wrapper in phase9/, NOT an edit to phase7/extract_features.py). If the
  extractor cannot run on the 117 poses without editing phase7, Q4 is logged as blocked and the
  other three answers still stand (Q4 is the contingent tiebreaker, not the core diagnostic).
- interpretation risk: a learning curve can be ambiguous (neither clearly flat nor clearly
  rising); the report must state the slope + CI honestly and, if ambiguous, say so rather than
  forcing a verdict.

## Rollback

- revert strategy: delete `phase9/`; no shared-state or existing-artifact change.
- containment: v1.1 remains the only shipped model regardless; this contract changes no model,
  only produces analysis.

## Progress Log

- 2026-07-12: scoped via /brainstorm after the v12-sar-data-integration adversarial verification
  (wf_8820cfdd-c99). Verification verdict TRUSTWORTHY-WITH-CAVEATS: flat cross result is a real
  null but uninformative (underpowered ~5-10x + 79% of new data excluded from cross universe);
  the diagnostic is the learning-curve slope, zero-GPU. User chose full scope (learning curve +
  censoring/within-champion cleanup + bridge_span_mean-on-505 tiebreaker). Awaiting approval.
- 2026-07-12: approved by sunghoon.kim ("승인"). All 6 tasks DONE, all zero-GPU. Outcome =
  REVERSAL of the standing "same-assay data is the lever" hypothesis. Q1 (CORE): fixed-test-set
  learning curve FLAT in both regimes across a 4.4x data range (cross rho
  0.578/0.578/0.547/0.557/0.523 at n_train 100/200/300/388/443, last-seg Δrho=-0.034 << CI
  half-width 0.153; within 0.472/0.523/0.462/0.468/0.502) — no rise even in the point estimates
  from n=100, materially stronger than the single phase8 delta. Q2: train-388 predict-117
  held-out rho=0.497 [0.325,0.641] / scaffold-disjoint 0.480 [0.320,0.617] — the new series is
  predictable, so what's tapped is the structure-as-FEATURE ceiling (~0.55 cross), not a broken
  model. Q3: single-cap reconcile barely moved the phase8 deltas (cross -0.034->-0.024, within
  +0.027->+0.025), the CORRECT within champion is ligand-gbdt on L (0.545, not the poolMSD-pairwise
  phase8 used) with +117 delta +0.005 [-0.051,+0.056] P=0.578 (null), and the honest matched-set
  A-on-135=0.5235/0.5334 trails B-on-135=0.5584 by ~0.03. Q4: bridge_span_mean's +0.028
  [+0.002,+0.057] n=388 headroom EVAPORATES at n=505 -> +0.021 [-0.015,+0.058] P=0.88 (CI now
  spans 0). CONVERGENT VERDICT: at n~505 with the current pipeline, incremental same-assay data at
  this scale is not expected to move the ranker; structure-as-ranking-feature is at/near exhausted.
  Ship model UNCHANGED (v1.1). Full writeup phase9/results_v9.md (supersedes two phase8/results_v8.md
  cross/within numbers). Resource-allocation call left to the user as OBSERVATIONS, per Non-Goals.
  Contract CLOSED. done.
