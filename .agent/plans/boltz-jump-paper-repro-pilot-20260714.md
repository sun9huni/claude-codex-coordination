---
contract: .agent/contracts/boltz-jump-paper-repro-pilot-20260714.md
slice: boltz-jump
status: done
total_tasks: 24
estimated_total_min: 170
---

# Plan: boltz-jump-paper-repro-pilot

All new code lives under `.agent/scratch/boltz_jump/` (matches the existing
`compass_steering`-style scratch convention). Zero edits to
`/home/ubuntu/AIGENFold/src/boltz` or `boltz_extension` anywhere in this plan.

**Amendment (2026-07-14, mid-execution)**: original Task 10 ("write the
pilot driver script") turned out to need real Boltz-2 internals engineering
(no ready PDB-to-internal-atom-coords utility exists) rather than a
5-minute wiring job, discovered via a read-only investigation agent after
Tasks 1-9 landed. Split into Task 10a (structure-loading utility, shared by
both demos) and Task 10b (the actual driver), confirmed with the user along
with the choice to seed the unguided demo from a genuinely extended
("all-trans") Trp-cage chain rather than pure Gaussian noise, for closer
fidelity to the paper's Figure 2. Task 11's prereq updated from `10` to
`10b`; `total_tasks`/`estimated_total_min` bumped accordingly.

**Amendment 2 (2026-07-14, mid-execution)**: separately, a GPU-approval
incident occurred during Task 10b's first attempt (a delegated subagent was
given ambiguous "CPU or available GPU" latitude for a smoke check — caught
by the user before any unauthorized GPU use happened, but the process gap
is real). Hardened in `AGENTS.md` §Approval Gates, `WORKFLOW.md` §3, and
memory `feedback_slurm_usage.md`; Task 10b was redispatched with GPU
explicitly forbidden and completed CPU-only. Task 11's own investigation
then found this GPU-safety fix (`CUDA_VISIBLE_DEVICES=""` unconditional)
was overly broad — it also blocks the real, approved Task 12 GPU run from
ever using a GPU, breaking the contract's same-hardware wall-clock
comparison. Added Task 10c to add an explicit `--device {cpu,cuda}` flag
(default `cpu`, opt-in only) plus a `--work-root` flag (Task 11's second
finding: hardcoded `/home/ubuntu` cache path risky on compute nodes),
confirmed with the user before adding GPU capability back in any form.
Task 11's prereq updated to include `10c`. `total_tasks`/
`estimated_total_min` bumped accordingly.

**Amendment 4 (2026-07-15, stabilization follow-up)**: Task 13's analysis
found both demos FAIL/PARTIAL — divergence to physically impossible
coordinates. A CPU-only diagnostic (`.agent/scratch/boltz_jump/
diagnose_divergence.py`, see `results_pilot.md`'s addendum) confirmed the
root cause: `delta=2.0`/`mass=1.0` makes each BAOAB half-kick add ~1-2
velocity units/atom, faster than `gamma=0.1` friction can dissipate — a
genuine integrator-stability issue, NOT a score/code bug (the real
Tweedie score was cross-checked correct and modest in magnitude). User
confirmed: implement the diagnosed fix and re-run. Added Tasks 15-18:
expose `--mass`/`--kT` on `run_pilot.py`, retune the SLURM launcher
(`delta=0.05`, `n_steps` scaled 20x to `16000` to preserve total
simulated time per the timestep-refinement argument, finer `jump_every`
so dynamics are actually observable per Task 13's own complaint, add the
`lam=0` control Task 13 flagged as missing, drop the already-successful
comparison-arm rerun), submit, and re-analyze. `total_tasks`/
`estimated_total_min` bumped accordingly; plan `status` reopened to
`in-progress`.

**Amendment 5 (2026-07-15, second stabilization round)**: Task 18's retest
(job 17211) found `delta=0.05` alone insufficient — the zero-force core
walk (both unguided seeds, and the new `lam=0.0` control on the 287-residue
target) still diverges over a full 16000-step run, just with delayed
onset (steps ~2200-4000, i.e. frames 11-20 of 80), not caught by the
diagnostic's original 20-step CPU sweep. User confirmed: proceed with
mass/kT tuning and/or explicit force clipping. Given the just-learned
lesson that short CPU sweeps don't predict full-length stability, this
round adds a genuinely longer CPU validation step (thousands of steps, not
20) BEFORE the next real GPU spend, rather than repeating the same
extrapolation mistake. Added Tasks 19-22: implement per-step force-norm
clipping in `WalkJumpSampler` (a `--clip-force` flag, bounding the
combined score+steering force's per-atom vector norm before each BAOAB
kick — directly targets the failure mechanism, teleportation-scale
per-step force, regardless of root cause), a long (thousands-of-steps)
CPU-only validation sweep comparing candidate configs (clip alone, clip +
higher mass) on the specific failing case, retune the SLURM launcher with
whichever config the long CPU validation actually supports, submit, and
re-analyze. `total_tasks`/`estimated_total_min` bumped accordingly.

## Task 1: Register the boltz-jump slice baton

- **Status**: done
- **Prereq tasks**: none
- **Files touched**: `.agent/status/boltz-jump.md` (created by script)
- **Change shape**: run the slice registration/handoff script to create the
  baton with frontmatter (owner, heartbeat, state: active,
  contract_pointers pointing at this contract), then hand-edit the body to a
  one-line current-state description ("pilot not yet started") and
  `remaining_actions: [AGENT: implement WalkJumpSampler core]`.
- **Verification**: `./scripts/handoff.sh claude boltz-jump && ./scripts/status.sh index` →
  new `boltz-jump` row appears in the regenerated `CURRENT.md` index
- **Estimated time**: 3 min
- **Rollback (if this task only)**: `./scripts/handoff.sh --release boltz-jump`
  then remove the file if truly unwanted

## Task 2: Confirm environment + fetch pilot reference structures

- **Status**: done
- **Prereq tasks**: none
- **Files touched**: `.agent/scratch/boltz_jump/refs/1L2Y.pdb`,
  `.agent/scratch/boltz_jump/refs/6XR6.pdb`,
  `.agent/scratch/boltz_jump/refs/6XR7.pdb`,
  `.agent/scratch/boltz_jump/env_check.txt`
- **Change shape**: activate `aigenfold_api`, confirm
  `from boltz.model.modules.diffusionv2 import AtomDiffusion` imports cleanly
  and `preconditioned_network_forward` is present on the class; download/copy
  the three reference PDBs (public RCSB entries) into `refs/`.
- **Verification**: `python -c "from boltz.model.modules.diffusionv2 import AtomDiffusion; print(hasattr(AtomDiffusion, 'preconditioned_network_forward'))"` → prints `True`;
  `ls .agent/scratch/boltz_jump/refs/*.pdb` → 3 files present
- **Estimated time**: 4 min
- **Rollback (if this task only)**: `rm -rf .agent/scratch/boltz_jump/refs`

## Task 3: Implement the Tweedie-score function

- **Status**: done
- **Prereq tasks**: 2
- **Files touched**: `.agent/scratch/boltz_jump/score_fn.py`
- **Change shape**: one pure function
  `tweedie_score(model, noised_coords, sigma, condition_kwargs) -> score`
  that calls `model.preconditioned_network_forward(noised_coords, sigma,
  condition_kwargs)` and returns `(denoised - noised_coords) / sigma**2`. No
  class, no loop — a single composable function per Constraints
  (composition, not editing `diffusionv2.py`).
- **Verification**: `python -c "import ast; ast.parse(open('.agent/scratch/boltz_jump/score_fn.py').read())"` →
  no syntax error; function signature matches spec (checked by a quick
  `inspect.signature` call in the same command)
- **Estimated time**: 4 min
- **Rollback (if this task only)**: `rm .agent/scratch/boltz_jump/score_fn.py`

## Task 4: Finite-difference sanity check for the score function

- **Status**: done
- **Prereq tasks**: 3
- **Files touched**: `.agent/scratch/boltz_jump/test_score_fn.py`
- **Change shape**: a standalone script that runs `tweedie_score` on a tiny
  synthetic noised-coordinate tensor (a handful of atoms) at a fixed sigma,
  and cross-checks the sign/rough magnitude against a numerical estimate of
  `∇_y log p_Y(y)` via a small finite-difference perturbation of the denoiser
  output. Not a rigorous gradient-check (the denoiser isn't a closed-form
  density) — this only confirms the score points back toward the denoised
  structure and scales as `1/sigma**2`, catching sign/scale bugs before the
  real pilot.
- **Verification**: `python .agent/scratch/boltz_jump/test_score_fn.py` → prints
  `PASS: score direction matches denoiser pull, scale ~ 1/sigma**2`
- **Estimated time**: 5 min
- **Rollback (if this task only)**: `rm .agent/scratch/boltz_jump/test_score_fn.py`

## Task 5: Implement the BAOAB Langevin integrator (model-free)

- **Status**: done
- **Prereq tasks**: none
- **Files touched**: `.agent/scratch/boltz_jump/baoab.py`
- **Change shape**: a standalone `BAOABIntegrator` class implementing the
  standard B-A-O-A-B splitting (Leimkuhler & Matthews 2013) taking a
  `score_fn(y) -> force`-shaped callback, timestep `delta`, friction `gamma`,
  mass `M`. No dependency on Boltz-2 at all — pure numerical method, so it
  can be tested against a toy harmonic-oscillator score independent of the
  model.
- **Verification**: none yet (covered by Task 6's unit test) — this task is
  the implementation only
- **Estimated time**: 5 min
- **Rollback (if this task only)**: `rm .agent/scratch/boltz_jump/baoab.py`

## Task 6: Unit-test the BAOAB integrator against a harmonic oscillator

- **Status**: done
- **Prereq tasks**: 5
- **Files touched**: `.agent/scratch/boltz_jump/test_baoab.py`
- **Change shape**: run `BAOABIntegrator` on a toy 1D harmonic score
  (`score(y) = -k*y`) for many steps and check the resulting sample variance
  converges to the analytic equilibrium value (`~ kT/k` at the configured
  friction/mass/temperature), within a stated tolerance.
- **Verification**: `python .agent/scratch/boltz_jump/test_baoab.py` → prints
  `PASS: equilibrium variance within tolerance`
- **Estimated time**: 5 min
- **Rollback (if this task only)**: `rm .agent/scratch/boltz_jump/test_baoab.py`

## Task 7: Implement WalkJumpSampler combining Task 3 + Task 5

- **Status**: done
- **Prereq tasks**: 4, 6
- **Files touched**: `.agent/scratch/boltz_jump/walk_jump_sampler.py`
- **Change shape**: `WalkJumpSampler` class: takes a loaded Boltz-2 model +
  fixed `sigma`, wraps `tweedie_score` as the BAOAB force callback, runs N
  walk steps, and at each step (or every k-th step) calls
  `preconditioned_network_forward` again to record the "jump" (denoised
  coordinate) into a trajectory list. Constructor accepts an optional
  `steering_force_fn(denoised_coords) -> force` hook (wired in Task 8) added
  to the score before the BAOAB step.
- **Verification**: `python -c "from boltz_jump.walk_jump_sampler import WalkJumpSampler; import inspect; print(inspect.signature(WalkJumpSampler.__init__))"`
  (run with `.agent/scratch/boltz_jump` on `PYTHONPATH`) → signature includes
  `model, sigma, delta, gamma, steering_force_fn=None`
- **Estimated time**: 5 min
- **Rollback (if this task only)**: `rm .agent/scratch/boltz_jump/walk_jump_sampler.py`

## Task 8: Implement the single-λ steering-force helper

- **Status**: done
- **Prereq tasks**: none
- **Files touched**: `.agent/scratch/boltz_jump/steering_force.py`
- **Change shape**: `make_target_state_force(target_coords, lam) ->
  steering_force_fn` — builds a force from
  `-lam * grad_coords(per_atom_deviation_loss(coords, target_coords,
  threshold=1.0))`, using `coords.detach().clone().requires_grad_(True)` +
  autograd, following the same pattern as
  `.agent/scratch/compass_steering/coordgd_potential.py`'s
  `compute_gradient` (referenced, not imported — this is a fresh standalone
  implementation per Constraints). Single fixed `lam` for the whole
  trajectory, no schedule.
- **Verification**: `python -c "from boltz_jump.steering_force import make_target_state_force; import torch; f = make_target_state_force(torch.zeros(5,3), 1.0); print(f(torch.ones(5,3)).shape)"` →
  prints `torch.Size([5, 3])`
- **Estimated time**: 5 min
- **Rollback (if this task only)**: `rm .agent/scratch/boltz_jump/steering_force.py`

## Task 9: Build Boltz-2 input configs for the three pilot targets

- **Status**: done
- **Prereq tasks**: 2
- **Files touched**: `.agent/scratch/boltz_jump/inputs/trpcage_1l2y.yaml`,
  `.agent/scratch/boltz_jump/inputs/ablkinase_6xr6.yaml`
- **Change shape**: read-only reuse of aigen-fold-core's existing single-target
  Boltz-2 YAML input convention (no edits to aigen-fold-core files — just
  read one example for the format) to build two new input configs: Trp-cage
  sequence (1L2Y) and Abl Kinase inactive sequence (6XR6). No MSA precompute
  needed beyond whatever the existing pipeline already does for single
  chains.
- **Verification**: `python -c "import yaml; yaml.safe_load(open('.agent/scratch/boltz_jump/inputs/trpcage_1l2y.yaml'))"` →
  no parse error, for both files
- **Estimated time**: 5 min
- **Rollback (if this task only)**: `rm -rf .agent/scratch/boltz_jump/inputs`

## Task 10a: Structure-loading utility (PDB -> Boltz-2 internal atom coords)

- **Status**: done
- **Prereq tasks**: 2, 9
- **Files touched**: `.agent/scratch/boltz_jump/structure_load.py`
- **Change shape**: amended per mid-execution investigation (see Progress Log)
  — this task did not exist in the original plan; Task 10 ("write the pilot
  driver script") was split in two because it turned out to need real
  engineering, not a 5-minute wiring job. This task builds the shared hard
  piece both demos need: a function
  `load_coords_for_yaml_input(yaml_path, pdb_path) -> (feats, override_coords, atom_pad_mask)`
  that (a) runs the existing Boltz-2 featurization for the given YAML up to
  `feats` (reusing `Boltz2InferenceDataModule`/featurizer code, read-only), and
  (b) converts the given real PDB's ATOM coordinates into Boltz-2's internal
  atom-coordinate tensor convention by adapting the atom-name-matching loop
  used by `process_atom_features`'s `override_coords` path
  (`AIGENFold/src/boltz/data/feature/featurizerv2.py`, read-only reference,
  no edits to that file) — matching by (chain, residue number, atom name)
  against `feats`'s token/atom ordering. Also builds a genuinely extended
  ("all-trans", idealized phi=psi=180 backbone) Trp-cage seed structure
  as a PDB (via straightforward ideal bond-length/bond-angle placement, e.g.
  with Biopython or a small hand-rolled geometry routine — no need for a
  real folding/embedding tool), so `load_coords_for_yaml_input` can be
  exercised on it the same way as a real crystal PDB (6XR6/6XR7).
- **Verification**: a standalone check script run inline (not a separate
  file) that calls `load_coords_for_yaml_input` for (a) the generated
  extended Trp-cage PDB against `inputs/trpcage_1l2y.yaml`, and (b) the real
  `refs/6XR6.pdb` against `inputs/ablkinase_6xr6.yaml`, asserting the
  returned coordinate tensor shape matches `feats["atom_pad_mask"].shape + (3,)`
  and that no atom-name-matching silently dropped more than a small
  tolerance fraction of atoms (report the actual match rate either way).
- **Estimated time**: 15 min (real engineering, not a wiring task)
- **Rollback (if this task only)**: `rm .agent/scratch/boltz_jump/structure_load.py`

## Task 10b: Write the pilot driver script (both demos)

- **Status**: done
- **Prereq tasks**: 7, 8, 9, 10a
- **Files touched**: `.agent/scratch/boltz_jump/run_pilot.py`
- **Change shape**: CLI script `run_pilot.py --mode {unguided,guided}
  --config <yaml> [--target-pdb <pdb> --lam <float>]`. Reuses
  `boltz.main.predict_core`'s model-loading path up to (but not including)
  the `structure_module.sample(...)` call — the pragmatic interception point
  found during investigation is monkeypatching
  `model_module.structure_module.sample` with a function that builds a
  `WalkJumpSampler` from the same `s_trunk`/`s_inputs`/`feats`/
  `diffusion_conditioning`/`atom_mask`/`multiplicity` kwargs the real
  `AtomDiffusion.sample` would have received, seeds `y0` via Task 10a's
  `load_coords_for_yaml_input` (extended-chain PDB for `--mode unguided`,
  real 6XR6 crystal coords for `--mode guided`'s starting seed, 6XR7 crystal
  coords as the `--target-pdb` for `make_target_state_force` in guided mode
  only), runs the walk, and dumps trajectory frames back to PDB by reusing
  the `BoltzWriter`/`to_pdb` pattern (`data/write/writer.py`,
  `data/write/pdb.py`, read-only reference) plus a `manifest.json` (frame
  count, sigma/delta/gamma used, wall-clock seconds).
- **Verification**: `python .agent/scratch/boltz_jump/run_pilot.py --help` →
  prints usage with both modes listed, no import errors
- **Estimated time**: 15 min (real engineering, not a wiring task)
- **Rollback (if this task only)**: `rm .agent/scratch/boltz_jump/run_pilot.py`

## Task 10c: Fix run_pilot.py device/work-root flags (found by Task 11)

- **Status**: done
- **Prereq tasks**: 10b
- **Files touched**: `.agent/scratch/boltz_jump/run_pilot.py`,
  `.agent/scratch/boltz_jump/submit_pilot.sh` (uncommitted at this point,
  authored by Task 11 — safe to amend directly rather than a separate commit)
- **Change shape**: amended per Task 11's own investigation, which surfaced
  two correctness gaps neither fixable within Task 11's own scope (it only
  touches `submit_pilot.sh`): (A) `run_pilot.py` forces
  `CUDA_VISIBLE_DEVICES=""` unconditionally, so even inside an approved GPU
  SLURM allocation the two real demos would still run on CPU, making the
  contract's own same-hardware wall-clock comparison invalid; (B)
  `structure_load.DEFAULT_WORK_ROOT` is a hardcoded `/home/ubuntu/...` path
  not exposed via CLI, risky on compute nodes that may not mount `/home`.
  Fix: add `--device {cpu,cuda}` to `run_pilot.py` (default `cpu`, preserving
  current safe behavior — only set `CUDA_VISIBLE_DEVICES`/`map_location`
  conditionally on an explicit `--device cuda`, confirmed with the user
  before making this change), and add `--work-root <dir>` threaded through to
  `load_coords_for_yaml_input(..., work_dir=...)`. Then update the
  already-authored (uncommitted) `submit_pilot.sh` to pass `--device cuda`
  for sub-jobs (1)/(2) and `--work-root` pointing at the staged kfs2
  directory.
- **Verification**: `python .agent/scratch/boltz_jump/run_pilot.py --help` →
  shows `--device` (default `cpu`) and `--work-root`; `bash -n
  .agent/scratch/boltz_jump/submit_pilot.sh` still passes. This task itself
  must NOT exercise `--device cuda` (no GPU touch) — verify only via
  `--help` and read-through, per the same GPU approval-gate constraint as
  every other task in this plan.
- **Estimated time**: 12 min
- **Rollback (if this task only)**: `git checkout -- run_pilot.py`
  (post-commit) or `rm` the flags manually; `submit_pilot.sh` isn't committed
  yet at this point so just re-edit it.

## Task 11: Write the SLURM launcher (kim account)

- **Status**: done (revised under contract amendment_3)
- **Prereq tasks**: 10b, 10c
- **Files touched**: `.agent/scratch/boltz_jump/submit_pilot.sh`
- **Change shape**: originally a single-GPU, 3-sequential-run script; revised
  per amendment_3 (user: "8장까지 쓸수 있는데 왜 1장만 써") into a whole-node
  `--gres=gpu:8` sweep: (1) guided-mode lambda sweep {0.3,1.0,3.0,10.0} on
  GPUs 0-3, (2) unguided-mode seed sweep {42,43} on GPUs 4-5, (3) the
  existing comparison-arm 4-seed sweep on GPUs 6-7 as 2 parallel waves.
  Each guided/unguided process gets its own `--work-root` (correctness
  requirement, not just a compute-mount fix — `process_inputs()` has no
  locking). Resource sizing re-derived from real `sinfo`/`scontrol` data.
- **Verification**: `bash -n .agent/scratch/boltz_jump/submit_pilot.sh` →
  no syntax error; manual review confirms `sudo -u kim sbatch --qos=normal`
  convention, no `ubuntu` account references, no destructive paths
- **Estimated time**: 4 min (original) + 15 min (amendment_3 revision)
- **Rollback (if this task only)**: `rm .agent/scratch/boltz_jump/submit_pilot.sh`

## Task 12: Submit the pilot job and monitor to completion

- **Status**: done
- **Prereq tasks**: 11
- **Files touched**: none (SLURM submission + log output under
  `.agent/scratch/boltz_jump/logs/`)
- **Change shape**: submit via the `gpu-dashboard-submit` skill or direct
  `sbatch` under `kim` per the contract's approval gate, then monitor the
  job foreground until all three runs (unguided, guided, comparison)
  complete or fail.
- **Verification**: `sacct -j <jobid> --format=JobID,State,ExitCode` → all
  steps show `COMPLETED`
- **Estimated time**: monitoring wall-clock, not counted in the 2-5 min
  active-work estimate (background wait)
- **Rollback (if this task only)**: `scancel <jobid>` if it needs to be
  stopped; no persistent state changes to undo otherwise

## Task 13: Analyze pilot outputs against Done-When criteria

- **Status**: done
- **Prereq tasks**: 12
- **Files touched**: `.agent/scratch/boltz_jump/results_pilot.md`
- **Change shape**: check the unguided trajectory's final frame for a
  folded, clash-free Trp-cage structure; check the guided trajectory's RMSD
  to 6XR7 decreases monotonically-ish over the run while secondary structure
  stays intact; pull the wall-clock numbers from `manifest.json` /
  `sacct` and compute the observed speedup ratio; write it all up.
- **Verification**: `test -f .agent/scratch/boltz_jump/results_pilot.md &&
  grep -q "speedup" .agent/scratch/boltz_jump/results_pilot.md` → passes
- **Estimated time**: 8 min
- **Rollback (if this task only)**: `rm .agent/scratch/boltz_jump/results_pilot.md`

## Task 14: Update the boltz-jump status baton with results

- **Status**: done
- **Prereq tasks**: 13
- **Files touched**: `.agent/status/boltz-jump.md`
- **Change shape**: replace the placeholder body from Task 1 with the pilot
  verdict (pass/fail against Done-When, observed speedup, whether to pursue
  integration into aigen-fold-core next), update `remaining_actions`
  accordingly, run the handoff script to bump frontmatter.
- **Verification**: `./scripts/handoff.sh claude boltz-jump && ./scripts/status.sh index` →
  index shows updated `last_updated`/summary line with no `<placeholder>`
  tokens
- **Estimated time**: 5 min
- **Rollback (if this task only)**: revert the file via git if it was
  already tracked, or hand-edit back

## Task 15: Expose --mass/--kT on run_pilot.py

- **Status**: done
- **Prereq tasks**: none (run_pilot.py already exists and is committed)
- **Files touched**: `.agent/scratch/boltz_jump/run_pilot.py`
- **Change shape**: add `--mass` (default 1.0) and `--kT` (default 1.0) CLI
  args, threaded into `WalkJumpSampler(..., mass=args.mass, kT=args.kT)` —
  currently hardcoded to the class defaults with no override, per the
  diagnostic's finding. Same pattern as Task 10c's `--device`/`--work-root`
  additions: purely additive, defaults preserve current behavior exactly.
- **Verification**: `python run_pilot.py --help` shows both new flags with
  default 1.0; a `--device cpu` (default) dry run with no `--mass`/`--kT`
  passed behaves identically to before (no behavior change when omitted).
- **Estimated time**: 8 min
- **Rollback (if this task only)**: `git checkout -- run_pilot.py` (if
  already committed) or manually remove the two flags

## Task 16: Retune the SLURM launcher for the stabilization retest

- **Status**: done
- **Prereq tasks**: 15
- **Files touched**: `.agent/scratch/boltz_jump/submit_pilot.sh`
- **Change shape**: per the diagnostic's empirical evidence — `DELTA=0.05`
  (was 2.0, clearly stable per the diagnostic's sweep: 0.14A max step
  displacement vs 19.2A at delta=2.0), `N_STEPS=16000` (20x more steps,
  preserving `n_steps*delta` = total simulated time at the new finer
  discretization — standard timestep-refinement practice, not a fresh
  guess), `JUMP_EVERY=200` (finer time-resolution per recorded frame than
  the original run: 10 simulated-time-units/frame vs ~100 before, directly
  addressing Task 13's "jump_every too coarse to see real dynamics"
  finding). `LAMS=(0.0 0.3 1.0 3.0 10.0)` — adds the `lam=0` control Task
  13 flagged as missing (disentangles "steering pulled it to 6XR7" from
  "denoiser's own unconditional bias already lands near 6XR7"). Drop the
  comparison-arm rerun entirely (already succeeded in job 17175, valid data
  already committed, re-running it wastes GPU/wall-clock for no new
  information). GPU assignment: 5 guided (lam sweep) + 2 unguided (seed
  sweep) = 7 of 8 GPUs (`--gres=gpu:7`). Re-derive the `--time` estimate for
  ~20x more steps per run (still cheap: ~20-30 min/run at the prior
  per-step cost, all in parallel).
- **Verification**: `bash -n .agent/scratch/boltz_jump/submit_pilot.sh` →
  no syntax error; manual review confirms GPU index assignment has no
  overlap, no `ubuntu` account references
- **Estimated time**: 15 min
- **Rollback (if this task only)**: `git checkout -- submit_pilot.sh` (if
  already committed) or hand-revert the knobs

## Task 17: Submit the stabilization retest job and monitor to completion

- **Status**: done
- **Prereq tasks**: 16
- **Files touched**: none (SLURM submission + log/output under
  `.agent/scratch/boltz_jump/pilot_runs/` and kfs2 staging)
- **Change shape**: user already authorized this run explicitly ("처방대로
  재구현 및 실행") — stage to kfs2, submit via `sudo -u kim sbatch
  --qos=normal ...`, monitor the log for the specific failure mode this
  fix targets (no more >50A single-step displacements), collect results
  back to `/home/ubuntu` on completion.
- **Verification**: `sacct -j <jobid> --format=JobID,State,ExitCode` → all
  processes `COMPLETED`; spot-check one guided/unguided log shows
  reasonable (not astronomical) position/Rg values
- **Estimated time**: monitoring wall-clock, not counted in active-work
  estimate (background wait, ~20-30 min expected)
- **Rollback (if this task only)**: `scancel <jobid>` if it needs stopping;
  no persistent state changes to undo otherwise

## Task 18: Re-analyze retest results vs Done-When + the lam=0 control

- **Status**: done
- **Prereq tasks**: 17
- **Files touched**: `.agent/scratch/boltz_jump/results_pilot.md` (append,
  not overwrite, a "Retest" section)
- **Change shape**: same analysis method as Task 13 (Kabsch-superposed
  CA-RMSD, chain-break/clash/Rg checks, P-SEA-like helix heuristic) applied
  to the retest outputs: does the unguided demo now fold without
  diverging; does the guided demo now behave sensibly across more of the
  lambda sweep; what does the new `lam=0` control show relative to
  `lam=0.3`'s apparent 6XR7 convergence (steering effect vs prior bias);
  is the finer `jump_every` resolution now actually showing gradual
  trajectory evolution rather than a flat/instant endpoint.
- **Verification**: `results_pilot.md` contains a "Retest" section with a
  clear PASS/FAIL/PARTIAL verdict per original Done-When criterion,
  referencing concrete numbers from the new run
- **Estimated time**: 10 min (analysis dispatch + review)
- **Rollback (if this task only)**: `git checkout -- results_pilot.md` (if
  already committed) or trim the appended section

## Task 19: Implement per-step force-norm clipping in WalkJumpSampler

- **Status**: done
- **Prereq tasks**: none (walk_jump_sampler.py/run_pilot.py already exist)
- **Files touched**: `.agent/scratch/boltz_jump/walk_jump_sampler.py`,
  `.agent/scratch/boltz_jump/run_pilot.py`
- **Change shape**: add an optional `clip_norm: Optional[float] = None`
  constructor param to `WalkJumpSampler`. In `combined_score_fn`, clip the
  COMBINED force (base Tweedie score + steering force, if any — clip after
  summing, not before, so the cap applies to whatever the BAOAB step
  actually receives) per-atom: each atom's 3-vector force is rescaled to
  have norm `<= clip_norm` if it exceeds it, direction preserved,
  untouched otherwise. `None` (default) means no clipping — current
  behavior unchanged. Thread a new `--clip-force` CLI flag (default
  `None`) through `run_pilot.py` into the `WalkJumpSampler(...)`
  constructor call, alongside the existing `mass`/`kT` flags.
- **Verification**: a small inline check (e.g. `python -c` snippet, not
  necessarily a committed test file) confirming a force vector with norm
  above the clip threshold gets rescaled to exactly the threshold, and one
  below it is returned unchanged; `python run_pilot.py --help` shows
  `--clip-force`; the existing CPU-only default dry run (no `--clip-force`
  passed) behaves identically to before.
- **Estimated time**: 12 min
- **Rollback (if this task only)**: `git checkout -- walk_jump_sampler.py
  run_pilot.py` (if already committed) or manually remove the additions

## Task 20: Long (thousands-of-steps) CPU-only stability validation

- **Status**: done
- **Prereq tasks**: 19
- **Files touched**: `.agent/scratch/boltz_jump/diagnose_divergence.py`
  (extend, don't rewrite — or a new sibling script if cleaner) or a new
  `.agent/scratch/boltz_jump/validate_stability.py`
- **Change shape**: per the lesson from Task 18 (a 20-step CPU sweep did
  NOT predict full 16000-step stability — the unguided/lam=0 divergence
  onset was delayed to steps ~2200-4000), run several THOUSAND manual
  BAOAB steps (e.g. 3000-4000, covering the onset window the real GPU run
  actually showed) on the specific failing case (unguided Trp-cage, zero
  steering — simplest, isolates the core walk) for each candidate config:
  (a) `delta=0.05` alone (reproduce the known-still-diverges baseline, as
  a sanity control that this longer CPU test can actually detect the
  failure it's meant to catch), (b) `delta=0.05` + `--clip-force` at a
  couple of candidate thresholds informed by the original diagnostic's
  measured score range (e.g. clip at 3.0 and at 5.0), (c) optionally
  `delta=0.05` + `--clip-force` + `mass` raised (e.g. 16 or 100) if (b)
  alone isn't sufficient. Track position/Rg norm over the full run, not
  just a handful of steps, and confirm whichever config is chosen stays
  bounded (no runaway growth) over the whole tested duration, not just the
  first 20 steps.
- **Verification**: script output clearly shows, for the chosen config,
  bounded position/Rg growth (or a stable plateau) over thousands of
  steps, with the baseline (a) config reproducing the known divergence as
  a sanity check that the test methodology itself is discriminating
  correctly
- **Estimated time**: 20 min (CPU compute takes real wall-clock time here,
  thousands of steps at ~0.075s/step-ish ~ several minutes per config)
- **Rollback (if this task only)**: `rm` the new/extended script

## Task 21: Retune SLURM launcher with the validated config, submit, monitor

- **Status**: done
- **Prereq tasks**: 20
- **Files touched**: `.agent/scratch/boltz_jump/submit_pilot.sh`
- **Change shape**: update the frozen knobs to the config Task 20's long
  CPU validation actually supports (`--clip-force` value, possibly
  retuned `mass`), keeping `n_steps=16000`/`jump_every=200` and the same
  7-process sweep design (5 guided incl. `lam=0.0` control + 2 unguided
  seeds) since Task 18 already showed 16000 steps is long enough to
  reveal instability — no need to go longer, just more stable. Stage,
  submit via `sudo -u kim sbatch --qos=normal ...` (already authorized by
  the user this round), monitor to completion, collect results.
- **Verification**: `bash -n submit_pilot.sh` clean; after submission,
  `sacct` shows all processes `COMPLETED`; spot-check logs show no
  tracebacks
- **Estimated time**: monitoring wall-clock not counted (background wait)
- **Rollback (if this task only)**: `scancel <jobid>` if needed; revert
  the script edits otherwise

## Task 22: Re-analyze final results vs Done-When

- **Status**: done
- **Prereq tasks**: 21
- **Files touched**: `.agent/scratch/boltz_jump/results_pilot.md` (append
  a "Round 3" section)
- **Change shape**: same Kabsch-RMSD/P-SEA-helix/chain-break method as
  Tasks 13/18, applied to the new run: does the unguided demo now actually
  stay stable AND fold (three-way distinction: folds / stable-but-stuck /
  still-diverges); does the `lam=0.0` control now stay near 6XR6 instead
  of diverging (which would finally let steering-vs-stabilization be
  cleanly separated); final overall verdict per contract Done-When
  criterion.
- **Verification**: `results_pilot.md` contains a "Round 3" section with a
  clear final PASS/FAIL/PARTIAL verdict per criterion
- **Estimated time**: 10 min (analysis dispatch + review)
- **Rollback (if this task only)**: trim the appended section

