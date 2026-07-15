---
contract: .agent/contracts/mmgbsa-couple-mdlen-sampling-20260601.md
slice: mmgbsa
status: in-progress
total_tasks: 8
estimated_total_min: 37
---

# Plan: couple MD length ↔ sampling window (enforce by construction)

Goal (from contract): one single-source config from which BOTH Stage-2 nsteps AND Stage-3
gmx_MMPBSA frame range (startframe/endframe/interval) are DERIVED, plus a fail-fast preflight
assert (env-bypassable) that the sampling window ⊆ trajectory & covers the intended fraction;
proven red→green + one end-to-end SLURM validation. Mechanism is VALUE-AGNOSTIC — Tasks 1–7
use a placeholder default that REPLICATES current behavior (window=first-5ns, 50 frames) so
nothing changes until Task 8 flips the default to Phase A's determined value. Code is in the
LOCAL repo (git-tracked: run_mmpbsa.py, gb.in, mmgbsa_guards.sh) → edit → /code-review → commit
→ cp-sync to shared (SLURM runs the shared copy).

## Task 1: Pin the single-source derivation inputs (inspect)

- **Status**: done (2026-06-01; .agent/scratch/mmgbsa_stable/coupling_inputs.md — frame_spacing=100ps via Stage-3 override (repo mdp 1000 stale), derive() inputs + placeholder default pinned)
- **Prereq tasks**: none
- **Files touched**: `.agent/scratch/mmgbsa_stable/coupling_inputs.md` (new)
- **Change shape**: confirm the AUTHORITATIVE frame spacing (Stage-3 `MDP_MMPBSA` override
  sets nstxout-compressed=50000 → 100 ps/frame at runtime; note the repo `workflow/mdp/
  mmpbsa_prod.mdp` shows 1000 = stale/overridden), dt=0.002, and exactly where nsteps (Stage-2)
  and start/end/interval (Stage-3 `patch_gb_in`) are produced today. Record the derive() inputs
  + the current (placeholder) values that replicate today's behavior.
- **Verification**: `coupling_inputs.md` states frame_spacing_ps=100 (with the override
  evidence), dt, the two producers, and the placeholder (window=[0,5]ns, n=50 → current).
- **Estimated time**: 5 min
- **Rollback (if this task only)**: `rm` the scratch file

## Task 2: Red test for the coupling module (derive + check)

- **Status**: pending
- **Prereq tasks**: 1
- **Files touched**: `scripts/mmgbsa_16gpu_multidir/tests/test_mmgbsa_coupling.py` (new)
- **Change shape**: pytest asserting (a) `derive_nsteps(L_ns, dt_ps)` and
  `derive_frame_range(window_ns, frame_spacing_ps, n_samples)` from a single config give the
  expected nsteps + (startframe,endframe,interval); (b) `coupling_check(...)` REJECTS a
  mismatch (window beyond traj; or first-5ns when window says full) and PASSES a match;
  (c) `COUPLING_CHECK=0` bypasses. Fails now (no module).
- **Verification**: `python -m pytest scripts/mmgbsa_16gpu_multidir/tests/test_mmgbsa_coupling.py`
  → fails with import/Attribute error (red).
- **Estimated time**: 5 min
- **Rollback (if this task only)**: `rm` the test file

## Task 3: Implement mmgbsa_coupling.py (single source + derive + check) → green

- **Status**: pending
- **Prereq tasks**: 2
- **Files touched**: `scripts/mmgbsa_16gpu_multidir/mmgbsa_coupling.py` (new)
- **Change shape**: canonical config (L_ns, dt_ps, frame_spacing_ps, sample window [a,b]ns,
  n_samples) + `derive_nsteps`, `derive_frame_range`, `coupling_check` (fail-fast, returns
  token + nonzero on mismatch; `COUPLING_CHECK=0` env bypass) + a CLI (`--emit nsteps` /
  `--emit gb-range` / `--check ...`) for bash callers. Default config = the placeholder
  replicating current behavior.
- **Verification**: the Task 2 pytest passes (green); `python -m mmgbsa_coupling --emit nsteps`
  prints the derived integer.
- **Estimated time**: 5 min
- **Rollback (if this task only)**: `rm` the module (Task 2 test goes red again)

## Task 4: Wire Stage-3 sampling to the single source (patch_gb_in)

- **Status**: pending
- **Prereq tasks**: 3
- **Files touched**: `workflow/scripts/run_mmpbsa.py`
- **Change shape**: `patch_gb_in` derives startframe/endframe/interval from
  `mmgbsa_coupling.derive_frame_range(...)` (single source) instead of only patching
  `endframe = samples`. Behavior-preserving under the placeholder default (still first-5ns/50).
- **Verification**: a unit/inline check — `patch_gb_in` on a sample gb.in yields the
  start/end/interval matching `derive_frame_range` (and = current values under the placeholder).
- **Estimated time**: 5 min
- **Rollback (if this task only)**: `git checkout workflow/scripts/run_mmpbsa.py`

## Task 5: Wire the coupling preflight into mmgbsa_guards.sh + Stage-3 (+ bash test)

- **Status**: pending
- **Prereq tasks**: 3
- **Files touched**: `scripts/mmgbsa_16gpu_multidir/mmgbsa_guards.sh`,
  `scripts/mmgbsa_16gpu_multidir/slurm_normtest143_stage3_postprocess_seed777.sh`,
  `scripts/mmgbsa_16gpu_multidir/tests/test_guard_coupling.sh` (new, dual-mode)
- **Change shape**: add `coupling_preflight` to mmgbsa_guards.sh (thin bash wrapper calling
  `python -m mmgbsa_coupling --check` with the actual traj frames vs derived range; emits a
  COUPLING_MISMATCH token + returns 1 on mismatch; `COUPLING_CHECK=0` bypass). Wire it into the
  Stage-3 script BEFORE the post loop. Add `test_guard_coupling.sh` to the bash harness.
- **Verification**: `bash scripts/mmgbsa_16gpu_multidir/tests/run_guards_tests.sh` → fail=0 and
  the new coupling test asserts mismatch→token+nonzero, match→0, COUPLING_CHECK=0→0.
- **Estimated time**: 5 min
- **Rollback (if this task only)**: `git checkout` the 2 scripts; `rm` the test

## Task 6: cp-sync changed files local→shared

- **Status**: pending
- **Prereq tasks**: 4, 5
- **Files touched**: shared copies of `workflow/scripts/run_mmpbsa.py`,
  `scripts/mmgbsa_16gpu_multidir/{mmgbsa_coupling.py,mmgbsa_guards.sh,slurm_normtest143_stage3_postprocess_seed777.sh}`
- **Change shape**: `sudo -u ubuntu` copy the changed files local→shared with a `.bak` of each
  existing shared file first.
- **Verification**: `sudo -u ubuntu cmp -s <local> <shared>` identical for each of the 4 files;
  `.bak` exists for the pre-existing ones.
- **Estimated time**: 4 min
- **Rollback (if this task only)**: restore the shared `.bak` copies

## Task 7: End-to-end SLURM validation (matched passes / mismatched rejected)  [SLURM GATE]

- **Status**: pending
- **Prereq tasks**: 6
- **Files touched**: a small staged OUT_BASE (reuse the Phase-A validation subset or a 1–2 traj
  fresh dir); logs
- **Change shape**: submit Stage-3 twice under contract mmgbsa-couple-mdlen-sampling-20260601:
  (1) a MATCHED config (window within the traj) → guard PASS + MMGBSA runs (dg_result produced);
  (2) a deliberately MISMATCHED config (window beyond traj length, or COUPLING off-by-design) →
  guard fails fast with COUPLING_MISMATCH BEFORE any MMGBSA compute.
- **Verification**: matched job log shows `coupling_preflight OK` + dg_result.json; mismatched
  job exits nonzero with `COUPLING_MISMATCH` and no gmx_MMPBSA invocation.
- **Estimated time**: 5 min agent + external Stage-3 wall
- **Rollback (if this task only)**: `scancel`; outputs in the small staged dir

## Task 8: Set the production default = Phase A value + record  [DEPENDS ON PHASE A]

- **Status**: pending
- **Prereq tasks**: 3, 7  (AND Phase A `mmgbsa-e2e-validate-length` complete — supplies L/window)
- **Files touched**: `scripts/mmgbsa_16gpu_multidir/mmgbsa_coupling.py`,
  `.agent/projects/fksfold-mmgbsa-slurm-harness.md`
- **Change shape**: flip the `mmgbsa_coupling.py` default config from the placeholder to Phase
  A's determined MD length + sampling window; record the coupled standard (L, window, derived
  nsteps + frame range) in the runbook §"Stage-2 MD STANDARD SETTINGS — FIXED" with the rule
  "set via the single source only".
- **Verification**: `python -m mmgbsa_coupling --emit nsteps` = Phase-A-derived value; runbook
  §FIXED shows the coupled standard + single-source rule; coupling tests still green.
- **Estimated time**: 3 min
- **Rollback (if this task only)**: `git checkout` the module + runbook
