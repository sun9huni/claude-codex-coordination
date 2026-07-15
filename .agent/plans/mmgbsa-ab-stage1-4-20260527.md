---
contract: .agent/contracts/mmgbsa-ab-stage1-4-20260527.md
slice: mmgbsa
status: in-progress
total_tasks: 10
estimated_total_min: 42
---

# MMGBSA Stage 1–4: AB-Pattern Structures (125 compounds)

SHARED=/mnt/data/users/ubuntu/workspace/FKSFold-Boltz_Advancement_shared
AB_OUT=$SHARED/outputs/vav1_ab_139batch_20260526_231435
AB_YAML=$SHARED/examples/normtest_msa_patched_vav1_iface_AB_139
STAGING=$SHARED/outputs/_mmgbsa_staging
SCRIPTS=$SHARED/scripts/mmgbsa_16gpu_multidir

---

## Task 1: Audit AB output — enumerate 125 valid PDB paths

- **Status**: done
- **Prereq tasks**: none
- **Files touched**: none (read-only audit)
- **Change shape**: Find all `VAV1_*_vav1_iface_AB_model_0.pdb` in `vav1_ab_139batch_20260526_231435/`. Confirm count = 125. List compound IDs and paths.
- **Verification**: `sudo -u kim find /mnt/data/users/ubuntu/workspace/FKSFold-Boltz_Advancement_shared/outputs/vav1_ab_139batch_20260526_231435 -name "*model_0.pdb" | wc -l` → `125`
- **Estimated time**: 2 min
- **Rollback (if this task only)**: no files changed

---

## Task 2: Create norm143_ab_sources.tsv

- **Status**: done
- **Prereq tasks**: 1
- **Files touched**: `/mnt/data/users/ubuntu/workspace/FKSFold-Boltz_Advancement_shared/outputs/_mmgbsa_staging/norm143_ab_sources.tsv`
- **Change shape**: Write a Python one-shot script (inline) that:
  1. Globs all 125 model_0.pdb paths from `vav1_ab_139batch_20260526_231435/`
  2. Constructs AB YAML path for each: `examples/normtest_msa_patched_vav1_iface_AB_139/VAV1_XXX_vav1_iface_AB.yaml`
  3. Merges dc50_nM / logDC50 from `norm143_corrected_sources.tsv` where compound_id matches; leaves blank otherwise
  4. Writes TSV with columns: compound_id, job_name, seed, yaml, pdb, dc50_nM, logDC50, production_rank, final_rank
  - job_name format: `VAV1_XXX_seed16_ab`, seed=16
- **Verification**: `wc -l /mnt/data/users/ubuntu/workspace/FKSFold-Boltz_Advancement_shared/outputs/_mmgbsa_staging/norm143_ab_sources.tsv` → `126` (header + 125)
- **Estimated time**: 5 min
- **Rollback (if this task only)**: `rm $STAGING/norm143_ab_sources.tsv`

---

## Task 3: Validate sources.tsv — PDB existence + DC50 coverage

- **Status**: done
- **Prereq tasks**: 2
- **Files touched**: none (read-only)
- **Change shape**: Inline validation:
  1. All 125 pdb paths in sources.tsv are `stat`-able (no missing files)
  2. All 125 yaml paths exist
  3. DC50 coverage: count rows with non-empty dc50_nM; document compound IDs missing DC50 (expected: compounds outside the 99-compound light-filter set)
- **Verification**: `python3 -c "import csv; rows=list(csv.DictReader(open('/mnt/data/users/ubuntu/workspace/FKSFold-Boltz_Advancement_shared/outputs/_mmgbsa_staging/norm143_ab_sources.tsv'),delimiter='\t')); missing=[r['compound_id'] for r in rows if not __import__('pathlib').Path(r['pdb']).exists()]; print('missing PDB:', missing)"` → `missing PDB: []`
- **Estimated time**: 3 min
- **Rollback (if this task only)**: no files changed

---

## Task 4: Create slurm_mmgbsa_ab_stage1.sh

- **Status**: done
- **Prereq tasks**: 3
- **Files touched**: `/mnt/data/users/ubuntu/workspace/FKSFold-Boltz_Advancement_shared/scripts/mmgbsa_16gpu_multidir/slurm_mmgbsa_ab_stage1.sh`
- **Change shape**: Copy `slurm_mmgbsa_norm143_corrected_stage1.sh` → `slurm_mmgbsa_ab_stage1.sh`. Apply these diffs:
  1. `#SBATCH --job-name=mmgbsa_ab_prep`
  2. Add line: `#SBATCH --exclude=host-10-0-5-232`
  3. `--output=/mnt/data/users/kim/logs/mmgbsa_ab_prep_%j.out`
  4. `--error=/mnt/data/users/kim/logs/mmgbsa_ab_prep_%j.err`
  5. Default `STAGING_TSV`: `norm143_ab_sources.tsv` (filename part)
  6. Default `ROOT_OUT_BASE`: `norm143_ab_seed${FIXED_SEED}_stage1_$(date +%Y%m%d_%H%M%S)`
  7. Update header comment: "Stage 1 prepare for 125 AB-pattern poses"
- **Verification**: `bash -n /mnt/data/users/ubuntu/workspace/FKSFold-Boltz_Advancement_shared/scripts/mmgbsa_16gpu_multidir/slurm_mmgbsa_ab_stage1.sh && grep 'exclude=host-10-0-5-232' /mnt/data/users/ubuntu/workspace/FKSFold-Boltz_Advancement_shared/scripts/mmgbsa_16gpu_multidir/slurm_mmgbsa_ab_stage1.sh` → outputs the `--exclude` line
- **Estimated time**: 5 min
- **Rollback (if this task only)**: `rm $SCRIPTS/slurm_mmgbsa_ab_stage1.sh`

---

## Task 5: ⛔ GATE — Submit Stage 1 SLURM job

- **Status**: done
- **Job ID**: 5754
- **OUT_BASE**: /mnt/data/users/ubuntu/mmgbsa_outputs/norm143_ab_seed16_stage1_20260527_182206/
- **Notes**: 3 failed attempts (5751 kim-no-high-qos, 5752 kim-logdir-perm, 5753 RUN_TYPES-comma). Fixed: log→ubuntu/logs, OUT_BASE→ubuntu/mmgbsa_outputs, RUN_TYPES="A B" (space not comma).
- **Prereq tasks**: 4
- **Files touched**: creates `$OUT_BASE/` directory tree under `/mnt/data/users/kim/mmgbsa_outputs/norm143_ab_seed16_stage1_<TS>/`
- **Change shape**: **APPROVAL GATE — stop and confirm before running sbatch.**
  Submit: `sudo -u kim sbatch /mnt/data/users/ubuntu/workspace/FKSFold-Boltz_Advancement_shared/scripts/mmgbsa_16gpu_multidir/slurm_mmgbsa_ab_stage1.sh`
  Record the returned SLURM job ID. Record OUT_BASE from job log once it starts.
- **Verification**: `squeue -u kim --format="%.10i %.9P %.30j %.8T %.10M" | grep mmgbsa_ab_prep` → shows RUNNING or PENDING job
- **Estimated time**: 2 min (submit) + ~24h (wait for completion — future session)
- **Rollback (if this task only)**: `sudo -u kim scancel <job_id>`; delete OUT_BASE directory

---

## Task 6: ⛔ GATE — Stage 1 completion check via mmgbsa-stage-check

- **Status**: done
- **Result**: 76/250 = 30.4% pass rate. 67/125 unique compounds ready. GO verdict. RunA weak (23), RunB strong (53). DC50 n=44.
- **Prereq tasks**: 5 (after Stage 1 SLURM completes)
- **Files touched**: none (read-only inspection)
- **Change shape**: **APPROVAL GATE — run after Stage 1 SLURM job finishes.**
  Use `mmgbsa-stage-check` subagent on OUT_BASE. Report:
  1. Stage 1 pass rate (ready count / 250 attempts = 125 × RunA+RunB)
  2. Comparison vs 5331 baseline: 70/198 (35.4%)
  3. Failure mode breakdown (early_nvt_hang vs other)
  4. Verdict: proceed to Stage 2? Stop if pass rate < 20% (worse than adjusted 5331 baseline)
- **Verification**: `wc -l <OUT_BASE>/ready_for_mmpbsa_prod.tsv` → non-zero (>1 including header); mmgbsa-stage-check subagent verdict = PASS
- **Estimated time**: 5 min
- **Rollback (if this task only)**: no files changed; don't proceed to Stage 2

---

## Task 7: ⛔ GATE — Submit Stage 2 MD production

- **Status**: done
- **Job ID**: 5809 (5808 cancelled — DIRS_PER_GPU=8→59% fill; resubmitted 5809 DIRS_PER_GPU=5→95% fill), nodes host-10-0-5-[73,90], 76 compounds (38+38 split)
- **Prereq tasks**: 6
- **Files touched**: `<OUT_BASE>/md_done.tsv` (new), MD trajectory files
- **Change shape**: **APPROVAL GATE — confirm after Task 6 pass.**
  Submit: `sudo -u kim OUT_BASE=<out_base> sbatch /mnt/data/users/ubuntu/workspace/FKSFold-Boltz_Advancement_shared/scripts/mmgbsa_16gpu_multidir/slurm_normtest143_stage2_md_multidir_seed777.sh`
  Must also add `--exclude=host-10-0-5-232` (can pass via `#SBATCH` override or env, or patch the script similarly to Task 4).
- **Verification**: `squeue -u kim | grep mmgbsa_norm143_md` → shows RUNNING; `wc -l <OUT_BASE>/md_done.tsv` > 1 after completion
- **Estimated time**: 2 min (submit) + ~24-48h (wait — future session)
- **Rollback (if this task only)**: `sudo -u kim scancel <job_id>`

---

## Task 8: ⛔ GATE — Submit Stage 3 MMPBSA postprocess WITH decomp

- **Status**: pending
- **Prereq tasks**: 7 (after Stage 2 SLURM completes)
- **Files touched**: `<OUT_BASE>/mmpbsa_done.tsv` (new), per-compound MMPBSA output, `FINAL_DECOMP_MMPBSA.dat` per RunA compound
- **Change shape**: **APPROVAL GATE — confirm after Stage 2 completion.**
  Prep work completed (2026-05-29):
  - `workflow/mdp/gb_decomp.in` created (gb.in + `&decomp idecomp=2, dec_verbose=1, print_res="within 6"`)
  - Stage 3 script patched: `GB_IN` env var now overrides hardcoded `gb.in` path
  Submit with decomp:
  ```bash
  sudo -u ubuntu OUT_BASE=/mnt/data/users/ubuntu/mmgbsa_outputs/norm143_ab_seed16_stage1_20260527_182206 \
    GB_IN=/mnt/data/users/ubuntu/workspace/FKSFold-Boltz_Advancement_shared/workflow/mdp/gb_decomp.in \
    sbatch /mnt/data/users/ubuntu/workspace/FKSFold-Boltz_Advancement_shared/scripts/mmgbsa_16gpu_multidir/slurm_normtest143_stage3_postprocess_seed777.sh
  ```
  Stage 3 uses `qos=normal` (CPU-heavy, no GPU needed). No node exclusion required.
  NOTE: RunA (ternary receptor = CRBN+VAV1) produces `FINAL_DECOMP_MMPBSA.dat` with per-residue contributions.
  VAV1 residues = AMBER 398–458 in the ternary topology (chain B, 61 residues).
  RunB (binary CRBN+PROTAC) also runs decomp but only prints CRBN residues (expected).
- **Verification**: `squeue -u ubuntu | grep mmgbsa_norm143_post` → RUNNING; `wc -l <OUT_BASE>/mmpbsa_done.tsv` > 1; check `find <OUT_BASE> -name FINAL_DECOMP_MMPBSA.dat | wc -l` > 0
- **Estimated time**: 2 min (submit) + ~12-24h (wait — future session)
- **Rollback (if this task only)**: `sudo -u ubuntu scancel <job_id>`

---

## Task 9: ⛔ GATE — Submit Stage 4 merge + ΔΔG report

- **Status**: pending
- **Prereq tasks**: 8 (after Stage 3 SLURM completes)
- **Files touched**: `<OUT_BASE>/stage4_merged_results.tsv` (new); DC50 correlation report
- **Change shape**: **APPROVAL GATE — confirm after Stage 3 completion.**
  1. Submit: `sudo -u kim OUT_BASE=<out_base> sbatch /mnt/data/users/ubuntu/workspace/FKSFold-Boltz_Advancement_shared/scripts/mmgbsa_16gpu_multidir/slurm_normtest143_stage4_merge_seed777.sh`
  2. After merge completes, run inline correlation analysis:
     - Load `stage4_merged_results.tsv` + `norm143_ab_sources.tsv` (for DC50)
     - Compute Spearman/Pearson(logDC50, ddTOTAL) for compounds with DC50 → full ternary ΔΔG signal
     - Extract VAV1:PROTAC decomp ΔG from RunA `FINAL_DECOMP_MMPBSA.dat` files:
       sum contributions from AMBER residues 398–458 (VAV1 chain B, 61 residues) per compound
     - Compute Spearman/Pearson(logDC50, VAV1_decomp_dg) → VAV1-specific signal
     - Compare both vs 5331 baseline: full ΔΔG Pearson −0.095, AUC 0.426
     - Write report: `analysis/mmgbsa/reports/ab_stage4_ddg_report_20260527.md`
- **Verification**: `ls <OUT_BASE>/stage4_merged_results.tsv` exists + row count > 1; report file exists
- **Estimated time**: 5 min (submit + analysis) + ~2h (wait for Stage 4 — short job)
- **Rollback (if this task only)**: delete report file; Stage 4 merge is non-destructive

---

## Task 10: Update mmgbsa.md + handoff

- **Status**: pending
- **Prereq tasks**: 9
- **Files touched**: `.agent/status/mmgbsa.md`
- **Change shape**: Update mmgbsa.md:
  - Add AB Stage 1-4 run to "Where we are" section (OUT_BASE, pass rate, ΔΔG result)
  - Update remaining_actions to reflect completion
  - Add contract pointer: `.agent/contracts/mmgbsa-ab-stage1-4-20260527.md`
  Run `./scripts/handoff.sh claude mmgbsa` + `./scripts/status.sh index`
- **Verification**: `head -8 .agent/status/mmgbsa.md` shows today's date + bumped version; `grep "ab_stage" .agent/status/mmgbsa.md` → found
- **Estimated time**: 3 min
- **Rollback (if this task only)**: `git checkout .agent/status/mmgbsa.md`
