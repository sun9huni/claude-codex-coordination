---
contract: .agent/contracts/aigen-fold-core-latent-interface-encoder-20260704.md
slice: aigen-fold-core
status: done
total_tasks: 9
estimated_total_min: 90
---

# Plan — learned interface encoder over full Boltz-2 latent

Work dir: `.agent/scratch/vav1_degrad_head/phase3/`. Latents (full per-pair npz):
388 trunk `vav1_2stage_alldock_20260702/latent`; 143 oracle
`vav1_oracle_latent_20260703/{latent,latent_pc,latent_affg,latent_out_aff}`.
Token layout CRBN 0-396 / VAV1 397-457 / ligand 458+. Baselines to beat (OOF
Spearman, 388): mean-pool Zt_z scaffold 0.29 / large 0.363; L 0.545 / 0.249;
L+Zt_z 0.452 / 0.383. GPU abundant → fan out. Training uses the rootfs torch or a
local torch env (decide in T4). Pose-dependent tasks need the pose pdb for interface
definition (2-stage pose for 388, oracle pose for 143).

## Task 1: Interface-definition helper
- **Status**: pending
- **Prereq tasks**: none
- **Files touched**: phase3/interface.py
- **Change shape**: given a pose pdb + token layout, return interface token-index
  sets: ligand-atom tokens; protein residues within 8 Å of any ligand atom
  (lig-interface); VAV1↔CRBN residue pairs within 8 Å (PPI). Map pdb atoms→token
  indices via the CRBN(0-396)/VAV1(397-457)/ligand(458+) convention (== RDKit heavy).
- **Verification**: `python3 interface.py <one pose>` → prints |lig|, |lig-iface|,
  |PPI pairs|; sanity: pocket ~10-30 CRBN residues, non-empty PPI.
- **Estimated time**: 8 min
- **Rollback**: rm interface.py

## Task 2: Interface-pair tensor builder
- **Status**: pending
- **Prereq tasks**: 1
- **Files touched**: phase3/build_pairs.py
- **Change shape**: per compound, using T1 interface sets, gather pair features from
  trunk z at {ligand}×{VAV1 ∪ CRBN-pocket} pairs (+ fuse pose-cond z_conf where
  present, channel concat) + interface s (ligand/VAV1/pocket tokens) + per-compound
  affinity-g + affinity scalar; write per-compound npz (pair feats [P,C], pair
  index/type, s feats, masks) + manifest.csv (compound_id, n_pairs, has_posecond,
  has_affinity). Variable P per compound.
- **Verification**: `python3 build_pairs.py --smoke` → 5 compounds written; print
  pair-tensor shapes, channel count, %compounds with pose-cond/affinity.
- **Estimated time**: 12 min
- **Rollback**: rm phase3/pairs/ + build_pairs.py

## Task 3: Extract pose-cond + affinity on the 388 2-stage inputs ⛔ GPU gate
- **Status**: pending
- **Prereq tasks**: none (independent; unblocks full-fusion on n=388)
- **Files touched**: kfs2 `vav1_2stage_alldock_20260702/` (cell_pc/cell_aff mirrors) + submit
- **Change shape**: reuse the 143 launchers pointed at the 388 stage2_input YAMLs
  (return_latent_feats pose-cond pass + affinity diffusion_samples_affinity=1 pass);
  smoke→full on kim --qos=normal 16 GPU; dump to new latent_pc/latent_affg dirs there.
- **Verification**: posecond npz ≈388, affg npz ≈388, affinity json ≈388, 0 FAIL.
- **Estimated time**: 6 min submit+verify (compute hours)
- **Rollback**: `sudo -u kim scancel <jid>; rm -rf <388 latent_pc/latent_affg>`

## Task 4: Dataset + dataloader + fold assignment
- **Status**: pending
- **Prereq tasks**: 2
- **Files touched**: phase3/data.py
- **Change shape**: torch Dataset over per-compound npz → (pair feats, pair mask, s
  feats, affinity vec, labels: logDC50/Dmax/degrader/censored); collate padding
  variable P; merge scaffold+fold from labels; expose scaffold & large-scaffold split
  iterators. Pick torch env (rootfs python vs local) here + record it.
- **Verification**: `python3 data.py --smoke` → one padded batch; shapes + label dtypes;
  fold sizes match rank_harness CV.
- **Estimated time**: 10 min
- **Rollback**: rm data.py

## Task 5: Encoder + multi-task head
- **Status**: pending
- **Prereq tasks**: 4
- **Files touched**: phase3/model.py
- **Change shape**: interface-pair encoder — attention-pool baseline (learned query
  over pair tokens: linear(pair feat)→attn weights→pooled) + optional shallow
  set-transformer block (flag); concat pooled-pair + pooled-s + affinity; MLP trunk
  → 3 heads (logDC50 reg, Dmax reg, degrader logit). Dropout + small width.
- **Verification**: `python3 model.py --smoke` → forward on a batch returns 3 head
  outputs with right shapes; param count printed (target < ~100k).
- **Estimated time**: 12 min
- **Rollback**: rm model.py

## Task 6: Training loop + multi-task losses
- **Status**: pending
- **Prereq tasks**: 5
- **Files touched**: phase3/train.py
- **Change shape**: loss = pairwise-ranking on logDC50 (censored-aware, pairs.csv) +
  logDC50 MSE + Dmax MSE + degrader BCE (weighted); AdamW + weight decay; early stop
  on val fold; per-fold OOF preds saved. One-fold short-run entry (`--fold k --epochs`).
- **Verification**: `python3 train.py --fold 0 --epochs 20 --smoke` → loss decreases,
  writes OOF preds for fold 0; no NaN.
- **Estimated time**: 15 min
- **Rollback**: rm train.py + phase3/oof/

## Task 7: OOF evaluation vs baselines
- **Status**: pending
- **Prereq tasks**: 6
- **Files touched**: phase3/eval_encoder.py
- **Change shape**: assemble OOF preds across folds → Spearman(logDC50) scaffold +
  large-scaffold + degrader AUROC; paired-bootstrap CI of Δρ vs mean-pool Zt_z, vs L,
  vs L+Zt_z (reuse rank_harness OOF for baselines on identical folds).
- **Verification**: `python3 eval_encoder.py` → table encoder vs 3 baselines + Δ+CI.
- **Estimated time**: 8 min
- **Rollback**: rm eval_encoder.py

## Task 8: Aggressive sweep + ensemble ⛔ GPU gate
- **Status**: pending
- **Prereq tasks**: 6, 7
- **Files touched**: phase3/sweep.py (+ SLURM submit)
- **Change shape**: fan out arch (attn-pool vs set-transformer; width/depth/dropout/
  loss-weights) × seed × fold on 16 GPU; nested-CV for hyperparams (tune on inner
  folds only); ensemble best config across seeds; collect OOF. Log any dropped cells.
- **Verification**: sweep manifest complete; best config's OOF Spearman + CI printed;
  ensemble ≥ single-run.
- **Estimated time**: 8 min submit+verify (compute hours)
- **Rollback**: `sudo -u kim scancel <jid>; rm -rf phase3/sweep_out`

## Task 9: encoder_results.md verdict + handoff
- **Status**: pending
- **Prereq tasks**: 8
- **Files touched**: phase3/encoder_results.md, .agent/status/aigen-fold-core.md, contract (→done)
- **Change shape**: results doc — OOF table (encoder vs mean-pool z vs L vs L+Zt_z,
  scaffold + large-scaffold + AUROC) + bootstrap CIs + PASS/escape verdict + which
  fused inputs/pairs mattered (ablation) + chosen model; update baton; mark contract+plan done.
- **Verification**: encoder_results.md has table+verdict; `./scripts/handoff.sh claude aigen-fold-core` clean.
- **Estimated time**: 11 min
- **Rollback**: revert doc/status edits
