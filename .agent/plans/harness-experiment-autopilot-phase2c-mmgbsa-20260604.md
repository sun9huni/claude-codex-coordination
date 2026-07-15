---
contract: .agent/contracts/harness-experiment-autopilot-20260604.md
slice: harness
status: done
total_tasks: 5
estimated_total_min: 26
---

# Plan: FEA Phase 2c (mmgbsa) — coupling preflight (pre-submit, independent of blocked B4)

Generalizes FEA Stage-1 preflight to **mmgbsa MD↔sampling coupling**, scoped to a
**pre-submit arithmetic check** that reuses the committed `mmgbsa_coupling.py` and
adds the coverage guard that catches the documented bug. Does **not** touch the
blocked `run_mmpbsa.py` (B4 wiring stays deferred per mmgbsa slice). The post-hoc
run-dir audit (gmx check on real trajectories) is a possible later task.

**Recon facts (verified):**
- `scripts/mmgbsa_16gpu_multidir/mmgbsa_coupling.py` is **complete + committed**
  (`8489bc0`, 11/11 tests): `derive_nsteps(L,dt)`, `derive_frame_range(window,
  spacing,n)`, `coupling_check(traj_frames,start,end,interval)` + CLI. We REUSE it.
- **Gap it does NOT cover**: `coupling_check` only flags *window > trajectory*
  (endframe > traj_frames / invalid start). It does **not** flag the documented
  ranking-corrupting bug — sampling only the **first 5 ns of a 20 ns** run
  (under-sampling; window ⊂⊂ trajectory). That coverage guard is FEA's addition.
- Canonical intent (contract `mmgbsa-couple-mdlen-sampling`, baton): full-traj
  window e.g. `(0,20)ns / 50 samples / interval 4` at 100 ps spacing; the bug is
  `(0,5)ns / interval 1`. Module DEFAULT still replicates today's `(0,5)` until the
  mmgbsa slice's Task B8 flips it — so the coverage policy lives FEA-side, not as a
  module default change.
- **Boundary**: `run_mmpbsa.py` is dirty/blocked on fksfold-core's reorg; B4/B6/B7
  deferred (user decision 2026-06-01). This plan adds a read-only/arithmetic
  validator only — it imports `mmgbsa_coupling` but edits nothing in that slice.

---

## Task 1: Red test — mmgbsa coupling preflight (under-sampling + window>traj)

- **Status**: done
- **Prereq tasks**: none
- **Files touched**: `scripts/fea/tests/test_mmgbsa_preflight.py`
- **Change shape**: Test imports `scripts.fea.mmgbsa_preflight.run_coupling_preflight`
  and asserts, for inputs `(md_length_ns, window_ns, frame_spacing_ps=100,
  n_samples, dt_ps=0.002)`:
  - **bug case** `md=20, window=(0,5), n=50` → an **error** issue code
    `coupling_undersampled` whose message cites the coverage (≈25%) and "first-5ns".
  - **matched case** `md=20, window=(0,20), n=50` → `.ok` (derives (1,200,4); coverage 100%).
  - **window>traj case** `md=5, window=(0,20), n=50` → an **error** code
    `coupling_window_exceeds_traj` (delegated to `mmgbsa_coupling.coupling_check`).
  Document the contract for Task 2. FAILS now (module absent).
- **Verification**: `pytest scripts/fea/tests/test_mmgbsa_preflight.py` → fails on import.
- **Estimated time**: 5 min
- **Rollback**: `rm -f scripts/fea/tests/test_mmgbsa_preflight.py`

## Task 2: Green — mmgbsa_preflight.py reusing mmgbsa_coupling + coverage guard

- **Status**: done
- **Prereq tasks**: 1
- **Files touched**: `scripts/fea/mmgbsa_preflight.py`
- **Change shape**: `run_coupling_preflight(md_length_ns, window_ns,
  frame_spacing_ps=100.0, n_samples=50, dt_ps=0.002, coverage_min=0.75) ->
  PreflightReport` (reuse `Issue`/`PreflightReport` from `scripts.fea.preflight`).
  Import `mmgbsa_coupling` by adding its dir to `sys.path` (mirror the
  `activity_eval_gates` import idiom in `postflight.py`). Logic:
  (a) `traj_frames = round(md_length_ns*1000/frame_spacing_ps)`;
  (b) `(start,end,interval) = mmgbsa_coupling.derive_frame_range(window, spacing, n)`;
  (c) if `mmgbsa_coupling.coupling_check(traj_frames,start,end,interval)` != 0 →
      Issue("error","coupling_window_exceeds_traj", ...);
  (d) coverage = `(window[1]-window[0]) / md_length_ns`; if `window[1] < md_length_ns`
      and coverage < coverage_min → Issue("error","coupling_undersampled",
      f"sampling window covers {coverage:.0%} of the {md_length_ns}ns trajectory "
      "(first-{window[1]}ns) — under-converged, corrupts ΔG ranking; use a full-traj window").
  Reuse the committed arithmetic; do NOT reimplement derive_frame_range.
- **Verification**: `pytest scripts/fea/tests/test_mmgbsa_preflight.py` passes.
- **Estimated time**: 6 min
- **Rollback**: `git checkout scripts/fea/mmgbsa_preflight.py`

## Task 3: Wire `fea preflight-mmgbsa` CLI subcommand

- **Status**: done
- **Prereq tasks**: 2
- **Files touched**: `scripts/fea/__main__.py`
- **Change shape**: Add `preflight-mmgbsa` subcommand: args `--md-length-ns`
  (required, float), `--window A B` (required, two floats), `--frame-spacing` (def
  100), `--n-samples` (def 50), `--dt` (def 0.002), `--coverage-min` (def 0.75),
  `--strict`. Handler calls `run_coupling_preflight`, prints the same ✗/⚠/✓ report
  format as `preflight`, exit 1 on error (or any issue under `--strict`).
- **Verification**:
  `python -m scripts.fea preflight-mmgbsa --md-length-ns 20 --window 0 5` → prints
  `coupling_undersampled` ✗ and exits 1; `--window 0 20` → `✓ preflight clean`, exit 0.
- **Estimated time**: 5 min
- **Rollback**: `git checkout scripts/fea/__main__.py`

## Task 4: Doc — note the post-hoc run-dir audit as a deferred follow-up

- **Status**: done
- **Prereq tasks**: 3
- **Files touched**: `scripts/fea/README.md`
- **Change shape**: Add a short section: Phase 2c ships the *pre-submit* coupling
  arithmetic check; the *post-hoc* run-dir audit (parse real `traj_frames` via
  `gmx check` + the patched `gb_run.in`, then `mmgbsa_coupling.coupling_check`) is a
  deferred follow-up (needs gmx + run dirs). Note FEA never edits the blocked
  `run_mmpbsa.py`; B4 wiring remains the mmgbsa slice's task.
- **Verification**: `grep -q "post-hoc" scripts/fea/README.md`.
- **Estimated time**: 3 min
- **Rollback**: `git checkout scripts/fea/README.md`

## Task 5: Finalize — baton + plan/contract status

- **Status**: done
- **Prereq tasks**: 4
- **Files touched**: `.agent/status/harness.md`, this plan, the contract Progress Log
- **Change shape**: Record Phase 2c (mmgbsa coupling preflight) shipped in the
  harness baton + contract Progress Log; set this plan `status: done`. Note the
  remaining Phase 2 work (Stage 2 watch; fksfold-core CRBN-anchor + GPU-UUID
  preflight; mmgbsa post-hoc run-dir audit).
- **Verification**: `python -m pytest scripts/fea/tests/ -q` all pass;
  `python -m scripts.fea preflight-mmgbsa --help` works; `./scripts/status.sh index` clean.
- **Estimated time**: 4 min
- **Rollback**: `git checkout .agent/status/harness.md`
