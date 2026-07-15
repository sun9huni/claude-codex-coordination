---
status: approved
slice: fragmap
topic: vav1-iface-anchor
date: 2026-05-21
owner: claude
approved_by: claude (user said "모두 진행" 2026-05-21)
decisions:
  - 3 conditions × 5 compounds = 15 cells (8-GPU parallel)
  - Option A = Boltz YAML `contact:` constraint (chain-chain CA-CA anchor)
  - Option B = pocket extension with crystal interface loops (VAV1 32-41 + CRBN 104-109)
  - Option C/D skipped (require code change)
  - Candidates: VAV1_345, VAV1_489, VAV1_209, VAV1_292, VAV1_411
---

# VAV1 inter-chain anchor sweep — test if rigid-body mispositioning is fixable

## Purpose

Test 3 YAML-only interventions designed to lock CRBN-VAV1 rigid-body
geometry. Diagnostic finding: 139/139 compounds have VAV1 mispositioned by
17 Å mean (ρ=−0.44 with F1). Single W400 anchor (gen355 ↔ gen16-19)
insufficient; crystal has 73 CA-CA contacts and a 2nd anchor at
CRBN gen106 ↔ VAV1 gen35 (6.16 Å) currently unconstrained.

## Conditions (parallel)

| | Pocket constraint | Contact constraint |
|---|---|---|
| baseline | 14-19 + 305-355 | none | (already in norm143_full) |
| **A** (contact) | 14-19 + 305-355 | `[A,106]↔[B,35]` + `[A,352]↔[B,16]` |
| **B** (pocket-ext) | 14-19 + 32-41 + 104-109 + 305-355 | none |
| **A+B** | 14-19 + 32-41 + 104-109 + 305-355 | same as A |

Contact distances from crystal (gen frame):
- `[A,106 GLY] ↔ [B,35 GLY]`: 6.16 Å → max_distance 7.0
- `[A,352 HIS] ↔ [B,16 ASP]`: 5.82 Å → max_distance 7.0

## Candidates

| compound | DC50 (nM) | baseline F1 | baseline VAV1 offset |
|---|---|---|---|
| VAV1_345 | 3.53 | 0.571 | 5.02 Å (best in dataset) |
| VAV1_489 | 2.84 | 0.667 | TBD |
| VAV1_209 | 7.35 | 0.667 | TBD |
| VAV1_292 | 12.68 | 0.667 | TBD |
| VAV1_411 | 1.99 | 0.571 | TBD |

## Done When

1. 15 cells COMPLETED (5 × 3 conditions)
2. Per-cell: `vav1_rigid_body_offset` (new metric) + `ligand_target_contact_f1` measured
3. Comparison table baseline vs A vs B vs A+B
4. Decision criterion:
   - If A+B (or A alone) reduces VAV1 offset by ≥5 Å mean: **paradigm confirmed**, recommend production YAML change
   - If no reduction: rigid-body issue not fixable by YAML, escalate to code-level intervention

## Non-Goals

- No code changes (Boltz src untouched)
- No new SLURM infrastructure
- No multi-seed (use seed=16 P7 baseline for all)
- No CDK2 or expanded VAV1 batch in this contract

## Verification

- `python -c "import yaml; yaml.safe_load(open(...))"` on each new YAML
- `bash -n workflow/slurm_vav1_iface_anchor_sweep.sh`
- After completion: `python analysis/compare_ternary_metrics_9nfr.py` + custom `vav1_rigid_body_offset` script
