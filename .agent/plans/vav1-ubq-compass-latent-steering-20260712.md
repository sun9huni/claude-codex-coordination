---
contract: .agent/contracts/vav1-ubq-compass-latent-steering-20260712.md
slice: vav1-ubq
status: done
total_tasks: 11
estimated_total_min: 52
---

# Plan: COMPASS decoupled latent steering ported to Boltz-2 (Path 2) — GT-free productive-geometry target battery + reaching-efficiency discriminator

Path 2 confirmed: port the COMPASS method (anchor-timestep Tweedie x̂0 → backprop to conditional
embeddings → clean reverse diffusion) onto our Boltz-2 engine. Precondition met: full PDF read,
exact params recorded in the contract Current State. Engine edits are ADDITIVE and confined to the
rootfs Boltz-2 copy (`/mnt/kfs2/data/users/ubuntu/boltz_native_20260621/rootfs/...`) + a saved
`.diff` artifact — the host WIP engine tree is NOT touched (chiral-wire precedent). New scripts live
under `.agent/scratch/compass_steering/`. Per-task time = active-agent work; GPU wall-clock (Tasks
7-9) is separate and tracked via `slurm-status` / Monitor. Tasks 7/8/9 are SLURM/GPU APPROVAL GATES
— /execute-plan must stop and get explicit user go before each.

Phase A (loss library) and Phase B (engine hook) are both zero/low-GPU and are the bulk of the
de-risking; the hard success gate is Task 7 (Stage-0 smoke). Tasks 8-11 are reported-not-gated
science.

## Task 1: Differentiable geometry-ops helper

- **Status**: done (commit b988ff45; Cα/Cβ dist-matrix + virtual-Cβ + Gram-Schmidt backbone frames
  + orientation loss, all autograd-differentiable, GEOM_OPS OK selftest grads finite+nonzero;
  code-review APPROVE)
- **Prereq tasks**: none
- **Files touched**: `.agent/scratch/compass_steering/geom_ops.py` (new)
- **Change shape**: torch-differentiable primitives operating on a coordinate tensor `x [N,3]` (or
  a Boltz atom-coord tensor): pairwise Cα distance matrix, virtual-Cβ construction + its distance
  matrix, per-residue backbone local frame (rotation) extraction, and the orientation loss
  `trace(R_pred·R_guide^T)` — all autograd-differentiable. Mirrors COMPASS's DCα/DCβ/Lori
  (PDF §4.2). No engine dependency; pure torch.
- **Verification**: `python3 .agent/scratch/compass_steering/geom_ops.py --selftest` → builds a
  random `x` with `requires_grad`, computes each op, calls `.backward()` on a scalar reduction, and
  asserts all input grads are finite + nonzero; prints `GEOM_OPS OK`.
- **Estimated time**: 5 min
- **Rollback (if this task only)**: delete `geom_ops.py`.

## Task 2: COMPASS-faithful coordinate-target loss (P1 / 9NFR)

- **Status**: done (commit 42431e44; compass_coord_loss Lca/Lcb/Lori/Lreg weights 1/2/1/1 +
  load_9nfr_backbone gemmi/PDB-fallback; selftest on REAL 9NFR (97-res interface) differentiable,
  monotonic descent 11.11→9.93, re-run verified; code-review APPROVE)
- **Prereq tasks**: 1
- **Files touched**: `.agent/scratch/compass_steering/losses_coord.py` (new)
- **Change shape**: the faithful COMPASS objective `Ltot = 1.0·Lca + 2.0·Lcb + 1.0·Lori + 1.0·Lreg`
  (MSE on Cα/Cβ distance matrices to a guidance structure + orientation + L2 on the embedding
  offset), taking a guidance structure's extracted (DCα, DCβ, R_guide) and a predicted x̂0. P1's
  guidance = the 9NFR SH3c-on-CRBN interface (read/align the 9NFR ternary). Weights/params from the
  contract (Table A1).
- **Verification**: `python3 .agent/scratch/compass_steering/losses_coord.py --selftest` → on a
  perturbed-vs-9NFR structure, loss decreases as the structure is nudged toward 9NFR, grad wrt x̂0
  is nonzero; prints `LOSS_COORD OK` + the loss value.
- **Estimated time**: 5 min
- **Rollback (if this task only)**: delete `losses_coord.py`.

## Task 3: Catalytic-geometry loss battery (C1-C4)

- **Status**: done (commit dd8715f7; C1 near-attack / C2 +Bürgi-Dunitz 107° / C3 per-lysine factory
  (K788/804/810/814/815, grad-isolated) / C4 cone-patch; real config values loaded (near-attack
  4.5Å, cone apex/axis, zone 21Å; BD 107° + half-angle 45° documented defaults); softplus hinges
  differentiable everywhere; re-run CATALYTIC OK; code-review APPROVE)
- **Prereq tasks**: 1
- **Files touched**: `.agent/scratch/compass_steering/losses_catalytic.py` (new)
- **Change shape**: differentiable geometric-criterion losses on x̂0 — C1 near-attack distance
  (Lys Nζ → Ub-Gly76-C in the cone frame), C2 = C1 + Bürgi-Dunitz approach angle (~107°) term,
  C3 per-lysine variants (K788/K804/K810/K814/K815), C4 cone-patch occupancy. Params from
  `discriminator_config_20260629.json` / CRLClosurePotential cone geometry. Each returns a scalar
  loss + is autograd-differentiable. (Genuine extension of COMPASS's protein-only distance loss to
  geometric criteria — flagged in the contract.)
- **Verification**: `python3 .agent/scratch/compass_steering/losses_catalytic.py --selftest` → each
  of C1-C4 differentiable, grad nonzero on a test complex, and C1 decreases when Nζ is moved toward
  the target; prints one `OK` line per loss.
- **Estimated time**: 5 min
- **Rollback (if this task only)**: delete `losses_catalytic.py`.

## Task 4: Interface / composite / manifold loss battery (P2, P3, G1, G2, M1)

- **Status**: done (commit 3bc09cf6; P2 degron-competence / P3 contact-recovery / G1 3-body
  bridging / G2 bridge-span / M1 apo-broadening, all differentiable via soft-min/soft-argmin/
  sigmoid-membership/band; cutoffs from glue_competence+phase7; master LOSS_BATTERY defensive
  import = 10/10 targets (14 keys, C3 split per-lysine); re-run INTERFACE OK; code-review APPROVE.
  Phase A loss battery complete.)
- **Prereq tasks**: 1
- **Files touched**: `.agent/scratch/compass_steering/losses_interface.py` (new)
- **Change shape**: differentiable losses — P2 degron-competence (D797 carboxyl / S799 OG contact),
  P3 contact-recovery (RT-loop {R796,D797,S799}↔{W400,H357,N351}), G1 3-body glue-bridging
  (glue atoms simultaneously near a CRBN and a VAV1 residue), G2 bridge-span (mean CRBN-VAV1 gap
  over bridging glue atoms), M1 apo-broadening (loose-encounter target). Reuse the geometric intent
  of glue_competence.py / contact_recovery / phase7 hyper3+bridge, reimplemented differentiably.
- **Verification**: `python3 .agent/scratch/compass_steering/losses_interface.py --selftest` → each
  of P2,P3,G1,G2,M1 differentiable + grad nonzero on a test complex; prints one `OK` line per loss.
  A registry `LOSS_BATTERY` (name→fn) enumerating all 10 (C1-4,P1-3,G1-2,M1) is importable.
- **Estimated time**: 5 min
- **Rollback (if this task only)**: delete `losses_interface.py`.

## Task 5: Boltz-2 conditional-embedding offset plumbing (rootfs, env-gated, additive)

- **Status**: done (commit 60179a20; rootfs diffusionv2_extend.py COMPASS_STEERING-gated additive
  block + compass_wire.diff [+62/-1, 0 content deletions]. Δ_single→s_trunk, Δ_pair→
  diffusion_conditioning['token_trans_bias'] (raw z not fed to denoiser — bias is the real 2D
  conditioning). inference_mode-exit clone → zero-init leaves → cond=base+Δ, dict shallow-copied,
  self._compass_* exposed for Task 6. ast.parse OK, flag-off provable no-op; GPU byte-identity
  deferred to Task 7. .pre_compass.bak backup made. code-review APPROVE.)
- **Prereq tasks**: none
- **Files touched**: `/mnt/kfs2/data/users/ubuntu/boltz_native_20260621/rootfs/app/src/boltz/model/
  modules/diffusionv2_extend.py` (rootfs copy edit) + `.agent/scratch/compass_steering/
  compass_wire.diff` (saved diff artifact)
- **Change shape**: add an env-gated (`COMPASS_STEERING=1`) additive path that, before the reverse
  loop, clones the conditional embeddings (trunk s/z in `network_condition_kwargs`) out of
  inference-mode into optimizable leaf tensors and injects additive offsets Δ_s, Δ_z (initialized
  0, so flag-on with 0 offsets == stock). No behavior change when the flag is off.
- **Verification**: with flag OFF, one Boltz-2 forward's `model_0.pdb` md5 is byte-identical to the
  stock rootfs (record both); with flag ON + Δ=0, also byte-identical; `compass_wire.diff` applies
  cleanly and is fragmap/chiral-wire-independent (diff touches only new COMPASS lines).
- **Estimated time**: 5 min
- **Rollback (if this task only)**: `git apply -R` the diff to the rootfs file (restore from
  `.preoverlay.bak`); delete `compass_wire.diff`. Host tree untouched throughout.

## Task 6: Anchor-timestep Tweedie latent optimization loop (rootfs, env-gated)

- **Status**: done (commit 7ed68ef7; rootfs diffusionv2_extend.py COMPASS_STEERING gate extended
  with Phases 2-4 + compass_wire.diff [+227/-1, 0 content deletions]. Phase 2 no_grad partial-denoise
  to midpoint anchor (EDM Euler VERIFIED byte-faithful to stock lines 1144-1149: same
  denoised_over_sigma=(x_noisy-x_den)/t_hat + step_scale*(sigma_t-t_hat) form); Phase 3 Adam
  (lr0.015/100it/clip1.0/clamp0.5) on Δ_single/Δ_pair via single backpropped anchor
  preconditioned_network_forward per iter (no trajectory unroll); Phase 4 detached base+Δ* rewire →
  existing unmodified no_grad reverse loop resamples fresh (atom_coords untouched by Phases 2-3).
  Pluggable loss via interface_args['compass_loss_fn'] OR module _COMPASS_LOSS_FN (globals().get,
  no sentinel), safe Δ=0 fallback when unset. anchor_frac 0.5 → round(0.5*n_steps) clamped
  [1,n_steps-1], overridable. ast.parse OK; AST-proof all Task-6 stmts inside gate (only new
  non-gated line = import os); Adam-loop fake-tensor selftest PASS (Δ grads |16.24|/|7.62| nonzero,
  loss 4.566→0.0001, Δ within clamp); patch --dry-run applies vs .pre_compass.bak. GPU byte-identity
  deferred to Task 7. code-review APPROVE_WITH_NITS.)
- **Prereq tasks**: 5
- **Files touched**: same rootfs `diffusionv2_extend.py` (extend the Task-5 branch) + updated
  `.agent/scratch/compass_steering/compass_wire.diff`
- **Change shape**: implement COMPASS Phases 2-4 in the gated branch: partial-denoise to anchor
  t_a≈0.5; at t_a, `torch.enable_grad()` scope, take `atom_coords_denoised`
  (= EDM x̂0 from `preconditioned_network_forward`, already the Tweedie estimate), compute the
  selected battery loss L(x̂0, target), backprop to Δ_s/Δ_z, Adam (lr 0.015, 100 iters, grad-clip
  1.0, clamp [-0.5,0.5]); then discard anchor coords and run a fresh clean reverse diffusion on
  s+Δ_s, z+Δ_z (no_grad, existing unmodified sampler path — NOT the coordinate-GD path).
- **Verification**: on 1 compound (CPU-tiny or 1-GPU), flag ON with target=P1: the per-iteration
  loss trace is monotone-ish decreasing (prints first/last loss), Δ_s/Δ_z grads are nonzero, and
  the final `model_0.pdb` md5 differs from the Δ=0 (unsteered) output. Prints `COMPASS_LOOP OK`.
- **Estimated time**: 5 min
- **Rollback (if this task only)**: revert the diff to the Task-5 state.

## Task 7: Stage-0 SLURM smoke — 1 compound × 1 target (HARD SUCCESS GATE)

- **Status**: done (PASS — job 16867 COMPASS_SMOKE OK. MRT6160 × P1/9NFR through the gated rootfs
  Boltz-2. Evidence: Adam Tweedie opt loss 9.499947 → 0.004369 over 100 iters at anchor idx=25/50
  (t~0.50, sigma_hat=75.77) = Δ_single/Δ_pair demonstrably steer to the P1 9NFR objective; 97/97
  guide residues matched via runtime feats NW-alignment; steered md5 cdfc98… ≠ unsteered 538f2b…;
  clash unsteered=456/steered=517 within tolerance (both baselines dominated by <2.0Å peptide-bond
  C-N inter-residue pairs; true added near-contacts ~61). Files committed d658fc5c + qos/atom-index/
  inference-mode fixes: 16860 surfaced atom_to_token/ref_atom_name_chars one-hot (argmax fix,
  committed), 16863 surfaced Lightning inference-tensor-saved-for-backward (deep-clone denoiser
  inputs to normal, committed), 16864 surfaced diffusion_conditioning['to_keys'] functools.partial
  capturing a trunk inference-tensor indexing_matrix (partial-aware deep-clone, committed). kim
  --qos=normal (batch decommissioned). Driver .agent/scratch/compass_steering/compass_driver.py +
  run_compass_smoke.sh; smoke out /mnt/kfs2/.../compass_smoke_20260713/. Stage-A/B refinement note:
  use a bonded-exclusion element-aware clash metric, not the raw <2.0Å inter-residue count.)
- **Prereq tasks**: 2, 3, 4, 6
- **Files touched**: `.agent/scratch/compass_steering/run_compass_smoke.sh` (new SLURM launcher),
  `.agent/scratch/compass_steering/compass_driver.py` (new, drives one compound×target through the
  gated Boltz-2 branch)
- **Change shape**: kim-account SLURM smoke (un-containerized rootfs, free-GPU selector) running the
  COMPASS branch on ONE compound (e.g. MRT6160) × target P1 (9NFR). **APPROVAL GATE: SLURM/GPU —
  stop and get user go before delegating.** THIS TASK IS THE CONTRACT'S HARD DONE-WHEN.
- **Verification**: job COMPLETED; stdout shows the Adam loss trace decreasing, gradient-nonzero,
  output ensemble produced; a clash check on the steered output is comparable to an unsteered Boltz
  run (not elevated) and md5 ≠ unsteered. The differentiable battery (all 10 losses) each printed
  `OK` in Tasks 2-4. If clash elevated or gradient zero, Stage 0 FAILS → stop, diagnose.
- **Estimated time**: 5 min (submit + inspect; GPU wall-clock separate)
- **Rollback (if this task only)**: `scancel`; delete the kfs2 smoke output dir; the rootfs diff
  stays (reused by Stage A/B) or is reverted if abandoning.

## Task 8: Stage A — 9NFR calibration (reported, GPU)

- **Status**: done (job 16868, 5 seeds; stageA_results.csv written). VERDICT = NEGATIVE at default
  COMPASS strength. Adam P1 loss converges reliably 5/5 (~0.005) — the anchor-Δ optimization
  mechanism works — BUT the FINAL Phase-4 resample does NOT reach near-native: steered SH3c-RMSD-to-
  9NFR WORSE than unsteered in 5/5 seeds (unsteered mean 3.02 / best 2.706 Å = matches documented
  ~3Å Boltz-vs-crystal offset; steered mean 17.14 / best 5.474 Å; delta +14.1 Å) with VdW clash
  75-91→190-3859. Interpretation: Δ overfits the interface-only P1 loss and pushes the conditional
  embeddings off-manifold; the frozen denoiser then resamples a distorted, clashy structure — the
  COMPASS on-manifold premise (tuned on single-chain BioEmu with a global distance-matrix loss) does
  NOT hold on our hetero-ternary at clamp=0.5. This INVALIDATES the Task-9 premise (sweep battery at
  fixed strength → correlate reaching-efficiency with DC50): a battery at default strength would
  yield uniformly off-manifold structures. LOOP PAUSED at the Task-9 gate pending a user decision
  (strength/anchor sweep on P1 to find an on-manifold setting, OR loss redesign with a global
  structure-preservation term, OR accept the negative port result). Artifacts
  .agent/scratch/compass_steering/{stageA_measure.py, run_stageA_9nfr.sh, } + kfs2
  compass_stageA_20260713/stageA_results.csv.
- **Prereq tasks**: 7
- **Files touched**: `.agent/scratch/compass_steering/run_stageA_9nfr.sh` (new),
  `.agent/scratch/compass_steering/stageA_results.csv` (new output)
- **Change shape**: steer toward P1 (9NFR) across seeds; measure whether COMPASS reaches near-native
  SH3c-on-CRBN (Cα-RMSD/interface) clash-free, the COMPASS-+42.9%-class calibration on our one GT.
  **APPROVAL GATE: SLURM/GPU.**
- **Verification**: `stageA_results.csv` reports per-seed best interface-RMSD-to-9NFR + clash; a
  reached-vs-unsteered comparison printed with the reaching metric. Reported regardless of value.
- **Estimated time**: 5 min (submit + inspect; GPU wall-clock separate)
- **Rollback (if this task only)**: `scancel`; delete stageA outputs.

## Task 9: Stage B — target battery × compound sweep (reported, GPU)

- **Status**: superseded — NOT RUN. The Stage-A calibration + strength/anchor/preservation sweeps
  (Task 8 + inserted diagnostics) established that steering is off-manifold at every effective
  setting on the ONE GT target (P1/9NFR). Running the full GT-free battery at a setting that fails
  calibration would only mass-produce off-manifold structures (violates diagnose-before-scaling).
  Gate not passed → battery not justified.
- **Prereq tasks**: 8
- **Files touched**: `.agent/scratch/compass_steering/run_stageB_sweep.sh` (new),
  `.agent/scratch/compass_steering/stageB_results.csv` (new output)
- **Change shape**: sweep the battery (C1-4,P2-3,G1-2,M1) × {Stage-D 8 + MRT6160 + C147 + VAV1_474},
  recording per (target,compound): productive-reach, clash, and target-reaching efficiency (final
  loss / Adam-iters-to-threshold / HR-style). Control-subset-first (MRT6160/C147 + Stage-D) then
  prune to signal-bearing targets; `log` any pruning. **APPROVAL GATE: SLURM/GPU.**
- **Verification**: `stageB_results.csv` has rows for every submitted (target,compound); pruning
  decisions logged with counts; no silent truncation.
- **Estimated time**: 5 min (submit + monitor setup; GPU wall-clock separate)
- **Rollback (if this task only)**: `scancel` the array; partial outputs harmless (Task 10 consumes
  what completed).

## Task 10: Stage C — efficiency-vs-DC50 discriminator analysis (reported, zero-GPU)

- **Status**: superseded — NOT RUN. Prereq (Stage B battery) not run. The reaching-efficiency-vs-DC50
  analysis presupposes usable steering across the battery, which the calibration disproved. The
  analytic effort instead went into the calibration campaign (Stage A + 3 sweeps) + the independent
  crystal-free verification, which is the actual scientific payload.
- **Prereq tasks**: 9
- **Files touched**: `.agent/scratch/compass_steering/stageC_analysis.py` (new),
  `.agent/scratch/compass_steering/stageC_results.csv` (new output)
- **Change shape**: per-target Spearman(reaching-efficiency, logDC50) with bootstrap CI (compared to
  the vav1-ubq MD FES ρ=+0.714), active/inactive (MRT6160/C147) separation, seed convergence, and
  the VAV1_474 rescue check (did COMPASS place 474 into near-attack, which 40ns MD never did). All
  external validators held fixed across targets (reaching≠validation caveat).
- **Verification**: `python3 stageC_analysis.py` → per-target ρ+CI table + active/inactive + 474
  result; every number carries a CI or is labeled point-estimate; caveat printed.
- **Estimated time**: 5 min
- **Rollback (if this task only)**: delete stageC files.

## Task 11: Results doc + baton + close contract/plan (docs)

- **Status**: done (commit 1dfcb746; results_compass.md = full arc + NEGATIVE verdict + the
  BioEmu-ensemble-manifold vs Boltz-point-predictor mechanistic diagnosis + 3 future directions
  the user endorsed [coord-GD resample intervention / Boltz ensemble finetune / ternary ensemble
  emulator], each a new contract. Independent crystal-free verification scripts committed. Contract
  → done, plan → done. Baton edit on vav1-ubq [cross-slice; owner 286d3f28 stale 12d].)
- **Prereq tasks**: 10
- **Files touched**: `.agent/scratch/compass_steering/results_compass.md` (new),
  `.agent/status/vav1-ubq.md` (additive edit), the contract + plan files (status edits)
- **Change shape**: results doc (phase-house style): the BioEmu-base finding + Path-2 port, Stage-0
  gate outcome, per-target efficiency-vs-DC50 with the reaching≠validation caveat inline, 474
  rescue, next steps. Baton: additive top remaining_actions entry + dated paragraph (vav1-ubq
  style), last_updated today. Contract approved→done + Notes; plan in-progress→done, Task 11 done.
  (Note: this session owns aigen-fold-core; editing the vav1-ubq baton is cross-slice — coordinate
  / or hand the baton edit to the vav1-ubq owner if contested.)
- **Verification**: results doc present with Stage-0 verdict + efficiency table + caveat;
  `grep 'status: done'` matches contract + plan; vav1-ubq baton YAML re-parses, last_updated=today.
- **Estimated time**: 5 min
- **Rollback (if this task only)**: `git checkout` baton/contract/plan or hand-revert; delete
  results doc.
