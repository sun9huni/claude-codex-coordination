---
contract: .agent/contracts/chronobridge-gspt1-leave-one-out-20260713.md
slice: chronobridge
status: done
total_tasks: 9
estimated_total_min: 45
---

# Plan: chronobridge Phase B — GSPT1 leave-one-ternary-out

Note on structure: this contract has a branching Done-When (분기 A: existing GSPT1
ensemble data found → build the leave-one-out pipeline; 분기 B: none found →
document + prep only). Tasks 6A/6B are mutually exclusive — only one executes,
selected by Task 5's decision. Task 3 (discovery) and Task 2 (PDB fetch) are
independent and can run in parallel.

## Task 1: scratch workspace + contract pointer

- **Status**: done
- **Prereq tasks**: none
- **Files touched**: `.agent/scratch/chronobridge/phaseB/README.md`
- **Change shape**: New directory `.agent/scratch/chronobridge/phaseB/`. README states
  the contract path (`chronobridge-gspt1-leave-one-out-20260713.md`), the one-line goal
  (test whether hiding one of 3 known GSPT1-CRBN-DDB1 ternary structures — 5HXB/6XK9/9HNE
  — and reconstructing its basin from the other 2 + glue info beats a naive baseline),
  and a `## Subdirs` stub (`pdb/`, `scripts/`, `results.md` to come).
- **Verification**: `test -f .agent/scratch/chronobridge/phaseB/README.md && grep -q chronobridge-gspt1-leave-one-out-20260713 .agent/scratch/chronobridge/phaseB/README.md`
- **Estimated time**: 2 min
- **Rollback (if this task only)**: `rm -rf .agent/scratch/chronobridge/phaseB/`

## Task 2: fetch GSPT1 ternary PDB structures

- **Status**: done
- **Prereq tasks**: 1
- **Files touched**: `.agent/scratch/chronobridge/phaseB/pdb/` (5HXB.pdb, 6XK9.pdb, 9HNE.pdb
  or .cif), `.agent/scratch/chronobridge/phaseB/pdb_notes.md`
- **Change shape**: Download the 3 structures from RCSB (no registration needed). Verify
  each contains the expected 3-chain-plus-ligand composition (GSPT1, CRBN, DDB1, + the
  respective glue: CC-885 / CC-90009 / Compound-1) and note chain IDs / hetero-ligand
  codes for each in `pdb_notes.md`.
- **Verification**: `ls .agent/scratch/chronobridge/phaseB/pdb/*.{pdb,cif} 2>/dev/null | wc -l` → 3, and `pdb_notes.md` lists chain/ligand composition for all 3.
- **Estimated time**: 5 min
- **Rollback (if this task only)**: `rm -rf .agent/scratch/chronobridge/phaseB/pdb/ .agent/scratch/chronobridge/phaseB/pdb_notes.md`

## Task 3: discover existing GSPT1 MD/docking data (zero-GPU)

- **Status**: done (finding: NOT FOUND — Branch B)
- **Prereq tasks**: 1
- **Files touched**: `.agent/scratch/chronobridge/phaseB/discovery_notes.md`
- **Change shape**: Search the workspace for any existing GSPT1-CRBN-DDB1 ternary MD
  trajectories, docking poses, or ensembles — check `.agent/scratch/`, `analysis/`,
  `/mnt/data` (permission-appropriate paths), and read
  `.agent/contracts/aigen-fold-core-crbn-transfer-pilot-20260706.md` +
  `.agent/status/aigen-fold-core.md`'s "CRBN-MGD data-scout" entry for leads. For any
  candidate found, verify it is actually a GSPT1 **ternary** complex (CRBN-DDB1-GSPT1),
  not just GSPT1 alone or a different target. Document every location checked and the
  final finding (found / not found, with paths if found).
- **Verification**: `grep -qE '^## (Found|Not found)' .agent/scratch/chronobridge/phaseB/discovery_notes.md` (a clear, unambiguous finding is recorded)
- **Estimated time**: 8 min
- **Rollback (if this task only)**: `rm .agent/scratch/chronobridge/phaseB/discovery_notes.md`

## Task 4: FP decoy design (glue × backbone cross-combination)

- **Status**: done
- **Prereq tasks**: 2
- **Files touched**: `.agent/scratch/chronobridge/phaseB/scripts/build_decoys.py`,
  `.agent/scratch/chronobridge/phaseB/decoys/`
- **Change shape**: Per the user-confirmed FP design, build at least one concrete decoy:
  take a glue ligand from one structure (e.g. 6XK9's CC-90009) and place it into a
  different structure's protein backbone conformation (e.g. 5HXB's CRBN-DDB1-GSPT1
  backbone) — a mismatched glue-backbone pairing that is a genuine near-miss (same
  target, wrong combination), not a different-fold decoy like Phase A's. Document the
  alignment/placement method used (e.g. superpose on CRBN, graft ligand coordinates,
  basic clash check) and produce at least one such cross-combination decoy structure.
- **Verification**: `ls .agent/scratch/chronobridge/phaseB/decoys/*.{pdb,cif} 2>/dev/null | wc -l` → at least 1, with a script that reproducibly builds it.
- **Estimated time**: 8 min
- **Rollback (if this task only)**: `rm -rf .agent/scratch/chronobridge/phaseB/scripts/build_decoys.py .agent/scratch/chronobridge/phaseB/decoys/`

## Task 5: record discovery decision (branch A vs branch B)

- **Status**: done (BRANCH B)
- **Prereq tasks**: 3
- **Files touched**: `.agent/scratch/chronobridge/phaseB/discovery_notes.md` (append a
  `## Decision` section)
- **Change shape**: Based on Task 3's finding, state explicitly which branch this
  contract follows: **BRANCH A** (existing ensemble data found — proceed to Task 6A) or
  **BRANCH B** (none found — proceed to Task 6B). This is a plain decision statement, not
  new research.
- **Verification**: `grep -qE '^## Decision' .agent/scratch/chronobridge/phaseB/discovery_notes.md && grep -qE 'BRANCH (A|B)' .agent/scratch/chronobridge/phaseB/discovery_notes.md`
- **Estimated time**: 2 min
- **Rollback (if this task only)**: revert the appended section

## Task 6A: build leave-one-ternary-out pipeline (ONLY if Task 5 = BRANCH A)

- **Status**: skipped (Task 5 recorded BRANCH B)
- **Prereq tasks**: 5
- **Files touched**: `.agent/scratch/chronobridge/phaseB/scripts/leave_one_out.py`,
  `.agent/scratch/chronobridge/phaseB/results_loo.json`
- **Change shape**: Using the ensemble data found in Task 3, hold out one of the 3
  ternary structures' basin, and attempt to reconstruct/predict it from the other 2 +
  glue chemical information (the concrete method depends on what format the found data
  is in — document the choice, mirroring how Phase A's Task 5/7 made and justified
  concrete method choices given an open-ended brief). Compare recovery quality against a
  naive baseline (e.g. nearest-neighbor-by-glue-similarity, or a random one of the other
  2 structures) with a bootstrap CI on the delta, per the contract's stated principle
  (statistically better than baseline, not an absolute threshold).
- **Verification**: `python -c "import json; d=json.load(open('.agent/scratch/chronobridge/phaseB/results_loo.json')); assert 'delta_ci_low' in d and 'delta_ci_high' in d"` (adjust key names to actual output) confirms a CI-based comparison was produced, not a bare point estimate.
- **Estimated time**: 15 min (open-ended; may need follow-up decomposition once Task 3's
  finding reveals the actual data shape)
- **Rollback (if this task only)**: `rm .agent/scratch/chronobridge/phaseB/scripts/leave_one_out.py .agent/scratch/chronobridge/phaseB/results_loo.json`

## Task 6B: document MD necessity + finalize prep (ONLY if Task 5 = BRANCH B)

- **Status**: done
- **Prereq tasks**: 5, 4
- **Files touched**: `.agent/scratch/chronobridge/phaseB/md_necessity.md`
- **Change shape**: Document why leave-one-ternary-out cannot proceed zero-GPU (no
  existing ensemble found) and estimate what new MD would require: number of systems (up
  to 3, one per ternary structure), a reasonable per-system simulation length for a
  short equilibration/production run sufficient for ChronoBridge/FP-detector to operate
  on (cite Phase A's own scale — ATLAS used 100 ns/1000 frames — as a reference point,
  not a mandate), and a rough GPU-hour estimate. This becomes the input for a follow-up
  contract's resource budget, not a request to submit anything now.
- **Verification**: `test -f .agent/scratch/chronobridge/phaseB/md_necessity.md && grep -qi 'GPU' .agent/scratch/chronobridge/phaseB/md_necessity.md`
- **Estimated time**: 8 min
- **Rollback (if this task only)**: `rm .agent/scratch/chronobridge/phaseB/md_necessity.md`

## Task 7: results document

- **Status**: done
- **Prereq tasks**: 6A or 6B (whichever ran)
- **Files touched**: `.agent/scratch/chronobridge/phaseB/results.md`
- **Change shape**: Final write-up: which branch occurred and why, PDB structures used,
  FP decoy design + example, and (branch A) leave-one-out metrics with CI + verdict, or
  (branch B) discovery finding + MD necessity estimate + explicit recommendation for the
  next contract's scope/budget.
- **Verification**: `grep -qE '^(BRANCH A|BRANCH B)' .agent/scratch/chronobridge/phaseB/results.md` (branch stated unambiguously near the top)
- **Estimated time**: 5 min
- **Rollback (if this task only)**: `rm .agent/scratch/chronobridge/phaseB/results.md`

## Task 8: update chronobridge slice status file

- **Status**: done
- **Prereq tasks**: 7
- **Files touched**: `.agent/status/chronobridge.md`
- **Change shape**: Update `remaining_actions`/`contract_pointers`/body to reflect Phase
  B's outcome (branch + verdict) and the next concrete step (either scope leave-one-glue-out
  next, or scope the MD-generation follow-up contract per Task 6B's estimate).
- **Verification**: `grep -q 'chronobridge-gspt1-leave-one-out-20260713' .agent/status/chronobridge.md`
- **Estimated time**: 3 min
- **Rollback (if this task only)**: revert via git (tracked file)

## Task 9: handoff + regenerate index + close contract

- **Status**: done
- **Prereq tasks**: 8
- **Files touched**: `.agent/status/chronobridge.md` (frontmatter bump via script),
  `.agent/handoffs/CURRENT.md` (regenerated), `.agent/handoffs/state/` (snapshot),
  `.agent/contracts/chronobridge-gspt1-leave-one-out-20260713.md` (`status: done`,
  Progress Log entry)
- **Change shape**: Run `./scripts/handoff.sh claude chronobridge`, then
  `./scripts/status.sh index`. Flip the contract's `status` to `done` and append a final
  Progress Log line summarizing the branch/outcome.
- **Verification**: `./scripts/handoff.sh claude chronobridge && ./scripts/status.sh index` exit 0; `grep -q 'status: done' .agent/contracts/chronobridge-gspt1-leave-one-out-20260713.md`
- **Estimated time**: 2 min
- **Rollback (if this task only)**: manually revert the contract frontmatter edit and
  re-run `./scripts/status.sh index`
