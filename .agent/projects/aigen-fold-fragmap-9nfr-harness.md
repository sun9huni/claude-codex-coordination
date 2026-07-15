# FragMap And 9NFR Harness

Project paths:

- `/home/ubuntu/FKSFold-Boltz_Advancement`
- `/mnt/data/users/ubuntu/workspace/FKSFold-Boltz_Advancement_shared`

Primary recent Cursor plans:

- `fragmap-generation-steering_7e2f2e29.plan.md`
- `fragmap_probability_steering_6a8034a0.plan.md`
- `target_fragmap_occupancy_af712dd6.plan.md`

## Purpose

This harness governs FragMap-assisted generation, 9NFR structural recovery,
pharmacophore mapping, target occupancy, and related diagnostics.

## Operating Principle

FragMap is not production truth by default. Treat it as a prior that must pass
diagnostic and structural recovery gates before it can influence generation.

Allowed progression:

1. Diagnostic-only overlay.
2. Posthoc score correlation on known cases.
3. Resampling-only pilot.
4. Weak late GD pilot.
5. Small panel validation.
6. Production consideration.

Do not jump from a new FragMap score directly to production GD.

## Active Assets

Code:

- `src/boltz_extension/steering/fragmap_steering.py`
- `src/boltz_extension/steering/interface_steering_utils.py`
- `src/boltz_extension/steering/biophysical_scorer.py`
- `src/boltz/model/modules/diffusionv2_extend.py`

Analysis:

- `analysis/compare_generated_to_9nfr.py`
- `analysis/compare_ternary_metrics_9nfr.py`
- `analysis/map_9nfr_pharmacophore_to_fragmap.py`
- `analysis/fragmap_feature_pose_breakdown.py`
- `analysis/fragmap_feature_probability_breakdown.py`
- `analysis/fragmap_feature_rigid_fit_diagnostic.py`

Configs and workflows:

- `configs/vav1_pipeline/fragmap_conditioning*.yaml`
- `workflow/slurm_fragmap_9nfr_*.sh`
- `workflow/slurm_9nfr_*shared.sh`

Outputs:

- `outputs/fragmap_9nfr_abc_20260511_143235`
- `outputs/fragmap_9nfr_c2_hotspot_20260518_100557`
- `outputs/fragmap_9nfr_c5_feature_20260518_133103`
- `outputs/fragmap_9nfr_c6_mrt6160_feature_20260518_135228`
- `outputs/fragmap_9nfr_probability_20260518_142633`

Actual implemented FragMap modes in `fragmap_steering.py`:

- `cluster`
- `grid`
- `cluster_then_grid`
- `feature`
- `feature_probability`

`target_occupancy` is a planned mode, not an implemented mode in the scanned
files. Treat it as a new scoring contract.

## Required Design Split

### Ligand Feature FragMap

Use only for:

- pharmacophore mapping
- diagnostic probability overlap
- ablation pilots C2/C5/C6/C7/C8/C9

Primary failure to guard:

- feature-center over-pull that improves FragMap score while worsening 9NFR
  ligand or ternary metrics.

### Target FragMap Occupancy

Use for the next implementation track:

- target patch occupancy in favorable probability mass
- ligand-proximal target shell reward
- exclusion/clash penalty
- patch-level aggregation

Production guard:

- no 9NFR-specific residue pairs in production configs
- 9NFR may be an evaluation case, not a production objective

## Metrics Gate

For every FragMap generation pilot, produce or inspect:

- `9nfr_comparison_chainmap.csv`
- `ternary_metrics.csv` or equivalent
- feature/occupancy breakdown CSV
- component score scale logs
- resampling weight non-uniformity or ESS when available

Primary metrics:

- ligand centroid RMSD
- ligand nearest-neighbor RMSD
- ligand-target contact F1
- CRBN-target interface F1
- target reference residue minimum distance
- clash count

Secondary metrics:

- CRBN-ligand contact F1
- iPTM/confidence collapse
- exclusion/bury penalty
- feature probability overlap

## Go / Hold / Stop

Go:

- FragMap condition improves or preserves 9NFR ligand metrics.
- Target/interface F1 improves without CRBN anchor collapse.
- Resampling weights become meaningfully non-uniform for the right reason.

Hold:

- FragMap score improves but 9NFR metrics worsen.
- GD helps one seed but increases collapse or clash.
- Mapping depends on features missing from the 9NFR crystal ligand residue.

Stop:

- Direct FragMap GD repeatedly worsens ligand or target contact metrics.
- New score cannot distinguish particles.
- Alignment or chain mapping is unstable.

## Verification Commands

Before SLURM:

```bash
python -m compileall src/boltz_extension/steering analysis
bash -n workflow/slurm_fragmap_9nfr_*.sh
```

After output generation:

```bash
python analysis/compare_ternary_metrics_9nfr.py --help
```

Use Docker only when a required dependency such as `gemmi` is unavailable in the
host Python environment. Record the image name and mounts in the task contract.

## Contract Requirements

Every new FragMap scoring mode needs a contract with:

- exact score formula
- config schema
- default weights
- no-go criteria
- benchmark outputs to compare against
- whether it is diagnostic, resampling, or GD
- list of files allowed to change
- explicit answer to whether gradients move ligand atoms only, target rigid body,
  or target internal coordinates
