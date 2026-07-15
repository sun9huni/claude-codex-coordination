---
contract: .agent/contracts/aigen-fold-core-vav1-degrad-head-v2-20260702.md
slice: aigen-fold-core
status: done
total_tasks: 13
estimated_total_min: 52
---

> DONE 2026-07-03. Executed via the latent-extraction + escalation path (not the
> literal T-by-T order): T1/T8/T9 (ligand/labels/harness) + T4 (latent hook) done;
> pose-geometry P (T2/T3) found non-additive; Z built as trunk (388 shared + 143
> oracle varying) AND pose-conditioned (s_conf/z_conf) AND affinity (scalar + g);
> ablation_final (T10-T12) + results_v2.md (T13). Verdict in the contract Notes:
> structure adds cross-scaffold via cheap trunk z (L+Zt_z 0.383 vs L 0.249, powered
> n=135); pose-conditioned/affinity did not add. v1 = L + trunk-latent-z.

# Plan — VAV1 degradation-ranking head v2 (full L/P/E/Z feature ablation)

Prereq gate G0 (not a task): SLURM job 13407 completes → 388 stage-2 pose ensembles
on kfs2. Pose-dependent tasks (T2,T3,T5,T6,T7) are blocked on G0. L / harness / hook
tasks (T1,T4,T8,T9) can run before G0.

Work dir: `/home/ubuntu/.agent/scratch/vav1_degrad_head/phase2/`.
Poses: `/mnt/kfs2/data/users/ubuntu/vav1_2stage_alldock_20260702/out_stage2/`.

## Task 1: Ligand feature builder (RDKit2D + Morgan)
- **Status**: done (388 rows, 173 rdkit + 2048 morgan -> ligand_features.csv; parquet engine absent -> ALL feature artifacts are CSV. code-review APPROVE 2026-07-02)
- **Prereq tasks**: none
- **Files touched**: phase2/features_ligand.py
- **Change shape**: compute RDKit2D (173, variance-filtered) + Morgan ECFP4 (2048) for
  all 388 valid compounds; write ligand_features.parquet (compound_id × features).
- **Verification**: `python3 features_ligand.py` → prints "388 rows, N_rdkit + 2048 morgan"; parquet exists.
- **Estimated time**: 4 min
- **Rollback**: rm ligand_features.parquet

## Task 2: Pose-geometry features + QC at 388
- **Status**: pending
- **Prereq tasks**: none (but blocked on G0 = 13407 done)
- **Files touched**: phase2/extract_features.py (exists; run at full scale)
- **Change shape**: run existing extractor on full out_stage2; escape-filter; write
  pose_features.csv (388 × geometry) + print QC (escape %, CULT-seated %, VAV1 F/ICC).
- **Verification**: `python3 extract_features.py` → pose_features.csv ~388 rows; QC prints between/within/F (does pilot F hold?).
- **Estimated time**: 4 min
- **Rollback**: keep prior pose_features.csv backup

## Task 3: Recompute engineered scores (E) on new productive poses
- **Status**: pending
- **Prereq tasks**: 2 (blocked on G0)
- **Files touched**: phase2/features_engineered.py
- **Change shape**: compute platform-style scores on the NEW stage-2 poses —
  keyres (R796/D797/S799/W820 functional-atom contacts), ligand_face, glueprint-style
  neosurface, g_bind (pocket occupancy), keyres_hit_rate (seed consistency); write
  engineered_features.csv (388 × ~6).
- **Verification**: `python3 features_engineered.py` → 388 rows, 6 E cols; sanity: keyres corr with CULT dists.
- **Estimated time**: 5 min
- **Rollback**: rm engineered_features.csv

## Task 4: boltz2.py latent-dump hook (additive, flag-gated) ⛔ host-code gate
- **Status**: done (rootfs COPY only, not live WIP repo; env-gated BOLTZ_DUMP_LATENT, +58/-0 lines in predict_step, backup .prehook_bak; flag-off byte-identical, flag-on dumps trunk s[1,N,384]+z[1,N,N,128]. code-review APPROVE 2026-07-03. ★CAVEAT: true pose-conditioned latent needs ConfidenceModule return_latent_feats=True (engine change, OUT OF SCOPE) -> Z family = TRUNK latent only (compound+template context, pose-independent, ~ligand-in-context); posecond fallback = trunk s + coords (redundant w/ P). Update T5-T7: extract trunk latent, K=1/compound, 388 forwards.)
- **Prereq tasks**: none
- **Files touched**: /home/ubuntu/AIGENFold/src/boltz/model/models/boltz2.py (+ mirror to rootfs)
- **Change shape**: additive `--dump_latent <dir>` flag; when set, after trunk pairformer
  writes s,z npz, and after structure sample + confidence module writes pose-conditioned
  representation npz. Default OFF → byte-identical. NOT touching WIP steering code.
- **Verification**: flag OFF → 1 predict md5 unchanged vs baseline; flag ON → s.npz+z.npz written on 1 smoke. `git diff` = additive only.
- **Estimated time**: 5 min
- **Rollback**: delete the added flag branch (NOT git restore — engine tree has WIP)

## Task 5: Latent-extraction launcher + smoke
- **Status**: pending
- **Prereq tasks**: 4 (blocked on G0)
- **Files touched**: kfs2 `.../vav1_2stage_alldock_20260702/latent_extract.sh` + cell
- **Change shape**: launcher reusing stage-2 templated inputs, rootfs python, SLURM-env
  unset, --dump_latent; trunk latent K=1/compound (pose-invariant) + pose-conditioned
  per stage-2 pose. 1-cell smoke first.
- **Verification**: smoke 1 compound → s/z/pose npz present, shapes sane.
- **Estimated time**: 5 min
- **Rollback**: rm launcher + latent out

## Task 6: SLURM latent-extraction pass ⛔ GPU gate
- **Status**: pending
- **Prereq tasks**: 4, 5 (blocked on G0)
- **Files touched**: (submit only) kfs2 latent out
- **Change shape**: `sudo -u kim sbatch --qos=normal` latent pass on exclusive nodes,
  16 GPU; smoke→afterok→full; dump latents for 388 (×K).
- **Verification**: latent npz count ≈ 388 (trunk) + 388×K (pose-cond); monitor rankerr=0.
- **Estimated time**: 4 min (submit+verify; compute hours)
- **Rollback**: `sudo -u kim scancel <jobid>; rm -rf <latent out>`

## Task 7: Latent feature matrix (Z)
- **Status**: pending
- **Prereq tasks**: 6
- **Files touched**: phase2/features_latent.py
- **Change shape**: interface-masked mean-pool of trunk s over VAV1 interface tokens +
  masked-mean of z over ligand-interface cross-pairs (mirror affinity.py); pose-cond
  latent aggregated over seeds; PCA/linear-probe reduce to ≤32 dims for n=388; write
  latent_features.parquet.
- **Verification**: `python3 features_latent.py` → 388 × ≤32; explained-variance printed.
- **Estimated time**: 5 min
- **Rollback**: rm latent_features.parquet

## Task 8: Labels + censoring + ranking pairs
- **Status**: done (388 cmp, 28 censored; within 555 / global-3x 50517 / hard 89 / certain-order 10080 = matches phase0 ref; labels.csv + pairs.csv. code-review APPROVE 2026-07-02)
- **Prereq tasks**: none
- **Files touched**: phase2/labels.py
- **Change shape**: logDC50 + degrader(Dmax≥50); mark right-censored (≥ceiling/inactive);
  build certain-order pairs (active<censored) + within-scaffold + global + hard
  (low-vs-high-Dmax same-scaffold) pair tables.
- **Verification**: `python3 labels.py` → pair counts printed (within/global/hard/censored).
- **Estimated time**: 4 min
- **Rollback**: rm labels artifacts

## Task 9: Ranking harness (pairwise-LTR + regression, scaffold + large-scaffold + LOSO)
- **Status**: done (generic evaluate()+CLI; ligand sanity gbdt scaffold 0.545/large 0.222/loso 0.599; LTR=logistic-fallback (no xgb/lgbm). Note: large_scaffold trains within big-subset. code-review APPROVE 2026-07-02)
- **Prereq tasks**: 8
- **Files touched**: phase2/rank_harness.py
- **Change shape**: generic harness: given a feature matrix, run ridge + GBDT (regression)
  + pairwise-LTR (LambdaMART/XGBoost-rank or logistic-pairwise); scaffold-split 5-fold +
  large-scaffold GroupKFold + LOSO; OOF Spearman + bootstrap CI.
- **Verification**: `python3 rank_harness.py --features ligand` → OOF ρ + CI on L (≈0.50 sanity).
- **Estimated time**: 5 min
- **Rollback**: rm rank_harness.py

## Task 10: Assemble feature matrices (L/P/E/Z + combos)
- **Status**: pending
- **Prereq tasks**: 1, 2, 3, 7
- **Files touched**: phase2/assemble.py
- **Change shape**: merge per-compound L/P/E/Z on compound_id; emit named feature sets
  {L, P, E, Z, L+P, L+E, L+P+E, L+Z, L+P+E+Z}; handle missing-pose compounds.
- **Verification**: `python3 assemble.py` → prints each set's shape + n compounds covered.
- **Estimated time**: 3 min
- **Rollback**: rm assemble artifacts

## Task 11: Ablation eval
- **Status**: pending
- **Prereq tasks**: 9, 10
- **Files touched**: phase2/ablation.py
- **Change shape**: run rank_harness over every feature set × {ridge,gbdt,LTR} ×
  {scaffold-split, large-scaffold GroupKFold}; write ablation_table.csv (set,model,cv,ρ,CI).
- **Verification**: `python3 ablation.py` → ablation_table.csv with all rows; L≈0.50 sanity.
- **Estimated time**: 4 min
- **Rollback**: rm ablation_table.csv

## Task 12: Does-structure-add verdict + gate
- **Status**: pending
- **Prereq tasks**: 11
- **Files touched**: phase2/verdict.py
- **Change shape**: for each pose family (P/E/Z), Δρ vs L with bootstrap-CI-nonoverlap +
  permutation p; pick best set; apply gate (scaffold ρ≥0.55 AND large-scaffold ρ≥0.50 →
  PASS else escape). Print decision.
- **Verification**: `python3 verdict.py` → prints best set, Δρ+p per family, PASS/escape.
- **Estimated time**: 3 min
- **Rollback**: rm verdict output

## Task 13: results_v2.md + handoff
- **Status**: pending
- **Prereq tasks**: 12
- **Files touched**: phase2/results_v2.md, .agent/status/aigen-fold-core.md, contract (→done)
- **Change shape**: write results doc (ablation table, verdict, chosen feature center,
  importance, caveats); update slice baton; mark contract+plan done.
- **Verification**: results_v2.md exists with table+verdict; `./scripts/handoff.sh claude aigen-fold-core` clean.
- **Estimated time**: 5 min
- **Rollback**: revert doc/status edits
