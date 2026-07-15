---
status: done
slice: boltz-jump
topic: paper-repro-pilot
date: 2026-07-14
owner: claude
requested: 2026-07-14
approved_by: user (2026-07-14, "승인")
decisions:
  - "Implement Boltz-Jump as a generation/exploration accelerator (walk-jump sampling: Tweedie-formula score off Boltz-2's existing one-step denoiser + BAOAB Langevin integrator), not a potency/DC50 discriminator -- zero retraining, additive-only, no edits to existing src/boltz or boltz_extension files."
  - "Success criterion = reproduce the paper's own two qualitative demos on public PDBs (unguided Trp-cage 1L2Y folding trajectory; single-lambda guided Abl Kinase 6XR6->6XR7 transition), not a novel benchmark -- and go straight to a real SLURM GPU pilot under the kim account rather than a CPU-only proof of concept."
  - "Root-cause fix for Round 1's divergence (job 17175) was BAOAB integrator instability (delta=2.0/mass=1.0 too hot for gamma=0.1 to dissipate, confirmed by a CPU-only diagnostic), not a score/code bug -- retuned delta=0.05 with n_steps scaled 20x (Round 2, job 17211)."
  - "Round 2's remaining unguided-demo divergence (delayed onset, not caught by a 20-step CPU sweep) was fixed by retuning mass=16.0 (not force-clipping alone), validated first by a genuinely long 5000-step CPU sweep before spending more GPU, then confirmed on the full 16000-step real GPU run (Round 3, job 17267)."
  - "Closed the contract on the Round 3 verdict: guided/steering demo decisively passes (all 4 nonzero lambda converge RMSD-to-6XR7, SS intact, lam=0.0 control resolves the steering-vs-stabilization confound); unguided/free-folding demo stays a known limitation (stable, no longer diverges, but never folds) rather than a pursued follow-up, since it needs a different fix (sigma/noise-schedule) than what this contract's rounds actually solved and was always the lower-priority demo."
closed_by: >
  user (2026-07-15, "닫자"): closed on the Round 3 (job 17267) verdict --
  guided/steering demo (RMSD-to-6XR7 convergence across all 4 nonzero
  lambda, SS intact, lam=0.0 control cleanly resolves the steering-vs-
  stabilization confound) decisively reproduces paper Figure 4 and is the
  actual "생성/탐색 가속기" use case the user wants. Unguided/free-folding
  demo stays PARTIAL (stable, no longer diverges, but never folds --
  helix_frac=0.000 throughout) and is logged as a known limitation, not
  pursued further -- it would need a sigma/noise-schedule investigation,
  a different problem than the mass/clip instability this contract's
  three rounds actually fixed, and was always the lower-priority demo.
  See .agent/scratch/boltz_jump/results_pilot.md's "Round 3" section for
  the full Done-When verdict table.
amendment_5: >
  user (2026-07-15, "mass/kT 튜닝이나 명시적 클리핑까지 마저 진행"):
  reopened after Task 18's retest (job 17211) found delta=0.05 alone
  insufficient -- the zero-force core walk still diverges over a full
  16000-step run, delayed onset (~steps 2200-4000) not caught by the
  original 20-step CPU diagnostic. Authorized implementing per-step
  force-norm clipping (and/or mass retuning) and re-running. Given the
  just-learned lesson that short CPU sweeps don't predict full-length
  stability, this round adds a genuinely long (thousands-of-steps) CPU
  validation before the next real GPU spend, rather than repeating the
  same extrapolation mistake. Plan tasks 19-22 added.
amendment_4: >
  user (2026-07-15, "처방대로 재구현 및 실행"): reopened after Task 13's
  FAIL/PARTIAL verdict + a CPU-only diagnostic
  (diagnose_divergence.py) confirmed the root cause as BAOAB
  integrator instability (delta=2.0/mass=1.0 too hot for gamma=0.1 to
  dissipate), not a score/code bug. Authorized implementing the
  diagnosed fix (expose --mass/--kT, retune delta=0.05 with n_steps
  scaled 20x to preserve total simulated time, finer jump_every, add a
  lam=0 control) and re-running the real SLURM pilot. Plan tasks 15-18
  added; Done When criteria below apply to the retest, not just the
  original run.
amendment_3: >
  user (2026-07-14, "8장까지 쓸수 있는데 왜 1장만 써"): scope widened from
  "single GPU, single job, not a sweep" to a generous 8-GPU parallel sweep
  on the same node, per feedback_compute_scaling policy (verify cheap first
  -- done, extensively, CPU dry runs + unit tests + real-checkpoint smoke
  tests -- then scale generously once justified, don't stay GPU-thrifty).
  Guided demo: lam in {0.3, 1.0, 3.0, 10.0} in parallel (4 GPUs) -- tests
  the paper's central "single fixed lambda suffices" claim instead of
  accepting one untested guess. Unguided demo: 2 independent seeds in
  parallel (2 GPUs) -- folding reliability, not an n=1 anecdote. Comparison
  arm: its existing 4 seeds run in 2 parallel waves of 2 (remaining 2 GPUs)
  instead of sequential. One sbatch job, --gres=gpu:8, background processes
  each pinned to a distinct CUDA_VISIBLE_DEVICES index, `wait`ed before
  collection.
cross_slice:
  - "aigen-fold-core (heads-up only, no coordination required yet): WORKFLOW.md §1 routes src/boltz
    internals work to aigen-fold-core. This pilot is scoped additive-only (new files calling into
    AtomDiffusion.preconditioned_network_forward from outside; zero edits to existing
    src/boltz or boltz_extension files), so it does not cross into aigen-fold-core's owned files.
    A follow-up contract to integrate Boltz-Jump into production ensemble generation WILL need
    aigen-fold-core coordination — out of scope here."
triggers_matched:
  - "diffusion sampling / steering potential / score scaling 의미 변경 — new walk-jump sampling mode
    (Langevin walk at fixed sigma + Tweedie-formula score) and a new single-lambda steering force,
    built on top of Boltz-2's existing denoiser."
  - "SLURM workflow script 수정 또는 신규 제출 — new SLURM launcher, submitted under the kim account."
  - "해당 없음 / 새 도메인 — user explicitly chose a new dedicated slice (boltz-jump) over folding this
    into aigen-fold-core or vav1-ubq; confirmed via AskUserQuestion this session."
---

# boltz-jump-paper-repro-pilot

## Purpose

Stand up Boltz-Jump (walk-jump sampling on the existing Boltz-2 denoiser,
per the Boltz-Jump paper at /home/ubuntu/Boltz-Jump.pdf) as a
generation/exploration accelerator, scoped explicitly OUT of any
potency/DC50 discriminator role (that door was already closed by the
vav1-ubq coord-GD NULL result, 2026-07-14). First pilot reproduces the
paper's own two qualitative demos (unguided folding trajectory; single-λ
steered conformational transition) on the paper's own public PDB targets,
as a correctness check before any integration into production ensembles.

## Current State

- Boltz-2 lives as an editable local fork at `/home/ubuntu/AIGENFold/src/boltz`
  (env `aigenfold_api`), plus `boltz_extension` alongside it. A separate
  untouched reference clone sits at `/tmp/boltz_upstream/src/boltz`
  (env `tpd_boltz2`). A GPU-side staged copy exists at
  `/mnt/kfs2/data/users/ubuntu/boltz_native_20260621/rootfs/app/src/boltz`.
- `AtomDiffusion.preconditioned_network_forward(noised_atom_coords, sigma,
  network_condition_kwargs)` in `diffusionv2.py:274` is already a standalone
  callable: arbitrary `sigma` in, EDM-preconditioned clean-coordinate
  prediction out. This is exactly the one-step denoiser Boltz-Jump's
  Tweedie-formula score (`score = (denoiser(y) - y) / sigma**2`) needs — no
  refactor of the existing multi-step `sample()` loop required.
- `.agent/scratch/compass_steering/coordgd_potential.py` +
  `coordgd_wire.diff` already hook a gradient-descent steering force onto
  `atom_coords_denoised` inside `diffusionv2_extend.py`'s reverse loop
  (env-gated by `COORDGD_STEERING`, fixed-scale not annealed). Useful as a
  design reference for how to autograd a coordinate-space loss, but it is
  wired into the existing multi-step loop, not a Langevin walk at fixed
  sigma — the walk-jump loop itself does not exist anywhere in this repo.
- No prior mention of walk-jump / JAMUN / BAOAB / Boltz-Jump anywhere in
  `.agent/` — this is new ground.
- WORKFLOW.md §1 routes "src/boltz internals / steering internals" work to
  the **aigen-fold-core** slice. This contract deliberately avoids that
  routing conflict for the pilot by keeping the implementation additive-only
  (see Constraints) so it does not touch aigen-fold-core-owned files.
  Integrating Boltz-Jump into production ensembles later is a separate,
  follow-up contract that WILL need aigen-fold-core coordination.

## Assumptions And Questions

- assumptions: Boltz-2's Pairformer-derived sequence/pair conditioning
  (`network_condition_kwargs`) can be computed once and held fixed across
  the walk, exactly as the base `sample()` loop already does.
- assumptions: paper's hyperparameters (sigma=2.0Å, BAOAB timestep=2.0,
  friction=0.1) are a reasonable starting point for small single-chain
  targets (Trp-cage, Abl Kinase) since that is the same regime the paper
  itself validated on (ATLAS/mdCATH monomers 38-2128 residues); no claim
  these transfer to multi-chain ternary complexes.
- open questions: none blocking — user has confirmed scope (new dedicated
  slice, paper-repro success criterion, straight-to-SLURM-GPU-as-kim
  compute gating).
- tradeoffs: skipping a CPU/low-compute correctness smoke step (per the
  general diagnose-before-scaling preference) in favor of going straight to
  a real GPU pilot, per explicit user choice this round. Mitigated by
  keeping the pilot targets tiny public PDBs and the job a single one-off
  submission, not a sweep.

## Constraints

- allowed change scope: new files only, under a new `boltz-jump` slice
  location (new repo/dir + `.agent/status/boltz-jump.md` +
  `.agent/projects/boltz-jump-harness.md` as needed). The walk-jump sampler
  must be implemented by composing/subclassing against the existing
  `AtomDiffusion` (calling `preconditioned_network_forward` from outside),
  not by editing `diffusionv2.py`, `diffusionv2_extend.py`, or any other
  file under `/home/ubuntu/AIGENFold/src/boltz` or `boltz_extension` in
  place.
- forbidden change scope: no edits to existing aigen-fold-core-owned
  src/boltz or boltz_extension files; no change to the default sampling
  path used by aigen-fold-core/vav1-ubq production pipelines; no
  retraining/fine-tuning of any model weights.
- external constraints: SLURM submission must go under the `kim` account
  only (user's explicit choice this round), not `ubuntu`. Pilot targets are
  the paper's own public PDBs (1L2Y Trp-cage; 6XR6/6XR7 Abl Kinase) — no
  proprietary sequence/MSA data involved. **Superseded by amendment_3**:
  originally "single GPU, single job, not a sweep" — widened to a single
  `sbatch` job requesting the whole node (`--gres=gpu:8`), running a small
  parallel sweep (guided-mode lambda values, unguided-mode seeds, comparison
  arm's existing seeds) as background processes each pinned to its own GPU
  index, per feedback_compute_scaling policy once wiring was validated.

## Non-Goals

- NOT a DC50/potency discriminator — already ruled out by the vav1-ubq
  coord-GD NULL result; do not reopen that question with this method.
- NOT applied to VAV1/ternary-complex or any other production target in
  this pilot — public PDB targets only.
- NOT a full ATLAS/mdCATH quantitative ensemble-metric benchmark
  reproduction (Tables 1-3 of the paper) — that is a much larger,
  separately-scoped follow-up if ever needed.
- NOT integration into aigen-fold-core/vav1-ubq production ensemble
  generation — explicit follow-up contract, coordinated with aigen-fold-core
  per the WORKFLOW.md §1 routing table.

## Done When

- A new standalone walk-jump sampling module runs end-to-end as one SLURM
  GPU job submitted under the `kim` account, no manual intervention.
- Unguided demo: starting from an unfolded/extended Trp-cage (1L2Y) seed, the
  walk-jump trajectory reaches a folded, physically sane structure (helix
  forms, no chain breaks/clashes) with no steering potential — qualitatively
  reproducing paper Figure 2.
- Guided demo: starting from Abl Kinase inactive (6XR6), a single fixed λ
  steering force (no annealed schedule) measurably reduces RMSD toward the
  active state (6XR7) over the trajectory, with secondary structure staying
  intact throughout — qualitatively reproducing paper Figure 4.
- Wall-clock of the walk-jump pilot vs. the existing full-diffusion
  multi-seed pipeline on the same target is measured and reported (actual
  ratio on our hardware, not required to hit the paper's 5-10x).
- `git status`/diff on the fork shows zero changes to existing
  aigen-fold-core-owned files — only new files added.

## Implementation Steps

1. Register the new `boltz-jump` slice (`.agent/status/boltz-jump.md`,
   routing note) and set up its own working directory.
   verify: `./scripts/status.sh index` shows the new slice cleanly
2. Implement the walk-jump sampler (BAOAB integrator + Tweedie score via
   `preconditioned_network_forward`) as a new module, unit-checked against
   a tiny synthetic case first (e.g. confirm score sign/scale matches a
   finite-difference check).
   verify: standalone script runs on CPU/local without SLURM, produces a
   trajectory of the right shape
3. Add the single-λ steering force term (fresh implementation, referencing
   `coordgd_potential.py`'s autograd pattern but not reusing its wiring)
   for the guided-transition demo.
   verify: gradient direction sanity-checked on a toy target before the
   real pilot
4. Write the SLURM launcher (kim account, single GPU job) covering both
   demos (1L2Y unguided, 6XR6→6XR7 guided) plus the wall-clock comparison
   run.
   verify: `sbatch` dry-run / script review confirms account, resources,
   no destructive paths
5. Submit the pilot job, inspect outputs against Done-When criteria.
   verify: visual/RMSD check of both trajectories; wall-clock numbers
   recorded
6. Update `.agent/status/boltz-jump.md` with pilot results and next-step
   recommendation (integrate vs. iterate vs. stop).
   verify: status file has no placeholder fields

## Change Discipline

- simplest adequate approach: compose against existing
  `preconditioned_network_forward` rather than forking the sampling loop
  internals; reuse the paper's own published hyperparameters as the
  starting point rather than tuning blind.
- new abstractions introduced: one new `WalkJumpSampler` class (BAOAB
  integrator + Tweedie score) and one steering-force helper.
- unrelated code touched: none (additive-only per Constraints).
- pre-existing dead code noticed: none yet.
- request-to-diff trace: user asked to scope Boltz-Jump as a
  generation/exploration accelerator only; this contract's Done-When is
  exactly the paper's own two qualitative demos, nothing broader.

## Verification

- `./scripts/verify.sh`
- task-specific command: pilot SLURM job log + output trajectory files for
  both demos, plus the wall-clock comparison numbers
- manual check: visual inspection of folded/steered trajectory frames
  (paper-style snapshot grid) for physical plausibility

## Risks

- regression risk: none expected — additive-only, no shared files touched.
- integration risk: paper hyperparameters (sigma/timestep/friction) may not
  transfer cleanly even to these small single-chain public targets; may
  need retuning during the pilot itself.
- hidden dependency risk: if `preconditioned_network_forward` has hidden
  coupling to loop-local state in `sample()` (e.g. running buffers, RNG
  state) that isn't obvious from a standalone call, the "no refactor
  needed" assumption in Current State could be wrong — first implementation
  step should confirm this before building the full BAOAB loop on top.

## Rollback

- revert strategy: delete the new `boltz-jump` slice directory / `git rm`
  the new files — zero impact on any other slice since nothing shared is
  edited in place.
- containment strategy: single one-off SLURM job, no `/mnt/data` production
  writes, no persistent state changes outside the new slice's own output
  directory.

## Progress Log

- 2026-07-14 14:30: contract drafted after paper read + codebase
  compatibility check (Boltz-2 fork location, `preconditioned_network_forward`
  standalone-callable confirmation, coord-GD hook precedent). Scope
  confirmed with user: new dedicated slice, paper-repro success criterion,
  straight-to-SLURM-GPU pilot submitted as `kim`.
- 2026-07-15: CLOSED. All 16 plan tasks executed
  (.agent/plans/boltz-jump-paper-repro-pilot-20260714.md). Real 8-GPU SLURM
  run (job 17175, after job 17152's device-mismatch bug was found and
  fixed) executed cleanly: zero interference with aigen-fold-core-owned
  files, wall-clock speedup real and paper-consistent (~9.4x
  per-equivalent-frame-count). Both qualitative reproduction demos (Done-When
  criteria 1-2) FAILED/PARTIAL at the paper's own unretuned hyperparameters
  (sigma=2.0, delta=2.0, gamma=0.1): unguided Trp-cage folding diverges to
  physically broken structures in both tested seeds; guided Abl-kinase
  steering stays numerically sane at only 1 of 4 tested lambda values.
  Control run (existing full-diffusion pipeline, same target) succeeds
  reliably, isolating the divergence to the walk-jump sampler's own BAOAB
  dynamics, not the environment/model. Diagnostic lead for any restart:
  `WalkJumpSampler`/`BAOABIntegrator` hardcode `mass=1.0`/`kT=1.0` with no
  CLI override, a plausible dimensional mismatch against the Tweedie
  score's real-Angstrom-scale magnitude. Full analysis:
  .agent/scratch/boltz_jump/results_pilot.md. Verdict: engineering
  succeeded (reusable harness for future walk-jump work), science did not
  (negative result at these hyperparameters) — a valid, informative pilot
  outcome, not a wasted one.
- 2026-07-15 (amendment_4 RE-CLOSED): CPU-only diagnostic
  (diagnose_divergence.py) confirmed the divergence was BAOAB
  integrator instability (delta=2.0/mass=1.0 too hot for gamma=0.1 to
  dissipate), not a score/code bug — the real Tweedie score was
  cross-checked correct and modest in magnitude. User authorized
  implementing the fix and re-running (job 17211, delta=0.05,
  n_steps=16000, finer jump_every, new lam=0.0 control). Result:
  partial improvement, not a clean fix. Guided demo's catastrophic
  per-lambda blow-up resolved (4/5 lambda now sane vs 1/4 before) with
  a genuine gradual RMSD-to-6XR7 descent now directly observable. But
  the zero-force core walk is still not stable over a full 16000-step
  run — both unguided seeds and the new lam=0.0 control diverge to
  similar eventual severity, just with a delayed onset. The lam=0.0
  control rules out "convergence = denoiser bias" (real news for the
  steering claim) but surfaces a new confound: the steering force may
  be acting as a de facto stabilizer on this target, not purely a
  directional pull, so steering-vs-stabilization can't be cleanly
  separated yet. Revised verdict: engineering meaningfully improved;
  science moved from unsupported to partially-supported-but-newly-
  confounded, still not a clean reproduction of either paper figure.
  Full analysis: results_pilot.md's "Retest (job 17211)" section.
  Recommended next step (unchanged in spirit): mass/kT retuning and/or
  explicit per-step clipping, verified on a full-length run before any
  further GPU spend, before considering aigen-fold-core integration.
