---
status: approved
slice: vav1-ubq
topic: ikzf3-gt-methodology-validation
date: 2026-07-14
owner: claude
requested: 2026-07-14
approved_by: sunghoon.kim (2026-07-14, "승인")
cross_slice: [aigen-fold-core]
triggers_matched:
  - "SLURM/GPU submission — CRBN-glue-IKZF3 structure prediction ±DDB1 across glues (kim account,
    un-containerized rootfs), + coord-GD refinement runs. GPU campaign."
  - "engine/pipeline change — extend api/pipeline.py builders to include DDB1 + a neosubstrate
    (IKZF3) chain in the input; refine the coord-GD loss (C2 angle + NAC band + sidechain-relaxed
    mask) in the rootfs engine copy (additive, env-gated)."
  - "4+ files — input builders (±DDB1, IKZF3) + GT-extraction + prediction runner + GT-reproduction
    measure + coord-GD refinement + results doc."
  - "ranking-adjacent semantics — secondary track links a predicted metric to known glue potency
    across IKZF3 structures (only as a GT-validated exploration, not a shipped ranker)."
---

# vav1-ubq — CRBN-neosubstrate productive-geometry methodology validation on IKZF3 ground truth

## Purpose

The entire VAV1 productive-geometry arc (COMPASS latent → coord-GD → DC50 discriminator) was crippled
by having NO experimental ground truth for the VAV1 productive ternary: every metric became circular
(reaching≠validation) or defaulted to activity proxies. The fix is to VALIDATE the methodology where
crystal ground truth EXISTS — CRBN-neosubstrate productive assemblies (9UUM = CRBN-glue-IKZF3-E2~Ub,
already held locally; extendable to 9UUQ/9V0C/9V0E/9V0F, other glues, same IKZF3). Establish whether
the 2-stage prediction reproduces the crystal productive geometry, quantify whether DDB1 is required
for a correct CRBN conformation, and re-anchor the coord-GD refinement to GT — BEFORE ever trusting or
transferring the method to VAV1.

Key GT already measured (9UUM crystal, this arc): the substrate IKZF3 lysine sits **17-21 Å** from the
ubiquitin Gly76 carbonyl (K158 17.3 Å, K172 20.6 Å; E2 Cys85 SG-Ub thioester intact 3.4 Å). So the
productive-COMPLEX resting geometry is ~17 Å, NOT near-attack — which vindicates the native prediction
(~17 Å) and shows the coord-GD near-attack forcing (2.6 Å) was not the crystal geometry.

## Scope

- PRIMARY (core Done): On 9UUM, build + run the CRBN-glue-IKZF3 prediction **±DDB1** and quantify
  reproduction of the crystal GT: (a) CRBN conformation Cα-RMSD vs the 9UUM CRBN; (b) IKZF3 neosubstrate
  placement RMSD vs crystal (CRBN-frame); (c) IKZF3 lysine Nζ → Ub-Gly76-C distance vs the GT (17-21 Å).
  Report the ±DDB1 delta (does DDB1 change the predicted CRBN conformation / placement toward the crystal).
- SECONDARY (in scope, staged): extend the same reproduction test to multi-glue IKZF3 (9UUQ Thalidomide
  / 9V0C Iberdomide / 9V0E Golcadomide / 9V0F Cemsidomide) as those structures are provided; if a
  predicted geometric metric tracks the glues' known potency ordering, report it (GT-validated only).
- SECONDARY (in scope, staged): re-anchor coord-GD to GT — refine the loss (C2 = distance + Bürgi-Dunitz
  angle; NAC distance band ~3.0-3.5 Å instead of unbounded pull; sidechain-relaxed atom mask instead of
  Nζ-only) and evaluate whether refined coord-GD reproduces a GT-consistent productive geometry (the
  ~17 Å resting placement, or a geometrically-sensible reactive state) rather than the crude jam.
- Reuse: api/pipeline.py builders (extend for DDB1 + IKZF3), the coord-GD engine/driver/measure/loss
  battery (C2 already exists), the un-containerized rootfs, 9UUM (local).

## Out of scope

- VAV1 prediction/steering — this contract validates the method on IKZF3 GT ONLY; transferring the
  validated method to VAV1 is a SEPARATE follow-up contract.
- Reviving the coord-GD reaching-efficiency DC50 discriminator as-is (NULL, closed) — the coord-GD
  refinement here is GT-anchored geometry reproduction, not a potency discriminator.
- Full CRL4 assembly dynamics / MD (the WTMetaD FES path is a separate, expensive lever).
- Shipping any production model / changing the v1.1 VAV1 ranker.
- Other neosubstrates (IKZF1 6H0F, GSPT1) — a broader panel is a possible later extension, not this.

## Success criteria (measurement + honest report; GT-anchored, no perf gate)

Produce a GT-reproduction table (per system, ±DDB1) with:
- CRBN conformation Cα-RMSD (predicted vs 9UUM crystal CRBN),
- IKZF3 neosubstrate placement RMSD (CRBN-frame, predicted vs crystal),
- IKZF3 lysine Nζ → Ub-Gly76-C distance (predicted) vs the crystal GT (17-21 Å),
- the ±DDB1 delta on each, with an explicit statement of whether DDB1 materially improves reproduction.
DONE = the 9UUM ±DDB1 reproduction table is produced with the crystal-GT comparison + the honest verdict
on (i) does the native 2-stage prediction reproduce the crystal productive geometry, (ii) does DDB1
matter. A result either way (reproduces / does not; DDB1 matters / not) is a valid, complete outcome —
this is a GT-anchored validation measurement. Multi-glue + coord-GD-refinement tracks report their own
GT-comparison tables when run. Verification command:
`python3 .agent/scratch/ikzf3_gt/gt_reproduce_analysis.py` → the per-system ±DDB1 table + verdict; plus
the prediction GPU jobs COMPLETED.

## Constraints

- GPU: kim account, un-containerized rootfs, --qos=normal, free-GPU selector (mem.free>75GB), output
  to kfs2 (NOT kfs5/kfs6). Standing SLURM pre-approval for this line of work (user, 2026-07-13/14).
  Diagnose-before-scaling: 9UUM ±DDB1 core FIRST; multi-glue + coord-GD refinement only after.
- Structures: 9UUM held locally (analysis/crl_integrative/refs/9UUM.cif). Multi-glue structures
  (9UUQ/9V0C/9V0E/9V0F) must be USER-PROVIDED (RCSB direct fetch is blocked in the sandbox) — the
  multi-glue track is gated on their availability; the core 9UUM track does not need them.
- Engine/pipeline edits: additive + env-gated in the ROOTFS copy only (host tree untouched); any
  api/pipeline.py extension (DDB1/IKZF3 builders) keeps the VAV1 path byte-identical by default.
- Scripts + outputs under .agent/scratch/ikzf3_gt/ + kfs2 run dirs.

## Resource budget

Modest core: 9UUM CRBN-glue-IKZF3 × {+DDB1, −DDB1} × a few seeds ≈ 4-12 short Boltz runs + zero-GPU
GT extraction/measure. Multi-glue adds ~2 conditions × N glues when provided. coord-GD refinement adds
a small sweep on 9UUM. Backfilled across free GPUs; analysis zero-GPU.

## Rollback plan

No production change (GT-anchored validation; nothing shipped). `scancel` any running jobs; delete the
kfs2 output dirs; any rootfs engine edit is env-gated + `git apply -R`-able (host tree untouched);
api/pipeline.py extension defaults to byte-identical VAV1 path. Scripts are scratch.

## Approval

- requested: 2026-07-14
- approved by: sunghoon.kim (2026-07-14, "승인")
