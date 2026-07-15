# Contract — token_trans_bias (diffusion-conditioning) extraction (388)

- **Slice**: aigen-fold-core
- **Status**: done
- **Approval**: requested + approved 2026-07-15 (user: "진행", continuing the
  same priority-4 item flagged after the raw-s control result). Executed same
  day, verdict recorded.

## Scope

Extract `token_trans_bias` (`DiffusionConditioning`, `boltz2.py:551/561-576` in
this rootfs copy) for all 388 compounds -- the token-level pairwise bias that
conditions the main 24-layer diffusion transformer. Computed once per
prediction, right after the recycling loop, from trunk z + relative-position
encoding via `PairwiseConditioning` (concat + 2 Transition blocks, NOT the same
as the confidence/affinity modules' own re-conditioning, and NOT identical to
trunk z itself). Pool it the same LV/LP/VP way as Zt_z (`phase4/poolfeats.py`
method reused as-is, since this is also a `[N,N,C]` token-pair tensor), and run
it through the same CV harness (scaffold + large_scaffold), with the same
between/within-scaffold direct-decomposition sanity check the last two rounds
required before trusting any large_scaffold number.

Motivation: this is the last of the "diffusion_conditioning 6종" priority item
from the boltz2 teardown; scoped down to just `token_trans_bias` because it is
the only one of the 6 that is token-level (the other 5 -- q, c, atom_enc_bias,
atom_dec_bias, to_keys -- are atom-level or non-tensor and would need a new
atom-to-token pooling scheme this pilot doesn't have built). It sits between
trunk z and the diffusion sampling loop; a genuinely untested axis.

## Out of scope

- q, c, atom_enc_bias, atom_dec_bias, to_keys (atom-level / non-tensor; would
  need new atom-to-chain pooling infrastructure, separate scope if pursued).
- Any change to the shipped v1.1 model.

## Triggers matched

- SLURM submission (GPU, new forward-pass extraction across 388 compounds).

## Success criteria

- 388 `token_trans_bias` arrays saved to a new kfs2 dir, one per compound.
- Pooled (LV/LP/VP) feature set run through `rank_harness.evaluate()`, same
  folds as L/Zt_z/s_inputs; report OOF Spearman rho (pooled + CI) next to
  L 0.545/0.222, Zt_z 0.290-0.363/0.363-0.383, s_inputs-control 0.20/(unreliable).
  large_scaffold numbers get the direct between/within-scaffold sanity check
  before being trusted (per the 2 prior rounds' methodology catch).
- Verify: `ls <out_dir>/*.npz | wc -l` == 388, or report shortfall + cause.

## Resource budget

- ~388 A100 forward passes, single seed (token_trans_bias depends only on
  trunk s/z + relative-position encoding, not the diffusion sampling seed --
  same reasoning as the s_inputs control, no 5-seed repeat needed). Reuses the
  existing stage2_input/ yamls, sampling_steps=5/recycling_steps=3 cheap
  recipe. kim, qos=normal, gpu:1 array, %30 throttle, split into <=100-element
  batches per kim's normal QOS MaxSubmitPU=100 (same pattern as the s_inputs run).
- Engine change: one additive dict_out key (`token_trans_bias`, forward(),
  right after the `diffusion_conditioning = {...}` dict is built) + one new
  additive env-gated dump block (`BOLTZ_DUMP_TOKEN_TRANS_BIAS`, predict_step,
  mirrors BOLTZ_DUMP_S_INPUTS/BOLTZ_DUMP_LATENT exactly). Backup taken before
  editing.

## Rollback plan

- New kfs2 dir only (`vav1_ttb_control_20260715/`); no existing artifact
  touched. Delete the dir to revert. Engine hook is additive-only in the
  rootfs copy; backup restores byte-for-byte if needed.

## Progress Log

- 2026-07-15: contract drafted + approved per contract-check gate, continuing
  directly from the raw-s control result under the same user go-ahead.
- 2026-07-15: engine hook added, smoke + full 388-compound array succeeded
  (0 failures). Pooled + evaluated -- verdict: real signal, within-scaffold
  rho +0.31-0.32 (CI-separated), comparable to Zt_z; large_scaffold GroupKFold
  number (+0.39) partially but not fully corroborated by direct decomposition
  (weaker, non-significant, same direction). First of the 3 phase10 checks
  that behaves like a genuine feature rather than a confound/CV-artifact. See
  phase10/results_token_trans_bias.md. Contract done; redundancy-vs-Zt_z test
  flagged as a follow-up, not executed in this round.
