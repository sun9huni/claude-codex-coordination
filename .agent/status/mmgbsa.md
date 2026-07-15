---
owner_session: 21d5491d-21bb-437e-b499-05cd849295ec
owner_label: 
owner_agent: claude
version: 15
last_updated: 2026-06-02
heartbeat: 2026-06-02T13:57:18Z
remaining_actions:
  - "FINISH Phase B coupling (B4/B6/B7/B8) ONCE aigen-fold-core commits its run_mmpbsa.py dirty-tree WIP: wire patch_gb_in to mmgbsa_coupling single source with default window=(0,20)ns/50-samples/interval=4 (FULL-traj, NOT first-5ns), wire coupling_preflight into Stage-3, cp-sync, 1 matched+1 mismatched SLURM validation. Recipe: .agent/scratch/mmgbsa_stable/coupling_phase_status.md. This is REQUIRED before any real Stage-3 run (first-5ns sampling gives under-converged, ranking-corrupting ΔG)."
  - "REAL production run (still NOT submitted): 62 incomplete AB Stage-2 trajs (of 76; 14 done) at 20ns, DIRS_PER_GPU=2, NODES_FOR_MULTIDIR=2, --exclude=host-10-0-3-160,host-10-0-5-232,host-10-0-5-73. Stage-2 MD can run now (independent of sampling); run Stage-3 only AFTER the full-traj sampling fix lands. Recipe in runbook §FIXED + smoke_throughput.txt §REAL RUN."
  - "Bookkeeping: mark e2e-validate-length contract+plan done (delivered). Cleanup throwaway dirs on kfs5 (mmgbsa_smoke_20260601{,b,c}, mmgbsa_gpu_*, mmgbsa_pack_measure, mmgbsa_e2e_validate_20260601) via sudo -u ubuntu."
contract_pointers:
  - .agent/contracts/mmgbsa-stable-pipeline-20260601.md
  - .agent/contracts/mmgbsa-e2e-validate-length-20260601.md
  - .agent/contracts/mmgbsa-couple-mdlen-sampling-20260601.md
state: active
---
# MMGBSA / SLURM Status

As of: 2026-06-01 — **Stage-2 pipeline hardened+packed; e2e (Stage 3→4) validated + MD-length/sampling resolved; coupling module+guard landed (wiring deferred)**

## Stage-2 stable-pipeline (contract mmgbsa-stable-pipeline) — validated
- Smoke 5860: 16/16, audit 0, ENOSPC 0, stall 0. 3 hotfixes committed+shared-synced (8e28d9d mdrun output flags / de4b5f8 spool guards-source / 017b62c skew-robust watchdog). **DIRS_PER_GPU=2** fixed as throughput-optimal (job 5890; runbook §FIXED). Real 62-traj run NOT submitted.

## e2e-validate-length (this session) — DONE
- Stage 3 (MMGBSA) → Stage 4 (merge) validated end-to-end on 6 completed 20ns trajs: **6/6 sane ΔG** (dG_mean −33..−42 kcal/mol). ΔΔG empty (0 complete RunA/RunB pairs — documented; would need new RunB MD).
- **KEY FINDING (answers "is 20ns right?"): YES — 20ns is correct, but the BUG is the SAMPLING.** ΔG converges only ~10–15 ns; the current first-5ns/50-frame sampling (gb.in startframe=1/interval=1, endframe=50) is NOT converged — off 2–4 kcal/mol, error direction system-dependent (VAV1_320 over-binds, VAV1_291 under-binds → corrupts ΔΔG ranking). Fix = FULL-traj sampling (interval). Evidence + standard in runbook §"MD length + Stage-3 sampling — FIXED". Jobs 5966/5973/6070.

## couple-mdlen-sampling (this session) — module+guard landed, wiring DEFERRED
- Committed (clean): `8489bc0` mmgbsa_coupling.py single-source (derive_nsteps/derive_frame_range/coupling_check, pytest 11/11); `157dbdb` coupling_preflight guard (run_guards_tests 7/40 pass).
- B4/B6/B7/B8 DEFERRED: run_mmpbsa.py is entangled in **aigen-fold-core's pre-existing 157-entry dirty-tree reorg WIP** (see that slice's baton). A3 proved that WIP's portability refactor is NOT needed. My B4 edit reverted to un-entangle; ⚠️ the Edit→ruff hook reflowed run_mmpbsa.py (irreversible, no snapshot) — aigen-fold-core to reconcile. Full handoff: `.agent/scratch/mmgbsa_stable/coupling_phase_status.md`.

## Pending approval gate
- Real 62-traj Stage-2 run (multi-day) — gated; and Stage-3 must wait for the full-traj sampling fix (Phase B B4).
