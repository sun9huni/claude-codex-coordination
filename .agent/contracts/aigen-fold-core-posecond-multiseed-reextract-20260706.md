# Contract — pose-cond multi-seed re-extraction (388)

- **Slice**: aigen-fold-core
- **Status**: approved
- **Approval**: requested 2026-07-06; approved by user 2026-07-06 (directed the run + answered params: 5 seeds / mean / all 388 / 8 GPU).

## Scope
Re-extract the pose-conditioned latent (z_conf, s_conf) for all 388 VAV1/CRBN
compounds using **5 diffusion seeds** (16/123/300/42/777) at sampling_steps=50,
and **mean-aggregate** z_conf/s_conf across seeds, to test whether a seed-averaged
(denoised) pose-cond changes the within / in-distribution / cross-scaffold verdict
vs the existing single-seed (seed 16) pose-cond.

Motivation: the single-seed pose-cond is null cross-scaffold and additive only
in-distribution; ~10-20% of compounds are pose-bimodal across seeds, so seed
averaging is the residual-uncertainty test the single-seed run cannot answer.

## Out of scope
- Trunk z (pose-independent, unaffected — v1.1 B′ stands).
- Affinity latent, other targets/E3s.
- Re-fitting v1.1 unless the averaged pose-cond beats single-seed with CI separation.

## Triggers matched
- SLURM submission (GPU).

## Success criteria
- 388 averaged posecond npz at kfs2 `latent_pc388_ms5/` (z_conf/s_conf mean over
  seeds, n_seed recorded).
- Re-run phase4 pose-cond pooling + probe on the averaged z_conf; report whether
  within / in-dist / cross change vs single-seed (posecond_probe/posecond_only numbers).
- Verify: `ls latent_pc388_ms5/*.npz | wc -l` == 388 (or report shortfall + cause).

## Resource budget
- ~1940 A100 forwards (388×5), 50 sampling steps. kim, qos=normal, gpu:1 array
  width 8. ~8h wall. Output to kfs2 (14T free); per-seed temp cleaned per compound.

## Rollback plan
- New kfs2 dir `latent_pc388_ms5/` only; existing `latent_pc388` (single-seed) and
  all phase3/phase4 artifacts untouched. Delete the dir to revert. No engine edits
  (reuses existing rootfs env hooks BOLTZ_RETURN_LATENT_FEATS/BOLTZ_DUMP_LATENT).
