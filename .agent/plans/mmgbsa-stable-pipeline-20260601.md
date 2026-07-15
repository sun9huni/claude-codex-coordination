---
contract: .agent/contracts/mmgbsa-stable-pipeline-20260601.md
slice: mmgbsa
status: in-progress
total_tasks: 23
estimated_total_min: 100
---

# Plan — mmgbsa-stable-pipeline (hands-off large-panel MMGBSA hardening)

Strategy: factor the six failure-mode guards into a single sourced
library `mmgbsa_guards.sh` so each is unit-testable via fault injection
**without GPU** (red test → impl). Then wire guards into the orchestrator
and worker, prove them end-to-end with a stubbed-`gmx` smoke harness
(still no GPU), and only then spend GPU on the SLURM smoke + full-panel
acceptance (both approval gates).

**Dev location** (local, untracked git mirror):
`/home/ubuntu/FKSFold-Boltz_Advancement/scripts/mmgbsa_16gpu_multidir/`
(repo-relative paths below). SLURM executes the **shared** copy
(`/mnt/data/users/ubuntu/workspace/FKSFold-Boltz_Advancement_shared/scripts/mmgbsa_16gpu_multidir/`),
so Task 21 cp-syncs local→shared (`sudo -u ubuntu`). Rollback = restore
`.bak` (these files are not git-tracked) + `scancel` for SLURM tasks.

estimated_total_min counts **agent implementation time only**; Tasks 21–22
add multi-day external SLURM wall-clock and are gated on user approval.

---

## Phase 1 — Setup

## Task 1: Snapshot mergerfs config + per-branch free space
- **Status**: done
- **Prereq tasks**: none
- **Files touched**: `.agent/scratch/mmgbsa_stable/mergerfs_baseline_20260601.txt` (new)
- **Change shape**: Capture the rollback baseline: `cat /proc/mounts | grep merger`, the mergerfs create-policy (`getfattr -n user.mergerfs.create_policy /mnt/data` or mount opts), and `df -h /mnt/kfs1..7` per-branch usage, into one snapshot file. Read-only of the system; only writes the scratch file.
- **Verification**: `grep -c kfs .agent/scratch/mmgbsa_stable/mergerfs_baseline_20260601.txt` → ≥7 (one line per branch) and the create-policy line present.
- **Estimated time**: 3 min
- **Rollback (if this task only)**: `rm .agent/scratch/mmgbsa_stable/mergerfs_baseline_20260601.txt`

## Task 2: Create guards lib skeleton + test runner
- **Status**: done
- **Prereq tasks**: none
- **Files touched**: `scripts/mmgbsa_16gpu_multidir/mmgbsa_guards.sh` (new), `scripts/mmgbsa_16gpu_multidir/tests/run_guards_tests.sh` (new)
- **Change shape**: `mmgbsa_guards.sh` = empty sourceable lib with a header + `set -uo pipefail` guard and a `MMGBSA_GUARDS_VERSION` marker. `run_guards_tests.sh` = a tiny harness that sources each `tests/test_guard_*.sh` (namespaced glob — deliberately excludes the pre-existing `tests/test_worker_status_classify.sh`, which is a non-sourceable CLI test) and prints `PASS/FAIL` counts, exit 1 if any FAIL.
- **Verification**: `bash scripts/mmgbsa_16gpu_multidir/tests/run_guards_tests.sh` → exits 0, prints `tests=0 pass=0 fail=0`.
- **Estimated time**: 4 min
- **Rollback (if this task only)**: `rm scripts/mmgbsa_16gpu_multidir/mmgbsa_guards.sh scripts/mmgbsa_16gpu_multidir/tests/run_guards_tests.sh`

---

## Phase 2 — Guards (red test → impl, one guard at a time)

## Task 3: RED — preflight disk/branch check test
- **Status**: done
- **Prereq tasks**: 2
- **Files touched**: `scripts/mmgbsa_16gpu_multidir/tests/test_guard_preflight_disk.sh` (new)
- **Change shape**: Test asserts `preflight_disk_check <branch_dir> <min_free_gb>` (a) returns nonzero + emits `BRANCH_NEAR_FULL` when a fake branch dir reports < min_free, and (b) `resolve_out_base_branch` picks the branch with most free space from a fake `df` stub. Uses a stubbed `df`/fake dirs, no real FS pressure.
- **Verification**: `bash .../tests/test_guard_preflight_disk.sh` → **FAIL** with `preflight_disk_check: command not found` (red: function absent).
- **Estimated time**: 3 min
- **Rollback (if this task only)**: `rm .../tests/test_guard_preflight_disk.sh`

## Task 4: GREEN — implement preflight_disk_check + resolve_out_base_branch
- **Status**: done
- **Prereq tasks**: 3
- **Files touched**: `scripts/mmgbsa_16gpu_multidir/mmgbsa_guards.sh`
- **Change shape**: Add `preflight_disk_check` (refuse launch if target branch free < threshold, default 500 GB) and `resolve_out_base_branch` (pick lowest-usage mergerfs branch from `df`, pin OUT_BASE there — addresses kfs6-99% ENOSPC). No global mergerfs policy change.
- **Verification**: `bash .../tests/run_guards_tests.sh` → `test_guard_preflight_disk` PASS.
- **Estimated time**: 5 min
- **Rollback (if this task only)**: restore `mmgbsa_guards.sh.bak`

## Task 5: RED — node-health preflight test
- **Status**: done
- **Prereq tasks**: 2
- **Files touched**: `scripts/mmgbsa_16gpu_multidir/tests/test_guard_preflight_node.sh` (new)
- **Change shape**: Test asserts `preflight_node_health <nodelist>` returns an exclude-list containing a node whose (stubbed) GPU/health probe fails, and passes healthy nodes through. Stubs the probe command.
- **Verification**: `bash .../tests/test_guard_preflight_node.sh` → **FAIL** (`preflight_node_health` undefined).
- **Estimated time**: 3 min
- **Rollback (if this task only)**: `rm .../tests/test_guard_preflight_node.sh`

## Task 6: GREEN — implement preflight_node_health + auto-exclude
- **Status**: done
- **Prereq tasks**: 5
- **Files touched**: `scripts/mmgbsa_16gpu_multidir/mmgbsa_guards.sh`
- **Change shape**: Add `preflight_node_health` that probes each node (GPU visible + writable scratch) and returns a `--exclude` list; seed the known-bad `host-10-0-5-232`. Pure function over a probe command (injectable for tests).
- **Verification**: `bash .../tests/run_guards_tests.sh` → `test_guard_preflight_node` PASS.
- **Estimated time**: 5 min
- **Rollback (if this task only)**: restore `mmgbsa_guards.sh.bak`

## Task 7: RED — bounded-retry + failure-classification test
- **Status**: done
- **Prereq tasks**: 2
- **Files touched**: `scripts/mmgbsa_16gpu_multidir/tests/test_guard_retry.sh` (new)
- **Change shape**: Test asserts `classify_failure <logfile>` returns `persistent` for an `No space left on device` log and `transient` otherwise; and `bounded_retry <max> <cmd>` stops after `max` attempts with backoff and **aborts immediately** on a persistent classification (no infinite loop). Uses fake logs + a flaky stub command.
- **Verification**: `bash .../tests/test_guard_retry.sh` → **FAIL** (`classify_failure`/`bounded_retry` undefined).
- **Estimated time**: 3 min
- **Rollback (if this task only)**: `rm .../tests/test_guard_retry.sh`

## Task 8: GREEN — implement classify_failure + bounded_retry
- **Status**: done
- **Prereq tasks**: 7
- **Files touched**: `scripts/mmgbsa_16gpu_multidir/mmgbsa_guards.sh`
- **Change shape**: Add `classify_failure` (regex ENOSPC/quota → persistent) and `bounded_retry` (max attempts default 3, exponential backoff, abort+alert on persistent). Replaces the spirit of the current unbounded `retry_multidir_failures` (wired in Task 17).
- **Verification**: `bash .../tests/run_guards_tests.sh` → `test_guard_retry` PASS.
- **Estimated time**: 5 min
- **Rollback (if this task only)**: restore `mmgbsa_guards.sh.bak`

## Task 9: RED — stall-watchdog test
- **Status**: done
- **Prereq tasks**: 2
- **Files touched**: `scripts/mmgbsa_16gpu_multidir/tests/test_guard_watchdog.sh` (new)
- **Change shape**: Test asserts `stall_watchdog <progress_file> <timeout_s> <on_stall_cmd>` invokes `on_stall_cmd` when the progress file's mtime is older than timeout, and does NOT fire while it keeps updating. Uses a temp file + short timeout.
- **Verification**: `bash .../tests/test_guard_watchdog.sh` → **FAIL** (`stall_watchdog` undefined).
- **Estimated time**: 3 min
- **Rollback (if this task only)**: `rm .../tests/test_guard_watchdog.sh`

## Task 10: GREEN — implement stall_watchdog + requeue signal
- **Status**: done
- **Prereq tasks**: 9
- **Files touched**: `scripts/mmgbsa_16gpu_multidir/mmgbsa_guards.sh`
- **Change shape**: Add `stall_watchdog` (background-able loop watching a wave progress heartbeat; on timeout emits a `STALL_DETECTED` line + invokes a requeue callback). Default timeout = 2× single-traj wall (~40 h is too long for a wave; use per-wave heartbeat of mdrun step writes, e.g. 30 min no-progress).
- **Verification**: `bash .../tests/run_guards_tests.sh` → `test_guard_watchdog` PASS.
- **Estimated time**: 5 min
- **Rollback (if this task only)**: restore `mmgbsa_guards.sh.bak`

## Task 11: RED — checkpoint-resume skip test
- **Status**: done
- **Prereq tasks**: 2
- **Files touched**: `scripts/mmgbsa_16gpu_multidir/tests/test_guard_resume.sh` (new)
- **Change shape**: Test asserts `is_traj_complete <mmpbsa_dir>` returns true for a dir whose `mmpbsa_prod.log` contains `Finished mdrun` (or full nframes) and false for a truncated one; `resume_filter <dirlist>` drops the complete ones. Uses synthetic dirs/logs.
- **Verification**: `bash .../tests/test_guard_resume.sh` → **FAIL** (`is_traj_complete` undefined).
- **Estimated time**: 3 min
- **Rollback (if this task only)**: `rm .../tests/test_guard_resume.sh`

## Task 12: GREEN — implement is_traj_complete + resume_filter
- **Status**: done
- **Prereq tasks**: 11
- **Files touched**: `scripts/mmgbsa_16gpu_multidir/mmgbsa_guards.sh`
- **Change shape**: Add `is_traj_complete` (artifact-based completion: `Finished mdrun` in log AND expected nframes in xtc) and `resume_filter` (idempotent skip). Enables relaunch-continues across the 3-day walltime boundary.
- **Verification**: `bash .../tests/run_guards_tests.sh` → `test_guard_resume` PASS.
- **Estimated time**: 5 min
- **Rollback (if this task only)**: restore `mmgbsa_guards.sh.bak`

## Task 13: RED — completion-state audit test
- **Status**: done
- **Prereq tasks**: 2
- **Files touched**: `scripts/mmgbsa_16gpu_multidir/tests/test_guard_audit.sh` (new)
- **Change shape**: Test builds a synthetic OUT_BASE (some dirs with complete artifacts, some without) plus matching/mismatching `md_done.tsv`/`mmpbsa_done.tsv`/`ready_for_mmpbsa_prod.tsv`/`failed_stage.tsv`, and asserts `audit_completion_state.sh` reports `mismatches=0` for the consistent layout and `mismatches>0` (naming the offending rows) for the inconsistent one.
- **Verification**: `bash .../tests/test_guard_audit.sh` → **FAIL** (`audit_completion_state.sh` not found).
- **Estimated time**: 4 min
- **Rollback (if this task only)**: `rm .../tests/test_guard_audit.sh`

## Task 14: GREEN — implement audit_completion_state.sh
- **Status**: done
- **Prereq tasks**: 13
- **Files touched**: `scripts/mmgbsa_16gpu_multidir/audit_completion_state.sh` (new)
- **Change shape**: Standalone auditor: for each compound/run dir under OUT_BASE, derive true state from artifacts (`is_traj_complete` from the lib) and compare against the four status tables; print per-row mismatches and a final `mismatches=N`. This is the SLO's "tables match artifacts" check.
- **Verification**: `bash .../tests/run_guards_tests.sh` → `test_guard_audit` PASS.
- **Estimated time**: 5 min
- **Rollback (if this task only)**: `rm scripts/mmgbsa_16gpu_multidir/audit_completion_state.sh`

## Task 15: GREEN — make md_done finalization robust (orchestrator EXIT-trap)
- **Status**: done
- **Prereq tasks**: 12, 14
- **Files touched**: `scripts/mmgbsa_16gpu_multidir/slurm_normtest143_stage2_md_multidir_seed777.sh`
- **Change shape**: **CORRECTED diagnosis (2026-06-01, during execution):** `md_done` is NOT a worker concern (worker has zero `md_done` refs). The **orchestrator** already appends `done` rows at line ~426 — but inside the per-wave eval loop that runs AFTER `retry_multidir_failures` (line ~402). In 5809 that retry looped forever on node1 ENOSPC, so the eval loop was never reached and `md_done` (even per-node `md_done_node*.tsv`) stayed header-only, while `ready` (pre-MD) and `failed` (during-retry) populated. Task 17 (bounded_retry) makes the loop terminate so the eval runs; THIS task adds interruption-robustness: add `finalize_md_done()` that scans OUT_BASE for complete-on-disk trajectories (`is_traj_complete`) absent from `MD_DONE_LIST` and appends their rows (reusing the audit's reconciliation logic), installed via `trap finalize_md_done EXIT` so a walltime SIGTERM / early exit still leaves `md_done` matching on-disk reality. `source mmgbsa_guards.sh` for `is_traj_complete`. `.bak` checkpoint first; append-only / minimal-edit to the orchestrator (do not disturb the Task 16–19 wiring regions).
- **Verification**: drive `finalize_md_done` over a synthetic OUT_BASE containing a complete run dir absent from a header-only `md_done.tsv` → `md_done.tsv` gains the row → `bash audit_completion_state.sh <ob>` → `mismatches=0`. Plus `bash -n` on the orchestrator.
- **Estimated time**: 5 min
- **Rollback (if this task only)**: restore `...stage2_md_multidir_seed777.sh.bak`

---

## Phase 3 — Glue (wire guards into orchestrator)

## Task 16: Wire preflight (disk + node health) at orchestrator MASTER start
- **Status**: done
- **Prereq tasks**: 4, 6
- **Files touched**: `scripts/mmgbsa_16gpu_multidir/slurm_normtest143_stage2_md_multidir_seed777.sh`
- **Change shape**: **RE-SCOPED (2026-06-01):** OUT_BASE is PRE-STAGED (Stage-1 input, line 18), so `resolve_out_base_branch` (pick/relocate a branch) does NOT apply here — it belongs to the staging stage (out of this file's scope). Guards lib already sourced (Task 15). Add a preflight block in the MASTER branch (`STAGE2_NODE_WORKER != 1`) BEFORE the node-split/`srun` launch (~line 131): (a) `preflight_disk_check "$OUT_BASE" "${MIN_FREE_GB:-200}"` → on failure it already prints BRANCH_NEAR_FULL; `exit 2` (refuse to launch into a near-full branch — the 5809 guard); (b) `preflight_node_health $(scontrol show hostnames "${SLURM_JOB_NODELIST:-}" 2>/dev/null)` → log the exclude list (best-effort; do NOT hard-fail if scontrol/nodelist absent). Add a `PREFLIGHT_ONLY=1` early `exit 0` right after the preflight block (before the READY_LIST/gmx checks) for testing. `.bak` first; do not disturb finalize/trap or node-launch logic.
- **Verification**: `bash -n`; AND with a fake `df` earlier on PATH reporting a near-full OUT_BASE branch: `OUT_BASE=<tmp> PREFLIGHT_ONLY=1 PATH=<stubdir>:$PATH bash <orch>` → prints `BRANCH_NEAR_FULL`, exits nonzero; with a healthy stub df → prints a preflight-OK line, exits 0.
- **Estimated time**: 6 min
- **Rollback (if this task only)**: restore `...stage2_md_multidir_seed777.sh.bak`

## Task 17: Short-circuit persistent (ENOSPC) failures in retry_multidir_failures
- **Status**: done
- **Prereq tasks**: 8, 16
- **Files touched**: `scripts/mmgbsa_16gpu_multidir/slurm_normtest143_stage2_md_multidir_seed777.sh`
- **Change shape**: **RE-SCOPED (2026-06-01):** `retry_multidir_failures` is already a single-pass chunk loop (NOT infinite) — but on ENOSPC it pointlessly grinds every chunk + single-fallback. Integrate `classify_failure`: after a failed `run_multidir_group` attempt inside the retry loop, classify that attempt's `.mdrun.log` (the function writes `$wave_dir/${label}.mdrun.log`); if `persistent` (ENOSPC/quota), emit a `PERSISTENT_FAILURE` line and `return 1` from `retry_multidir_failures` IMMEDIATELY (abort the remaining chunks/single-fallbacks). Transient path unchanged. `.bak` first; surgical edit to `retry_multidir_failures` only.
- **Verification**: `bash -n`; AND extract `retry_multidir_failures` (+ `classify_failure` from guards) into a harness with a stub `run_multidir_group` that writes an ENOSPC `.mdrun.log` and returns nonzero → assert the loop aborts after the FIRST chunk with `PERSISTENT_FAILURE` (does not process all unfinished).
- **Estimated time**: 6 min
- **Rollback (if this task only)**: restore `.bak`

## Task 18: Stall watchdog around run_multidir_group (kill-on-stall)
- **Status**: done
- **Prereq tasks**: 10, 16
- **Files touched**: `scripts/mmgbsa_16gpu_multidir/slurm_normtest143_stage2_md_multidir_seed777.sh`
- **Change shape**: **RE-SCOPED (2026-06-01):** there is NO per-wave heartbeat file; the watchdog's progress target is the wave mdrun log `$wave_dir/${label}.mdrun.log` written by `run_multidir_group` (line ~240). That mdrun currently runs SYNCHRONOUSLY (blocks to walltime if a system hangs — the core stall mode). Modify `run_multidir_group` to run the `mpirun` in the BACKGROUND (capture PID), launch `stall_watchdog "$mdrun_log" "${MD_STALL_TIMEOUT_S:-1800}" "${MD_STALL_POLL_S:-60}" <max_polls> _kill_mdrun "$pid"` where `_kill_mdrun` kills the mdrun process (group); `wait` the mdrun PID and capture its rc. On STALL_DETECTED the mdrun is killed so the wave proceeds to retry/eval/finalize instead of hanging to walltime. The watchdog must stop once mdrun exits (bound max_polls by walltime, or kill the watchdog after wait). `.bak` first.
- **Verification**: `bash -n`; AND extract `run_multidir_group` into a harness with a stub `mpirun`/`gmx_mpi` that writes the log then sleeps without further writes → assert `stall_watchdog` emits STALL_DETECTED and `_kill_mdrun` fires (sentinel) within bounded polls, and the function returns. (Use tiny timeout/poll for the test.)
- **Estimated time**: 7 min
- **Rollback (if this task only)**: restore `.bak`

## Task 19: Skip completed trajectories at wave assembly (resume)
- **Status**: done
- **Prereq tasks**: 12, 16
- **Files touched**: `scripts/mmgbsa_16gpu_multidir/slurm_normtest143_stage2_md_multidir_seed777.sh`
- **Change shape**: **RE-SCOPED (2026-06-01):** in the wave-assembly loop (where ready entries `compound|run_type|run_dir|mmpbsa_dir|tpr` are gathered into a wave and symlinked into `$wave_dir`), skip any entry where `is_traj_complete "$run_dir"` is already true (is_traj_complete checks `$run_dir/mmpbsa/mmpbsa_prod.log` — matches the orchestrator's layout). This makes a post-walltime relaunch continue rather than recompute finished trajectories. Log the skipped count (`resume: skipped N already-complete`). `.bak` first; surgical edit to the assembly loop only.
- **Verification**: `bash -n`; AND extract the assembly filter logic into a harness with a mix of complete/incomplete synthetic run dirs → only incomplete are scheduled (count matches), skipped count logged.
- **Estimated time**: 5 min
- **Rollback (if this task only)**: restore `.bak`

---

## Phase 4 — Local acceptance (no GPU)

## Task 20: Fault-injection smoke harness (stubbed gmx)
- **Status**: done
- **Prereq tasks**: 17, 18, 19, 15
- **Files touched**: `scripts/mmgbsa_16gpu_multidir/tests/smoke_fault_injection.sh` (new)
- **Change shape**: Drive the orchestrator in dry-run with a stub `gmx`/`mdrun` on PATH that can simulate: normal completion, ENOSPC, a stall, and a bad node. Assert each of the 6 guards fires/recovers and the audit reports `mismatches=0`. This is the local proxy for the SLURM smoke (proves guard logic without GPU).
- **Verification**: `bash .../tests/smoke_fault_injection.sh` → prints `guards: 6/6 PASS` and exits 0.
- **Estimated time**: 6 min
- **Rollback (if this task only)**: `rm .../tests/smoke_fault_injection.sh`

---

## Phase 5 — SLURM acceptance (APPROVAL GATES)

## Task 21: cp-sync to shared + submit short SLURM smoke; validate + measure throughput
- **Status**: done (2026-06-01, job 5860 COMPLETED; result in .agent/scratch/mmgbsa_stable/smoke_throughput.txt)
- **Outcome**: 16/16 complete, audit mismatches=0, ENOSPC 0, stall 0, intervention 0. Throughput @2 trajs/GPU: RunA ~26.4 / RunB ~39.3 ns/day. The smoke surfaced + fixed 3 orchestrator regressions (commits 8e28d9d mdrun output flags / de4b5f8 spool guards-source / 017b62c skew-robust watchdog) and 1 infra hazard (node host-10-0-3-160 had 2 non-functional GPUs -> task-assign MPI_ABORT; smoke pinned to healthy host-10-0-5-73). Dead-GPU robustness flagged for Task 22.
- **Prereq tasks**: 20
- **DECIDED SMOKE PARAMS (2026-06-01, user):** MD length **~1 ns (EXPECTED_MMPBSA_NSTEPS=500000, ~1 h/traj)**; **16-compound throwaway subset**; **1 node / 8 A100**; **OUT_BASE on a healthy branch (kfs1/3/4, NOT kfs5/6)**.
- **Files touched**: shared copies under `/mnt/data/users/ubuntu/workspace/FKSFold-Boltz_Advancement_shared/scripts/mmgbsa_16gpu_multidir/` (sync, not new); a fresh smoke OUT_BASE on a healthy branch; `.agent/scratch/mmgbsa_stable/smoke_throughput.txt` (new)
- **Execution recipe**:
  1. **Stage inputs:** copy 16 ready compounds' equi'd run dirs from the AB OUT_BASE (`/mnt/data/users/ubuntu/mmgbsa_outputs/norm143_ab_seed16_stage1_20260527_182206/`, read-only source on kfs6) into a fresh smoke OUT_BASE on a healthy branch; build a `ready_for_mmpbsa_prod.tsv` with those 16 rows. (`sudo -u ubuntu`.)
  2. **cp-sync code:** `sudo -u ubuntu` copy the hardened local `mmgbsa_16gpu_multidir/` files (guards lib, audit, orchestrator) → shared, with `.bak` of each shared file first.
  3. **Submit:** `sudo -u ubuntu OUT_BASE=<smoke_ob> EXPECTED_MMPBSA_NSTEPS=500000 NODES_FOR_MULTIDIR=1 MD_STALL_TIMEOUT_S=900 sbatch --nodes=1 --time=06:00:00 <shared orchestrator>` (under active contract mmgbsa-stable-pipeline-20260601). Adjust nsteps via the smoke mdp / EXPECTED override.
- **Verification**: smoke job COMPLETED; `[preflight] OK` logged; resume/finalize lines present; `audit_completion_state.sh` on smoke OUT_BASE → `mismatches=0`; `grep -c 'No space left on device' <logs>` → 0; `smoke_throughput.txt` records completions/hour + ns/day (resolves the budget open question for Task 22).
- **Estimated time**: ~15 min agent (staging) + ~2-4 h external smoke wall-clock
- **Rollback (if this task only)**: `scancel` smoke job; restore shared `.bak`; delete smoke OUT_BASE

## Task 22: Project full-panel budget, confirm, submit 250-panel hands-off run; measure SLO
- **Status**: pending — DEFERRED to a fresh session (user choice 2026-06-01). Budget projected (below); needs explicit go.
- **Prereq tasks**: 21 (done), + dead-GPU robustness decision (below)
- **Files touched**: `.agent/scratch/mmgbsa_stable/panel250_slo_report.txt` (new)
- **VALIDATED CONFIG (user's "8 node × 8 dir" = 1 traj/GPU) — NO CODE CHANGE:** `NODES_FOR_MULTIDIR=8 DIRS_PER_GPU=1` (WAVE_SIZE=8, 8 dirs/wave = 1/GPU) + `sbatch --exclude=host-10-0-3-160,host-10-0-5-232`. Verified: job 5862 (8 dir/healthy node, no -gputasks) rc=0; 5863 (6 dir/dead node) rc=0 auto-assign used only functional GPUs; 5861 (8 dir/dead node) failed = oversubscription only. At DIRS_PER_GPU=1 on healthy (8 functional) nodes the current -gputasks i%8 maps onto real GPUs, so no code change is needed once dead-GPU nodes are excluded.
- **Budget:** 64 GPU (8 nodes) → 250/64 ≈ 4 waves; 1/GPU gives each traj a full A100 (~50–90 ns/day) → 20ns in ~5–10h, **FITS one 3-day window (no per-traj checkpoint-resume needed)**. Wall ~1.7 days; ~1700 GPU-hours. (Alt: fewer nodes = longer wall, same GPU-hr.)
- **OPEN for next session:** the master-split path (`NODES_FOR_MULTIDIR>1` sruns per-node workers + merges) was NOT exercised this session (smoke used =1). Either test the split on a tiny multi-node run first, OR submit N single-node jobs (=1 path validated by 5860) over ready-list slices and merge md_done. Optional deeper robustness (use degraded nodes): drop -gputasks + set N_GPUS=detected functional count (5863 mechanism).
- **Change shape**: confirm budget + dead-GPU approach with user; submit full-panel hands-off (checkpoint-resume across windows). Record SLO. **APPROVAL GATE: SLURM submission + budget confirmation.**
- **Verification**: `panel250_slo_report.txt` shows interventions=0, undetected-stalls=0, completion ≥90% of preparable, `audit_completion_state.sh` → `mismatches=0`, `grep -c 'No space left on device' .../*.err` → 0. **= contract Done When met.**
- **Estimated time**: 5 min agent + multi-day external SLURM wall-clock
- **Rollback (if this task only)**: `scancel` panel job; revert mergerfs policy to Task 1 baseline (if changed); panel OUT_BASE is isolated/deletable

---

## Phase 6 — Docs / handoff

## Task 23: Update slice status + runbook with SLO results
- **Status**: pending
- **Prereq tasks**: 22
- **Files touched**: `.agent/status/mmgbsa.md`, `.agent/projects/mmgbsa-harness.md` (runbook section)
- **Change shape**: Record the hardened pipeline (6 guards, audit script, resume), the measured throughput/budget, the 250-panel SLO outcome, and the now-trustworthy completion-table workflow. Then run `./scripts/handoff.sh claude mmgbsa` + `./scripts/status.sh index`.
- **Verification**: `.agent/status/mmgbsa.md` has no `<placeholder>`; `grep -l mmgbsa-stable-pipeline .agent/status/mmgbsa.md` matches; `./scripts/status.sh index` regenerates CURRENT.md without error.
- **Estimated time**: 5 min
- **Rollback (if this task only)**: `git checkout .agent/status/mmgbsa.md` (revert the status edit)
