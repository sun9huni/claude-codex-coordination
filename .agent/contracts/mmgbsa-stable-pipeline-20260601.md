# mmgbsa-stable-pipeline — harden 16-GPU MMGBSA orchestrator for hands-off large-panel runs

- **Status:** approved
- **Slice:** mmgbsa
- **Approval:** requested 2026-06-01 · approved by: sunghoon.kim 2026-06-01
- **Supersedes:** subsumes the narrow
  [.agent/contracts/mmgbsa-ab-stage2-rerun-20260601.md](mmgbsa-ab-stage2-rerun-20260601.md)
  — the AB VAV1-decomp rerun becomes a *downstream consumer* of a hardened
  pipeline and is explicitly OUT of scope here (see Non-Goals). Recommend
  marking that contract `superseded` on approval of this one.
- **Depends on:**
  [.agent/contracts/mmgbsa-worker-status-bug-20260526.md](mmgbsa-worker-status-bug-20260526.md)
  — the "trustworthy completion tables" SLO requires the `md_done`/status
  attribution to be correct (see Assumptions).

## Purpose

Harden the existing 16-GPU `mmgbsa_16gpu_multidir` orchestrator so a large
compound panel runs to completion **hands-off** — surviving mergerfs disk
pressure, node faults, and the 3-day SLURM walltime — with completion state
the operator can trust. Motivated by job 5809, which wasted ~3 GPU-days in a
**silent ENOSPC retry loop** (mergerfs branch kfs6 99% full while the pool
had 49T free) and went undetected until manual diagnosis.

## Current State

Orchestrator:
`/mnt/data/users/ubuntu/workspace/FKSFold-Boltz_Advancement_shared/scripts/mmgbsa_16gpu_multidir/slurm_normtest143_stage2_md_multidir_seed777.sh`
(2 nodes × 8 A100, `DIRS_PER_GPU`, `WAVE_SIZE`, multidir; production = 20 ns /
10M steps / ~19 h wall at ~25 ns/day). mergerfs `/mnt/data` = union of
`/mnt/kfs1..7`; create policy not yet captured.

Observed failure modes (the hardening targets — evidence from 5809):

| # | Failure mode | Evidence |
|---|---|---|
| 1 | mergerfs branch saturation → ENOSPC (pool had 49T free) | kfs6 99%, kfs5 94%; node1 ENOSPC on `*.mdrun.log` |
| 2 | No walltime-aware checkpoint/resume; work past 3 d is lost | ~13/250 done at walltime kill; no auto-requeue |
| 3 | Completion state untrustworthy | `md_done.tsv` header-only (worker bug + ENOSPC append fail) |
| 4 | No stall/liveness detection | node1 retry-looped 3 d, found only by manual probe |
| 5 | Unbounded retry, no backoff | `retry_multidir_failures` spins forever on persistent failures |
| 6 | No node-health gating / auto-exclude | host-10-0-5-232 hardware fault needed manual `ExcNodeList` |

## Assumptions And Questions

- assumptions:
  - Keep the bash multidir orchestrator; **no rewrite to SLURM job array /
    Snakemake** unless a specific guard provably requires it (simplicity-first).
  - The `md_done` status-tracking fix is treated as IN-scope here (or as a hard
    dependency on its own contract) because the SLO's "tables match artifacts"
    clause cannot pass without it.
- open questions (must be resolved in the smoke stage, before the full panel):
  - **Effective throughput/window (critical, mirrors 5809):** the healthy node0
    completed only ~8 production trajectories in 3 days — far below a GPU-bound
    ~30/node/window. Until the idle/stall cause is removed and throughput
    measured on the smoke, the **number of 3-day windows for the 250-panel and
    thus the GPU budget are unknown.**
  - mergerfs handling: global `mfs` create-policy change vs per-run OUT_BASE
    pinning to an empty branch (kfs1/3/4, 15T) — prefer pin (lower blast radius).
- confirm-at-approval (left IN by omission, not explicit choice):
  node auto-exclusion (#6) and the `md_done` fix (#3) — confirm both belong here
  vs deferred.

## Constraints

- allowed change scope (the guards):
  1. branch-aware write placement (pin OUT_BASE to a low-usage branch and/or set
     mergerfs policy) + **pre-flight disk check** (per-branch free space) that
     refuses to launch if the target branch is near-full;
  2. **pre-flight node-health check** + node auto-exclusion;
  3. **bounded retry with backoff** (no infinite loop); distinguish transient vs
     persistent (e.g. ENOSPC) failure and abort-with-alert on persistent;
  4. **stall/liveness watchdog** (per-wave progress heartbeat) + auto-requeue;
  5. **walltime-aware checkpoint-resume** — idempotent skip of completed
     trajectories so a relaunch continues rather than restarts;
  6. **completion-state accuracy** (`md_done`/`mmpbsa_done`/`ready`/`failed`
     reflect on-disk artifacts) + an audit script.
- forbidden change scope:
  - No rewrite to SLURM array / Snakemake (hardening only).
  - No change to MD physics (mdp, `nsteps`, dt, forcefield) or pose generation.
  - No deletion/move of any data (esp. other users', e.g. `/mnt/data/users/kim/`).
  - No mergerfs global rebalancing of existing data.
- external constraints: SLURM per-job walltime 3-00:00; `/mnt/data/users/ubuntu`
  writes need `sudo -u ubuntu`; mergerfs policy change is infra state — record
  the original before any change.

## Non-Goals

- VAV1 per-residue decomp / DC50 correlation science analysis — pipeline
  *consumer*, separate track (note: only ~23 RunA exist; decomp n is capped
  there regardless of this work).
- Re-running the AB 76-ready set for decomp (the subsumed rerun contract).
- mergerfs global data rebalancing; MD physics changes.

## Done When (SLO — runnable acceptance gate)

- **Smoke (≥16 attempts):** each of the 6 guards demonstrably fires/recovers
  under injected fault — fill a target branch (ENOSPC), drain/kill a node
  mid-wave, and force a per-wave stall; each is detected, contained
  (bounded-retry/abort or requeue), and logged. No silent spin.
- **Full panel (125 × RunA+RunB = 250) hands-off run:**
  - **0 manual interventions** during the run;
  - **0 undetected stalls** (watchdog catches any progress gap > threshold);
  - **≥90% of preparable attempts** reach `mmpbsa_done`;
  - **completion tables match on-disk artifacts** — audit script reports
    **0 mismatches** across `md_done`/`mmpbsa_done`/`ready`/`failed`;
  - **no run-ending ENOSPC** in `.err`.
- verify:
  - `bash <repo>/scripts/.../audit_completion_state.sh <OUT_BASE>` → `mismatches=0`
  - `grep -c 'No space left on device' <OUT_BASE-or-logs>/*.err` → `0`
  - completion rate: `ready+mmpbsa_done / preparable ≥ 0.90`
  - intervention log empty for the panel run.

## Implementation Steps (high-level; decompose in /write-plan)

1. Capture mergerfs config + per-branch free space; instrument a smoke to
   **measure throughput/window** (resolves the budget open question).
   verify: snapshot file + ns/day-and-completions/window report.
2. Branch-aware placement + pre-flight disk check.  verify: launch refused on near-full target; writes land off kfs5/6.
3. Pre-flight node-health + auto-exclude.  verify: faulty node skipped automatically.
4. Bounded retry + backoff + persistent-failure abort/alert.  verify: injected ENOSPC aborts-with-alert, not infinite loop.
5. Stall watchdog + auto-requeue.  verify: forced stall detected & requeued.
6. Walltime-aware checkpoint-resume (idempotent skip-completed).  verify: relaunch continues, no recompute of finished trajectories.
7. Completion-state accuracy + audit script.  verify: tables match artifacts (mismatches=0).
8. Smoke acceptance (all guards fire) → full-panel acceptance (SLO met).

## Change Discipline

- simplest adequate approach: pre-flight + watchdog + checkpoint-resume on top
  of the existing orchestrator; pin OUT_BASE (avoid global policy change if possible).
- new abstractions introduced: a watchdog + an audit script (minimal).
- unrelated code touched: none expected.
- request-to-diff trace: 5809 ENOSPC + silent 3-day waste → hands-off SLO.

## Verification

- task-specific: the Done When verify commands.
- manual: `df -h | grep kfs` before/after; intervention log review.

## Risks

- regression risk: global mfs policy change affects other users → prefer pin;
  revert on rollback.
- integration risk: guard interactions (watchdog vs bounded-retry vs resume)
  could double-requeue — needs the smoke to shake out.
- budget risk: throughput unknown → 250-panel window count/GPU-hours uncertain
  until smoke (explicit open question, gated before the full run).

## Rollback

- revert strategy: `git revert` the orchestrator/script/config changes; revert
  mergerfs create policy to the recorded original; `scancel` benchmark jobs.
- containment strategy: benchmark runs in their own timestamped OUT_BASE
  (isolated, deletable); no in-place mutation of prior runs; kfs5/6 untouched.

## Resource budget

- Smoke: ~1 short window, ≥16 attempts, 2 nodes (or fewer).
- Full-panel acceptance: ~N × (2-node A100, 3-day) windows; **N projected from
  the smoke throughput measurement** (open question — confirm before launch).
- Exclude host-10-0-5-232 (hardware fault).

## Progress Log

- 2026-06-01: contract drafted from /brainstorm. Goal re-framed from the narrow
  "fix disk + rerun 76" to a hands-off SLO-gated hardening of the orchestrator,
  using the 5809 ENOSPC post-mortem (6 failure modes) as the evidence base.
