# MMGBSA end-to-end validation + MD-length standard

- **Status**: done
- **Slice**: mmgbsa
- **Approval**: requested 2026-06-01, approved by: user ("진행") 2026-06-01
- **Notes (done 2026-06-01)**: Stage 3→4 validated end-to-end on 6 completed 20ns trajs (6/6 sane dG_mean; ΔΔG empty = 0 complete pairs, documented). MD-length/sampling resolved: ΔG converges ~10–15ns; the first-5ns/50-frame sampling is NOT converged (off 2–4 kcal/mol, system-dependent → corrupts ΔΔG); fix = full-traj sampling. Recorded in runbook §"MD length + Stage-3 sampling — FIXED". The enforcement of that fix is the separate couple-mdlen-sampling contract (B4 deferred on fksfold-core WIP). Jobs 5966/5973/6070.
- **Triggers matched**: SLURM submission (Stage 3 MMGBSA), shared-storage writes (kfs5), likely 4+ files
- **Resource budget**: ZERO new MD (no GPU-days for production MD). Only Stage-3 MMGBSA
  compute over the already-completed trajectories × cumulative windows (CPU-parallel,
  bounded) + a light convergence analysis. No 62-traj Stage-2 submit in this phase.

## Purpose

Close the two gaps that block a *stable, large-scale, end-to-end* MMGBSA pipeline
BEFORE committing GPU-days to the 62-trajectory Stage-2 production run:
1. The downstream (Stage 3 MMGBSA over frames → Stage 4 ΔΔG merge) has NOT been
   exercised in this hardening effort — only Stage 2 (MD) was validated (smoke 5860).
2. The MD length is an inherited 20 ns (the value the AB tprs were built with), not a
   determined, justified pipeline standard.
Both are answered using the 14 already-completed 20 ns trajectories as a free asset
(no new MD), so the pipeline's downstream is proven and its MD-length default is fixed
on evidence — the same discipline already applied to DIRS_PER_GPU=2.

## Current State

- Stage 2 (MD): hardened + validated. Smoke 5860 = 16/16, audit mismatches=0, ENOSPC 0,
  stall false-fires 0. Packing fixed at DIRS_PER_GPU=2 (throughput-optimal, job 5890).
  3 orchestrator hotfixes committed + synced (8e28d9d / de4b5f8 / 017b62c).
- Stage 3 (MMGBSA over sampled frames → dg_result.json / FINAL_RESULTS_MMPBSA.dat) and
  Stage 4 (RunA/RunB merge → mmgbsa_components.tsv, mmgbsa_ddg_components.tsv): NOT run
  in this effort. Runbook defaults: SAMPLES=50, POST_PARALLEL=4, POST_THREADS=8.
- AB OUT_BASE `/mnt/data/users/ubuntu/mmgbsa_outputs/norm143_ab_seed16_stage1_20260527_182206`:
  76 ready (23 RunA + 53 RunB); 14 completed at 20 ns (resume-skippable); 62 incomplete.
- MD length = inherited 20 ns (nsteps=10M). MMGBSA endpoint ΔG typically converges in a
  few ns; a CRBN–PROTAC–VAV1 ternary may drift over 20 ns (adding noise). A 20 ns traj is
  a SUPERSET — it can be analyzed over any window ≤ 20 ns, so determining a shorter
  standard does NOT waste the 14 completed trajs and keeps the panel internally consistent
  (all 76 later analyzed over the same window).

## Assumptions And Questions

- assumptions: the completed 14 trajs are physically valid 20 ns runs; Stage 3/4 tooling
  exists in the shared tree; ΔΔG = ΔG(RunA) − ΔG(RunB) per compound (RunB = binary ref).
- open questions: how many of the 14 complete form RunA/RunB pairs (needed for a Stage-4
  ΔΔG vs only Stage-3 ΔG); does ΔG plateau before 20 ns for this ternary; is Stage 3 light
  enough for inline or must it go to SLURM (resolved at plan time → assume SLURM/gate).
- tradeoffs: shorter standard = cheaper + less ternary-drift noise but fewer frames;
  longer = more sampling but diminishing returns + drift risk + 2–4× GPU-hours.

## Constraints

- allowed change scope: run Stage 3 → Stage 4 on the completed-traj subset into a SEPARATE
  fresh OUT_BASE (14 trajs are read-only source); compute ΔG/interface-stability over
  cumulative windows (2,4,…,20 ns); write the chosen MD-length standard into the runbook
  `.agent/projects/fksfold-mmgbsa-slurm-harness.md`; analysis artifacts in `.agent/scratch`.
- forbidden change scope: no new production MD; no MD physics changes; no Stage-1 re-prep;
  no re-running the 14; no Stage 3/4 code hardening (guards) in this phase.
- external constraints: `/mnt/data/users/ubuntu/` writes via `sudo -u ubuntu`; SLURM submit
  only under this contract; `rm -rf /mnt/data*` hook-blocked for claude (cleanup via ubuntu).

## Non-Goals

- The 62-trajectory Stage-2 production submit (deferred until this phase passes + length fixed).
- Stage 3/4 robustness guards (preflight/resume/audit) — a separate later phase.
- Stage-1 re-prep or re-running the 14 completed trajectories.
- MD physics changes (force field / water / integrator / coupling).

## Done When

- **End-to-end pass (once):** Stage 3 → Stage 4 runs to completion on the completed-traj
  subset and produces a ΔG output (dg_result.json / FINAL_RESULTS_MMPBSA.dat) AND, for at
  least one complete RunA/RunB pair, a ΔΔG row (mmgbsa_ddg_components.tsv); values inspected
  and sane (finite, right sign/magnitude order), not NaN/empty. If no complete pair exists
  among the 14, Stage-3 ΔG is produced + the pairing gap is documented (no new MD to fill it).
- **Length fixed:** ΔG (and an interface-stability proxy: interface RMSD or short-range
  interaction energy from the .edr) computed over cumulative windows; the plateau / useful
  window identified; a standard MD length chosen.
- **Recorded:** the chosen MD-length standard written into
  `.agent/projects/fksfold-mmgbsa-slurm-harness.md` §Stage-2 MD STANDARD SETTINGS — FIXED,
  with the convergence evidence, as the mandatory default (parallel to DIRS_PER_GPU=2).

## Implementation Steps

1. inspect Stage 3/4 scripts in the shared tree + identify completed trajs / RunA-RunB pairs
   verify: list of complete trajs + which form pairs; Stage 3/4 entrypoints confirmed
2. stage a separate fresh OUT_BASE referencing the 14 completed trajs read-only
   verify: fresh dir on a healthy branch; source xtc untouched
3. run Stage 3 (MMGBSA) → Stage 4 (merge) end-to-end on the subset (SLURM, under this contract)
   verify: dg_result / ddg_components produced; values finite + sane
4. convergence: compute ΔG + interface-stability proxy over cumulative windows; find plateau
   verify: window-vs-ΔG table/plot in .agent/scratch shows a plateau; standard length chosen
5. fix the MD-length standard in the runbook with the evidence
   verify: runbook §FIXED shows the chosen length + rationale

## Change Discipline

- simplest adequate approach: reuse existing Stage 3/4 tooling on existing trajs; window
  analysis by re-sampling frames from the same xtc (no recompute of MD).
- new abstractions introduced: none (analysis scripts live in .agent/scratch).
- unrelated code touched: none (no orchestrator/guard edits this phase).
- request-to-diff trace: goal (stable e2e pipeline) → validate Stage 3→4 + fix MD length.

## Verification

- task-specific command: Stage-4 output `mmgbsa_ddg_components.tsv` exists with ≥1 finite
  ΔΔG row (or Stage-3 ΔG + documented pairing gap); convergence table in
  `.agent/scratch/mmgbsa_stable/` shows the ΔG plateau; runbook §FIXED updated.
- manual check: inspect ΔG/ΔΔG magnitudes for sanity; confirm chosen window ≤ 20 ns.

## Risks

- regression risk: none to existing trajs (read-only); Stage-3 outputs are in a fresh dir.
- integration risk: Stage 3/4 tooling may need flags/inputs not yet wired (first real run).
- hidden dependency risk: ΔΔG needs RunA/RunB pairs; may be scarce among the 14 complete.

## Rollback

- revert strategy: discard the fresh Stage-3 OUT_BASE dir (sudo -u ubuntu); analysis is in
  `.agent/scratch` (throwaway); runbook edit reverts via `git checkout`.
- containment strategy: 14 source trajectories are read-only and untouched throughout.

## Progress Log

- 2026-06-01: contract drafted via /brainstorm (success=e2e pass once + length fixed;
  out-of-scope=62-traj submit / Stage3-4 hardening / Stage-1 re-prep; rollback=fresh dir;
  gates=SLURM + shared writes).
