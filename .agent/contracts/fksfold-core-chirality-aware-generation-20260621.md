# Contract — chirality-aware structure generation (config → encoder wiring)

- **Status**: approved
- **Slice**: vav1-ubq
- **Requested**: 2026-06-21
- **Approved by**: user (2026-06-21)

## Goal (one sentence)
Make AIGEN-Fold/Boltz-2 outputs respect the **input ligand chirality** for the VAV1 glue
enantiomers (g3=S vs g4=R, chemotype B; g1/g2 chemotype A) — fixing the *real* causes
established by a runtime code trace + 3 confirmatory probes (the model is **NOT
architecture-blind**; the failure is a measurement artifact + a chiral-steering force
imbalance, with a secondary unused-feature wiring gap) — via a cheapest-first staged
program: **Stage 0** (zero-GPU measurement fix) → **Stage A** (strengthen the existing
chiral steering, no retrain) → **Stage B** (wire the already-computed `ref_chirality`
into the encoder, light finetune).

## Current State (diagnosis, high confidence — see `.agent/scratch/chirality_diagnosis_and_plan_20260621.md`)
- Input isomeric SMILES preserved (g3=S/g4=R), reaches encoder via **signed** `ref_pos`
  (`encodersv2.py:263`, not reflection-invariant); chiral steering ON but weak
  (`ChiralAtomPotential` guidance_weight=0.10 vs `--interface_lambda 20`, `potentials.py:725`);
  loss implicitly chiral (det=+1 align, `loss/diffusionv2.py:73-78`).
- **Probe 3 (decisive)**: g3(S) and g4(R) outputs both collapse to the SAME R handedness in
  **16/16 seeds** (signed triple-vol ≈ -2.66 vs -2.68) = sampling force-imbalance, not
  representational limit.
- "InChIKey collapse" = post-hoc re-perception from bond-less coordinate PDB (measurement
  artifact). Committed offender: `crl_glue_md_20260618/build/param_tleap.py:105`
  (`AssignStereochemistry(force=True)` on coords after template bond assignment).
- Secondary gap: categorical `ref_chirality` computed (`featurizerv2.py:1227-1232,:1549`) but
  consumed by ZERO model code (encoder concat `encodersv2.py:316-339` omits it).
- Runtime featurizer lives in docker image `fksfold-boltz:steering-v3` at `/app/src/boltz`
  (NOT the host src tree); fork model/steering = host working tree.

## Constraints
- **Allowed**: Stage 0 = host analysis/build code (`analysis/crl_integrative/`, glue-MD `build/`)
  + new identity/metric utilities. Stage A = config/env-var override of chiral potential params,
  delivered by overlay-mounting an edited `potentials.py` into the image (default-OFF, no
  `main.py`/CLI change, no retrain). Stage B = zero-init widen `embed_atom_features` + one-hot
  `ref_chirality` concat + ckpt zero-pad surgery on a COPY + short conditioning finetune.
- **Forbidden**: aborting/disturbing the running MD job 8098; modifying the production checkpoint
  in place (surgery on a copy only); enabling the strengthened steering by default; any Stage C
  retrain or Stage D SAR claim under this contract.
- **External**: GPU stages (A, B) behind the AGENTS.md approval gate (active contract <7d + user
  go); ckpt must load **bit-identical** after zero-init surgery (proven before any finetune);
  byte-faithful seed314 metad env where reused.

## Non-Goals (out of scope — gated follow-ons, NOT this contract)
- **Stage C**: full finetune with an explicit signed-improper chirality LOSS term. Only justified
  if Stage A AND Stage B both fail to make g3/g4 output handedness track input. Separate contract.
- **Stage D**: whether corrected chirality predicts the >100× enantiomer SAR — a pose is geometry,
  not affinity; needs MD/MM-GBSA/ΔΔG per-enantiomer (lab rule: no-GT → activity validators).
  Separate downstream workstream.
- Affinity-head (`boltz2_aff.ckpt`) chirality surgery.
- Re-running / re-building the in-flight glue-MD (8098) for chirality (its purpose is
  chemotype/control, not enantiomer SAR).

## Done When
- **Stage 0** (zero-GPU): (a) `build/lig_identity.py` returns DISTINCT input-graph identities
  g3→`BNPXZVKFXBHEKC-DEOSSOPVSA-N` (S) vs g4→`-XMMPIXPASA-N` (R) — no coordinate re-perception;
  (b) `param_tleap.py:105` coord re-perception removed (stereo from template), re-run `make_ligand`
  for g3/g4 confirms tag-correct; (c) `analysis/crl_integrative/crl_chirality.py` (signed
  triple-product + signed improper + template-correct CIP) wired into `glue8_pose_scan.py`, and on
  existing g3/g4 outputs it reports the current collapse (both R) AND fires an input≠pose WARNING.
- **Stage A**: an env-var override raises `ChiralAtomPotential` weight/shrinks buffer; a g3+g4
  single-seed smoke per tier scored by `crl_chirality`. **GO** = output stereocenter sign tracks
  input (g3→S, g4→R) and, on the winning-tier 16-seed sweep, ≥14/16 track input WITHOUT interface
  degradation (iptm + key-residue contacts vs baseline). **NO-GO** (can't flip, or flipping breaks
  the interface) is documented with evidence → escalate to Stage B. Either way the gate verdict is
  recorded.
- **Stage B**: (g1) ckpt loads bit-identical pre-finetune (zero-init identity); (g2)
  `ref_chirality` reaches the encoder (shape == 7) and differs g3 vs g4 at the stereocenter row;
  (g3, decisive) post-finetune `crl_chirality` FLIPS sign g3 vs g4 (g3→S, g4→R) in ≥14/16 seeds
  with no held-out non-chiral lDDT/RMSD regression. NO-GO documented → Stage C contract.
- **Verification command**: `python analysis/crl_integrative/crl_chirality.py <g3_out> <g4_out>`
  → prints distinct signed-improper signs + template-correct CIP per pose.

## Implementation Steps (high level — full decomposition in /write-plan)
1. Stage 0 measurement fix (identity + param_tleap + pose metric). verify: distinct identities, WARNING fires.
2. Stage A steering-override + 3-tier smoke + winning-tier sweep. verify: sign tracks input ≥14/16, interface intact.
3. Stage B encoder widen + ckpt surgery + identity check + finetune + Probe-3 re-measure. verify: sign flips post-finetune.

## Risks
- **Stage A**: strong chiral guidance warps geometry or breaks the interface pose (mitigate: tiered,
  scored by iptm/contacts/PoseBusters; default-OFF).
- **Stage B**: ckpt surgery non-identical (mitigate: zero-init + bit-identical gate before finetune);
  catastrophic forgetting (mitigate: general-PDB-ligand mix in finetune set).
- **Empty chiral tensor**: if `chiral_atom_index.shape[1]==0` for these ligands the potential is a
  no-op → Stage A cannot work and the problem is upstream featurization (pre-check before Stage A).

## Rollback
- Stage 0: `git revert` (pure analysis/build code).
- Stage A: default-OFF env var — simply don't set it; remove the overlay mount. No state change.
- Stage B: finetuned weights are NEW artifacts; revert = point back to the original checkpoint;
  encoder code change `git revert`. Production ckpt never mutated in place.
