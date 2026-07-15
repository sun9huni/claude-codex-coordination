---
contract: .agent/contracts/mmgbsa-e2e-validate-length-20260601.md
slice: mmgbsa
status: done
total_tasks: 8
estimated_total_min: 36
---

# Plan: MMGBSA end-to-end validation + MD-length standard

Goal (from contract): on the 14 already-completed 20 ns trajectories (ZERO new MD),
(a) run Stage 3 (MMGBSA) → Stage 4 (merge) end-to-end and produce a sane ΔΔG/ΔG, and
(b) determine + FIX the MD-length standard from convergence. Two SLURM gates (Tasks 3, 6).
Work in a SEPARATE fresh OUT_BASE (AB trajs are read-only source) per the rollback decision.

## Task 1: Inspect Stage 3/4 tooling + pairing + window mechanism

- **Status**: done (2026-06-01; .agent/scratch/mmgbsa_stable/e2e_inspect.md — window=endframe(first-N-frames), pairs=0, gmx_MMPBSA present; KEY: current sampling uses only first 5ns of 20ns)
- **Prereq tasks**: none
- **Files touched**: `.agent/scratch/mmgbsa_stable/e2e_inspect.md` (new)
- **Change shape**: Read `merge_normtest143_stage4_ddg.py` (how it pairs RunA/RunB, output
  columns/path) and `$WORKDIR/scripts/run_mmpbsa.py` (does it support a time window —
  begin/end/last-N-ns — or must frames be windowed by pre-truncating the xtc?). Confirm
  `MMGBSA_ENV/bin/gmx_MMPBSA` + `cpptraj` exist. Enumerate which of the 14 complete trajs
  form RunA/RunB pairs (same compound, both `is_traj_complete`). Write findings to scratch.
- **Verification**: `e2e_inspect.md` records (1) window mechanism (flag name OR "trjconv
  truncation needed"), (2) count of complete RunA/RunB pairs + their compounds, (3)
  gmx_MMPBSA present (path + `--version` ok). Non-empty on all three.
- **Estimated time**: 5 min
- **Rollback (if this task only)**: `rm .agent/scratch/mmgbsa_stable/e2e_inspect.md`

## Task 2: Stage the completed-traj subset into a fresh validation OUT_BASE

- **Status**: pending
- **Prereq tasks**: 1
- **Files touched**: new `/mnt/data/users/ubuntu/mmgbsa_e2e_validate_20260601/` (healthy
  branch); a staging script in `/tmp`
- **Change shape**: `sudo -u ubuntu` copy the completed-pair subset's FULL run_dir trees
  (`equi/equi_prod.{gro,cpt}`, `topol.top`, `chain_info.json`, `mmpbsa/` incl.
  `mmpbsa_prod.{xtc,gro,log}`, `input/ligand/LIG.mol2`) from the AB OUT_BASE into the fresh
  OUT_BASE; build `md_done.tsv` (header matching the orchestrator's 11 cols) with the
  subset rows pointing at the FRESH copies, `status=done`. Subset = all complete RunA/RunB
  pairs (from Task 1) + a few singles if pairs are scarce.
- **Verification**: `find <fresh> -name mmpbsa_prod.xtc | wc -l` = subset N; `tail -n +2
  <fresh>/md_done.tsv | wc -l` = N; AB OUT_BASE `mmpbsa_prod.xtc` mtimes unchanged (source
  read-only — spot-check one `stat -c %Y`).
- **Estimated time**: 5 min agent + copy time
- **Rollback (if this task only)**: `sudo -u ubuntu rm -rf <fresh OUT_BASE>` (fresh dir; AB untouched)

## Task 3: Run Stage 3 MMGBSA on the fresh OUT_BASE  [SLURM GATE]

- **Status**: pending
- **Prereq tasks**: 2
- **Files touched**: fresh OUT_BASE (`dg_result.json` per run_dir, `mmpbsa_done.tsv`)
- **Change shape**: `sudo -u ubuntu OUT_BASE=<fresh> MD_DONE_LIST=<fresh>/md_done.tsv
  SAMPLES=50 sbatch <shared>/scripts/mmgbsa_16gpu_multidir/slurm_normtest143_stage3_postprocess_seed777.sh`
  under contract mmgbsa-e2e-validate-length-20260601. Wait for completion.
- **Verification**: `mmpbsa_done.tsv` has N `done` rows (no `gmx_mmpbsa_failed` for the
  subset); every subset `dg_result.json` exists and `python -c 'json.load… ["dg"]'` is
  finite (sane magnitude, not NaN/empty).
- **Estimated time**: 5 min agent + external MMGBSA wall (CPU, 50 frames × N)
- **Rollback (if this task only)**: `scancel` the Stage-3 job; outputs are in the fresh dir

## Task 4: Run Stage 4 merge → ΔΔG (end-to-end pass)

- **Status**: pending
- **Prereq tasks**: 3
- **Files touched**: fresh OUT_BASE (`mmgbsa_components.tsv`, `mmgbsa_ddg_components.tsv`)
- **Change shape**: run `merge_normtest143_stage4_ddg.py --out-base <fresh>` (via the
  Stage-4 sbatch or inline if light) on the fresh OUT_BASE.
- **Verification**: `mmgbsa_ddg_components.tsv` exists with ≥1 finite ΔΔG row; OR (if no
  complete pair) `mmgbsa_components.tsv` has ≥1 finite ΔG row AND the pairing gap is noted
  in `e2e_inspect.md`. **This is the contract's "end-to-end pass once" criterion.**
- **Estimated time**: 3 min + short job
- **Rollback (if this task only)**: delete the merge outputs in the fresh dir

## Task 5: Interface-stability proxy vs time (cheap, all subset)

- **Status**: pending
- **Prereq tasks**: 2
- **Files touched**: `.agent/scratch/mmgbsa_stable/convergence_stability.txt` (new)
- **Change shape**: with the MMGBSA/gmx env, compute per-subset-traj the interface (or
  ligand-vs-pocket) RMSD vs time (`gmx rms`) and a short-range protein-ligand interaction
  energy vs time from the `.edr` (`gmx energy`), reading the EXISTING xtc/edr (no MMPBSA
  recompute). Summarize where (if anywhere) the complex drifts.
- **Verification**: `convergence_stability.txt` shows, per traj, RMSD + interaction-E vs
  time and a one-line drift verdict (stable-through-20ns OR drift-onset≈X ns).
- **Estimated time**: 5 min agent + light gmx
- **Rollback (if this task only)**: `rm` the scratch file

## Task 6: ΔG over cumulative windows on a representative subset  [SLURM GATE]

- **Status**: pending
- **Prereq tasks**: 1, 2
- **Files touched**: fresh OUT_BASE window outputs; `.agent/scratch/mmgbsa_stable/convergence_dg_windows.txt` (new)
- **Change shape**: for a small representative subset (≈2 RunA + 2 RunB), compute Stage-3
  MMGBSA ΔG sampling over cumulative windows 0–2, 0–4, 0–8, 0–12, 0–20 ns — using the
  window mechanism from Task 1 (run_mmpbsa.py begin/end flag if present, else `gmx trjconv`
  truncate each window then sample). Tabulate ΔG vs window per traj.
- **Verification**: `convergence_dg_windows.txt` lists ΔG per (traj, window); the running
  value either plateaus (|ΔG(w) − ΔG(20ns)| within ~1 kcal/mol from some w) or is flagged
  "no plateau by 20 ns".
- **Estimated time**: 5 min agent + external MMGBSA wall (subset × 5 windows)
- **Rollback (if this task only)**: `scancel`; outputs in fresh dir / scratch

## Task 7: Decide the standard MD length

- **Status**: pending
- **Prereq tasks**: 5, 6
- **Files touched**: `.agent/scratch/mmgbsa_stable/md_length_decision.md` (new)
- **Change shape**: combine the ΔG-window plateau (Task 6) with the stability proxy
  (Task 5) → choose the standard length = the smallest window where ΔG is within tolerance
  of the 20 ns value AND the interface is still stable. Record the number + the evidence +
  the corresponding `EXPECTED_MMPBSA_NSTEPS` (length/dt).
- **Verification**: `md_length_decision.md` states chosen length (ns + nsteps) + the two
  evidence lines (ΔG within tol by Y ns; stable through Y ns).
- **Estimated time**: 5 min
- **Rollback (if this task only)**: `rm` the scratch file

## Task 8: Fix the MD-length standard in the runbook

- **Status**: pending
- **Prereq tasks**: 7
- **Files touched**: `.agent/projects/fksfold-mmgbsa-slurm-harness.md`
- **Change shape**: in §"Stage-2 MD STANDARD SETTINGS — FIXED", record the chosen MD length
  + its `EXPECTED_MMPBSA_NSTEPS` as the mandatory default (alongside DIRS_PER_GPU=2), with
  the convergence rationale + a note that 20 ns trajs stay usable (analyze over the standard
  window) so the panel is internally consistent.
- **Verification**: `grep -n 'EXPECTED_MMPBSA_NSTEPS' .agent/projects/fksfold-mmgbsa-slurm-harness.md`
  shows the chosen value in the FIXED section; the rationale + window-consistency note present.
- **Estimated time**: 3 min
- **Rollback (if this task only)**: `git checkout .agent/projects/fksfold-mmgbsa-slurm-harness.md`
