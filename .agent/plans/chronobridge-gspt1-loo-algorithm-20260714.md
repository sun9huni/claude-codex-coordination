---
contract: .agent/contracts/chronobridge-gspt1-loo-algorithm-20260714.md
slice: chronobridge
status: done
total_tasks: 7
estimated_total_min: 36
---

# Plan: chronobridge GSPT1 leave-one-out — algorithm spec + 3-fold decoy completion

## Task 1: verify GSPT1/DDB1/CRBN sequence identity across 5HXB/6XK9/9HNE

- **Status**: done
- **Prereq tasks**: none
- **Files touched**: `.agent/scratch/chronobridge/phaseB/sequence_check.md`
- **Change shape**: For each of GSPT1, DDB1, CRBN, extract the residue sequence (one-letter
  code, standard residues only) from each of the 3 structures (5HXB.pdb, 6XK9.pdb via
  Bio.PDB.PDBParser; 9HNE.cif via Bio.PDB.MMCIFParser — using whichever "copy" chain per
  structure per pdb_notes.md's chain-lettering). Compare pairwise: are the 3 depositions'
  GSPT1 sequences identical? DDB1? CRBN? Report residue counts and any mismatches (position
  and identity) explicitly — do not just report "mostly the same," give exact counts.
  Conclude whether direct (uncropped) Cα-based featurization across all 3 structures is
  valid, or whether an alignment/crop step (like Phase A's 1k5n_A vs 1r6w_A handling) is
  needed for the algorithm spec (Task 3).
- **Verification**: `test -f .agent/scratch/chronobridge/phaseB/sequence_check.md && grep -qE 'GSPT1.*(IDENTICAL|MISMATCH)' .agent/scratch/chronobridge/phaseB/sequence_check.md` (adjust exact grep to whatever explicit verdict phrasing is used, but a clear per-protein verdict must be present)
- **Estimated time**: 5 min
- **Rollback (if this task only)**: `rm .agent/scratch/chronobridge/phaseB/sequence_check.md`

## Task 2: add 9HNE support + build a 9HNE-involving decoy

- **Status**: done
- **Prereq tasks**: 1
- **Files touched**: `.agent/scratch/chronobridge/phaseB/scripts/build_decoys_9hne.py` (new
  script, or an additive extension — do NOT modify `build_decoys.py`'s existing 5HXB/6XK9
  logic), `.agent/scratch/chronobridge/phaseB/decoys/` (new decoy file(s))
- **Change shape**: Using Task 1's sequence findings, build at least one decoy involving
  9HNE as backbone or glue donor (e.g. a foreign glue from 5HXB or 6XK9 placed into 9HNE's
  CRBN pocket, via Bio.PDB.MMCIFParser + the same CRBN-chain Kabsch-superposition method as
  `build_decoys.py`, adapted for 9HNE's A/B/C(+D/E/F) chain convention and mmCIF residue-id
  scheme). Run the same clash check as Task 4 of the prior contract (min heavy-atom distance,
  count of pairs under 2.4 Å threshold) and report it. Do NOT modify the existing
  `build_decoys.py` file or its 2 already-built 5HXB/6XK9 decoys.
- **Verification**: `ls .agent/scratch/chronobridge/phaseB/decoys/*9hne* 2>/dev/null | wc -l` → at least 1, AND `git diff --stat -- .agent/scratch/chronobridge/phaseB/scripts/build_decoys.py .agent/scratch/chronobridge/phaseB/decoys/5hxb_glue_into_6xk9_backbone.pdb .agent/scratch/chronobridge/phaseB/decoys/6xk9_glue_into_5hxb_backbone.pdb` shows no changes (existing decoys/script untouched)
- **Estimated time**: 10 min
- **Rollback (if this task only)**: `rm .agent/scratch/chronobridge/phaseB/scripts/build_decoys_9hne.py .agent/scratch/chronobridge/phaseB/decoys/*9hne*`

## Task 3: write the leave-one-out algorithm spec (3-fold)

- **Status**: done
- **Prereq tasks**: 1, 2
- **Files touched**: `.agent/scratch/chronobridge/phaseB/loo_algorithm_spec.md`
- **Change shape**: Document, per fold (A=hold out 5HXB, B=hold out 6XK9, C=hold out 9HNE):
  (a) calibration set = pooled MD-ensemble frames from the OTHER 2 systems (once MD exists),
  (b) test set = held-out system's own real-ensemble frames + that fold's decoy structure's
  own relaxed-ensemble frames (from Task 2 or the prior contract's Task 4, once each decoy is
  itself simulated), (c) statistic: reuse Phase A's `evaluate.py` pattern (PCA-residual +
  kNN FP-detector calibrated on the calibration set's pooled Cα-distance features, scored on
  the test set, bootstrap CI on the real-vs-decoy FP-score separation) — state explicitly
  whether Phase A's code is reusable as-is or needs adaptation given Task 1's sequence
  findings. Define the pass/generalizes bar (e.g. how many of the 3 folds need a
  CI-excluding-zero separation to call the method "generalizes"). Also write a dedicated
  section stating ChronoBridge's role is per-system QC ONLY (confirm each system's own
  ensemble forms one coherent connected component in the diffusion-map affinity graph, per
  Phase A's `chronobridge.py` diagnostic — not used for any cross-system prediction).
- **Verification**: `grep -cE '^### Fold [ABC]' .agent/scratch/chronobridge/phaseB/loo_algorithm_spec.md` → 3, and `grep -qi 'ChronoBridge' .agent/scratch/chronobridge/phaseB/loo_algorithm_spec.md` (role documented)
- **Estimated time**: 8 min
- **Rollback (if this task only)**: `rm .agent/scratch/chronobridge/phaseB/loo_algorithm_spec.md`

## Task 4: update MD necessity estimate (3 → 6 systems)

- **Status**: done
- **Prereq tasks**: 3
- **Files touched**: `.agent/scratch/chronobridge/phaseB/md_necessity.md` (append a new
  section, do not rewrite the existing 3-system analysis — keep it as the historical
  starting point and layer the update on top)
- **Change shape**: Add a `## Update (2026-07-14): 6 systems, not 3` section: 3 native
  structures + 3 decoy structures (one per fold, per Task 3's spec) each need their own MD
  ensemble, roughly doubling the earlier GPU-hour estimate (~30-80 GPU-hours → ~60-160
  GPU-hours, ~100 GPU-hours central estimate, same per-system ns assumptions as before
  unless Task 2/3 revealed a reason to change them).
- **Verification**: `grep -q '## Update' .agent/scratch/chronobridge/phaseB/md_necessity.md && grep -qi '6 system' .agent/scratch/chronobridge/phaseB/md_necessity.md`
- **Estimated time**: 3 min
- **Rollback (if this task only)**: revert the appended section

## Task 5: results document

- **Status**: done
- **Prereq tasks**: 4
- **Files touched**: `.agent/scratch/chronobridge/phaseB/loo_algorithm_results.md`
- **Change shape**: Summarize: sequence-identity finding (Task 1), the new 9HNE decoy +
  clash result (Task 2), the 3-fold algorithm spec pointer (Task 3), and the updated
  6-system MD estimate (Task 4). State clearly this contract is zero-GPU design/prep work;
  the next contract (separate, B200) executes the actual MD using this spec.
- **Verification**: `test -f .agent/scratch/chronobridge/phaseB/loo_algorithm_results.md`
- **Estimated time**: 5 min
- **Rollback (if this task only)**: `rm .agent/scratch/chronobridge/phaseB/loo_algorithm_results.md`

## Task 6: update chronobridge slice status file

- **Status**: done
- **Prereq tasks**: 5
- **Files touched**: `.agent/status/chronobridge.md`
- **Change shape**: Update `remaining_actions`/`contract_pointers`/body: algorithm spec +
  3-fold decoys done; next step is a DECISION to approve the separate B200 MD-generation
  contract (real SLURM/GPU approval gate, ~6 systems / ~100 GPU-hours central estimate per
  the updated md_necessity.md).
- **Verification**: `grep -q 'chronobridge-gspt1-loo-algorithm-20260714' .agent/status/chronobridge.md`
- **Estimated time**: 3 min
- **Rollback (if this task only)**: revert via git (tracked file)

## Task 7: handoff + regenerate index + close contract

- **Status**: done
- **Prereq tasks**: 6
- **Files touched**: `.agent/status/chronobridge.md` (frontmatter bump via script),
  `.agent/handoffs/CURRENT.md` (regenerated), `.agent/handoffs/state/` (snapshot),
  `.agent/contracts/chronobridge-gspt1-loo-algorithm-20260714.md` (`status: done`,
  Progress Log entry)
- **Change shape**: Run `./scripts/handoff.sh claude chronobridge`, then
  `./scripts/status.sh index`. Flip the contract's `status` to `done` and append a final
  Progress Log line.
- **Verification**: `./scripts/handoff.sh claude chronobridge && ./scripts/status.sh index` exit 0; `grep -q 'status: done' .agent/contracts/chronobridge-gspt1-loo-algorithm-20260714.md`
- **Estimated time**: 2 min
- **Rollback (if this task only)**: manually revert the contract frontmatter edit and
  re-run `./scripts/status.sh index`
