---
status: done
slice: vav1-ubq
topic: compass-latent-steering
date: 2026-07-12
owner: claude
approved_by: sunghoon.kim (2026-07-12, "승인")
requested: 2026-07-12
cross_slice: [aigen-fold-core]
triggers_matched:
  - "engine change — additive COMPASS steering branch in the Boltz-2 diffusion sampler
    (diffusionv2_extend.py, rootfs copy); same engine class as the chiral-wire / CRLClosure hooks
    (aigen-fold-core-owned code — cross-slice coordination required)"
  - "SLURM/GPU submission — Boltz-2 generation sweep over a target battery x compound set (kim account)"
  - "4+ files — engine steering branch + differentiable target-loss library + smoke/driver +
    sweep launcher + eval + results doc"
  - "ranking-adjacent semantics — a candidate DC50 discriminator (target-reaching efficiency)
    is evaluated against logDC50 / active-inactive"
---

# vav1-ubq — COMPASS decoupled latent steering on Boltz-2: GT-free productive-geometry target battery + reaching-efficiency discriminator

## Purpose

Apply COMPASS-style **decoupled latent steering** (Changyu Lee, Sunghee Choi, Gyu Rie Lee;
GenBio 2026, submission 234) to our Boltz-2 engine: at an intermediate anchor diffusion timestep,
backprop a target-reaching loss ONLY to the conditional prior embeddings via Tweedie's expectation,
leaving reverse diffusion unmodified so geometry stays clash-free. Because VAV1 ternary has no
per-compound crystal ground truth, define a BATTERY of GT-free "what is productive" geometric
targets and steer toward each, then test whether **target-reaching efficiency ranks DC50 /
separates active from inactive** — a generation-side, per-compound-cheap analog of the vav1-ubq
WTMetaD FES-barrier discriminator (ρ=+0.714 p=0.047, n=8, currently 474-fragile + 40ns MD/compound).
Directly attacks the failure mode all our prior placement work hit: 3D-coordinate guidance and
static graft produce geometric violations / clashes ("productive≈0" in phase7 because touching
poses clash), which COMPASS's latent (not coordinate) steering is designed to avoid.

## Current State

- Method source: full PDF read 2026-07-12 (/home/ubuntu/234_COMPASS_Decoupled_Latent_S.pdf;
  code github.com/Chan-gyuLee/COMPASS). ★KEY FINDING: COMPASS's base model is **BioEmu v1.1**
  (GVP-Transformer, ESM E_s/E_p, VP-SDE, DPM-Solver) — NOT AF3/Boltz-2 (AF3 is only the contrast
  baseline). BioEmu is a SINGLE-CHAIN equilibrium ensemble emulator; the paper's benchmark
  explicitly excludes multi-chain interfaces / hetero-multimers (§5.1). So COMPASS as-published
  CANNOT produce our CRBN-VAV1-glue hetero-ternary near-attack arrangement. Its molecular-glue
  ternary results (MGBench 44) steer BioEmu by AF3-Apo then dock the ligand DOWNSTREAM via PLACER;
  on the KRAS TS-mimetic ternary (9bh*) COMPASS beat AF3 Holo (3.71 vs 4.66 Å), validating the
  method's direction for transition-state-like ternary receptors.
- Exact method (PDF §4, Alg.1, Table A1): anchor t=0.5 (partial denoise 1.0→0.5, DPM-Solver 25
  NFE; optimal steering t 0.55 apo / 0.60 holo, robust 0.35-0.70); Phase 3 optimizes additive
  offsets Δ_single(1D)/Δ_pair(2D) to the conditional embeddings via Adam (lr 0.015, 100 iters,
  grad-clip 1.0, clamp [-0.5,0.5]); loss = 1.0·Cα-dist-MSE + 2.0·virtual-Cβ-dist-MSE +
  1.0·backbone-orientation(trace R_pred·R_guide^T) + 1.0·L2(Δ); Tweedie x̂0=(1/α_t)(x_t+σ²_t·s_θ);
  Phase 4 fresh reverse diffusion (50 NFE) on updated embeddings + inference-dropout ensemble.
  Guidance = a 3D target structure → Cα/Cβ distance matrices + frames (protein-only; ligand
  features are future work). Memory: score-net backprop at the anchor is heavy for >1000 residues.
- **PATH DECISION (user, pending)**: Path 1 = run COMPASS code on BioEmu (faithful but single-chain,
  poor fit to our hetero-ternary). Path 2 = port the COMPASS *method* to our Boltz-2 engine (fits
  the hetero-ternary; Boltz-2's preconditioned_network_forward already yields the EDM x̂0 so the
  Tweedie step is direct, Δ_single/Δ_pair ↔ Boltz trunk s/z offsets, loss extended to our
  near-attack/cone geometry). Path 2 is a novel port (paper's +42.9% evidence does NOT transfer);
  recommended, with Path 1 kept only as a method-understanding/calibration reference. This
  contract's engine sections assume Path 2.
- Engine (verified this session): `boltz_native_20260621/rootfs/.../diffusionv2_extend.py`
  `_sample_with_interface_steering` reverse loop. `preconditioned_network_forward(atom_coords_noisy,
  t_hat, network_condition_kwargs)` returns `atom_coords_denoised` = the EDM-preconditioned denoiser
  output = Tweedie E[x0|xt] — available per step, currently under `with torch.no_grad()`. Existing
  steering pushes gradients onto COORDINATES (should_apply_gd branch) = the coordinate-guidance
  COMPASS replaces. Conditional prior embeddings = `network_condition_kwargs` (trunk s/z). Env-gated
  additive-hook precedent exists (BOLTZ_DUMP_LATENT / RETURN_LATENT_FEATS / chiral-wire diff);
  inference_mode scoping issue previously solved (fix 04abc6a).
- Target-loss source artifacts (all vav1-ubq/analysis, to be reimplemented as differentiable on
  x̂0): discriminator_config_20260629.json (near-attack, cone frame, SH3 lysines
  K788/K804/K810/K814/K815), CRLClosurePotential (9UUM cone/Kabsch), glue_competence.py (degron
  D797 carboxyl / S799 OG, SH3c-RMSD≤8Å), contact_recovery (RT-loop {R796,D797,S799}↔{W400,H357,N351}),
  phase7 hyper3 (3-body glue-bridging) + bridge_span_mean, zone_body_reach (full-VAV1 cone patch),
  9NFR experimental ternary (the one coordinate GT).
- Compound set available: Stage D 8 compounds (DC50 spread, MD FES ρ=+0.714 comparator),
  MRT6160 (active) / C147 (inactive) controls, VAV1_474 (Stage D fragile case, never entered
  near-attack in 40ns).

## Assumptions And Questions

- assumptions (REVISED after PDF): COMPASS's method — anchor-timestep Tweedie x̂0 → backprop to
  conditional embeddings → clean reverse diffusion — ports from BioEmu (VP-SDE/GVP) to Boltz-2
  (EDM/pairformer) because Boltz-2's preconditioned_network_forward already emits the EDM x̂0 and
  its trunk s/z are the conditional embeddings to offset. This is a PORT to a different base model,
  not a same-family transfer; the paper's quantitative gains are NOT assumed to carry over.
- resolved from PDF: anchor t=0.5, Adam lr 0.015 / 100 iters / clip 1.0 / clamp [-0.5,0.5],
  loss weights 1/2/1/1 (Cα/Cβ/ori/L2), inference-dropout ensemble. "Target-reaching efficiency" in
  the paper is operationalized as hit-rate (HR at Cα-RMSD thresholds) + Avg-Best-RMSD + ETH
  (effective time-to-hit); our discriminator will adapt these to a per-compound reaching cost.
- open questions: (a) Path 1 vs Path 2 (user decision); (b) COMPASS's guidance is a full 3D target
  structure (distance-matrix loss) whereas our GT-free targets (near-attack/cone) are geometric
  criteria — expressing them as partial distance-matrix/frame targets is a genuine loss extension
  beyond validated COMPASS (paper notes ligand/geometry-criterion objectives are future work).
- ★ central methodological caveat: COMPASS reaches ANY defined target by construction, so "reached
  the target" is NOT evidence the target is the right notion of productive. With no GT, target
  validity is adjudicated ONLY by external signal held fixed across all targets: (1) reaching-
  efficiency vs logDC50, (2) active/inactive separation, (3) physical validity (clash/geometry),
  (4) seed convergence. This is written into Done-When, not left implicit.

## Constraints

- allowed: additive COMPASS branch in the rootfs Boltz-2 sample copy ONLY (not the host WIP engine
  tree); new scripts + outputs under `analysis/crl_integrative/compass/` (or a vav1-ubq scratch
  dir); a differentiable target-loss library; SLURM via kim account (free-GPU selector).
- forbidden: editing host WIP engine files (diffusionv2_extend.py etc. carry aigen-fold-core's
  chiral-wire/CRLClosure uncommitted WIP — additive rootfs-copy diff only, coordinate with the
  aigen-fold-core owner before any host commit); re-freezing ternary_r*_maps.npz; any change to the
  shipped DC50 ranking model (data-limited, out of scope); wet-lab.
- external: **COMPASS PDF must be obtained + its method extracted BEFORE Stage 0** (user decision);
  SLURM GPU via kim, no hard GPU-hour cap; all GPU via SLURM.

## Non-Goals

- The aigen-fold-core DC50 ranking model — it is data-limited (learning-curve flat), frozen-feature,
  and steering is a generation technique that does not produce ranking features. Unchanged.
- RMSD-to-crystal validation beyond the single 9NFR calibration — there is no per-compound GT; the
  experiment is GT-free by construction.
- Shipping a model or a productive-geometry predictor; producing a wet-lab claim.
- Re-opening the τ-RAMD residence pilot or the static-graft screen (superseded approaches).

## Done When (staged: hook = hard gate; science = reported, not gated)

- **Precondition (gating)**: COMPASS PDF obtained; anchor timestep / Tweedie application /
  embedding-optimization / efficiency-metric extracted and recorded in the results doc. No Stage-0
  code until this lands.
- **Stage 0 — HARD SUCCESS GATE (zero/low-GPU smoke)**: COMPASS branch in the rootfs Boltz-2
  sampler — at the anchor timestep, enable-grad scope, differentiable Tweedie x̂0 from
  `preconditioned_network_forward`, backprop a target loss ONLY to the conditional prior embedding,
  optimize it, resume unmodified reverse diffusion. Verify on ONE compound×ONE target: gradient
  flows to the embedding (nonzero), output md5 moves vs unsteered, and geometry stays clash-free (no
  coordinate-GD path used). PLUS the differentiable target-loss battery (C1 near-attack dist, C2
  +Bürgi-Dunitz angle, C3 per-lysine, C4 cone-patch, P1 9NFR-RMSD, P2 degron-competence, P3
  contact-recovery, G1 3-body bridging, G2 bridge-span, M1 apo-broadening) — each verified
  differentiable + gradient-nonzero on one compound. **This is the contract's hard done-when.**
- **Stage A — reported (GPU)**: T1/P1 (9NFR) calibration — does COMPASS reach near-native
  SH3c-on-CRBN clash-free, in the COMPASS +42.9% class, on our one GT.
- **Stage B — reported (GPU)**: target battery × {Stage D 8 + MRT6160 + C147 + VAV1_474} sweep;
  record productive-reach, clash score, and target-reaching efficiency per (target, compound).
  Throttle: after a first pass, prune to targets whose efficiency shows any logDC50/active-inactive
  signal.
- **Stage C — reported (zero-GPU)**: per-target efficiency vs logDC50 correlation (compared to the
  MD FES ρ=+0.714), active/inactive separation, seed convergence, and the VAV1_474 rescue test.
  Reported regardless of direction, with the reaching≠validation caveat stated inline.
- results doc + baton update; contract → done.

## Resource budget

- Precondition: PDF retrieval, no compute.
- Stage 0: zero/low-GPU (1-compound smoke). Bulk of the risk is retired here CPU-side (loss
  differentiability, hook wiring).
- Stage A/B: GPU via kim, no hard cap, but battery(10) × compounds(11) × seeds is large — run the
  control+Stage-D subset first, prune, then widen. `log()` any pruning so coverage is honest.
- Stage C: zero-GPU.

## Risks

- COMPASS may not transfer AF3→Boltz-2 (different conditioning plumbing) — Stage 0 smoke catches
  this before any GPU sweep (diagnose-before-scale).
- Engine WIP entanglement — additive rootfs-copy diff only; no host engine commit without
  aigen-fold-core owner coordination.
- reaching≠validation (no-GT) — mitigated by fixing external validators (DC50 / active-inactive /
  clash / seed) across all targets; target validity remains inferential, stated as a limitation.
- Battery×compound×seed cost blow-up — mitigated by control-subset-first + prune-to-signal.

## Rollback

- revert strategy: delete the rootfs COMPASS branch (byte-faithful to stock when the flag is off,
  like the chiral-wire diff); delete the scratch analysis dir. No host WIP touched, no shipped
  artifact.
- containment: vav1-ubq Stage D MD result and the shipped v1.1 DC50 model are both untouched
  regardless of outcome.

## Progress Log

- 2026-07-12: scoped via /brainstorm after engine + target discussion. Success criterion = staged
  (Stage 0 hook working = hard gate; efficiency-vs-DC50 science reported not gated, per user).
  PDF-first: obtaining the COMPASS OpenReview PDF + extracting anchor/efficiency/hyperparameters is
  a gating precondition before Stage 0 (per user). GT-free target battery (C1-4, P1-3, G1-2, M1)
  with external-validator adjudication (reaching≠validation caveat). Cross-slice: engine hook is
  aigen-fold-core-owned code (rootfs-copy additive diff, coordinate before host commit). Awaiting
  approval; execution blocked on PDF retrieval.
- 2026-07-12: APPROVED by sunghoon.kim ("승인"). Next gate = obtain the COMPASS OpenReview PDF
  before /write-plan finalizes the Stage-0 engine-hook task (anchor/efficiency come from it). Two
  web searches did not surface the PDF (GenBio 2026 submission 234, likely OpenReview dynamic page);
  awaiting the link/PDF from the user.
- 2026-07-12: PDF obtained (/home/ubuntu/234_COMPASS_Decoupled_Latent_S.pdf) + read in full.
  Material finding: base model is BioEmu (single-chain), not AF3/Boltz-2 — see revised Current
  State. Exact method params extracted. New open decision: Path 1 (BioEmu code, poor hetero-ternary
  fit) vs Path 2 (port method to Boltz-2, recommended). Contract now assumes Path 2. Awaiting user
  confirmation of the path before /write-plan; if Path 2 confirmed, the spec is otherwise complete
  and planning can proceed.
- 2026-07-12: PATH 2 CONFIRMED by user ("진행") — port the COMPASS method to the Boltz-2 engine
  (Path 1/BioEmu kept only as a method-understanding reference). Spec complete; proceeding to
  /write-plan.
- 2026-07-12: STANDING GPU APPROVAL granted by user for this plan's SLURM submissions ("제출에
  확인 받지 말고 스트레이트로 진행해 내가 다 승인할게") — Tasks 5-verification/7/8/9 proceed
  without per-submission confirmation. Engine-hook (Task 5-6) = diff-writing + code-review zero-GPU;
  GPU verification folded into Task 7 Stage-0 smoke.

## Notes (closeout 2026-07-13)

DONE, verdict NEGATIVE. Full record: .agent/scratch/compass_steering/results_compass.md; plan
.agent/plans/vav1-ubq-compass-latent-steering-20260712.md (all tasks done/superseded).

The COMPASS anchor-Tweedie optimize-then-resample method was ported faithfully to Boltz-2 (additive,
env-gated `COMPASS_STEERING` branch in the rootfs diffusionv2_extend.py; host tree untouched; diff
in compass_wire.diff). The MECHANISM works: the Stage-0 smoke passed (job 16867; Adam P1 loss
9.50→0.0044, atom-index resolution 97/97 via runtime feats NW-alignment) after fixing 3 integration
bugs the smoke surfaced (one-hot atom_to_token/ref_atom_name_chars; Lightning inference-tensor
saved-for-backward; functools.partial `to_keys` capturing a trunk inference tensor).

But the ported method FAILS its purpose. On the only GT target (P1/9NFR), calibration (job 16868,
5 seeds) + strength sweep (16869, clamp×reg) + anchor sweep (16870) + loss redesign with a CRBN-fold
preservation term (16871, clamp×w_preserve) ALL negative. Effective steering (Adam loss→0) always
drives CRBN off-manifold (17-19Å internal distortion, crystal-independently verified) with clash
blow-up; the only on-manifold cell (anchor 0.85 / clamp 0.1) is a near-no-op (VAV1 moves 1.1Å, loss
stuck 7.5). Preservation up to w_preserve=200 fails to hold the fold (crbn_fit stays 13-22Å).
Interface-move and CRBN-distortion are inseparable in the embedding→structure map.

Root cause = base-model mismatch, not hyperparameters. COMPASS's base (BioEmu) is a single-chain
equilibrium ENSEMBLE emulator whose latent space is a trained manifold of valid conformations, so
embedding steering moves between valid states (on-manifold by construction). Boltz-2 is a single
STRUCTURE PREDICTOR whose latent encodes one answer with no "nearby-embedding = other valid
structure" pressure, so perturbing it leaves the valid-structure manifold and the frozen denoiser
resamples off-manifold. Supporting mismatches: COMPASS loss covers the whole single chain vs our
partial interface loss; VP-SDE t=0.5 (moderate noise) vs EDM t~0.5 (sigma_hat 82, near-pure noise);
pair-rep injection vs one-step-removed token_trans_bias; ensemble-distribution vs single-structure
eval.

SHIP: nothing changed in production (this was an exploratory method port; v1.1 DC50 ranker and the
vav1-ubq WTMetaD discriminator are untouched). The scientific payload is the mechanistic diagnosis.

FUTURE (user endorsed all three 2026-07-13; each = a NEW contract/brainstorm):
1. Intervene in the fresh resample itself (couple our productive-geometry loss battery with the
   engine's existing coord-GD steering) — coordinate-space intervention sidesteps the latent-manifold
   problem; lowest startup cost, reuses the loss battery as GD gradients.
2. Finetune Boltz to emit an ensemble/manifold (impose the manifold condition by training).
3. Extend an ensemble emulator (BioEmu-class) to hetero-ternary to restore COMPASS's precondition.

Reusable assets kept: the 10-target differentiable loss battery, the gated engine plumbing +
anchor-Tweedie loop (both env-overridable clamp/lr/iters/reg/anchor + CRBN-preservation), the
runtime feats→atom-index NW resolver, and the SH3c-RMSD-to-9NFR + VdW-clash measurement.
