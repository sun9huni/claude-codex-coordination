# Contract — raw pre-recycling s control-group test (388)

- **Slice**: aigen-fold-core
- **Status**: done
- **Approval**: requested 2026-07-15; approved by user 2026-07-15 (contingent on kim's SLURM submission being currently viable). Executed same day, verdict recorded.

## Scope

Extract `s` (= `s_inputs`, InputEmbedder/AtomAttention-encoder output, `trunkv2.py:192-208`)
for all 388 VAV1/CRBN compounds — the token representation as it exists **before**
entering the recycling loop, i.e. before Template/MSA/PairFormer touch it at all.
Pool it the same way Zt_z is pooled (masked mean over the LV/LP/VP interface
blocks, `phase4/poolfeats.py`'s method) and run it through the identical CV
harness (`phase2/rank_harness.py`, scaffold + large_scaffold, same folds already
used for Zt_z/Zaffg/L) to get a directly comparable OOF Spearman rho.

Motivation (control group, per Boltz-2 teardown discussion 2026-07-15): every
structural feature tested so far (Zt_z, Zpc_z, Aff, Zaffg) is read out **after**
at least the trunk's Template+MSA+PairFormer processing. `s_inputs` has zero
structural context — it is res-type + MSA-profile + atom-attention pooling only,
no recycling, no triangle updates, no template information. If `s_inputs` alone
reproduces Zt_z's cross-scaffold rho (0.363/0.383 combined with L), that would
mean the "structure adds value cross-scaffold" reading of v1.1 is confounded with
plain sequence/composition information, not genuine structural context — a
result that would require revisiting the v1.1 model card's interpretation
(not necessarily the model itself, which doesn't depend on this claim to work).

## Out of scope

- Full diffusion / pose generation — not needed, `s_inputs` is computed before
  recycling and pose generation both.
- Any change to the shipped v1.1 model or its features (Zt_z stays as-is
  regardless of this result).
- Re-running Zt_z/Zpc_z/Aff/Zaffg (already extracted, untouched).

## Triggers matched

- SLURM submission (GPU, new forward-pass extraction across 388 compounds).

## Success criteria

- 388 `s_inputs` arrays (or their LV/LP/VP-pooled features, whichever is cheaper
  to hook) saved to a new kfs2 dir, one per compound (deterministic given the
  same stage2 YAML input — no per-seed variation expected, single extraction
  pass suffices, unlike pose-conditioned features).
- Pooled feature set run through `rank_harness.evaluate()` on the same
  scaffold/large_scaffold folds; report OOF Spearman rho (pooled + CI) next to
  the standing baselines: L 0.545/0.222, Zt_z 0.290-0.363/0.363-0.383,
  L+Zt_z(pairwise, v1.1) 0.558 cross.
- Verify: `ls <out_dir>/*.npz | wc -l` == 388, or report shortfall + cause.

## Resource budget

- ~388 A100 forward passes (single seed each — `s_inputs` doesn't depend on
  diffusion sampling seed, so no 5-seed repeat needed, unlike the pose-cond
  re-extraction contract). Same YAML inputs as the existing stage2 trunk
  extraction (`vav1_2stage_alldock_20260702/stage2_input/`), so cost is
  comparable to one seed's worth of that prior run, not a new pipeline.
- Engine change: one additive env-gated line in the rootfs copy
  (`BOLTZ_DUMP_S_INPUTS=1` -> `np.save(...)` right after
  `s_inputs = self.input_embedder(feats)`, `boltz2.py:414`), flag-off
  byte-identical, no control-flow change (does not skip the rest of the
  forward pass — same safety pattern as the existing DUMP_AFFG/RETURN_LATENT_FEATS
  hooks). kim, qos=normal, gpu:1 array, backfill free GPUs.

## Rollback plan

- New kfs2 dir only (e.g. `latent_sinputs388/`); no existing artifact touched.
  Delete the dir to revert. Engine hook is additive-only in the rootfs copy
  (never the shared WIP repo); reverting = removing the one `if os.environ.get(...)`
  block, or just leaving it (no-op when the env var is unset).

## Progress Log

- 2026-07-15: contract drafted per contract-check gate (SLURM submission
  trigger), awaiting approval before any GPU work.
- 2026-07-15: approved. Engine hook added (boltz2.py, additive, backup kept),
  smoke (2 compounds) + full 388-compound array all succeeded, 0 failures.
  Pooled + evaluated -- verdict: control-group hypothesis does NOT hold
  (v1.1's cross-scaffold interpretation survives); see
  phase10/results_raw_s_control.md for full writeup. Contract done.
