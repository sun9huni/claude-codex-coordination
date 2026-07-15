# Contract — CRBN cross-target transfer pilot (GSPT1 -> VAV1)

- **Slice**: aigen-fold-core
- **Status**: approved
- **Approval**: user 2026-07-06 (picked "GSPT1 최소 파일럿" among transfer design options).

## Scope
Test whether external CRBN-glue degrader labels (GSPT1) transfer to VAV1 cross-scaffold
ranking via the shared, target-agnostic CRBN-pocket engagement (LP block = ligand x
CRBN-pocket trunk-z). Steps:
- Extract trunk-z from a CRBN+glue BINARY Boltz prediction (no neosubstrate) for
  GSPT1 118 glutarimide glues + VAV1 388 (re-extracted binary for apples-to-apples).
- Pool the LP block (ligand x CRBN-pocket 14 residues) from the binary trunk z.
- Transfer eval: pairwise ranker on VAV1 (ligand + LP), add GSPT1 (ligand + LP,
  within-target pairs) as aux; measure VAV1 cross-scaffold (large_scaffold) vs no-aux.

## Out of scope
- Full ternary / new-target (GSPT1/IKZF3) pipelines. IKZF3 (deferred to after pilot).
- Absolute-value pooling across assays (within-target pairwise only).

## Triggers matched
- SLURM submission (GPU).

## Success criteria
- 506 binary trunk-z npz produced (VAV1 388 + GSPT1 118).
- LP-block features built; transfer eval reports VAV1 cross-scaffold rho with vs without
  GSPT1 aux (paired bootstrap). Go/no-go: does GSPT1 aux move VAV1 cross.

## Resource budget
- 506 CRBN+glue binary predictions x (sampling_steps 5, recycling 3, 1 seed) = cheap
  trunk-only forwards. kim, qos=normal, gpu:1 array width 8. ~20 min. Output in new
  bundle vav1_crbn_binary_latent_20260706 (ubuntu-owned, 777 for kim job writes).

## Rollback plan
- New bundle only; VAV1 388 ternary latents untouched. Delete bundle to revert. No
  engine edits (reuses env-gated latent hook + boltz.main predict).
