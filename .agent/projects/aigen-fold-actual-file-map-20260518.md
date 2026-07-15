# FKSFold Actual File Map

Scan date: 2026-05-18

This map is based on actual files under:

- `/home/ubuntu/FKSFold-Boltz_Advancement`
- `/mnt/data/users/ubuntu/workspace/FKSFold-Boltz_Advancement_shared`

It supersedes inferences based only on Cursor history.

## Workspace Reality

### Local Git Repo

Path: `/home/ubuntu/FKSFold-Boltz_Advancement`

Observed state:

- Git branch: `platform-versioning-r20260417`.
- Dirty tree with many tracked deletions, modifications, and untracked
  experiment files.
- `README.md` is deleted in the local worktree.
- `scripts/vav1_ensemble_rank.py` is deleted in the local worktree.
- Local steering code contains recent FragMap and Glueprint work.

Use this path for:

- git-aware review and patches
- project-local docs
- source changes that should eventually be committed

### Shared Execution Workspace

Path: `/mnt/data/users/ubuntu/workspace/FKSFold-Boltz_Advancement_shared`

Observed state:

- Not a git repository.
- Contains the complete `README.md`.
- Contains active ranking script `scripts/vav1_ensemble_rank.py`.
- Contains staged MMGBSA scripts and recent output roots.
- Contains recent FragMap/9NFR analysis scripts and output roots.

Use this path for:

- reading active runner and production output state
- SLURM workflow operations after explicit approval
- MMGBSA staged status/merge work

Do not treat shared edits as version-controlled unless copied back to a git
repo intentionally.

## Source Entry Points

### CLI And Config Merge

File: `src/boltz/main.py`

Relevant behavior:

- CLI exposes `--biophysical_config` and `--fragmap_config`.
- `merge_fragmap_yaml_blocks()` merges top-level `fragmap_conditioning` blocks.
- Interface steering args include particles, lambda, resampling strategy,
  GD start, W400 range, blind patch options, and biophysical config.

Harness implication:

- Any config schema change must be checked against CLI parsing and YAML merge.
- FragMap configs can enter through either biophysical config or explicit
  fragmap config.

### Diffusion Extension

File: `src/boltz/model/modules/diffusionv2_extend.py`

Relevant behavior:

- Creates and uses `FragMapSteeringPotential`.
- Applies optional ligand-only FragMap GD when `guidance_weight > 0`.
- Adds FragMap reward into biophysical hybrid resampling through
  `fragmap_reward` and `w_frag`.
- Logs resampling weights and ESS.

Harness implication:

- New steering modes must define whether they affect GD, resampling, or both.
- Any score-scale change needs ESS/resampling-weight inspection.

### Steering Package

Directory: `src/boltz_extension/steering/`

Actual files:

- `base.py`
- `biophysical_scorer.py`
- `fragmap_steering.py`
- `interface_steering_utils.py`
- `potentials.py`
- `schedules.py`
- `ternary_steering.py`
- `trajectory_recorder.py`
- `vis_mixin.py`
- `w400_conditioning.py`

Harness implication:

- Keep new potentials in this package.
- Do not mix scoring math changes with unrelated runner or workflow changes.

## Generation Runner

File: `scripts/run_vav1_s3b_ri3_batch.py`

Actual behavior from docs/code:

- Inputs: `examples/vav1_s3b_ri3/*.yaml` and subset files.
- Uses Docker-style mounted configs under `configs/vav1_pipeline/`.
- Defaults include:
  - `num_particles=4`
  - `interface_lambda=0.5`
  - `interface_resampling_interval=3`
  - `gd_start_t=0.5`
  - W400 conditioning and interface range enabled
- Supports `--dry_run`.

Verification:

```bash
python scripts/run_vav1_s3b_ri3_batch.py --mode oracle --dry_run --config_name oracle_generation.yaml --seed 42 --subset_file configs/vav1_pipeline/controllability_smoke_subset.txt
```

Harness implication:

- Generation changes should prove runner compatibility with `--dry_run` before
  any GPU run.

## FragMap And 9NFR

Main file: `src/boltz_extension/steering/fragmap_steering.py`

Actual modes/features:

- `cluster`
- `grid`
- `cluster_then_grid`
- `feature`
- `feature_probability`
- exclusion, bury, unmapped penalties
- probability grid conversion with local probability overlap
- ligand-only GD support
- CA alignment to FragMap reference PDB

Recent configs:

- `configs/vav1_pipeline/fragmap_conditioning_c2_hotspot.yaml`
- `configs/vav1_pipeline/fragmap_conditioning_feature_c5.yaml`
- `configs/vav1_pipeline/fragmap_conditioning_feature_c6_mrt6160.yaml`

Recent analysis:

- `analysis/map_9nfr_pharmacophore_to_fragmap.py`
- `analysis/fragmap_feature_pose_breakdown.py`
- `analysis/fragmap_feature_probability_breakdown.py`
- `analysis/fragmap_feature_rigid_fit_diagnostic.py`
- `analysis/compare_ternary_metrics_9nfr.py`

Harness implication:

- `target_occupancy` is not yet an implemented mode in the scanned code.
- It should be treated as a new contract-backed scoring mode, not as a tweak to
  feature probability.
- Any target occupancy implementation must define target atom selection, patch
  aggregation, exclusion behavior, and whether GD is ligand-only or target-rigid.

## VAV1 Ranking

Active shared file:

- `/mnt/data/users/ubuntu/workspace/FKSFold-Boltz_Advancement_shared/scripts/vav1_ensemble_rank.py`

Actual current behavior in shared file:

- Computes `baseline_rank` using `ranking_priority`.
- Computes `production_score` from `production_ranking.score_weights`.
- Computes `production_rank` using `production_ranking.priority`.
- Sets `final_rank = production_rank`.
- Adds keyres median, std, hit rate, stability flag, dominance flag, artifact
  risk, QC status, and Dmax risk annotations.

Important divergence:

- The local git worktree has `scripts/vav1_ensemble_rank.py` deleted.
- Shared ranking code appears ahead of the local deleted state.

Harness implication:

- Ranking work must first choose a source of truth.
- If the desired production ranking is the shared implementation, copy or
  reconcile it into the local git repo in a dedicated task.
- Do not evaluate ranking from the local repo until this divergence is resolved.

## MMGBSA And SLURM

Core Snakemake file:

- `workflow/Snakefile`

Core staged scripts in shared workspace:

- `scripts/mmgbsa_16gpu_multidir/slurm_normtest143_stage1_prepare_seed777.sh`
- `scripts/mmgbsa_16gpu_multidir/slurm_normtest143_stage2_md_multidir_seed777.sh`
- `scripts/mmgbsa_16gpu_multidir/slurm_normtest143_stage3_postprocess_seed777.sh`
- `scripts/mmgbsa_16gpu_multidir/slurm_normtest143_stage4_merge_seed777.sh`
- `scripts/mmgbsa_16gpu_multidir/merge_normtest143_stage4_ddg.py`

Actual stage contracts:

- Stage 1 writes `ready_for_mmpbsa_prod.tsv` and `failed_stage.tsv`.
- Stage 2 consumes ready list and writes `md_done.tsv`.
- Stage 3 consumes `md_done.tsv`, runs `run_mmpbsa.py`, and writes
  `mmpbsa_done.tsv`.
- Stage 4 runs `merge_normtest143_stage4_ddg.py` and writes component/DDG TSVs.

Default resource patterns observed:

- Stage 1/2 normtest: `gpu`, `qos=high`, `2 nodes`, `8 A100 per node`,
  `64 cpus/task`, `512G`, `3-00:00:00`.
- Stage 3: `qos=normal`, CPU postprocess, `64 cpus`, `512G`,
  `7-00:00:00`.
- Stage 4: `qos=batch`, `4 cpus`, `32G`, `02:00:00`.

Harness implication:

- SLURM jobs must be treated as external side effects.
- Every submission needs an explicit resource/dependency summary.
- Status must be reported by manifest row counts, not by directory count alone.

## Documentation Anchors

Use these actual docs before broad changes:

- `docs/README.md`
- `docs/repo_operational_surface_20260416.md`
- `docs/vav1_generation_runner_cli.md`
- `docs/fragmap_generation_surface_quality_plan_20260430.md`
- `docs/mmgbsa_role_and_limitations.md`
- `docs/generation_ranking_metric_formulas_20260420_ko.md`
- `docs/mgd_eval_9nfr_benchmark_20260423.md`
- `docs/ternary_fragmap_assessment_20260427.md`

## Verification Matrix

| Task | Minimum file checks | Minimum command checks |
| --- | --- | --- |
| Steering code | `src/boltz_extension/steering/`, `src/boltz/main.py`, `diffusionv2_extend.py` | `python -m compileall src/boltz_extension/steering src/boltz/model/modules src/boltz/main.py` |
| Generation config | config YAML + runner | `python scripts/run_vav1_s3b_ri3_batch.py --dry_run ...` |
| FragMap mode | `fragmap_steering.py`, analysis scripts, 9NFR metrics | `python -m compileall src/boltz_extension/steering analysis` |
| Ranking | active `vav1_ensemble_rank.py` + ranking YAML | `python scripts/vav1_ensemble_rank.py --help` |
| MMGBSA scripts | staged scripts + merge script | `bash -n scripts/mmgbsa_16gpu_multidir/*.sh`; `python scripts/mmgbsa_16gpu_multidir/merge_normtest143_stage4_ddg.py --help` |
| Docs/report only | target docs and linked sources | `rg` link/path sanity; no heavy runtime needed |

## Stop Conditions

Stop and ask before:

- reconciling deleted local files from shared copies
- writing to shared workspace files
- submitting SLURM jobs
- changing production ranking defaults
- changing output directory structure
- adding GD to a new score without diagnostic/resampling evidence
