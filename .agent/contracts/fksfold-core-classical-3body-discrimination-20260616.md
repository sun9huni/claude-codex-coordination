# Contract — classical non-additive three-body patch discrimination (CNTP-test)

- **slice**: aigen-fold-core
- **status**: approved
- **approval**: requested 2026-06-16 · approved by: user ("맞다면 그대로 계획 진행" — 검증 후 진행, conditional pre-approval met) 2026-06-16
- **parent**: fksfold-core-glue-synth-constraint-20260616 (this resolves its open "constraint encoding" decision: the synthesis SELECTOR = a self-implemented classical non-additive three-body score)

## Hypothesis (X — one sentence)

A **self-implemented, no-fit classical non-additive three-body score** (ΔBSA_3,
H-bond bridge chain, then induced-dipole polarization W3_pol) ranks the TRUE ternary
target patch above pairwise-plausible decoys — beating a pairwise-additive control by
ΔAUROC ≥ 0.10 AND recovering the true patch at top-1/top-3 — on the held-out GT for
Nek7 (9H59), PDE6D (9DWW), CK1α (9OTY), establishing (without QM) whether a classical
three-body term can select the productive patch (→ usable to SYNTHESIZE a Boltz
constraint) or whether the discriminating signal is genuinely electronic (→ QM needed).

## Scope (zero-GPU, no Boltz)

Staged, no-fit, with a pairwise control at every stage:
- **Stage 0** — decoy set: per target generate decoys that are PAIRWISE-PLAUSIBLE but
  three-body-broken (not just far-away), drawn from the distribution a synthesis pose
  search would propose (rigid placements on the CRBN–glue composite surface; glue-bridge
  broken; wrong CRBN–target orientation with contacts retained). Decoy quality is the
  make-or-break — too-easy decoys invalidate the test.
- **Stage 1** — ΔBSA_3 alone (BSA_ABC − BSA_AB − BSA_BC). lightest; run FIRST.
- **Stage 2** — H-bond bridge chain alone (Σ H(CRBN,glue)·H(glue,target)·G_angle).
- **Stage 3** — z-normalized ΔBSA_3 + Hbond (NO fitted weights; z-score or fixed α=β=1).
- **Stage 4** — add induced-dipole W3_pol (Thole-damped, charges = FF/AM1-BCC prep,
  polarizabilities from tables; with solvent screening, NOT vacuum) — only if 1–3 insufficient.
- pairwise-additive control (S_AB+S_BC+S_AC analogues) at each stage.

## Out of scope

- Any Boltz/GPU run — that is the NEXT contract, gated on this passing.
- Particle-resampling injection of the score — EMPIRICALLY bounded: the deep-sampling
  falsification WAS p=8 SMC resampling by a steering score and got 0/64 on blind targets.
  The score's role here is to SELECT a patch for CONSTRAINT synthesis, not to reweight
  Boltz generation.
- QM (xTB/FMO) — only escalate if classical three-body fails to discriminate.
- Fitting any weights to the n=3 targets (overfit/circularity ban).
- Using ternary-GT contact geometry to BUILD the score (circularity ban) — score uses
  only glue-in-CRBN + target monomer + the candidate placement.

## Triggers matched

- Shared-storage / repo writes (new analysis scripts; likely 4+ files). No SLURM, no
  GPU, no src/ change, no scorer fork.

## Success criteria (no-fit)

PASS (per stage, vs pairwise control):
- native-vs-decoy AUROC ≥ 0.70, AND
- **top-1 (or top-3) recovery of the true patch** (stronger than AUROC — synthesis uses
  the top pose), AND
- three-body beats pairwise control by ΔAUROC ≥ 0.10 (proves non-additivity is needed),
- with NO target-specific fitted weights.
FAIL: true patch not enriched / favorable decoys dominate / pairwise does equally well.
- H-bond-chain failing on a hydrophobic glue is per-class, not global failure.

## Resource budget

zero-GPU, CPU-only (gemmi geometry; SASA via freesasa or equivalent; small induced-
dipole linear solve for Stage 4). Hours of CPU.

## Rollback

Pure analysis scripts under analysis/. Delete to undo. No SLURM, no shared-config, no
src/, no sibling-slice touch.

## On the result

- PASS (≥ Stage 3, classical) → green-light the synthesis run: score-guided pose search
  → top-patch residues → Boltz constraint channel (proven basin-injection, 0.58 ref) →
  best-of-N DockQ on Nek7/PDE6D (parent contract).
- PASS only with Stage 4 (polarization) → polarization is the load-bearing classical term.
- FAIL even with polarization → discriminating signal is electronic (charge-transfer/
  exchange) → escalate ONLY those residue clusters to xTB/FMO (m-relativity dependency).
This also serves the grant logic: classical non-additive control BEFORE any quantum claim.
