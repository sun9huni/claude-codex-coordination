# Contract — 2-stage validation on 9NFR-glue (A1BYX) + MRT6160

- **Slice**: aigen-fold-core
- **Status**: approved
- **Approval**: user 2026-07-06 (proposed the run + chose 5 seeds / MRT6160+A1BYX).

## Scope
Run the existing 2-stage pipeline (stage-1 free predict -> protein-only template ->
stage-2 templated docking) for two glues, SAME 5-seed set (16,123,300,42,777):
- A1BYX (= MRT-23227, the 9NFR crystal glue): SMILES
  `Cn1ccc(COc2ccc(-c3cccc([C@H]4CCC(=O)NC4=O)c3Cl)cc2)n1`
- MRT6160 (active control, = VAV1_185): SMILES
  `ClC1=C(C=CC=C1C2CCC(NC2=O)=O)C(C=C3)=CC=C3N(C=CC=C4)C4=O`
CRBN/VAV1 sequences, pocket + contact constraints, MSA identical to the 388 inputs.
Purpose: A1BYX docked pose vs 9NFR crystal = ground-truth pipeline validation (does
it reproduce the experimental pose for the crystal's own glue); MRT6160 same-seed
comparison.

## Out of scope
- Latent/ranking (this is pose generation only).
- Other glues; engine changes.

## Triggers matched
- SLURM submission (GPU).

## Success criteria
- stage-1 + template + stage-2 (5 seeds) complete for both glues.
- Compare stage-2 docked (CRBN-aligned) to 9NFR crystal: VAV1 RMSD, glue RMSD,
  DockQ-style. Report both glues + seed consistency.

## Resource budget
- ~2 glues x (2 stage1 + 5 stage2) x 50 steps = ~14 A100 forwards. kim, qos=normal,
  gpu:1 array width 2. ~15-20 min. Output in existing bundle
  vav1_2stage_alldock_20260702 under new ids VAV1_MRT6160 / VAV1_A1BYX (no collision
  with numeric 388).

## Rollback plan
- New ids only (VAV1_MRT6160*, VAV1_A1BYX*); existing 388 outputs untouched.
  Delete those files to revert. No engine edits (reuses cell.sh + convert_build_stage2).
