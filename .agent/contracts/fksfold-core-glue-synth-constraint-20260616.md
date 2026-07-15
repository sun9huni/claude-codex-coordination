# Contract — glue-synthesized placement constraint (crystal-free basin injection)

- **slice**: aigen-fold-core
- **status**: approved
- **approval**: requested 2026-06-16 · approved by: user ("승인") 2026-06-16

## Hypothesis (X — one sentence)

A placement constraint **synthesized from the glue alone** (glue-in-CRBN geometry
→ glue solvent-exposed face → target-side contact set), fed through Boltz-2's
existing pocket/contact constraint channel, can raise best-of-N DockQ on
prior-blind OOD targets (Nek7 9H59, PDE6D 9DWW) from the blind baseline (~0.007)
to **≥ 0.25–0.30** (halfway to the crystal-derived-pocket ceiling 0.58) — WITHOUT
using the ternary crystal — thereby showing the crystal pocket can be replaced as
the basin source by the (in-distribution) glue.

Rationale: the three-body→pair marginalization B_AC(a,c)=Σ_b T(a,b,c) reduces, for
a FIXED glue pose, to synthesizing an effective CRBN–target placement constraint
from the known linchpin. This addresses the model's pairwise-representation limit
for GEOMETRY (placement) — explicitly NOT the force-field many-body energy problem.

## Scope

- Build a glue-synthesized constraint per target from the **crystal CRBN–glue
  subset** (extract CRBN chain + glue ligand from the GT cif; the recruited-target
  chain and its crystal placement are NOT used). CRBN–glue binding is
  in-distribution and independently determinable, so no ternary-placement info leaks.
- Identify the glue's solvent-exposed heavy atoms (those not buried against CRBN)
  = the face that recruits the target.
- Synthesize a target-side contact/pocket constraint from that exposed face and
  feed it to Boltz-2 via the existing `constraints:` channel (the same channel that
  rescued Nek7 0.007→0.58 with the crystal pocket).
- Targets: Nek7 (9H59), PDE6D (9DWW) = clean blind collapses; CK1α (9OTY) = positive
  control (must not break an already-working crystal-free case).
- Score best-of-N DockQ vs held-out GT; compare to the two reference points already
  measured: blind ~0.007 and crystal-pocket 0.58.

## Out of scope

- Fully Boltz-predicted glue-in-CRBN binary pose — that is the **staged v2**, run
  ONLY if this v1 (crystal CRBN-glue subset) confirms the idea.
- Raw attention-bias / pair-representation injection (§15–16 of the brainstorm dump)
  and any model RETRAINING — we use the existing constraint channel only, no retrain.
- Quantum / W3_elec / FMO / Phi_Qcorr cooperativity ENERGY — different problem
  (energy non-additivity); pairwise projection would defeat it. Placement geometry only.
- PROTAC targets; new-corpus curation; 9OS2 (input-incomplete, confounded).
- Learned complementarity models — v1 uses a simple geometric/shape complementarity.

## Triggers matched

- SLURM GPU submission (Boltz-2 prediction array) → PreToolUse sbatch gate.
- Shared-storage writes under /mnt/data/users/ubuntu/workspace/.
- New constraint-synthesis script (analysis-layer, not src/) + likely 4+ files.

## Success criteria

1. **PRIMARY**: best-of-N (N ≥ 16) glue-synthesized-constraint DockQ for **both**
   Nek7 (9H59) and PDE6D (9DWW) **≥ 0.25** (target band 0.25–0.30), vs blind ~0.007.
   → idea CONFIRMED: glue synthesizes a usable basin without the crystal.
2. **CONTROL**: CK1α (9OTY) with the synthesized constraint does NOT drop below its
   crystal-free baseline (~0.73) — the synthesized constraint doesn't harm a working case.
3. **NULL is informative**: if both blind targets stay < 0.10, the glue-exposed-face
   signal is insufficient (complementarity too weak / pose underdetermined) → the
   full §1–22 build is NOT justified; record and stop.
Verification: a `collect_*` best-of-N table (DockQ vs GT) with the three reference
columns (blind / glue-synth / crystal-pocket) per target.

## Resource budget

3 targets × N≈16–32 seeds × (1 constraint variant for v1) ≈ 50–100 Boltz-2 ternary
predictions, gpu:1 each. QOS high (throttled submit, ≤15 in-flight as before).
A few GPU-hours. Physical GPUs ample. Zero new wet-lab.

## Rollback

Pure compute + one new constraint-synthesis script (analysis layer). No src/ change,
no scorer fork, no shared-config edit, no sibling-slice touch. Undo: `scancel`,
delete output dir under /mnt/data/users/ubuntu/workspace/ (sudo -u ubuntu).

## Open implementation decision (for /write-plan)

The constraint ENCODING is the riskiest, least-specified step and must be nailed in
planning:
- (a) **glue-proximity constraint**: target chain must contact the glue's exposed
  atoms (no target-residue prediction) — minimal, purest glue-only signal.
- (b) **complementarity-predicted patch**: score target surface residues by
  shape/electrostatic complementarity to the exposed-glue face, constrain those.
Start with whichever Boltz's constraint format supports most directly; (a) is the
cleaner test of the core hypothesis.
