# aigen-fold-core — learned interface encoder over full Boltz-2 latent

Status: done
Slice: aigen-fold-core
Topic: latent-interface-encoder
Date: 2026-07-04
Approval: requested 2026-07-04; approved by: user (2026-07-04 "승인")

## Notes — DONE (2026-07-05)

Deliverable: `.agent/scratch/vav1_degrad_head/phase3/encoder_results.md` + full
pipeline (interface/build_pairs/data/model[BlockPMA-X 34k]/train/eval_encoder) +
kfs2 bundle `vav1_encoder_20260704/`. Design via workflow wf_f68f8a86-6a7.

Verdict: ESCAPE VALVE. A learned interface encoder over the full z does NOT beat the
mean-pool baseline at n=388 on cross-scaffold (the regime that matters) — it overfits
and is significantly WORSE: best encoder large-scaffold 0.178 vs mean-pool Zt_z 0.363
(Δ−0.183, bootstrap P(worse)=0.985). Within-scaffold it does beat mean-pool
(0.398 vs 0.290, +0.109 P=0.99) but still loses to ligand gbdt (0.545). Ablations:
attention is largely inert (mean-only ties full), fusion (pose-cond+affinity) hurts,
stronger reg / drop-VP don't rescue cross-scaffold. Conclusion: the ceiling is the
Boltz features + sample size, NOT the pooling head. v1 stays L + mean-pool trunk-z;
do NOT ship the learned encoder; next lever = cross-program transfer (more n), a
separate contract. Success gate (encoder beats mean-pool cross-scaffold, CI-separated)
NOT met → escape valve documented as designed. All GPU via SLURM as kim (gpu:1 arrays;
whole-node exclusive pends under contention even with idle-but-reserved GPUs).
Follows: aigen-fold-core-vav1-degrad-head-v2-20260702 (done — mean-pool ablation)

## Purpose

The v2 ablation showed the Boltz trunk pair-rep z carries cross-scaffold DC50
signal that ligand fingerprints lack (L+Zt_z 0.383 vs L 0.249, large-scaffold
n=135), but we consumed z by MEAN-POOLING three interface blocks: ~30M values ->
384. That destroys the per-pair "which contact differs" signal. Even so mean-pool
z tied ligand (Zpc_z 0.242). This contract builds a LEARNED interface encoder that
consumes the full interface z (+ s + pose-cond + affinity-g) instead of mean-pool,
to test whether properly using the latent we already have beats the mean-pool and
ligand baselines. GPU is abundant — sweep architectures/seeds/folds aggressively.

## Current State

- Latents on kfs2 (full per-pair npz): 388 trunk (`vav1_2stage_alldock_20260702/latent`)
  + 143 oracle trunk/pose-cond/affinity (`vav1_oracle_latent_20260703/`).
- Token layout verified: CRBN 0-396 / VAV1 397-457 / ligand 458+ (== RDKit heavy).
- Baselines to beat (scaffold-split OOF Spearman, 388 universe):
  mean-pool z: Zt_z scaffold 0.29 / large-scaffold 0.363; ligand L 0.545 / 0.249;
  L+Zt_z 0.452 / 0.383. (142-oracle universe: Zpc_z 0.242 scaffold, large n=27 noise.)

## Scope

- Data prep: from full z npz, build per-compound INTERFACE-PAIR tensors — pairs =
  {ligand atoms} x {VAV1 residues UNION CRBN pocket residues (yaml 15 + contacts)},
  plus interface s (ligand/VAV1/pocket tokens). Fuse trunk z + pose-cond z_conf
  (channel concat) + per-compound affinity-g + affinity scalar. Bounded pair-map
  (pocket-restricted, not all 397 CRBN) to control size/overfit.
- Extraction to unblock full fusion on the POWERED n=388: run the pose-cond
  (return_latent_feats) + affinity (diffusion_samples_affinity=1) passes on the 388
  2-stage inputs too (they exist only for the 143 oracle set now). 388 poses are
  collapsed so pose-cond ~ trunk there, but affinity-g is a genuinely new per-388
  signal. GPU (kim --qos=normal, 16 GPU).
- Model: interface pairs as tokens -> set-transformer (handles variable ligand size)
  with learned attention-pool -> MLP heads. Start from a low-param attention-pool
  baseline; escalate to set-transformer only if it helps. Heavy regularization
  (dropout, weight decay, interface masking) for n=388.
- Head: MULTI-TASK — logDC50 regression + pairwise ranking (censored-aware, pairs.csv)
  + degrader BCE (Dmax>=50) + Dmax regression. Shared encoder, per-task heads.
- Validation: scaffold 5-fold + large-scaffold GroupKFold, OOF Spearman on logDC50
  (primary) + degrader AUROC. Aggressive: architecture x seed x fold sweep in
  parallel on 16 GPU + ensemble + nested-CV hyperparameter search.

## Out of scope

- Cross-program / cross-target transfer (separate contract; the big data lever next).
- Generative / latent-guided design (separate contract).
- New latent TYPES not yet dumped (distogram, atom-level ligand, refined affinity-z)
  — a later escalation only if the encoder saturates.
- Any change to the live WIP Boltz repo; engine edits stay in the kfs2 rootfs copy.

## Success criteria

- PASS: learned-encoder OOF Spearman beats mean-pool z by a CI-separated margin on
  AT LEAST the large-scaffold split (the regime where structure lives), and matches
  or beats L+Zt_z (large-scaffold 0.383). Verification: a scaffold-split OOF table
  (encoder vs mean-pool-z vs L vs L+Zt_z) + paired-bootstrap CI of the deltas,
  written to `phase3/encoder_results.md`.
- Secondary: does the encoder ADD to ligand (L + encoder-embedding > L)? report Δρ+CI.
- ESCAPE (documented, not failure): if the learned encoder cannot beat mean-pool z at
  n=388, conclude the latent's usable signal is saturated at this sample size ->
  transfer/more-data (next contract) is the only path; record it and stop.

## Constraints / budget

- GPU abundant — aggressive sweeps explicitly allowed (many small runs, ensembles,
  nested-CV). SLURM = kim `--qos=normal`; outputs to kfs2 (kfs5/6 full); /home not on
  compute -> rootfs python. Training itself is small-model (CPU/1-GPU per run) but
  fanned out wide.
- n=388 overfit is the central risk -> low-capacity + regularization + honest
  scaffold-split; never tune on the test fold (nested-CV or fixed protocol).

## Non-goals

- Not a within-scaffold potency win (ligand gbdt 0.545 already owns that regime).
- Not a precise predictor claim; the target is cross-chemotype ranking / triage.

## Assumptions and questions

- Assumes the per-pair z variation (erased by mean-pool) holds compound-discriminating
  DC50 signal. If a learned pool over the SAME z can't beat the mean, that assumption
  is falsified (-> escape valve).
- Open: pocket-residue set for bounding the pair-map (start = yaml 15 + per-pose
  contacts <=8A); set-transformer depth/width (start tiny).

## Rollback

- All artifacts in `.agent/scratch/vav1_degrad_head/phase3/` (scratch) + kfs2 latent
  dirs; revert = `sudo -u kim scancel <jobid>; rm -rf <phase3 / kfs2 extra latents>`.
- Read-only on existing latents/poses; no repo/engine changes.

## Implementation steps (high level; /write-plan will decompose)

1. Interface-pair tensor builder from full z npz (pocket-bounded, fusion of trunk+
   pose-cond z + s); per-compound variable-size pair sets + masks. Zero-GPU.
2. Extract pose-cond + affinity(g) on the 388 2-stage inputs (GPU, kim normal).
3. Encoder + multi-task head (attention-pool baseline -> set-transformer); training
   loop with pairwise + regression + BCE; scaffold/large-scaffold CV.
4. Aggressive sweep (arch x seed x fold) + ensemble + nested-CV on 16 GPU.
5. encoder_results.md: OOF table vs baselines + bootstrap CIs -> PASS/escape verdict.

## Progress log

- 2026-07-04: /brainstorm. Decisions (user): VAV1-only first; input = trunk+pose-cond
  z + affinity-g + s (full fusion); multi-task (DC50+Dmax+degrader). Draft pending approval.
