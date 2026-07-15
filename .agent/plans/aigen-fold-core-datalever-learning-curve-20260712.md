---
contract: .agent/contracts/aigen-fold-core-datalever-learning-curve-20260712.md
slice: aigen-fold-core
status: done
total_tasks: 6
estimated_total_min: 28
---

# Plan: data-is-the-lever diagnostic — learning curve + held-out-117 OOF + censoring reconcile + bridge_span_mean-on-505

All tasks are ZERO-GPU (CPU/sklearn/numpy/rdkit/gemmi), reusing already-extracted 505 features +
117 docked poses + the phase2/4/6/7 harness unmodified. New artifacts live under `phase9/`.

## Task 1: Shared 505 data loader

- **Status**: done (commit e4fd94e1; load_505() -> (505,3377) feat + (505,5) labels, 5 folds;
  cross-checked bit-for-bit against eval_v12.py's assembly; code-review APPROVE)
- **Prereq tasks**: none
- **Files touched**: `.agent/scratch/vav1_degrad_head/phase9/data_505.py` (new)
- **Change shape**: A thin importable module that assembles, once, the 505 L+poolMSD feature
  matrix (row-concat 388+117 ligand features, row-concat 388+117 Zpool, merged on compound_id
  exactly like `sweep.feature_registry()["L+poolMSD"]`'s `_merge`) and the 505 label table
  (compound_id, logDC50, scaffold, fold from `phase8/vav1_dataset_505_folds.csv`, censored
  per-source: 388 at dc50>=10000, 117 from their own `censored` column). Exposes a function like
  `load_505() -> (Xdf, lab_df)` plus a helper to identify the 117-new-compound id set. Mirrors
  the assembly already validated in `phase8/eval_v12.py` (reuse its logic, do not re-derive a
  different merge).
- **Verification**: `python3 -c "import sys; sys.path.insert(0,'phase9'); import data_505; X,l=data_505.load_505(); print(X.shape, l.shape, l.fold.nunique())"` (from `vav1_degrad_head/`) → feature matrix ~505 rows, label table 505 rows, 5 folds; columns match `phase8/eval_v12.py`'s assembled matrix.
- **Estimated time**: 4 min
- **Rollback (if this task only)**: delete `phase9/data_505.py`.

## Task 2: Fixed-test-set learning curve (Q1)

- **Status**: done (commit 56939cb7. CORE DIAGNOSTIC = PLATEAU both regimes. cross (fixed test =
  3 largest scaffolds, n=62): rho 0.578/0.578/0.547/0.557/0.523 at n_train 100/200/300/388/443 —
  NO upward trend across a 4.4x data range (last-seg Δrho=-0.034 vs CI half-width 0.153 →
  PLATEAU). within (fixed test = fold 0, n=101): 0.472/0.524/0.462/0.469/0.502, also PLATEAU.
  Sanity: n_train=388 cross=0.557 (v1.1 champion scores 0.598 on these 62 via its own CV). The
  whole-curve flatness from n=100 is stronger than the last-segment test alone: not "small rise
  undetected" but "no rise even in point estimates" → structure-as-feature TAPPED, data volume is
  NOT the current lever. _pair_fold no-leakage + scaffold-disjoint asserts verified; code-review
  APPROVE.)
- **Prereq tasks**: 1
- **Files touched**: `.agent/scratch/vav1_degrad_head/phase9/learning_curve.py` (new),
  `.agent/scratch/vav1_degrad_head/phase9/learning_curve_results.csv` (new output)
- **Change shape**: For BOTH regimes, train the v1.1 spec on nested scaffold-disjoint training
  subsets and evaluate on a FIXED test set, plotting test-rho vs n_train. Cross: fix the
  cross-scaffold test set (the ~135 large-scaffold overlap from v1.2's condition B), draw
  scaffold-disjoint training subsets at n_train ≈ 100/200/300/388/full-available, train the
  cross champion (L+poolMSD "aware" pairwise via `sweep.oof_pairwise` machinery, or a direct
  train/predict using the same estimator), record test-rho + bootstrap CI (`eval_pretrain.rho_ci`)
  at each n. Within: analogous nested-subset curve across the full 505 using `cv_scaffold`.
  Compute the slope of the final segment (388→full). Write one CSV row per (regime, n_train)
  with rho/ci_lo/ci_hi/n_train/n_test, and print a slope verdict (plateaued vs rising + numeric
  last-segment slope).
- **Verification**: `python3 phase9/learning_curve.py` → `learning_curve_results.csv` has ≥4
  (n_train, rho, ci_lo, ci_hi) rows per regime; stdout prints a last-segment slope value + a
  "PLATEAU"/"RISING"/"AMBIGUOUS" verdict for each regime.
- **Estimated time**: 6 min
- **Rollback (if this task only)**: delete `phase9/learning_curve.py` + `learning_curve_results.csv`.

## Task 3: Held-out OOF specifically on the 117 new compounds (Q2)

- **Status**: done (commit 96354df7; train-on-388 predict-117: full-117 rho=0.497 [0.325,0.641]
  n=117, scaffold-disjoint-117 rho=0.480 [0.320,0.617] n=113 — new series is genuinely
  predictable from the old 388, comparable to v1.1 cross 0.558; _pair_fold no-leakage verified;
  code-review APPROVE)
- **Prereq tasks**: 1
- **Files touched**: `.agent/scratch/vav1_degrad_head/phase9/heldout_117.py` (new),
  `.agent/scratch/vav1_degrad_head/phase9/heldout_117_results.csv` (new output)
- **Change shape**: Train the v1.1 cross spec on the 388 original compounds, predict the 117 new
  compounds as a pure held-out set; report rho(pred, logDC50) on the 117 with bootstrap CI + n,
  for both a scaffold-disjoint view (117 whose scaffold is unseen in 388) and the full 117. This
  is the metric the v1.2 eval never computed — "how well does the model predict the NEW
  compounds at all". Reuse `data_505.py`'s loader + `rank_harness`/`sweep` estimator + `rho_ci`.
- **Verification**: `python3 phase9/heldout_117.py` → prints rho(117) with CI + n for both views;
  writes them to `heldout_117_results.csv`; every number carries a CI (no bare point estimate).
- **Estimated time**: 4 min
- **Rollback (if this task only)**: delete `phase9/heldout_117.py` + `heldout_117_results.csv`.

## Task 4: Censoring-cap reconcile + shipped within champion + corrected A-on-135 (Q3)

- **Status**: done (commit 4c467348. (a) single-cap reconcile barely moves deltas: cross
  -0.0344→-0.0243, within +0.0270→+0.0250, both same-sign CI-straddles-0 — cap mismatch was NOT
  driving the v1.2 verdict. (b) CORRECT within champion = ligand-gbdt on L (verified vs
  v1_model_card.md:55 / results_v3.md:78, sanity reproduces shipped 0.545→0.5449): Δ(505 vs 388)
  =+0.0047 [-0.051,+0.056] P=0.578 — essentially null, flatter than v1.2's +0.027 which used the
  WRONG model (poolMSD-pairwise). (c) honest matched-set A-on-135=0.5235(per-src)/0.5334(1-cap)
  vs B-on-135=0.5584 — A trails B by ~0.03 on the shared set, not the near-tie the v1.2 prose
  implied. code-review APPROVE, gbdt wiring verified.)
- **Prereq tasks**: 1
- **Files touched**: `.agent/scratch/vav1_degrad_head/phase9/eval_reconciled.py` (new),
  `.agent/scratch/vav1_degrad_head/phase9/eval_reconciled_results.csv` (new output)
- **Change shape**: Re-run the v1.2 A-vs-B paired deltas under ONE censoring-cap convention
  (document which — the 24 new 1000nM-capped compounds are uncensored under the 388's 10000nM
  rule; rebuild the `cens` array accordingly), AND evaluate the ACTUAL shipped WITHIN champion
  (ligand-gbdt on L, via `rank_harness`/`sweep`'s gbdt path — NOT poolMSD-pairwise, which the
  v1.2 eval wrongly used for within), AND report the corrected A-on-shared-135 cross number
  (v1.2 prose quoted A=0.5524 on its 160-universe; the matched-set A-on-135 is ~0.5235 — recompute
  and confirm). Output a corrected comparison table with the cap convention stated inline.
- **Verification**: `python3 phase9/eval_reconciled.py` → prints the reconciled paired deltas
  (cross+within) with CIs, the ligand-gbdt within number, and the A-on-135 cross number; writes
  to CSV; stdout states the single cap convention used.
- **Estimated time**: 5 min
- **Rollback (if this task only)**: delete `phase9/eval_reconciled.py` + `eval_reconciled_results.csv`.

## Task 5: bridge_span_mean on 505 (Q4)

- **Status**: done (commit 5a8b3edc; NOT blocked — phase7 features_one() imported by-path +
  pose_path monkeypatched, 388 spot-check reproduces phase7 to 1e-9. 117/117 bridge extracted
  (mean over 5 seeds' model_0; 116 with bridging, 1 NaN). 505 cross ablation: base 0.5524 → aug
  0.5739, paired Δ +0.021 [-0.015,+0.058] P=0.88 → EVAPORATES (CI spans 0). Same sign/magnitude
  as n=388's +0.028 [+0.002,+0.057] but CI-separation lost at the larger scaffold-diverse set →
  structure-as-ranking-feature at/near exhausted. code-review APPROVE.)
- **Prereq tasks**: 1
- **Files touched**: `.agent/scratch/vav1_degrad_head/phase9/bridge_on_505.py` (new),
  `.agent/scratch/vav1_degrad_head/phase9/bridge_505.csv` (new output: 117 bridge features)
- **Change shape**: Extract bridge_span_mean (and whatever minimal 3-body columns the phase7
  extractor needs) for the 117 new compounds from their docked poses at
  `/mnt/kfs2/.../vav1_sar117_dock_20260712/<CODE>_<cid>/stage2_seed*_model_0.pdb`, reusing
  `phase7/extract_features.py` UNMODIFIED via a thin phase9 wrapper (pass the 117 pose dir as a
  path arg; do NOT edit phase7). Combine with the 388's existing bridge_span_mean, then test
  L+poolMSD+bridge_span_mean vs L+poolMSD cross-scaffold on 505 with a paired-bootstrap Δ
  (`paired_boot_on_overlap`). Report whether the +0.028 headroom seen at n=388 survives at n=505.
  If the phase7 extractor cannot run on the 117 pose layout without editing phase7, log Q4 as
  BLOCKED (per the contract's integration-risk clause) and still write the partial output — do
  NOT edit phase7 to force it.
- **Verification**: `python3 phase9/bridge_on_505.py` → `bridge_505.csv` has 117 rows (or logged
  fewer with reason); prints the L+poolMSD+bridge vs L+poolMSD paired Δ on 505 with CI, or a
  clear "Q4 BLOCKED: <reason>" line.
- **Estimated time**: 5 min
- **Rollback (if this task only)**: delete `phase9/bridge_on_505.py` + `bridge_505.csv`.

## Task 6: Results doc + baton + close contract/plan (Docs)

- **Status**: done (wrote `phase9/results_v9.md` in phase7/8 house style — all four answers
  Q1/Q2/Q3/Q4 with exact numbers+CIs read from the four result CSVs, headline = FLAT learning
  curve -> data-volume-at-this-scale is not the lever [REVERSAL of the standing hypothesis], both
  honesty caveats stated inline [Q2 shows the model generalizes so "tapped"=feature ceiling not
  broken model; cross underpowered per-point so "no DETECTABLE rise" is the rigorous claim but the
  flat 4.4x-range SHAPE is stronger than the single phase8 point], a Corrections section
  superseding two phase8/results_v8.md numbers [cross A-on-160=0.5524 -> matched-set
  A-on-135=0.5235/0.5334; within champion poolMSD-pairwise -> ligand-gbdt on L with +117 delta
  +0.005 P=0.578], and Do-next OBSERVATIONS (i)/(ii)/(iii). Baton: additive top-of-list
  remaining_actions entry + dated body paragraph + contract/plan pointers appended, additive-only.
  Contract frontmatter approved->done + closing Progress Log entry; this plan in-progress->done.)
- **Prereq tasks**: 2, 3, 4, 5
- **Files touched**: `.agent/scratch/vav1_degrad_head/phase9/results_v9.md` (new),
  `.agent/status/aigen-fold-core.md` (additive edit), the contract + plan files (status edits)
- **Change shape**: `results_v9.md` (phase7/8 house style) states all four answers with numbers
  +CIs read from the actual result CSVs (not from memory), the overall data-lever verdict
  (tapped vs still-a-lever, slope as primary evidence; state AMBIGUOUS honestly if so), and the
  recommended next resource allocation as an OBSERVATION not a decision. Baton: additive
  top-of-list remaining_actions entry + dated body paragraph (match the file's existing
  per-session-entry style, additive only), `last_updated` today. Contract frontmatter
  approved→done + closing Progress Log entry; plan frontmatter in-progress→done + Task 6 marked
  done.
- **Verification**: `results_v9.md` exists with all 4 answers + a slope verdict + a
  next-allocation observation; `grep 'status: done'` matches both contract and plan; baton
  frontmatter re-parses with `yaml.safe_load` and `last_updated` = today.
- **Estimated time**: 4 min
- **Rollback (if this task only)**: `git checkout` the baton/contract/plan (if committed) or
  hand-revert; delete `phase9/results_v9.md`.
