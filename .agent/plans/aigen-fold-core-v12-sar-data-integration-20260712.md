---
contract: .agent/contracts/aigen-fold-core-v12-sar-data-integration-20260712.md
slice: aigen-fold-core
status: done
total_tasks: 7
estimated_total_min: 35
---

# Plan: v1.2 data integration — fold-reassign + feature-extract the 117 new SAR compounds

Active-agent-work estimates only (2-5 min each); Tasks 3/4 additionally involve SLURM
wall-clock time that is NOT counted in the per-task estimate (job runs in the background,
tracked via `slurm-status` agent / `srun --overlap` liveness check per
`feedback_slurm_liveness_check`).

## Task 1: Build the 505-compound scaffold-CV fold reassignment

- **Status**: done (commit 2f873ca; 505 rows, 5 folds of 101 each, invariant PASS; code-review APPROVE_WITH_NITS, 1 non-blocking nit re: dropna default, not fixed since currently inert)
- **Prereq tasks**: none
- **Files touched**: `.agent/scratch/vav1_degrad_head/phase8/refold_505.py` (new),
  `.agent/scratch/vav1_degrad_head/phase8/vav1_dataset_505_folds.csv` (new output)
- **Change shape**: Load `phase0/vav1_dataset_final.csv` (388) + `phase0/vav1_dataset_sar20260701_new.csv`
  (117), concat compound_id+scaffold only (thin join table, not a full feature dump), run the
  same scaffold-GroupKFold logic `phase2/rank_harness.py` uses for the existing 388, write a
  505-row `(compound_id, scaffold, fold)` CSV. Do NOT touch the existing 388's own fold column
  in `vav1_dataset_final.csv` — this is a new, separate output.
- **Verification**: `python3 phase8/refold_505.py` → prints `505 rows written`, plus an
  invariant check `assert no scaffold appears in more than one fold` prints `PASS`.
- **Estimated time**: 5 min
- **Rollback (if this task only)**: delete `phase8/refold_505.py` +
  `phase8/vav1_dataset_505_folds.csv`; no other file touched.

## Task 2: Build the 117-compound docking input manifest

- **Status**: done (commit 1fa11503; 117 rows, build_stage1_yaml(smiles, config=VAV1_CONFIG) compatibility confirmed; code-review APPROVE)
- **Prereq tasks**: none
- **Files touched**: `.agent/scratch/vav1_degrad_head/phase8/build_dock_manifest.py` (new),
  `.agent/scratch/vav1_degrad_head/phase8/dock_manifest_117.csv` (new output)
- **Change shape**: Read `phase0/vav1_dataset_sar20260701_new.csv`, emit one row per compound
  (compound_id, code, smiles_canon) plus the target config reference (`VAV1_CONFIG` from
  `api/pipeline.py` / `api/ternary_config.py`, imported not re-defined) that the SLURM array
  script (Task 3/4) will consume by array index. Confirms at write-time that
  `TernaryConfig`/`VAV1_CONFIG` import + the 4 pipeline builders accept a bare SMILES string for
  the ligand field (no new builder code — read-only compatibility check).
- **Verification**: `python3 phase8/build_dock_manifest.py` → `dock_manifest_117.csv` has 117
  rows, 3 columns, no blank SMILES; a dry-run YAML build (`api/pipeline.py` stage-1 builder
  called on manifest row 0) succeeds and prints a valid YAML string.
- **Estimated time**: 5 min
- **Rollback (if this task only)**: delete `phase8/build_dock_manifest.py` +
  `phase8/dock_manifest_117.csv`.

## Task 3: SLURM smoke — 1 compound through the 2-stage pipeline (kim account)

- **Status**: done (commit a0324842; job 16537, kim/--qos=normal, 4:33 elapsed, exit 0; schema
  independently verified via gemmi — chain A=397/CRBN, B=61/VAV1, C=1/LIG, matches 388-compound
  schema exactly; code-review APPROVE. Correction: kim account has QOS=normal not batch —
  contract's Resource budget section updated. Note carried to Task 4: JobStore's single sqlite
  jobs.db may need per-array-index db files to avoid write contention under 116 concurrent tasks.)
- **Prereq tasks**: 2
- **Files touched**: `.agent/scratch/vav1_degrad_head/phase8/run_dock_117.sh` (new, SLURM
  launcher script, smoke mode = manifest row 0 only),
  `.agent/scratch/vav1_degrad_head/phase8/dock_driver.py` (new, thin CLI wrapper around
  `api/jobs.py::run_ternary_prediction`, reads one manifest row by array index)
- **Change shape**: A single-compound SLURM submission (`--qos=batch`, kim account, free-GPU
  selector `memory.free>75GB` per `reference_slurm_free_gpu_selection`) that runs the existing
  2-stage pipeline unmodified on manifest row 0, writing output to a new kfs2 directory
  (`vav1_sar117_dock_20260712/`, sibling to `vav1_2stage_alldock_20260702/`). **APPROVAL GATE:
  this is a SLURM/GPU submission — /execute-plan must stop and get explicit user go-ahead before
  this task is delegated, per the contract's matched trigger.**
- **Verification**: job completes (`slurm-status` agent or `sacct`); output pose dir contains
  `model_0.pdb` with chain A=CRBN/B=VAV1/C=glue matching the 388-schema chain-identity check
  used in `phase4/poolfeats_contact.py`; CULTsum/plddt values in the sane range the 388 poses
  showed (not NaN, not near-zero across the board).
- **Estimated time**: 5 min (submission + result inspection; GPU wall-clock separate)
- **Rollback (if this task only)**: `scancel <job_id>` if still running; delete the kfs2 smoke
  output dir; delete `phase8/run_dock_117.sh` + `phase8/dock_driver.py` only if abandoning the
  approach entirely (otherwise they are reused by Task 4).

## Task 4: SLURM full array — remaining 116 compounds (afterok dependency on smoke)

- **Status**: done (commit 107a74d2; 117/117 new SAR compounds docked — 108 clean on first pass
  across 2 batches (job 16540 rows 1-100, job 16638 rows 101-116), 9 recovered via a
  --exclude=host-10-0-5-36 resubmit (job 16657) after diagnosing a node-level GPU-contention
  issue unrelated to the pipeline. 2 dependency-anchor job-ID aging incidents required
  re-confirmation with the user each time (SLURM purges completed jobs from its live table
  faster than expected) — resolved via fresh re-smoke (job 16539) then gating on live array
  elements. Schema independently verified via gemmi on 6+ spot-checked poses across all 3
  submission waves: chain A=397/CRBN, B=61/VAV1, C=1/glue. Zero sqlite lock-contention or
  cache-collision errors across 117 runs. code-review APPROVE.)
- **Prereq tasks**: 3
- **Files touched**: `.agent/scratch/vav1_degrad_head/phase8/run_dock_117.sh` (extend smoke
  script to full-array mode, or a second `run_dock_117_full.sh` submitted with
  `--dependency=afterok:<Task-3-job-id>`), reuses `phase8/dock_driver.py` unmodified
- **Change shape**: Job array over the remaining 116 manifest rows (array indices 1-116),
  kim account, free-GPU selector, writing to the same `vav1_sar117_dock_20260712/` directory
  as Task 3's smoke output. Gated `afterok` on the Task 3 smoke job so a broken pipeline does
  not burn GPU-hours across all 116 before being caught. **APPROVAL GATE: SLURM/GPU submission
  — stop and confirm with the user before delegating, same as Task 3.**
- **Verification**: `sacct` / `slurm-status` shows all 116 array tasks `COMPLETED` (or a
  documented subset with failure reasons logged — not silently fewer than expected); pose dir
  count in `vav1_sar117_dock_20260712/` = 117 total (1 smoke + 116 array), or the logged
  failure count accounts for the gap.
- **Estimated time**: 5 min (submission + monitoring setup; GPU wall-clock separate, watch via
  `srun --overlap` liveness check, not login-node mtime)
- **Rollback (if this task only)**: `scancel <array_job_id>`; partial outputs in the kfs2 dir
  are harmless (Task 5 only consumes what completed, logging the rest as failures) — no revert
  needed beyond stopping the job.

## Task 5: Extract pooled trunk-z + ligand features for the 117 new compounds

- **Status**: done (5a + 5b). 5b: commit 09210ea8 — `phase8/Zpool_117.csv` (117x1156) and
  `phase8/ligand_features_117.csv` (117x2222) built, column schema independently verified
  exact-match (set+order) against `phase4/Zpool_388.csv` / `phase2/ligand_features.csv`. Ligand
  features correctly SELECT the 388's fixed kept-column schema rather than re-deriving a
  variance filter on the 117 alone (the critical correctness risk for this task). No phase0-4
  file touched (git status clean). code-review APPROVE. **Discovery (2026-07-12, before
  starting)**: v1.1's poolMSD feature reads
  trunk s/z tensors from `phase3/pairs/VAV1_<cid>.npz`, sourced (per `phase3/build_pairs.py`)
  from `vav1_2stage_alldock_20260702/latent/VAV1_<cid>_tmpl_trunk.npz` — a separate latent dump
  produced via the Boltz `BOLTZ_DUMP_LATENT` env-gated hook (`boltz2.py:1202-1262`), NOT
  derivable from the PDB poses Task 3/4 already produced. Task 3/4's `dock_driver.py` did not
  set this hook, so a cheap prerequisite GPU pass is needed first: reuse each compound's
  already-built `stage2.yaml` (present at
  `/mnt/kfs2/.../vav1_sar117_dock_20260712/work/<uuid>/stage2/stage2.yaml`, confirmed intact
  for all 117/118 work dirs) with `BOLTZ_DUMP_LATENT=<dir>`, seed=16, sampling_steps=5 (vs 200
  for real docking — pose quality irrelevant here, only the trunk forward pass matters),
  recycling_steps=3 — exact recipe replicated from the original 388's
  `vav1_2stage_alldock_20260702/latent_cell.sh`. User approved this additional SLURM/GPU
  sub-step 2026-07-12. Sub-tasks: 5a (latent-dump GPU pass, SLURM/kim, approval-gated) then 5b
  (the originally-planned poolfeats-style extraction, now reading the new trunk npz files
  instead of the PDB pose dirs directly).

  **Task 5a: done** (commit a540cf6f; 117/117 compounds have a valid
  `VAV1_<compound_id>_tmpl_trunk.npz` at
  `/mnt/kfs2/.../vav1_sar117_dock_20260712/latent/`, s=[1,N,384]/z=[1,N,N,128], N~485-493,
  matching the 388's schema. 6 SLURM jobs total (16666 smoke-perm-fail/16668 smoke-retry/16670
  Batch A/16768 Batch B/16769+16800 node-exclusion resubmits) — all failures were the same
  recurring host-10-0-5-36 GPU-contention issue from Task 4, resolved identically via
  `--exclude`. Independently re-verified via `verify_latent_117.py`, re-run myself: 117/117,
  5/5 spot-checks SANE=True. `git status --porcelain -- api/` clean + `boltz2.py` md5 unchanged
  in AIGENFold/rootfs. code-review APPROVE.)
- **Prereq tasks**: 4
- **Files touched**: `.agent/scratch/vav1_degrad_head/phase8/extract_features_117.py` (new),
  `.agent/scratch/vav1_degrad_head/phase8/features_117.csv` (new output)
- **Change shape**: Reuse `phase4/poolfeats.py`'s pooling logic (unmodified, imported) against
  the `vav1_sar117_dock_20260712/` pose directories to build pooled trunk-z (poolMSD) features,
  plus the existing zero-GPU ligand ("L") descriptor extractor on the 117 SMILES. Any compound
  whose docking failed (per Task 4's logged count) is excluded here with its compound_id
  recorded, not silently dropped.
- **Verification**: `python3 phase8/extract_features_117.py` → row count = successfully-docked
  count (≤117, matches Task 4's completion count exactly); column schema
  (`features_117.csv.columns`) is identical to the existing 388 feature CSV's columns.
- **Estimated time**: 5 min
- **Rollback (if this task only)**: delete `phase8/extract_features_117.py` +
  `phase8/features_117.csv`.

## Task 6: Merge + evaluate v1.1 model spec on the 505-compound set

- **Status**: done (commit 4181530c; independently re-ran the script myself, reproduced every
  number bit-for-bit). Result: **flat/inconclusive — adding the 117 new SAR compounds neither
  clearly helps nor hurts the v1.1 champion.** 3-condition design (A=505 new-fold,
  B=388-only new-fold [PRIMARY control, isolates data-volume alone], C=388-only original fold
  [context, documented 0.5584/0.429]) correctly isolates the data-volume variable from the
  fold-reassignment variable. Sanity check: C reproduces documented v1.1 numbers exactly
  (cross 0.5584, within 0.4290). PRIMARY deltas (A vs B): cross -0.034 [-0.133,+0.049]
  P(A>B)=0.240 (CI straddles zero); within +0.027 [-0.022,+0.077] P(A>B)=0.867 (leans positive,
  CI still includes zero). Notable methodological finding (verified directly against
  `rank_harness.cv_large_scaffold`'s source): the "cross" CV scheme's `fold` parameter is
  accepted but never referenced — GroupKFold splits are rebuilt purely from scaffold-membership
  counts each call — so Task 1's fold reassignment has ZERO effect on any cross-scaffold number
  (B and C are bit-identical for cross); it only matters for "within" (`cv_scaffold`, which
  does key off `fold` directly). Censoring-convention mismatch (388 caps at 10000, 117 caps at
  1000) fed into the pairwise-aware loss as-is per source, stated as a caveat not resolved.
  code-review APPROVE.
- **Prereq tasks**: 1, 5
- **Files touched**: `.agent/scratch/vav1_degrad_head/phase8/eval_v12.py` (new),
  `.agent/scratch/vav1_degrad_head/phase8/eval_v12_results.csv` (new output)
- **Change shape**: Join Task 1's fold assignments + Task 5's new features + the existing 388
  features/folds into one matrix; run the UNCHANGED v1.1 model spec (L+poolMSD pairwise
  ranker) via `phase4/sweep.py`'s `oof_pairwise` + `phase2/rank_harness.py`'s CV machinery;
  compute cross-scaffold and within-scaffold Spearman with paired-bootstrap CI against the
  388-only baseline (0.5584 cross), reusing the comparison style from
  `phase6/eval_pretrain.py` (`rho_ci`, `paired_boot_on_overlap`). No new model code — same
  estimator, same loss, only the row count changes.
- **Verification**: `python3 phase8/eval_v12.py` prints a comparison table (388-baseline vs
  505-result, cross + within, each with CI) and writes it to `eval_v12_results.csv`; no
  point-estimate-only lines (every number has a CI or is explicitly labeled point-estimate).
- **Estimated time**: 5 min
- **Rollback (if this task only)**: delete `phase8/eval_v12.py` + `phase8/eval_v12_results.csv`.

## Task 7: Write results doc, update baton, close contract

- **Status**: done. Produced `phase8/results_v8.md` (comparison table + paired deltas read
  verbatim from `eval_v12_results.csv`, all 4 caveats stated inline next to the relevant
  numbers, honest verdict: success criterion MET, ship/no-ship decision explicitly left open
  per Non-Goals). `.agent/status/aigen-fold-core.md` got an additive-only top-of-list
  `remaining_actions` entry + a new dated body paragraph (2026-07-11 entry and all prior
  content untouched). Contract `status: approved` -> `done` + closing Progress Log entry added.
  This plan's own `status: in-progress` -> `done`.
- **Prereq tasks**: 6
- **Files touched**: `.agent/scratch/vav1_degrad_head/phase8/results_v8.md` (new),
  `.agent/status/aigen-fold-core.md` (edit: new remaining_actions entry + progress note),
  `.agent/contracts/aigen-fold-core-v12-sar-data-integration-20260712.md` (edit: status → done)
- **Change shape**: Results doc states the Task 6 performance numbers (both directions, no
  gate/spin), the docking success/failure count from Task 4, and restates the 3 open curation
  caveats (censoring cap, AIG22071 A/B, non-canonical-warhead) inline next to the reported
  number — not buried in a separate section. Baton gets a new top-of-list remaining_actions
  entry summarizing this contract's outcome + the follow-on ship/no-ship decision as an open
  item. Contract Progress Log gets a closing entry; `status: done`.
- **Verification**: `results_v8.md` exists and contains all 3 caveats + the CI'd performance
  numbers; `.agent/status/aigen-fold-core.md` frontmatter `last_updated` = today;
  `grep 'status: done' .agent/contracts/aigen-fold-core-v12-sar-data-integration-20260712.md`
  matches.
- **Estimated time**: 5 min
- **Rollback (if this task only)**: `git checkout` the baton + contract files (if committed) or
  hand-revert the edits; delete `phase8/results_v8.md`.
