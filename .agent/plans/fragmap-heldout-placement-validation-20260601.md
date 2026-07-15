---
contract: .agent/contracts/fragmap-heldout-placement-validation-20260601.md
slice: fragmap
status: stage-a-done
total_tasks: 7
outcome: "Stage A (zero-compute prep) COMPLETE: 4 held-out CIFs (9NYR/9NGT/9NFQ/9OS2) + GT extraction + nativeAB YAMLs + DockQ de-risked (self 1.0/+5Å 0.53) + frozen pre-registration (36-job TSV, DockQ PROVE/KILL, wrongAB transform). Stage B (GPU generation + verdict) = gated milestone: needs own write-plan round + separate SLURM go. Stage-B-entry check: 9NGT author-numbering (2088-2092) index convention."
estimated_total_min: 30
program: .agent/plans/fragmap-leverage-program-20260601.md (T2/D3)
note: "STAGED. Tasks 1-7 = Stage A (zero-compute: download held-out + extract GT + build inputs + pre-register). Stage B (GPU generation + DockQ verdict) is a GATED MILESTONE — own write-plan round + separate SLURM go after Stage A done."
---

# Plan — Held-out placement validation, Stage A (zero-compute prep)

Phases: Data (1-4, download + GT + inputs) → Pre-register (5) → Smoke (6) →
Handoff (7). All zero-GPU. Stage B (generation + verdict) decomposed separately
only after Stage A completes. Repo: /home/ubuntu/FKSFold-Boltz_Advancement;
work dir: `analysis/heldout_placement_20260601/`.

## Task 1: Download held-out CIFs + sources manifest

- **Status**: done (a90ca46) — 4 CIFs, chain maps + flags in SOURCES.md, .cif not gitignored
- **Prereq tasks**: none
- **Files touched**: `analysis/heldout_placement_20260601/SOURCES.md`; held-out CIFs under `examples/heldout/` (9NYR, 9NGT, 9NFQ [, 9OS2])
- **Change shape**: `wget` the 4 CIFs from RCSB (`https://files.rcsb.org/download/<ID>.cif`). For each, record in SOURCES.md: PDB ID, target name + UniProt, ligand component ID, resolution, method, release date, and the chain inventory (which chain = CRBN, target, ligand). Verify `.cif` is NOT gitignored (examples/9nfr/9NFR.cif is tracked → likely fine); if large/ignored, store under a pointer + note.
- **Verification**: `ls examples/heldout/*.cif | wc -l` → 3 or 4; `grep -c 'PDB ID' analysis/heldout_placement_20260601/SOURCES.md` matches; each CIF parses (`python3 -c "from Bio.PDB import MMCIFParser; MMCIFParser(QUIET=1).get_structure('x','examples/heldout/9NYR.cif')"`).
- **Estimated time**: 3 min
- **Rollback**: rm the CIFs + SOURCES.md.

## Task 2: Generalize the GT-extraction recipe + smoke on 9NYR

- **Status**: done (45cb8a6) — extract_heldout_gt.py; 9NYR smoke pp-iface 12/13, pocket 22
- **Prereq tasks**: 1
- **Files touched**: `analysis/heldout_placement_20260601/extract_heldout_gt.py`
- **Change shape**: adapt the `examples/9d0w/` GT recipe (which produced `9d0w_ground_truth.json`) into a general script that, given a CIF + chain map (CRBN/target/ligand), extracts: (a) CRBN–target protein-protein interface residues (heavy-atom contact < 5 Å, both sides) → for DockQ reference, (b) target pocket residues around the ligand (< 5 Å) → for the oracle steering constraint, (c) writes a per-target `<ID>_gt.json`. Reuse Bio.PD / the 9d0w code patterns. Smoke on 9NYR only.
- **Verification**: `python3 analysis/heldout_placement_20260601/extract_heldout_gt.py --cif examples/heldout/9NYR.cif --out /tmp/9NYR_gt.json` → JSON with non-empty `pp_interface_residues` + `pocket_residues`; print counts.
- **Estimated time**: 6 min
- **Rollback**: rm the script.

## Task 3: Extract GT for all held-out targets

- **Status**: done (c980452) — 4/4 GT JSONs non-zero; 9OS2=chain C
- **Prereq tasks**: 2
- **Files touched**: `analysis/heldout_placement_20260601/gt/<ID>_gt.json` (3-4 files)
- **Change shape**: run the Task-2 script over all held-out CIFs (chain maps from SOURCES.md) → per-target GT JSON. Record any target where chain mapping is ambiguous (flag, don't guess).
- **Verification**: `ls analysis/heldout_placement_20260601/gt/*_gt.json | wc -l` matches target count; each has non-empty interface + pocket residue lists.
- **Estimated time**: 4 min
- **Rollback**: rm the gt/ dir.

## Task 4: Build per-target FKSFold input YAMLs

- **Status**: done (80c2efa) — 4 nativeAB YAMLs, pocket counts match GT
- **Prereq tasks**: 3
- **Files touched**: `examples/heldout/<ID>.yaml` (3-4 files)
- **Change shape**: from each GT JSON, build the FKSFold input YAML (CRBN seq + target seq + ligand SMILES + pocket constraint = the target pocket residues), mirroring `examples/9d0w/9d0w_cpd4_cdk2.yaml`. The pocket constraint = nativeAB condition's GT pocket.
- **Verification**: `for f in examples/heldout/9N*.yaml; do python3 -c "import yaml,sys;yaml.safe_load(open(sys.argv[1]))" "$f"; done` → all parse; each has sequences + pocket constraint block.
- **Estimated time**: 5 min
- **Rollback**: rm the YAMLs.

## Task 5: Pre-register condition matrix + Stage B jobs manifest

- **Status**: done (8114afc) — PREREGISTER.md + 36-job TSV; wrongAB table; 9NGT numbering flag
- **Prereq tasks**: 4
- **Files touched**: `analysis/heldout_placement_20260601/PREREGISTER.md` + `analysis/heldout_placement_20260601/stageB_jobs.tsv`
- **Change shape**: PREREGISTER.md freezes (restating the contract): the 3 conditions per target — nativeAB (GT pocket), **wrongAB (define the wrong constraint: transplant another target's pocket residue indices, or shuffle)**, baseline (no AB) — × 3 seeds; the DockQ primary endpoint + the frozen PROVE/KILL (median nativeAB DockQ ≥0.23 on ≥3/4 AND nativeAB>baseline AND nativeAB>wrongAB by margin); contact-F1 as context only. stageB_jobs.tsv enumerates (target, condition, seed) rows for the Stage B array. The wrongAB constraint per target is defined HERE, before any run.
- **Verification**: `grep -qiE 'nativeAB|wrongAB|baseline|DockQ|0.23' analysis/heldout_placement_20260601/PREREGISTER.md`; `wc -l analysis/heldout_placement_20260601/stageB_jobs.tsv` = targets×3×3 + header.
- **Estimated time**: 5 min
- **Rollback**: rm both files.

## Task 6: Smoke the DockQ eval on a held-out reference

- **Status**: done (ba5e3b7) — dockq 2.1.3; self 1.0000, +5Å 0.5346; recipe in SOURCES.md
- **Prereq tasks**: 3
- **Files touched**: `analysis/heldout_placement_20260601/SOURCES.md` (append eval-smoke record)
- **Change shape**: confirm MGD_eval (or DockQ directly) computes a CRBN–target interface DockQ given a held-out GT + a test prediction (e.g., the GT vs itself = DockQ 1.0 sanity, and GT vs a perturbed copy = <1). Record the exact invocation for Stage B. This de-risks that the DockQ endpoint is computable for these targets before GPU.
- **Verification**: DockQ(GT, GT) ≈ 1.0 printed; invocation recorded in SOURCES.md.
- **Estimated time**: 4 min
- **Rollback**: revert the SOURCES.md append.

## Task 7: Commit Stage A + update plan/contract/baton

- **Status**: done — Stage A complete (Tasks 1-6 committed FKSFold a90ca46→8114afc). Stage B = gated milestone (separate write-plan + SLURM go). 9NGT numbering = Stage-B-entry check.
- **Prereq tasks**: 1,2,3,4,5,6
- **Files touched**: FKSFold commit (script, GT, YAMLs, manifests, CIFs-if-trackable); workspace (plan statuses, contract progress, baton, index)
- **Change shape**: surgical commits of git-trackable Stage A artifacts (respect *.cif/*.csv policy — pointer if ignored); record Stage A done in contract Progress Log; baton + handoff + index. Stage A complete → Stage B awaits a fresh write-plan round + SLURM go.
- **Verification**: both repos `git status --porcelain <paths>` empty; contract Progress Log notes Stage A done + Stage B gated.
- **Estimated time**: 3 min
- **Rollback**: git revert.

---

## MILESTONE — Stage B (GPU generation + DockQ verdict), GATED

- **Entry gate**: Stage A done + explicit user SLURM "go" (WORKFLOW §3). ~tens GPU-hr.
- **Stage-B-entry check ✅ RESOLVED (2026-06-01, FKSFold 3a7debd)**: the 9NGT author-numbering flag was systematic (Boltz pocket contacts = 1-based seq position, proven via W400→355). 3/4 nativeAB YAMLs + the wrongAB table corrected pre-GPU (9NYR was already correct); PREREGISTER.md AMENDMENT 1 (intent + PROVE/KILL unchanged). nativeAB/wrongAB now on the same footing for all targets. Provenance: `analysis/heldout_placement_20260601/fix_pocket_numbering.py`.
- **Shape (future write-plan round)**: adapt the glueprint/oracle SLURM array (FK src/ pin, PINS.md) to `stageB_jobs.tsv` (target × {nativeAB,wrongAB,baseline} × 3 seed) → generate → MGD_eval DockQ (primary) + contact-F1 (context) → apply the frozen PROVE/KILL (nativeAB DockQ ≥0.23 on ≥3/4 AND > baseline AND > wrongAB) under T0 guardrails (proxy-audit, power_preflight bound) → report.
- **Action when reached**: `/write-plan` on the contract for Stage B, then a separate SLURM go.
