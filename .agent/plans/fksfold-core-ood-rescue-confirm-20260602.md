---
contract: .agent/contracts/fksfold-core-ood-rescue-confirm-20260602.md
slice: fksfold-core
status: done
outcome: "DONE = CONFIRM (FKSFold 6283739). 120/120 OOD cells (5 targets×3cond×8seed). Regime-stratified: OOD steering-rescue REAL+reproducible+specific — 9DWW(PDE6D) baseline 0.006→nativeAB 0.683 (8/8 acceptable, iRMSD ~1Å, wrongAB 0.047), 9OS2 partial; 9NFQ/9DUR(PROTAC) none. nativeAB accept 10/32 vs wrongAB 0/32. Frozen (i)(ii)(iii) all met → steering-strengthening follow-on JUSTIFIED. Corrects Stage-B pooled-KILL (mixed regimes + lacked 9DWW). Harness: orchestrator v1 race-bug (dropped 2 chunks) → v2 full-drain fix."
total_tasks: 9
estimated_total_min: 40
note: >
  Confirm + characterize the OOD-regime steering-rescue, regime-stratified (NOT
  pooled — the Stage-B verdict's flaw). Two gates: (1) plan approval authorizes the
  zero-GPU work (Tasks 1-5); (2) Task 6 SLURM submit needs a separate explicit "go".
  Frozen CONFIRM/NOT-CONFIRM + regime rule (baseline<0.23=OOD) come from the
  contract — do NOT change after seeing new scores. Reuses the Stage-B harness
  (per-task UUID GPU selector, /mnt/data staging, DockQ scorer {native:model}).
---

# Plan — OOD-rescue confirm + characterize

Repo: `/home/ubuntu/FKSFold-Boltz_Advancement`; work dir `analysis/heldout_placement_20260601/`
(+ a new `ood_rescue_20260602/` subdir for this study's outputs). Reuses
`stageB_dockq_results.tsv`, `score_heldout_dockq.py`, `run_stageB_scoring.py`,
`stage_heldout_stageB.sh`, `extract_heldout_gt.py`, `verify_heldout_anchor.py`,
`fix_pocket_numbering.py`. Phases: **A Re-analysis** → **B New-target prep** →
**C Harness** → **D Gated gen + verdict**.

## Task 1: Regime-stratified re-analysis of the existing 36 cells (zero-GPU)

- **Status**: done (7faa10a; OOD=9NFQ/9OS2, native 1/6 > wrong 0/6 specificity; §1 written)
- **Prereq tasks**: none
- **Files touched**: `analysis/heldout_placement_20260601/ood_rescue_20260602/reanalyze_existing.py` (new); `.../ood_rescue_20260602/OOD_RESCUE_RESULTS.md` (new, §1)
- **Change shape**: read `stageB_dockq_results.tsv`; classify each target by the FROZEN rule (median baseline DockQ < 0.23 → OOD/prior-fails); for the OOD subset compute per-(target,condition) DockQ median + **acceptable-rate** (fraction of seeds ≥0.23) for native/base/wrong, and the specificity (native acceptable-rate vs wrong acceptable-rate). Write OOD_RESCUE_RESULTS.md §1 = "existing-data re-cut" (regime table + OOD-subset stats). NO pooled median.
- **Verification**: `python3 .../reanalyze_existing.py` prints the regime classification (9NGT/9NYR=prior-works, 9NFQ/9OS2=OOD) + OOD-subset native/base/wrong acceptable-rates; §1 written. Cross-check: 9OS2 native shows 1/3 seeds ≥0.23, wrong 0/3 (the seed16 rescue + specificity).
- **Estimated time**: 5 min
- **Rollback**: rm the two files.

## Task 2: Select + download new OOD-candidate held-out targets (zero-GPU)

- **Status**: done (350f1a9; 9W2F/9DWW/9DUR, non-kinase, bridge-verified; per-entry chains in SOURCES.md; 9DUR=PROTAC flag)
- **Prereq tasks**: none
- **Files touched**: `examples/heldout/<NEWID>.cif` (≥2); `analysis/heldout_placement_20260601/SOURCES.md` (append new rows)
- **Change shape**: from the recon (`.agent/scratch/d3_heldout_recon_20260601.md`, ~15 candidates) pick ≥2 NEW CRBN-ternary targets (distinct from 9NYR/9NGT/9NFQ/9OS2; prefer diverse/non-classic pockets likely to be prior-fails — but do NOT pre-filter by baseline, classify post-hoc). `wget` CIFs from RCSB; record chain maps (CRBN/target/ligand) + resolution + DockQ chain-map (`:B?`) in SOURCES.md, flagging any ambiguity (don't guess).
- **Verification**: `ls examples/heldout/<NEWID>.cif` exists + parses (Bio.PDB); SOURCES.md has the new rows with CRBN/target/ligand chains + a contact check confirming the degrader bridges CRBN+target.
- **Estimated time**: 5 min
- **Rollback**: rm the new CIFs + revert SOURCES.md.

## Task 3: GT + input YAMLs for new targets (zero-GPU)

- **Status**: done (532fe82; 3 GT + 9 YAMLs; nativeAB numbering independently resname-xchecked PASS 3/3)
- **Prereq tasks**: 2
- **Files touched**: `analysis/heldout_placement_20260601/gt/<NEWID>_gt.json`; `examples/heldout/<NEWID>.yaml` + `<NEWID>_wrongAB.yaml` + `<NEWID>_baseline.yaml`
- **Change shape**: run `extract_heldout_gt.py` per new target → GT JSON. Build the 3 input YAMLs with the AMENDMENT-1 convention (pocket contacts = **1-based sequence position**, via the fix_pocket_numbering remap; wrongAB = `((r-1+N//2) mod N)+1` opposite-face fold; baseline = no constraints). SMILES from RCSB chemcomp.
- **Verification**: per new target — `fix_pocket_numbering.py`-style check: nativeAB contacts in 1..N + resname cross-check; wrongAB disjoint from nativeAB; baseline has no `constraints`; all parse.
- **Estimated time**: 5 min
- **Rollback**: rm the new gt/ + YAML files.

## Task 4: Per-target configs + re-derived CRBN anchor for new targets (zero-GPU)

- **Status**: done (5d75e04; W400→356/319/340 all→W verified independently; target terms disabled; w400 indices for Task-5 case: 9W2F=356,9DWW=319,9DUR=340)
- **Prereq tasks**: 3
- **Files touched**: `analysis/heldout_placement_20260601/configs/oracle_generation_heldout_<NEWID>.yaml`; extend `verify_heldout_anchor.py` coverage (or a sibling check) for new targets
- **Change shape**: per new target, build the config like the existing 4 (re-derived CRBN anchor via residue-walk: glueprint `anchor_patch`/`pocket_residues` + biophysical `key_residues_B`; **all target-side terms disabled** — glueprint `target_key_residues:[]`/`w_ligand_face:0`, biophysical `key_residues_A:[]`; per STAGEB_RECIPE §5). Compute each new target's re-derived `w400` index. Verify the CRBN anchor lands on 'W' (4/4-style pass) for the new targets.
- **Verification**: new configs parse + glueprint/biophysical anchor = re-derived + target terms disabled; anchor check prints `W400→<pos>(W)` per new target (PASS).
- **Estimated time**: 5 min
- **Rollback**: rm the new configs.

## Task 5: Build the expanded OOD jobs matrix + harness + static smoke (zero-GPU)

- **Status**: done (6fddd8b; 120-cell TSV + slurm_ood_rescue_20260602.sh + stage_ood_rescue.sh + smoke; 120/120 resolve, 18 skip, ~2-5 GPU-hr). ⚠️ GATE NOTE: qos=batch MaxSubmit=50 < 120 → submit in 3 sequential chunks of ≤40 (gpu:4 cap → ~4 concurrent); %8 in script is moot.
- **Prereq tasks**: 1, 3, 4
- **Files touched**: `analysis/heldout_placement_20260601/ood_rescue_jobs.tsv` (new); `analysis/heldout_placement_20260601/stage_ood_rescue.sh` (new, adapted from stage_heldout_stageB.sh); reuse `workflow/slurm_heldout_placement_stageB_20260601.sh` (parameterized by TSV)
- **Change shape**: enumerate the OOD matrix = {9NFQ, 9OS2, new OOD targets} × {nativeAB,wrongAB,baseline} × **8 frozen seeds** ({16,42,123} existing + 5 new frozen: 7,99,256,314,512). Existing 9NFQ/9OS2 seed16/42/123 cells are reused via the idempotent skip (re-point OUT_BASE to the Stage-B output base so they're found). Stage the new inputs/configs/TSV to `/mnt/data` (stage_ood_rescue.sh, FK-superset src). The SLURM script reads the TSV + per-target w400 (extend the `case` for new targets) + per-task UUID GPU selector (already in script).
- **Verification**: `bash -n` the (extended) SLURM script; dry-resolve every TSV row → input YAML + config + w400 exist under `/mnt/data`; idempotent-skip count for the already-done existing-seed cells; `wc -l ood_rescue_jobs.tsv` = (n_OOD_targets × 3 × 8) + header. NO sbatch.
- **Estimated time**: 5 min
- **Rollback**: rm the new TSV/stage script; revert the SLURM `case` extension.

## Task 6: SUBMIT the expanded OOD array — ⛔ STOP GATE (explicit "go")

- **Status**: done (user "제출" 2026-06-02; normal qos gpu:8 8-wide. qos submit-cap 30<120 → chunked. v1 orchestrator race-bug dropped 2 chunks → v2 full-drain re-run → 110/120 → requeue transient-OOM → 120/120. arrays 5974/5998/6022/6046-6143/6167)
- **Prereq tasks**: 1, 2, 3, 4, 5
- **Files touched**: (none in repo — SLURM array; outputs to scratch OUT_BASE)
- **Change shape**: **WORKFLOW §3 hard gate.** Bring the GPU-hour estimate + resource request (qos=batch, gres=gpu:1, time, `--array=1-N%K`). On "go": `mkdir` slurm log dir + `sbatch` under the active contract. Watch wave-1 (distinct GPU UUIDs + no OOM, as in 5911). Requeue any transient-OOM cells (idempotent).
- **Verification**: `squeue`/`sacct` shows the array; OUT_BASE fills `<target>_<cond>_seed<seed>/` dirs; wave-1 shows distinct GPU UUIDs + no OOM.
- **Estimated time**: 3 min hands-on (+ GPU wall per estimate)
- **Rollback**: `scancel`; rm scratch OUT_BASE. No repo state touched.

## Task 7: Score all new/expanded cells with DockQ (post-completion)

- **Status**: done (run_ood_scoring.py → ood_rescue_dockq.tsv 120/120; +3 GT chain maps, 9DWW GT-vs-GT=1.0 verified)
- **Prereq tasks**: 6
- **Files touched**: `analysis/heldout_placement_20260601/ood_rescue_20260602/ood_rescue_dockq.tsv` (new); reuse/extend `run_stageB_scoring.py` to iterate the OOD matrix (8 seeds)
- **Change shape**: run the scorer (miniconda python: `/home/ubuntu/miniconda3/bin/python3`) over every OOD cell → per-(target,condition,seed) DockQ TSV. Record missing/failed as NA.
- **Verification**: `wc -l ood_rescue_dockq.tsv` = matrix size (+header); every present cell has numeric DockQ in [0,1]; per-(target,condition) acceptable-rate computable.
- **Estimated time**: 5 min hands-on (+ eval wall)
- **Rollback**: rm the tsv (re-runnable from OUT_BASE).

## Task 8: Regime-stratified CONFIRM/NOT-CONFIRM verdict (zero-GPU)

- **Status**: done (OOD_RESCUE_RESULTS.md §2-§3; VERDICT=CONFIRM; (i)(ii)(iii) all met; 9DWW strong/9OS2 partial rescue)
- **Prereq tasks**: 1, 7
- **Files touched**: `analysis/heldout_placement_20260601/ood_rescue_20260602/OOD_RESCUE_RESULTS.md` (complete §2-§3)
- **Change shape**: classify all targets (incl. new) by the frozen baseline<0.23 rule; over the OOD subset apply the FROZEN CONFIRM criteria — (i) reproducibility (nativeAB reaches ≥0.23 in ≥1 seed on ≥2 OOD targets), (ii) specificity (nativeAB acceptable-rate > wrongAB AND median nativeAB > baseline), (iii) non-fluke (≥2 targets or ≥2 seeds). State **CONFIRM** or **NOT-CONFIRM** verbatim. Report as a bound (power). Run proxy-audit. Include the §1 existing-data re-cut for continuity + limitations.
- **Verification**: OOD_RESCUE_RESULTS.md has the regime table, OOD-subset per-target native/base/wrong acceptable-rate, the three CONFIRM conditions each with numbers + pass/fail, the proxy-audit outcome, and one explicit CONFIRM/NOT-CONFIRM line bound to frozen thresholds.
- **Estimated time**: 5 min
- **Rollback**: revert OOD_RESCUE_RESULTS.md to §1 state.

## Task 9: Commit + update contract/plan/baton/handoff

- **Status**: done (FKSFold 6283739 + prior; contract+plan done; baton + handoff)
- **Prereq tasks**: 1,2,3,4,5,7,8
- **Files touched**: FKSFold commit (scripts, new CIF/GT/YAML/config, TSVs, OOD_RESCUE_RESULTS.md — scratch OUT_BASE NOT committed; respect *.csv/outputs* policy); workspace (contract status→done + verdict, plan status→done, fksfold-core baton, index)
- **Change shape**: surgical commits (stay off the 157-entry dirty tree). Contract `status: done` + Notes (CONFIRM/NOT-CONFIRM + next: strengthen follow-on or lane-close). Plan `status: done`. Update `.agent/status/fksfold-core.md` baton + `scripts/handoff.sh claude fksfold-core` + `scripts/status.sh index`.
- **Verification**: `git status --porcelain <paths>` clean for tracked artifacts; contract + plan `done`; verdict in baton.
- **Estimated time**: 3 min
- **Rollback**: git revert.

---

## Gate reminders

1. **Plan approval** authorizes Tasks 1-5 (all zero-GPU: re-analysis + new-target prep + harness). Does NOT authorize the sbatch.
2. **SLURM "go"** (Task 6) is a separate WORKFLOW §3 gate + resource request.
3. **Frozen, regime-stratified:** classification rule (baseline<0.23) + CONFIRM thresholds come from the contract; do NOT change after seeing new scores; NO pooled median.
