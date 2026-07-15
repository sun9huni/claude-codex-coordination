---
status: approved
approved_by: claude (proceed signal from user 2026-05-21)
decisions:
  - 3-chain pilot (CRBN+CDK2+ligand), no CyclinE1
  - inner-shell 8 CDK2 residues (F80, E81, F82, L83, H84, D86, K89, Q131)
  - W400 anchor = CDK2 [11, 12, 13, 14] (G-loop, interface CA-CA overlap)
slice: fragmap
topic: cdk2-9d0w-pilot
date: 2026-05-21
owner: claude
---

# CDK2/9D0W cocrystal pilot — apply structure-driven workflow to a new MGD target

## Purpose

Validate that the 9NFR-derived corrected YAML pattern generalizes to a
second MGD ternary target (CDK2/CyclinE1 via Cpd 4, PDB 9D0W). Success
= reproduce the cocrystal ligand-CDK2 contact pattern from a single
generation. If pilot works, opens path to CDK2 MGD screening (Kymera +
Plexium series).

## Current State

- 9NFR pipeline is production-ready (P7, lambda=20, FragMap target_occupancy r10, light filter).
- Ground truth extracted to `examples/9d0w/9d0w_ground_truth_report.md` +
  `9d0w_ground_truth.json`.
- CDK2 chain mapping: gen frame = ref frame (offset 0). CRBN offset +45,
  matching 9NFR.
- No CDK2/CyclinE1 generations attempted yet.

## Assumptions And Questions

Assumptions:
- The 9NFR P7 setup (interface_lambda=20, npart=8, FragMap r10, biophysical_hybrid)
  is target-agnostic and transfers without re-tuning.
- CDK2 ATP-pocket binding (a much deeper, more enclosed pocket than VAV1
  SH3) does not require a different steering profile. **High risk** — VAV1
  was a surface interaction, CDK2 is a buried ATP pocket.
- CyclinE1 (chain D in 9D0W) can be modeled or omitted. **Decision needed**:
  include CyclinE1 as 4th chain, or model CDK2 alone?
- The FragMap NPZ (`silcs_oracle_real/ternary_r2_maps.npz`) was generated
  against VAV1/9NFR coords. For 9D0W it is **CRBN-aligned only** — the
  target-side FragMap signal will be near-random. So target_occupancy
  FragMap contribution should be expected ≈ 0 for the pilot; W400 + pocket
  constraints + interface_lambda are the real drivers.

Open questions:
- Include CyclinE1 (chain D) in YAML?
- W400-equivalent anchor: which CDK2 residue pairs with CRBN W400/355?
  Candidate from CA-CA interface: K6, G11-T14, R36. **Recommend T14** —
  closest to G-loop, structurally analogous to VAV1 16-19.
- Which CDK2 pocket residues for inner-shell constraint? Inner 8 (F80-Q131)
  or wider 22-residue 5Å shell?

Tradeoffs:
- Tight constraint (8 inner residues) → faster convergence, risk of over-anchor
  collapse (Phase 1 lesson).
- Wide constraint (22 residues 5Å) → slower, less precise.
- Recommend tight (8) for pilot, mirror 9NFR's 6-residue corrected pattern.

## Constraints

Allowed change scope:
- New YAML: `examples/9d0w/9d0w_cpd4_cdk2.yaml`
- (Optional) new SLURM wrapper: `workflow/slurm_9d0w_cpd4_pilot.sh`
- (Optional) new biophysical config copy if anchor changes

Forbidden change scope:
- No changes to `src/boltz_extension/steering/*` (target-agnostic).
- No new FragMap NPZ generation (use existing CRBN-aligned grids).
- No new scoring mode.

External constraints:
- SLURM submission must be approved by user (hook auto-blocks `sbatch`
  without active contract under .agent/contracts).
- Shared GPU partition `gpu`, qos=high, single A100 (1 GPU × ~10 min).
- Run as `kim` (file ownership convention).

## Non-Goals

- Not running a multi-compound batch in this contract. Pilot = 1 compound (Cpd 4 cocrystal).
- Not introducing W400-equivalent code changes; just reuse existing `--w400_*` flags
  with CDK2 residue indices.
- Not generating new FragMap grids.
- Not modeling CyclinE1 inhibitor binding (CyclinE1 is co-target, not target).

## Done When

1. `9d0w_cpd4_cdk2.yaml` exists, validates with `python -m boltz.main predict --help`
   smoke (no submit).
2. Pilot generation completes (single SLURM job, ~10 min).
3. Generated PDB has:
   - ligand-CDK2 F1 > 0 (barrier broken)
   - CRBN-CDK2 iface F1 > 0
   - target_min_dist < 8 Å
4. Comparison report at `analysis/9d0w/9d0w_cpd4_pilot.md`.
5. Status updated: `.agent/status/fragmap.md` + `.agent/handoffs/CURRENT.md`.

## Implementation Steps

1. Draft `examples/9d0w/9d0w_cpd4_cdk2.yaml`:
   - Chain A = CRBN sequence (reused from 9NFR YAML)
   - Chain B = CDK2 (298 aa, from `9d0w_ground_truth_report.md`)
   - Chain C = ligand SMILES (RCSB canonical for A1A1I)
   - Pocket 1 = CRBN 305-355 (14 residues, same as 9NFR)
   - Pocket 2 = CDK2 [80, 81, 82, 83, 84, 86, 89, 131] (8 inner shell)
   verify: yaml lint + Boltz parser dry-run

2. Draft `workflow/slurm_9d0w_cpd4_pilot.sh`:
   - Same docker invocation pattern as 9NFR P7
   - `--w400_vav1_residues 11,12,13,14` (CDK2 G-loop, analog of VAV1 16-19)
   - Single GPU, single seed (16), npart=8
   - **Do not submit** — user-approval gate
   verify: `bash -n` syntax + manual review

3. Pause for user approval before `sbatch`.

4. After submit + completion: write `compare_generated_to_9d0w.py` analog
   of `compare_generated_to_9nfr.py` with new chain map (`A:B:45`, `B:C:0`).
   verify: F1, RMSD, contact recall against `9d0w_ground_truth.json`.

5. Update CURRENT.md Phase 7 to "in progress" with results; close if pilot
   succeeds, escalate to /brainstorm batch contract if not.

## Change Discipline

- Simplest adequate approach: pure YAML + SLURM additions, zero src changes.
- New abstractions: none.
- Unrelated code touched: none.
- Pre-existing dead code: none observed in pilot scope.
- Request-to-diff trace: user "Phase 7 진행" → CDK2/9D0W contract → 1 YAML + 1 SLURM + 1 analysis script.

## Verification

- `python -c "import yaml; yaml.safe_load(open('examples/9d0w/9d0w_cpd4_cdk2.yaml'))"`
- `bash -n workflow/slurm_9d0w_cpd4_pilot.sh`
- After completion: contact F1 against ground truth, clash count, iface F1.
- Manual check: pymol/chimera overlay of generated PDB vs 9D0W (CDK2 hinge alignment).

## Risks

- Regression risk: none (additive only).
- Integration risk: FragMap NPZ is CRBN-aligned for VAV1/9NFR coords;
  target-side FragMap signal will be near-random for CDK2. Steering may
  rely solely on pocket constraints + W400 + interface_lambda.
- Hidden dependency: CDK2 hinge region (F80-H84) is conserved across kinases;
  the FragMap probe densities in that region (if any signal leaks) may pull
  ligand toward a non-CDK2 kinase-like pose. Mitigation: tight pocket
  constraint + monitor F1 vs ground truth.

## Rollback

- Revert strategy: YAML + SLURM are net-new files. Delete to remove.
- Containment strategy: pilot is 1 GPU × 10 min, no shared state mutation,
  output to scratch dir.
