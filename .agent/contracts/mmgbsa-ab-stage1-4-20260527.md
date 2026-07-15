# MMGBSA Stage 1–4: AB-Pattern Structures (125 compounds)

**Status**: approved  
**Slice**: mmgbsa  
**Requested**: 2026-05-27  
**Approved by**: user (2026-05-27)

## Purpose

Run MMGBSA Stage 1–4 full pipeline on the 125 AB-pattern–generated structures
(SLURM 5638, `vav1_ab_139batch_20260526_231435`) to test whether better VAV1
placement (vav1_offset 3.16 Å median vs. baseline 17.4 Å) improves Stage 1
pass rate and produces a cleaner ΔΔG vs. DC50 signal.

**Hypothesis**: Prior MMGBSA null (ΔΔG Pearson −0.095, 5331 corrected-YAML run)
may be partly a measurement artifact caused by poor starting poses. AB structures
place VAV1 correctly → fewer early_nvt_hang failures → higher pass rate → tighter
ΔΔG estimates. If null persists with AB structures, the ranking problem is
confirmed structural (not measurement noise).

## Current State

- 5331 corrected-YAML Stage 1: 70/198 ready (35.4%). Dominant failure: early_nvt_hang.
  OUT_BASE: `outputs/norm143_corrected_seed16_stage1_20260520_111530/`
- AB structures: 125 valid PDB at
  `outputs/vav1_ab_139batch_20260526_231435/VAV1_XXX/boltz_results_VAV1_XXX_vav1_iface_AB/predictions/VAV1_XXX_vav1_iface_AB/VAV1_XXX_vav1_iface_AB_model_0.pdb`
- AB YAMLs: 145 available at
  `examples/normtest_msa_patched_vav1_iface_AB_139/VAV1_XXX_vav1_iface_AB.yaml`
- node1 (host-10-0-5-232): **hardware fault confirmed** (5627, 10/10 PASS on node0) → must exclude from SLURM

## Triggers matched

- SLURM submission (high QOS, 16 GPU, 2 node × 8 A100)
- `/mnt/data` writes (MMGBSA outputs under `/mnt/data/users/kim/mmgbsa_outputs/`)
- New sources.tsv creation

## Scope

1. Generate `norm143_ab_sources.tsv` (125 rows): AB PDB paths + AB YAML paths + DC50 metadata
2. Submit MMGBSA Stage 1 prepare (SLURM, high QOS, 2 node × 8 A100, RunA+RunB, node1 excluded)
3. On Stage 1 completion: gate check via `mmgbsa-stage-check` subagent → proceed to Stage 2 (MD) → Stage 3 (MMPBSA) → Stage 4 (merge)
4. Final report: Stage 1 pass rate vs. 5331 baseline (35.4%), ΔΔG vs. DC50 Pearson/AUC

## Non-Goals

- v3-original paired prep comparison (same 99 compounds, old YAML) — separate contract
- 20 OOM cell recovery (AB 125 → 145) — separate job after this run completes
- Any modification to fragmap code or AB generation parameters
- F105 workstream — separate (never mix with normtest143)

## Done When

1. `norm143_ab_sources.tsv` created with 125 rows; `wc -l` returns 126 (header + 125)
2. Stage 1 SLURM job submitted and completed; `ready_for_mmpbsa_prod.tsv` row count > 0
3. Stage 1 pass rate documented: AB vs. 5331 baseline (35.4%)
4. Stage 2–4 complete; `stage4_merged_results.tsv` exists with ΔΔG values
5. ΔΔG vs. DC50 Pearson/Spearman + AUC reported (n = Stage 4 survivors)

## Resource Budget

- SLURM: high QOS, 2 node × 8 A100 = 16 GPU, RunA + RunB (same as 5331)
- Walltime: ~24h Stage 1 (125 × 2 runs); Stage 2–4 proportional to pass count
- Storage: `/mnt/data/users/kim/mmgbsa_outputs/norm143_ab_stage1_<TS>/`

## Constraints

- **node1 exclusion mandatory**: `#SBATCH --exclude=host-10-0-5-232`
- SLURM submit only after this contract is approved
- Stage 2–4 gated on `mmgbsa-stage-check` subagent approval after Stage 1

## Rollback

- Stage 1 outputs are a new OUT_BASE directory; 5331 corrected-YAML outputs are unaffected
- If Stage 1 pass rate < 20% (worse than 5331 with node1 bias removed), stop — don't proceed to Stage 2
- No code changes → no revert needed

## Verification commands

```bash
# sources.tsv row count
wc -l /mnt/data/users/ubuntu/workspace/FKSFold-Boltz_Advancement_shared/outputs/_mmgbsa_staging/norm143_ab_sources.tsv

# Stage 1 ready count
wc -l <OUT_BASE>/ready_for_mmpbsa_prod.tsv

# Stage 4 ΔΔG check
head -5 <OUT_BASE>/stage4_merged_results.tsv
```

## Progress Log

- 2026-05-27: contract drafted
