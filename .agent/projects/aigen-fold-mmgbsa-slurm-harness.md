# MMGBSA And SLURM Harness

Project path: `/mnt/data/users/ubuntu/workspace/FKSFold-Boltz_Advancement_shared`
Related local repo: `/home/ubuntu/FKSFold-Boltz_Advancement`

## Purpose

This harness governs shared-workspace MMGBSA production, staged SLURM chains,
F105 custom runs, normtest143 RunA/RunB runs, and DDG merge/reporting.

## Current Active Work

Recent activity includes:

- F105 10ns retry:
  - `outputs/custom_f105_mmgbsa10ns_20260511_1729`
  - final DDG tables generated on 2026-05-18
- normtest143 RunA:
  - `outputs/mmgbsa_normtest143_seed777_stage1_runa_fastmin_v3_chunks_20260508_164435`
  - `md_done.tsv`, `mmpbsa_done.tsv`, `mmgbsa_ddg_components.tsv`
- normtest143 RunB:
  - `outputs/mmgbsa_normtest143_seed777_stage1_runb_from_runa55_20260518_0945`
  - staged chain submitted as Stage 1 through Stage 4 in Cursor transcript
- Original backup import workstream:
  - Cursor plan `original-backup-import_05f9a8a6.plan.md`
  - selective port of `shared_workflow/scripts`, MDP, config, Slurm operations,
    and PBC audit from an original backup. Diff-first, no full overwrite.
  - changes here flow through the same Stage 1 prepare → parameterization →
    equilibration gates as RunB; do not commit ported files until the diff is
    explicitly approved.

## Safety Rules

- Treat `/mnt/data` outputs as production-like artifacts.
- Never delete or overwrite output directories without explicit approval.
- Do not submit SLURM jobs unless the user asks for execution or approves the
  exact resource request.
- Always separate prepare, MD, postprocess, and merge stages in status reports.
- Use manifests instead of implicit directory scans when selecting compounds.

## Standard Stages

Stage 1 prepare:

- builds run inputs
- writes `ready_for_mmpbsa_prod.tsv`
- writes `failed_stage.tsv`
- may fail fast on parameterization or equilibration
- observed normtest default: 2 nodes, 8 A100 per node, high QoS, 3 day limit

Stage 2 MD:

- consumes ready manifest
- produces `md_done.tsv`
- writes trajectory artifacts such as `mmpbsa_prod.xtc`
- consumes `DIRS_PER_GPU`, `WAVE_SIZE`, `NODES_FOR_MULTIDIR`,
  `GPUS_PER_NODE`, and `MDRUN_NOAPPEND`

Stage 3 postprocess:

- runs MMPBSA over sampled frames
- produces `mmpbsa_done.tsv`
- writes `dg_result.json` and `FINAL_RESULTS_MMPBSA.dat`
- defaults to `SAMPLES=50`, `POST_PARALLEL=4`, `POST_THREADS=8`

Stage 4 merge:

- creates component and DDG TSVs
- joins RunA/RunB pairs
- default outputs are `mmgbsa_components.tsv` and
  `mmgbsa_ddg_components.tsv`

## Stage-2 MD STANDARD SETTINGS — FIXED (measured 2026-06-01, job 5890)

**Always run Stage-2 MD with `DIRS_PER_GPU=2` (2 trajectories per GPU).** This is
the throughput-optimal packing, measured directly on A100-80GB; do not change it
without re-measuring.

Aggregate throughput vs packing (per GPU, ~100k-atom systems):

| DIRS_PER_GPU | per-traj ns/day | aggregate ns/day/GPU |
|---|---|---|
| **2** | RunA 26 / RunB 39 | **~66  ← optimal** |
| 4 | 14.1 | ~57 |
| 6 | 5.9 | ~35 |
| 8 | 4.7 | ~38 |

WHY (counter-intuitive): packing MORE trajs/GPU raises `nvidia-smi` GPU **utilization**
(2/GPU≈35% → 4/GPU≈62%) but **lowers aggregate throughput** — the extra util is
contention, not work. So **do NOT target ">=70% GPU util"**; it trades throughput
away. (The 5809 slowdown of ~5 ns/day/traj matches the measured 6/GPU=5.9 — it was
over-packed at ~4.75 dirs/GPU.) GPU memory is a non-constraint (~500 MiB/traj).

Standard hardened invocation (the shared orchestrator already carries the 3 fixes
below; SLURM runs the shared copy):

```
sudo -u ubuntu OUT_BASE=<staged> EXPECTED_MMPBSA_NSTEPS=10000000 EXPECTED_MMPBSA_DT=0.002 \
  NODES_FOR_MULTIDIR=2 DIRS_PER_GPU=2 MD_STALL_TIMEOUT_S=1800 MDRUN_NOAPPEND=0 \
  sbatch --nodes=2 --ntasks=2 --ntasks-per-node=1 --gres=gpu:a100:8 --time=3-00:00:00 \
  --exclude=host-10-0-3-160,host-10-0-5-232,host-10-0-5-73 \
  <shared>/scripts/mmgbsa_16gpu_multidir/slurm_normtest143_stage2_md_multidir_seed777.sh
```

- `EXPECTED_MMPBSA_NSTEPS=10000000` = 20 ns production (use `500000`=1ns only for smokes).
- `--exclude`: host-10-0-3-160 (GPUs #6,#7 non-functional → gputasks→dead GPU → MPI_ABORT),
  host-10-0-5-232 (seeded known-bad), host-10-0-5-73 (GPU-0 had a leaked ~50GB process).
  Always sanity-check `nvidia-smi`/`sinfo` for dead or occupied GPUs before submitting.
- Hardening already in the orchestrator/guards (2026-06-01): explicit mdrun output flags +
  `MDRUN_NOAPPEND` conditional + heartbeat `find -L` (8e28d9d); guards sourced via
  `SCRIPT_PATH` for the SLURM spool (de4b5f8); skew-robust `stall_watchdog` keying off
  mtime ADVANCEMENT — the kfs* NFS branches run ~8.8h behind the GPU nodes (017b62c).
- Resume is automatic: `is_traj_complete` skips finished trajectories; rerun the same
  OUT_BASE to continue after walltime/interruption.

### MD length + Stage-3 sampling — FIXED (measured 2026-06-01, jobs 5966/5973/6070)

**MD length 20 ns is CORRECT — but sample the FULL trajectory, NOT just the first 5 ns.**

The MMGBSA ΔG was measured over cumulative windows on 2 stable RunA trajs (gmx_MMPBSA,
50→ frames; full convergence curve):

| window | VAV1_320 ΔG | VAV1_291 ΔG |
|---|---|---|
| 5 ns  | −41.6 | −39.8 |
| 10 ns | −39.0 | −41.9 |
| 15 ns | −38.8 | −42.3 |
| 20 ns | −38.1 | (~plateau) |

- **ΔG converges only at ~10–15 ns** (both plateau there within the ~1.5 kcal/mol dG_std).
- **The first-5 ns estimate is NOT converged — off by 2–4 kcal/mol, and the error direction is
  SYSTEM-DEPENDENT** (320 over-binds at 5 ns, 291 under-binds). That corrupts ΔΔG ranking.
- ⇒ 20 ns MD is appropriate (at/past the plateau, with margin), NOT overkill. The real defect
  was the SAMPLING: `run_mmpbsa.py::patch_gb_in` sets `endframe=samples` with gb.in defaults
  `startframe=1, interval=1`, so `--samples 50` reads frames 1–50 = the first 5 ns and DISCARDS
  the converged 10–20 ns region.

**FIX (the MD-length ↔ sampling coupling):** sample N frames SPREAD over the whole trajectory:
`startframe=1, endframe=total_frames, interval=floor(total_frames/n_samples)`. For 20 ns @ 100 ps
= 200 frames, 50 samples → `interval=4` (frames 1,5,…,200). Better still, drop a short burn-in
(start ~2 ns in). This is exactly what the single-source coupling
(`scripts/mmgbsa_16gpu_multidir/mmgbsa_coupling.py`, contract mmgbsa-couple-mdlen-sampling) must
encode: default config window=(0,20)ns, n_samples=50 (NOT the placeholder (0,5)/interval-1).
Wiring it into `patch_gb_in` (plan B4) + cp-sync is DEFERRED until aigen-fold-core's run_mmpbsa.py
dirty-tree WIP is committed (see .agent/scratch/mmgbsa_stable/coupling_phase_status.md).

## Required Preflight

Before preparing or submitting:

```bash
find /mnt/data/users/ubuntu/workspace/FKSFold-Boltz_Advancement_shared/scripts/mmgbsa_16gpu_multidir -maxdepth 1 -type f -print
bash -n scripts/mmgbsa_16gpu_multidir/*.sh
python scripts/mmgbsa_16gpu_multidir/merge_normtest143_stage4_ddg.py --help
```

Before using an output directory:

```bash
find <OUT_BASE> -maxdepth 2 -type f -name '*.tsv' -print
```

For active SLURM jobs:

```bash
squeue -j <jobids> -o '%.10i %.9q %.24j %.8u %.2t %.12M %.10l %.6D %.12b %.30R'
sacct -j <jobids> --format=JobID,JobName%24,State,ExitCode,Elapsed,AllocTRES%60 -P
```

## Status Report Template

Every MMGBSA status report should include:

- `OUT_BASE`
- input manifest path and row count
- stage status by job id
- ready, failed, MD done, MMPBSA done row counts
- RunA/RunB pair count for DDG
- failed compounds and failure reason class
- exact output TSV paths

## Resource Request Gate

Before submitting jobs, state:

- partition or QoS
- node count
- GPU count and GPU type if known
- CPU and memory request
- expected wall time
- dependency chain
- stop condition if Stage 1 ready count is too low

## Merge Gate

Only run Stage 4 merge when:

- both RunA and RunB references exist for the intended compounds
- `mmpbsa_done.tsv` exists for completed runs
- component files are not being actively written

After merge, inspect:

- components TSV row count
- DDG TSV row count
- strongest positive and negative DDG cases
- missing RunA/RunB pairs

## Knowledge To Preserve

Add a note to the task contract whenever:

- a parameterization failure is recurrent
- an MDP file differs from default 20ns or 10ns assumptions
- a run uses `SAMPLES`, `DIRS_PER_GPU`, `WAVE_SIZE`, or `MDRUN_NOAPPEND`
- a result relies on Docker or a non-host dependency
