# Plan — glue-synthesized placement constraint (contract fksfold-core-glue-synth-constraint-20260616)

Decompose the approved contract. Boltz pocket constraint format REQUIRES target
residue indices (`contacts: [[B, idx], ...]`), so the glue-only signal must be
turned into a PREDICTED target patch (option b). That prediction is the crux risk →
gate it zero-GPU before any submission.

## Task 1 (zero-GPU) — premise check
On the GT (held-out) for 9H59/9DWW/9OTY: confirm the true target contacts (crystal
pocket) actually lie against the glue's SOLVENT-EXPOSED face (not the CRBN-buried
side), and measure how LOCALIZED they are. If the true contacts are not near the
exposed glue atoms, the whole "target docks onto exposed glue face" premise is wrong
→ KILL cheaply. Output: per-target, fraction of crystal-pocket residues within
contact distance of exposed-glue atoms + spatial spread.

## Task 2 (zero-GPU) — synthesis method + recovery gate
Build `synth_glue_constraint_*.py`: from the CRBN+glue subset (no target pose),
predict the target's glue-contacting residues (v1 method TBD by Task 1 — candidates:
shape-complementarity coarse dock of the target monomer onto the exposed face, or a
pose-free chemical-propensity ranking). VALIDATE by recovery: does the synthesized
contact set overlap the TRUE crystal pocket (precision/recall) on the 3 targets?
GATE: if recovery is poor (e.g., precision < ~0.3) the constraint will misdirect →
iterate method or KILL. Do NOT submit GPU until recovery is acceptable.

## Task 3 (GPU) — stage + submit
If Task 2 passes: stage YAMLs with the synthesized `constraints:` block, 3 targets ×
N≈16–32 seeds, reuse the proven runner + throttled high-QOS submitter. Also record
the synthesized-pose's own DockQ (attribution: did the dock alone solve it, or did
Boltz add value?).

## Task 4 (score) — verdict
best-of-N DockQ table with three columns: blind (~0.007) / glue-synth / crystal-pocket
(0.58). PRIMARY: Nek7 AND PDE6D ≥ 0.25. CONTROL: CK1α not below ~0.73. NULL: both
< 0.10 → glue-exposed-face signal insufficient, stop (don't build §1–22).

## Discipline
diagnose-before-scale: Tasks 1–2 are zero-GPU gates; GPU only after recovery passes.
No src/ change, no scorer fork. Reuse stager/runner/collector patterns.
