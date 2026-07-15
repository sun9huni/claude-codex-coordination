# Recent Cursor Activity Scan

Scan date: 2026-05-18
Window: files modified on or after 2026-05-11
Source root: `/home/ubuntu/.cursor`

## Summary

The last-week Cursor activity is concentrated in the FKSFold-Boltz program,
with work split across the local git repository and the shared `/mnt/data`
workspace. No other top-level project had comparable recent Cursor project
activity in this window.

## Evidence

Recent Cursor plans:

- `/home/ubuntu/.cursor/plans/fragmap-generation-steering_7e2f2e29.plan.md`
  - Modified 2026-05-11.
  - Scope: FragMap generation steering, 9NFR comparison, late-stage steering.
- `/home/ubuntu/.cursor/plans/fragmap_probability_steering_6a8034a0.plan.md`
  - Modified 2026-05-18.
  - Scope: probability-field FragMap steering and C7/C8/C9 pilots.
- `/home/ubuntu/.cursor/plans/target_fragmap_occupancy_af712dd6.plan.md`
  - Modified 2026-05-18.
  - Scope: target patch occupancy and reference-free recruitment field.

Recent Cursor state:

- `ide_state.json` points at:
  - `/home/ubuntu/AGENTS.md`
  - FKSFold FragMap visualization artifacts under
    `/home/ubuntu/FKSFold-Boltz_Advancement/analysis/fragmap_visualization_20260511/`
  - Cursor canvases for FragMap atlas and 9NFR pharmacophore mapping.

Recent Cursor transcripts:

- `/home/ubuntu/.cursor/projects/home-ubuntu/agent-transcripts/...`
  - May 11 and May 18 transcripts reference:
    - `/home/ubuntu/FKSFold-Boltz_Advancement`
    - `/mnt/data/users/ubuntu/workspace/FKSFold-Boltz_Advancement_shared`
    - `/mnt/data/users/kim/outputs`
  - Themes: VAV1 ranking, FragMap/9NFR pilots, F105 MMGBSA, normtest RunB
    prepare and staged MMGBSA.

Recent output and analysis files in the shared workspace:

- `analysis/fragmap_feature_probability_breakdown.py`
- `analysis/map_9nfr_pharmacophore_to_fragmap.py`
- `analysis/compare_ternary_metrics_9nfr.py`
- `outputs/fragmap_9nfr_*`
- `outputs/custom_f105_mmgbsa10ns_20260511_1729`
- `outputs/mmgbsa_normtest143_seed777_stage1_*`

## Active Project Slices

### 1. FKSFold-Boltz Core Repository

Path: `/home/ubuntu/FKSFold-Boltz_Advancement`

Primary activity:

- steering code changes
- FragMap steering implementation
- VAV1 generation configs
- docs and analysis assets
- dirty git tree with many deletions, modifications, and untracked files

Harness: `fksfold-boltz-core-harness.md`

### 2. FragMap / 9NFR Structural Recovery

Paths:

- `/home/ubuntu/FKSFold-Boltz_Advancement`
- `/mnt/data/users/ubuntu/workspace/FKSFold-Boltz_Advancement_shared`

Primary activity:

- 9NFR reference benchmark
- C2/C5/C6/C7/C8/C9 FragMap pilots
- pharmacophore-to-FragMap diagnostics
- target occupancy design

Harness: `fksfold-fragmap-9nfr-harness.md`

### 3. MMGBSA / SLURM Production

Path: `/mnt/data/users/ubuntu/workspace/FKSFold-Boltz_Advancement_shared`

Primary activity:

- F105 10ns retry and DDG merge
- normtest143 RunA/RunB staged MMGBSA
- 16GPU multidir scripts
- SLURM dependency chains and output accounting

Harness: `fksfold-mmgbsa-slurm-harness.md`

### 4. VAV1 Ranking

Paths:

- `/mnt/data/users/ubuntu/workspace/FKSFold-Boltz_Advancement_shared/scripts/vav1_ensemble_rank.py`
- `/home/ubuntu/FKSFold-Boltz_Advancement/configs/vav1_pipeline/`

Primary activity:

- production ranking philosophy
- keyres/hit-rate/consistency-aware ranking
- dead config concern around `ranking_priority`
- baseline vs production rank separation

Harness: `vav1-ranking-harness.md`

## Non-Project Cursor Changes

The recent `.cursor/skills-cursor` and canvas SDK updates look like Cursor
environment updates, not user project work. Treat them as tool context unless
the user explicitly asks to modify Cursor skills or canvases.
