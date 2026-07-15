# MMGBSA: couple MD length ↔ sampling window (enforce by construction)

- **Status**: approved
- **Slice**: mmgbsa
- **Approval**: requested 2026-06-01, approved by: user ("승인") 2026-06-01
- **Triggers matched**: 4+ files, shared-storage writes (cp-sync to shared tree), small
  SLURM validation (one Stage-3 run to prove the guard end-to-end)
- **Resource budget**: code + guard + test + ONE small Stage-3 validation run. No production
  MD, no panel re-run. Mechanism is VALUE-AGNOSTIC; the default L/window comes from Phase A.
- **Depends on**: `.agent/contracts/mmgbsa-e2e-validate-length-20260601.md` (Phase A) supplies
  the DEFAULT values (MD length L, sample window); this phase enforces the COUPLING rule and
  can be built in parallel, with A's values plugged in as the config default at the end.

## Purpose

Make the Stage-2 MD length and the Stage-3 MMGBSA sampling window **coupled by construction**
so a mismatch like the one found 2026-06-01 — 20 ns MD (200 frames) but Stage-3 sampling the
first 50 frames (= first 5 ns), silently discarding 15 ns — can never recur unnoticed. A
stable large-scale pipeline must guarantee the binding-energy estimate actually uses the
trajectory it pays to compute.

## Current State

- Two knobs set INDEPENDENTLY with no link or check:
  - Stage-2 MD length: `nsteps` (via `EXPECTED_MMPBSA_NSTEPS` / the prod mdp); 20 ns = 10M steps.
  - Stage-3 sampling: `workflow/mdp/gb.in` (`startframe=1, interval=1, endframe=9999999`),
    and `run_mmpbsa.py::patch_gb_in` patches ONLY `endframe = {samples}`. With nstxout-compressed
    =50000 → 100 ps/frame, `--samples 50` ⇒ frames 1–50 = first 5 ns. `interval`/`startframe`
    never reconciled with the MD length.
- Touch points: `workflow/scripts/run_mmpbsa.py` (patch_gb_in, sampling), `workflow/mdp/gb.in`,
  `slurm_normtest143_stage3_postprocess_seed777.sh` (SAMPLES env), the Stage-2 length source,
  `scripts/mmgbsa_16gpu_multidir/mmgbsa_guards.sh` (home for a preflight assert). Local repo +
  shared tree (SLURM runs the shared copy → cp-sync, like the Stage-2 hotfixes).
- No single source of truth; no consistency assertion.

## Assumptions And Questions

- assumptions: frame spacing = nstxout-compressed × dt (100 ps at current mdp); actual frame
  count is knowable at Stage-3 time (md_done nframes / `gmx check` on the xtc).
- open questions: exact single-source format (env block vs JSON vs a derive() in run_mmpbsa.py);
  whether the assert lives in mmgbsa_guards.sh (wired into Stage-3) or inside run_mmpbsa.py.
- tradeoffs: derivation removes the footgun but adds one config layer; the assert adds a
  fail-fast gate (bypassable via env for emergencies).

## Constraints

- allowed change scope: add a single-source config from which BOTH nsteps and the gmx_MMPBSA
  frame range (startframe/endframe/interval) are DERIVED; add a preflight assert (fail-fast,
  env-bypassable) that the sampling window ⊆ trajectory AND covers the intended fraction; a
  red→green test; cp-sync to shared.
- forbidden change scope: no production MD / panel re-run; no MD physics changes; no other
  Stage-3/4 guards (resume/audit) — coupling only; do not re-determine L/window (Phase A owns that).
- external constraints: shared writes via `sudo -u ubuntu`; SLURM only under this contract;
  `rm -rf /mnt/data*` hook-blocked for claude.

## Non-Goals

- Determining the actual MD length / sampling window values (Phase A's job; this consumes them).
- Production MD or panel re-run.
- MD physics changes (force field / water / integrator).
- Other Stage-3/4 robustness hardening (resume/audit) — this is the coupling rule only.

## Done When

- **Single-source derivation:** one config block (MD length L ns, frame spacing, sample window
  [a,b] ns and/or N samples) is the SOLE source; `nsteps` (Stage-2) and `startframe`/`endframe`/
  `interval` (Stage-3 gb.in) are computed from it — neither can be set independently.
  Verify: changing L in the single source updates BOTH the derived nsteps and the derived
  frame range (a unit assertion on the derive function).
- **Preflight assert (fail-fast, bypassable):** a guard (in `mmgbsa_guards.sh`, wired into
  Stage-3 / the orchestrator) FAILS with a clear token when the sampling window is not within
  the trajectory OR does not cover the intended fraction; honored env `COUPLING_CHECK=0` bypass.
  Verify: red→green test — a mismatched config (window beyond traj, or first-5ns-of-20ns when
  the window says "full") is REJECTED (nonzero + token); a matched config PASSES (0).
- **End-to-end:** a real Stage-3 run with a matched config passes the guard and runs; a
  deliberately mismatched config is rejected BEFORE compute (no wasted MMGBSA).
  Verify: the matched Stage-3 job logs the guard PASS + produces dg_result; the mismatched
  submission exits fast with the guard token.

## Implementation Steps

1. inspect current nsteps + gb.in + patch_gb_in derivation points; confirm frame-spacing source
   verify: derivation inputs enumerated (L, dt, spacing, window)
2. add the single-source config + derive() for nsteps and frame range (red test first)
   verify: derive() unit test — L→(nsteps, startframe/endframe/interval) correct; mismatch caught
3. add the preflight coupling assert to mmgbsa_guards.sh + wire into Stage-3 (env-bypassable)
   verify: red→green guard test (mismatch rejected / match passes; COUPLING_CHECK=0 bypasses)
4. cp-sync changed files local→shared (.bak each)
   verify: cmp identical local↔shared
5. end-to-end SLURM validation: one matched Stage-3 run passes; one mismatched rejected fast
   verify: matched → guard PASS + dg_result; mismatched → guard token, no MMGBSA compute

## Change Discipline

- simplest adequate approach: one derive() + one assert + one test; reuse mmgbsa_guards.sh.
- new abstractions introduced: a single-source config block + derive() (justified — it IS the
  coupling).
- unrelated code touched: none (no resume/audit/merge changes).
- request-to-diff trace: "MD length & sampling must be coupled" → single-source derive + assert.

## Verification

- task-specific command: `bash scripts/mmgbsa_16gpu_multidir/tests/run_guards_tests.sh` includes
  a coupling test (mismatch rejected / match passes); a Stage-3 dry/real run shows the guard PASS
  on a matched config and fail-fast token on a mismatched one.
- manual check: changing L in the single source changes BOTH nsteps and the frame range.

## Risks

- regression risk: a too-strict assert could false-reject valid configs → env bypass + test coverage.
- integration risk: derive() must match gmx_MMPBSA's frame indexing (1-based, interval) exactly.
- hidden dependency risk: other callers of gb.in/patch_gb_in must go through the single source.

## Rollback

- revert strategy: `git revert` the change in the local repo; restore the shared `.bak` copies;
  set `COUPLING_CHECK=0` to bypass the assert immediately if it false-rejects in production.
- containment strategy: the guard is additive + fail-fast (rejects BEFORE compute) — it cannot
  corrupt data; the single-source derivation only changes how existing params are produced.

## Progress Log

- 2026-06-01: contract drafted via /brainstorm (success=single-source derive + preflight assert
  + red→green test; out-of-scope=value re-determination(Phase A)/production MD/other Stage3-4
  hardening/MD physics; rollback=git revert + .bak + COUPLING_CHECK=0; gates=4+ files + shared
  writes + small SLURM validation). Depends on Phase A (mmgbsa-e2e-validate-length) for defaults.
