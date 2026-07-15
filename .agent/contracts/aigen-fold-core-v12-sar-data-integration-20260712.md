---
status: done
slice: aigen-fold-core
topic: v12-sar-data-integration
date: 2026-07-12
owner: claude
approved_by: sunghoon.kim (2026-07-12, "승인")
requested: 2026-07-12
cross_slice: []
triggers_matched:
  - "SLURM/GPU submission — 117 new compounds need the 2-stage ternary docking pipeline
    (api/jobs.py::run_ternary_prediction) re-run to produce pooled trunk-z features, same
    pipeline class as vav1_2stage_alldock_20260702 (388 poses)"
  - "ranking semantics — the VAV1 DC50 cross-scaffold ranking model's training set changes
    388→505 compounds, same trigger class as latent-interface-encoder / mosir / ssl-pretrain /
    3body-mgoff-features (all took contracts)"
  - "4+ files — fold-reassignment script, GPU docking submission, feature-build script,
    eval/report script, results doc"
---

# aigen-fold-core — v1.2 data integration: fold-reassign + feature-extract the 117 new SAR compounds, report performance

## Purpose

Incorporate the 117 newly-curated same-assay VAV1 DC50 compounds
(`phase0/vav1_dataset_sar20260701_new.csv`, curated 2026-07-11 from
`20260701_VAV1_SAR.xlsx`) into the modeling dataset, going 388→505
(+30.2%). This is the standing lever identified across the last several
sessions (representation-side levers — learned encoder, set-kernel,
MoSIR, SSL-pretrain, 3-body features — are exhausted at n=388; same-assay
data expansion is the only lever left untried). The goal THIS contract is
**data incorporation, not a performance guarantee**: build the 505-compound
feature matrix correctly (same pipeline as v1.1, extended to the new
rows) and report cross-scaffold performance honestly, whatever it shows.

## Current State

- `phase0/vav1_dataset_final.csv` (388, shipped) + `phase0/vav1_dataset_sar20260701_new.csv`
  (117 new, compound_id 511-627, fold=-1 unassigned) + `phase0/vav1_dataset_extended.csv`
  (505, audit-merge only — not feature-complete, not fold-complete).
- v1.1 champion (shipped, UNCHANGED by this contract): pairwise ranking loss on
  L (ligand GBDT descriptors, zero-GPU) + poolMSD (per-block mean+std+median of
  pooled trunk-z from the 2-stage docked pose). Cross-scaffold Spearman 0.5584.
  Artifacts: `phase3/v1/v1_1_B_pairwise_{poolmsd,lzt}.joblib`, `v1_model_card.md`.
  Pipeline: `phase4/{poolfeats,sweep,pairwise_ranker,v1_1_model}.py`,
  `phase2/rank_harness.py` (build_matrix, CV_SCHEMES incl. scaffold-GroupKFold, load_labels).
- Trunk-z source for the existing 388: docked poses at
  `/mnt/kfs2/.../vav1_2stage_alldock_20260702/latent_out_pc388/VAV1_<cid>_tmpl/.../model_0.pdb`.
  The 117 new compounds have NO docked poses yet — this is the GPU-bound part of this contract.
  Reuse `api/pipeline.py` / `api/jobs.py::run_ternary_prediction` (target/E3-parametric,
  `VAV1_CONFIG` preset) — same 2-stage recipe (stage-1 2-seed free pred → CULTsum pick →
  templated CIF → stage-2 5-seed), byte-identical VAV1 path per the semantic-object-layer
  contract's golden test.
- Ligand descriptor features ("L") are SMILES-only, zero-GPU, trivially extendable to 117 new
  rows with the existing extractor.
- 3 open curation caveats (NOT resolved by this contract, carried forward as documented
  limitations): censoring cap 1000nM (new) vs 10000nM (legacy) not equated; AIG22071A*/B*
  same-structure discordant DC50 (68.19 vs 149.52nM) not auto-merged; 3 non-canonical-warhead
  compounds (AIG22013/22018/22138) flagged not dropped.

## Assumptions And Questions

- assumptions: the existing 2-stage ternary pipeline (VAV1_CONFIG preset) generalizes to the
  117 new ligands without per-compound tuning (same assumption already validated for all 388);
  RDKit can parse all 117 SMILES (already confirmed 0 invalid during curation).
- open questions / risks: (a) censoring-cap and duplicate-structure caveats may inject noise
  into the ranking signal — not resolved here, reported as a limitation on the performance
  number, not silently smoothed over; (b) 117 new poses may fail CULTsum/geometry QC at a
  different rate than the original 388 (unknown until run) — failures are logged and excluded
  with a stated count, not silently dropped.
- tradeoffs: running the full 2-stage GPU pipeline per new compound (vs. a cheaper single-pass
  encoder-only extraction) keeps the v1.2 feature pipeline byte-identical in kind to v1.1's,
  which is required to make the 388-vs-505 performance comparison attributable to data volume
  alone (not a confounded feature-pipeline change).

## Constraints

- allowed: new scripts under `.agent/scratch/vav1_degrad_head/phase8/`; SLURM submission via
  the `kim` account (`--qos=batch`, free-GPU selector `memory.free>75GB`, per
  `reference_slurm_free_gpu_selection`); reuse `api/pipeline.py`/`api/jobs.py` unmodified;
  reuse `phase2/rank_harness.py`, `phase4/{poolfeats,sweep,pairwise_ranker}.py` unmodified;
  write new fold assignments + new pose/feature CSVs only under phase8/.
- forbidden: modifying `phase3/v1/*.joblib`, `v1_model_card.md`, or any existing 388-compound
  CSV/fold column; modifying `api/pipeline.py`/`api/jobs.py`/engine files; touching
  `bridge_span_mean` or any other post-v1.1 candidate feature (separate contract); resolving
  the 3 open curation caveats via wet-lab (not available); re-deriving the 388's own trunk-z
  (already extracted, reused as-is).
- external: SLURM GPU via `kim` account, no GPU-hour cap (user-confirmed); all GPU jobs via
  SLURM only, never inline (hard rule).

## Non-Goals

- Adding `bridge_span_mean` or any other new engineered feature to v1.2 — separate contract,
  so the 505-vs-388 delta is attributable to data volume alone.
- Replacing v1.1 as the shipped model — this contract only measures and reports; the
  ship/no-ship call is a separate decision made after the report lands.
- Wet-lab resolution of the 3 open curation items (censoring cap origin, AIG22071 A/B
  representative value, non-canonical-warhead re-confirmation).
- Any change to REST API (`/v1/ternary`) or the semantic-object-layer schema.
- Re-scoring or re-folding the existing 388 beyond regenerating the fold COLUMN across the
  combined 505 (their features/poses are untouched).

## Done When

- `phase8/refold_505.py`: scaffold-GroupKFold fold reassignment across all 505 compounds
  (388 + 117), using the same fold logic as `phase2/rank_harness.py`. Verify: 505 rows, no
  compound_id collision, per-fold scaffold-group isolation holds (no scaffold split across
  train/test within a fold, same invariant check as the original 388 build).
- 117 new compounds docked via the existing 2-stage pipeline (SLURM, kim account) and pooled
  trunk-z features extracted (`phase4/poolfeats.py` logic, reused). Verify: 117 (or documented
  fewer, with failure count + reason) pose dirs + feature rows produced; spot-check byte-shape
  match against the 388 feature schema (same columns).
- Ligand ("L") features extended to the 117 new rows using the existing zero-GPU extractor.
  Verify: 117 new rows, no NaN columns beyond what's already tolerated in the 388 baseline.
- Combined 505-row feature matrix + fold assignment written to `phase8/` (NOT overwriting any
  388-only artifact).
- Cross-scaffold + within-scaffold performance of the UNCHANGED v1.1 model spec (L+poolMSD
  pairwise ranker) reported on 505 vs the existing 388 baseline (0.5584 cross), with
  paired-bootstrap CI, reusing `eval_pretrain.py`-style comparison machinery. Reported
  regardless of direction (no performance gate on "done").
- Results doc (`phase8/results_v8.md`) states the 3 open curation caveats explicitly next to
  the performance number (not buried) + baton update; contract → done.

## Implementation Steps

1. `phase8/refold_505.py`: build the combined 505-row scaffold set, run scaffold-GroupKFold,
   write `phase8/vav1_dataset_505_folds.csv` (compound_id, scaffold, fold only — a thin join
   table, not a full feature dump). verify: 505 rows, scaffold-isolation invariant check passes.
2. SLURM submission (kim account) of the 117 new compounds through the existing 2-stage
   ternary pipeline. verify: job completes; N pose dirs written; failure count logged if <117.
3. `phase8/extract_features_117.py`: pooled trunk-z (poolMSD) + ligand ("L") features for the
   117 new compounds, using the existing 388 extractors unmodified. verify: 117-row feature
   CSV, column schema matches the 388 feature CSV exactly.
4. `phase8/eval_v12.py`: merge features+folds into the 505-row matrix, run the unchanged v1.1
   model spec via `rank_harness`/`sweep` machinery, cross+within Spearman with paired-bootstrap
   CI vs the 388 baseline. verify: comparison table printed, CI reported, no point-estimate-only
   claims.
5. `phase8/results_v8.md` + baton update + contract → done. verify: doc present, 3 caveats
   stated inline with the reported number, scripts reproducible.

## Resource budget

- GPU: SLURM via `kim` account, no hard GPU-hour cap (user-confirmed 2026-07-12). Scale
  precedent: the 388-compound 2-stage docking (`vav1_2stage_alldock_20260702`) is the closest
  comparable full-pipeline run; 117 is ~30% of that volume. Submit as a job array over free
  GPUs (`memory.free>75GB` selector), not a single exclusive multi-GPU block.
  **Correction (Task 3, 2026-07-12)**: `sacctmgr show assoc user=kim` shows kim's association
  only has `QOS=normal` (no `batch`) — `--qos=batch` from the original assumption above does
  not exist for this account; actual smoke job ran `--qos=normal --gres=gpu:1`. `ubuntu` has no
  SLURM association at all (consistent with the prior mmgbsa-era baton note). Same no-cap
  budget, corrected flag only.
- CPU: fold reassignment + feature merge + eval are all zero-GPU/minutes-scale.

## Risks

- regression risk: none to v1.1 — all new artifacts land under `phase8/`, no existing file
  touched (enforced by the Constraints section).
- integration risk: the 2-stage pipeline is reused unmodified, but a first-time run on 117
  never-before-docked ligands could surface parsing/QC edge cases the 388 didn't hit (e.g. the
  3 non-canonical-warhead compounds) — logged and excluded with a stated count, not silently
  papered over.
- hidden dependency risk: the censoring-cap and duplicate-structure caveats are real label
  noise sources that could suppress or inflate the measured delta — explicitly named in the
  results doc rather than left implicit in a single performance number.

## Rollback

- revert strategy: delete `phase8/`; no shared-state or existing-artifact changes to undo.
- containment strategy: v1.1 artifacts (`phase3/v1/v1_1_B_pairwise_*.joblib`, `v1_model_card.md`)
  remain untouched and are still the ONLY shipped model regardless of this contract's outcome;
  v1.2 (if ever promoted) would be new versioned files alongside, not an in-place overwrite.

## Progress Log

- 2026-07-12: scoped via /brainstorm. Success criterion = data incorporation confirmed (505
  correctly fold-reassigned + feature-complete), performance reported not gated. Out-of-scope:
  bridge_span_mean (separate contract, keeps this a single-variable data-volume comparison),
  v1.1 replacement decision, wet-lab resolution of 3 open curation items. Constraint: SLURM via
  kim account, no GPU cap (user-confirmed). Rollback: v1.1 artifacts untouched, v1.2 versioned
  separately (user-confirmed).
- 2026-07-12: APPROVED by sunghoon.kim ("승인"). Next: /write-plan.
- 2026-07-12: CLOSED. All 7 plan tasks done (per
  `.agent/plans/aigen-fold-core-v12-sar-data-integration-20260712.md`'s per-task Status notes):
  (1) 505-row scaffold-CV fold reassignment, invariant PASS; (2) 117-compound docking manifest;
  (3) SLURM smoke (job 16537, kim/normal QOS — corrected from the Resource-budget section's
  original `batch` assumption, which does not exist for the kim association) — schema PASS via
  gemmi; (4) full 116-compound array (jobs 16540/16638, 9 recovered via node-exclusion resubmit
  job 16657 after a host-10-0-5-36 GPU-contention issue, not a pipeline bug) — **117/117 docked**;
  (5a) mid-plan discovery that poolMSD needs Boltz TRUNK latents not derivable from the poses —
  user-approved second cheap GPU pass (6 jobs incl. 2 node-exclusion resubmits, same
  host-10-0-5-36 contention pattern) — **117/117 latents**, re-verified 5/5 spot-checks sane;
  (5b) `Zpool_117.csv` + `ligand_features_117.csv`, column schema independently verified
  identical to the existing 388 tables; (6) evaluated the UNCHANGED v1.1 model spec on 505 vs
  388-only, 3-condition design (A=505 new-fold, B=388-only new-fold PRIMARY, C=388-only original
  fold sanity-check — reproduces documented 0.5584/0.4290 exactly) — **result: flat/inconclusive**
  (cross Δ−0.034 [−0.133,+0.049] P=0.240; within Δ+0.027 [−0.022,+0.077] P=0.867, neither
  CI-separated), plus a new methodology finding that `cv_large_scaffold`'s `fold` argument is
  accepted but never used internally (fold reassignment affects within-scaffold numbers only);
  (7) this task — `phase8/results_v8.md` written with the full comparison table + all 4 caveats
  (censoring-cap mismatch, AIG22071 A/B, 3 non-canonical-warhead compounds, the CV-scheme
  fold-ignoring finding) stated inline next to the relevant numbers, baton updated, contract and
  plan closed. **Done-When criteria all met**: 505-row fold reassignment done+verified, 117
  compounds docked+feature-extracted with schema parity, 505-vs-388 performance reported with
  CIs regardless of direction, caveats stated inline not buried. Success criterion (data
  incorporation confirmed + honest report, not a performance gate) MET. Ship model UNCHANGED:
  v1.1 (cross 0.5584). The v1.2 ship/no-ship call remains a separate, explicitly out-of-scope
  decision for the user (per this contract's own Non-Goals) — not made here.
