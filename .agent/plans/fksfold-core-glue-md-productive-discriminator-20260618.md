---
contract: .agent/contracts/fksfold-core-glue-md-productive-discriminator-20260618.md
slice: vav1-ubq
status: in-progress
total_tasks: 8
estimated_total_min: 95
---

# Plan — glue MD productive-geometry discriminator (dynamics escalation)

Escalate the 6 glue candidates (= 2 chemotypes × 3 stereo: A{g1,g2,g5} flexible / B{g3,g4,g6}
rigidified) + controls (MRT6160 active, C147 inactive) from the method-negative static screen to
**8 × 40 ns well-tempered metad** (1 GPU/compound, 8 parallel on one node), judged by a 4-axis MD
verdict + an active/inactive separation gate. Byte-faithful to the MRT6160/seed314 metad setup.
GPU tasks (4, 5) cross the ★APPROVAL GATE — contract approved + user go (2026-06-18) already given;
/execute-plan still pauses to confirm before each sbatch. Campaign/output dir:
`/mnt/data/users/ubuntu/workspace/crl_glue_md_20260618/` (MDDIR).

## Task 1: All-5-lysine dual-register scan dump (zero-GPU)
- **Status**: done
- **Prereq tasks**: none
- **Files touched**: `analysis/crl_integrative/glue8_pose_scan_all5.py`; `MDDIR/glue8_dualreg_all5.csv`
- **Change shape**: variant of `glue8_pose_scan.py` that, per of the 768 poses, dumps ALL 5 lysines'
  Nζ→Ub-G76-C AND Nζ→Cys85-Sγ (reuse `scan_one`'s `per_lys`), not just the closest. Columns:
  compound, angle, seed, then per-lysine `K788_dub,K788_dcys,...,K815_dub,K815_dcys`, clash.
- **Verification**: `head -1 CSV` shows 10 per-lysine distance columns + clash; `wc -l` ≈ 769;
  spot-check g_mrt6160_0_seed2718 K810 dub≈6.06 (matches Task 5 closest).
- **Estimated time**: 5 min agent (PyMOL re-scan ~20 min wall, run in background)
- **Rollback**: `rm analysis/crl_integrative/glue8_pose_scan_all5.py MDDIR/glue8_dualreg_all5.csv`

## Task 2: Per-chemotype productive-lysine + representative start-pose selection (zero-GPU)
- **Status**: done
- **Prereq tasks**: 1
- **Files touched**: `analysis/crl_integrative/glue8_md_pose_select.py`; `MDDIR/glue8_md_starts.tsv`
- **Change shape**: from the all-5 CSV, per CHEMOTYPE aggregate the ensemble to pick the productive
  lysine = the lysine minimizing dual-register `max(dub,dcys)` most robustly across the chemotype's
  3 stereo-forms (A{g1,g2,g5}, B{g3,g4,g6}); assign the SAME cv_lysine to all 3 members of a
  chemotype (resolve g1/g2↔g5 inconsistency). Controls (MRT6160, C147) by the same per-compound rule.
  Then per compound select the representative start pose (its best dual-register pose for that
  cv_lysine, clash-tolerant). Emit `compound chemotype cv_lysine start_cell dub dcys clash`.
- **Verification**: `column -t MDDIR/glue8_md_starts.tsv` → 8 rows; A-members share one cv_lysine,
  B-members share one; a printed within-chemotype consistency line.
- **Estimated time**: 5 min
- **Rollback**: `rm analysis/crl_integrative/glue8_md_pose_select.py MDDIR/glue8_md_starts.tsv`

## Task 3: Build 8 MD systems (CPU)
- **Status**: done
- **Prereq tasks**: 2
- **Files touched**: `MDDIR/systems/<compound>/` (crl_system.prmtop/.inpcrd + crl_atom_index.json per compound)
- **Change shape**: for each of the 8 compounds, run the seed314 build pipeline (crl_rebuild from the
  selected start pose → crl_md_prep: GAFF2/AM1-BCC ligand param + tleap + solvate) producing an
  MD-ready prmtop/inpcrd AND a `crl_atom_index.json` recording that compound's CV atoms (productive
  lysine Nζ idx + Ub-G76 C idx) for the metad driver.
- **Verification**: for each compound `ls MDDIR/systems/<c>/crl_system.prmtop` exists;
  `crl_confirm.py --t0` (CRL_WORKDIR=that system) prints the cv_lysine→Ub-G76 distance matching the
  selected start pose (±0.5 Å) and finite; 8/8 built (failures enumerated).
- **Estimated time**: 40 min agent (antechamber+tleap per ligand; can parallelize)
- **Rollback**: `rm -rf MDDIR/systems/`

## Task 4: Metad launcher + SMOKE (1 system) ★GPU GATE
- **Status**: done (launcher MDDIR/run_glue_md.sh; SMOKE job 7971)
- **Prereq tasks**: 3
- **Files touched**: `MDDIR/run_glue_md.sh`; `MDDIR/SMOKE.md`
- **Change shape**: launcher = 8 compounds, 1 GPU each (free-GPU selector by memory.free +
  clean-node check, [[reference-slurm-free-gpu-selection]]), byte-faithful seed314 metad params
  (WT bias factor 10, CV = compound's productive-lysine Nζ→Ub-G76-C, OpenCL platform, 40 ns,
  per-compound `crl_atom_index.json`). SMOKE=1 runs ONE system (MRT6160) a few hundred steps to
  validate the system loads, CV computes, bias deposits.
- **Verification**: `bash -n run_glue_md.sh`; SMOKE log shows metad steps advancing + a finite CV
  value at frame 0 matching the built system; `SMOKE.md` PASS.
- **Estimated time**: 5 min agent (smoke job ~few min)
- **Rollback**: `scancel` smoke; `rm -rf MDDIR/outputs/smoke`

## Task 5: Submit full 8 × 40 ns metad (parallel, 1 GPU/compound) ★GPU GATE
- **Status**: submitted (job 7972, afterok:7971; ~48h)
- **Prereq tasks**: 4
- **Files touched**: `MDDIR/outputs/<compound>/` (metad trajectories + bias)
- **Change shape**: submit the launcher (8 compounds, 8 GPUs, one 8-GPU clean node, qos=high,
  --time≈60:00:00). Monitor via srun (GPU util + step advance), NOT login mtime.
- **Verification**: 8 tasks RUNNING on free GPUs; after spin-up each compound's CV trace file grows
  + step advances (srun check); enumerate any failed compound.
- **Estimated time**: 5 min agent (job wall ~48 h; re-invoked on completion)
- **Rollback**: `scancel` job; `rm -rf MDDIR/outputs/<failed>`; resubmit subset (skip-existing).

## Task 6: Per-compound final read → 4-axis metrics (zero-GPU)
- **Status**: pending
- **Prereq tasks**: 5
- **Files touched**: `analysis/crl_integrative/glue_md_readout.py`; `MDDIR/glue_md_4axis.tsv`
- **Change shape**: per compound run `crl_confirm.py --traj --fes` + cvtrace on its 40 ns trajectory
  → 4 axes: (1) clash relief (t=0 severe → trajectory-median severe), (2) register (does cv_lysine
  reach the thioester, dual-register ≤ thresholds), (3) FES (near-attack min + shape: basin vs wall),
  (4) ternary integrity (VAV1↔CRBN COM drift / interface contacts maintained). Emit one row/compound.
- **Verification**: `column -t MDDIR/glue_md_4axis.tsv` → 8 rows × 4 axes + populated near-attack%;
  MRT6160(fresh) reproduces the seed314 reference (near-attack reached, severe→~0) as a sanity check.
- **Estimated time**: 20 min
- **Rollback**: `rm analysis/crl_integrative/glue_md_readout.py MDDIR/glue_md_4axis.tsv`

## Task 7: Active/inactive separation gate (MD) + per-chemotype verdict
- **Status**: pending
- **Prereq tasks**: 6
- **Files touched**: `analysis/crl_integrative/glue_md_verdict.py`; appends to `MDDIR/glue_md_4axis.tsv`
- **Change shape**: on the 4-axis metric, test MRT6160(active) vs C147(inactive) separation →
  `SEPARATION(MD): PASS|FAIL` (FAIL = MD can't discriminate → method-negative, 음성 자동선언 금지).
  Then per-chemotype (A flexible / B rigidified) productive/non-productive call, trust-qualified by
  the gate, with within-chemotype stereo-consistency + chirality (g1 vs g2, g3 vs g4) notes.
- **Verification**: script prints SEPARATION(MD) verdict + 2 chemotype calls + consistency lines.
- **Estimated time**: 8 min
- **Rollback**: `rm analysis/crl_integrative/glue_md_verdict.py`

## Task 8: Result doc + commit
- **Status**: pending
- **Prereq tasks**: 7
- **Files touched**: `analysis/crl_integrative/glue_md_results_20260618.md`
- **Change shape**: doc = 4-axis table (8 compounds, grouped by chemotype) + separation-gate verdict
  + per-chemotype call + chirality/consistency + static-vs-MD contrast (why MD was needed) +
  caveats (A1 ternary-formation blind spot, N=1 pose/compound, deferred lysine-agnostic metric).
  Commit (analysis files + doc); mark plan+contract done.
- **Verification**: doc committed (`git log --oneline -1`); contains all sections; contract+plan done.
- **Estimated time**: 7 min
- **Rollback**: `git revert` the commit.
