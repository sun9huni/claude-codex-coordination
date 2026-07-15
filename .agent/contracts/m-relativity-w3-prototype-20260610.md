# m-relativity-w3-prototype

**Status:** approved
**Slice:** m-relativity
**Scope:** exploratory (scratch-only)
**Approval:** requested 2026-06-10 · approved by: user 2026-06-10 ("계획서 검토 및 이상 없으면 구현")

## Purpose

Turn the M-RELATIVITY proposal's **unconditional R-spine** — the irreducible
three-body electronic term

```
W3 = E[ABC] - E[AB] - E[AC] - E[BC] + E[A] + E[B] + E[C]
```

— from an analytic claim into a **runnable computation on the real
glue-mediated 3-body interface of 9NFR**. The point is to answer one question
with real data, not a synthetic toy: *does a real {VAV1, glue, CRBN} interface
actually carry a non-zero W3 (so that pairwise-additive force fields are
structurally blind to it), and does the M-RELATIVITY pipeline produce a real
number at all?* This is the first **computational prototype** of the engine
(the interactive page built 2026-06-10 is a didactic visualizer, not a
computation — see [[project_m_relativity]] / slice baton).

## Current State

- `best_structures/9NFR_reference.cif` — VAV1 ternary, **contains a real
  molecular glue `A1BYX`** (HETATM) + Zn + Cl; 5 chains, 12092 atoms. The glue
  mediates the VAV1–CRBN interface = the proposal's "strongest W3 site" (§4.2.2).
- No W3 computation exists anywhere in the repo. The interactive page's W3 module
  (`m3_w3.js`) uses a synthetic toy energy model, not real QM.
- Local QM: **none installed** (no pyscf/psi4/orca). pyscf **is** pip-installable
  (2.13.1). MM/cheminformatics: openmm 8.5, mdtraj 1.11, rdkit 2025.09, numpy/scipy/sklearn.

## Assumptions And Questions

- assumptions:
  - DFT (ωB97X-D / def2-SVP) on a **minimal fragment** (glue A1BYX + 1 nearest
    residue from VAV1 + 1 nearest residue from CRBN, H/methyl-capped at backbone
    cuts) is a **feasibility demonstrator**, run on CPU.
  - 7-term counterpoise with a single shared **ABC ghost basis** removes BSSE
    (the proposal stresses this is mandatory: W3 is a small difference of large
    energies — catastrophic cancellation).
- open questions:
  - `A1BYX` formal charge / protonation and the protonation state of the chosen
    Lys/Asp/Glu interface residues — wrong charge can flip W3's sign. Resolve from
    the CIF + a pKa heuristic; log the assumed charges.
  - which interface residues are genuinely closest to A1BYX in 9NFR (pick by
    minimum heavy-atom distance to the glue; confirm both a VAV1-side and a
    CRBN-side contact exist).
- tradeoffs:
  - DFT W3 is **not** the proposal's pre-registered R-PASS verdict (that needs
    CCSD(T)-F12b/CBS + independent 3-body SAPT/ISAPT). A 1-residue-per-body
    fragment may under- or over-state the true interface cooperativity.

## Constraints

- allowed change scope: **scratch only** — `.agent/scratch/m_relativity_w3_prototype/`
  (a python script + its outputs/log). May vendor a trimmed fragment PDB there.
- forbidden change scope: no edits to any project source tree; no changes to
  the interactive page; no ranking/ground-truth artifacts; no shared `/mnt/data` writes.
- external constraints:
  - **new dependency: pyscf** (pip; CPU build). Install into the existing env (or a
    venv) — note it in the run log.
  - **direct run, NO SLURM** (`sbatch` is hook-blocked without an active contract; this
    prototype is small enough for a direct CPU run — consistent with [[feedback_slurm]]).
  - fragment kept small (~40–90 atoms total) so def2-SVP + 7 CP terms finishes on CPU
    in minutes–~1 h.

## Non-Goals

- CCSD(T)-F12b/CBS, Helgaker T/Q extrapolation, SAPT/ISAPT cross-check.
- The Q (quantum-computer necessity) multireference battery M1–M5, SIE masquerade,
  any quantum-tier or QPE work. **R only.** R justifies *quantum mechanics*, never a
  quantum *computer* — the prototype must not let the two merge.
- The committor / diffusion-map / MD outer layer; the rate/Damköhler layer.
- A production-grade fragmentation/embedding scheme; QM/MM electrostatic embedding.
- Emitting a **pre-registered R-PASS verdict** — this is a feasibility number, labeled as such.

## Done When

- A script `compute_w3.py` run against 9NFR completes and prints:
  - the chosen fragment provenance (3 bodies, residues, atom counts, assumed charges/multiplicity, method, basis);
  - the 7 CP-corrected energies and **W3 in kcal/mol**;
  - the relative magnitude `|W3| / |dE_int|`;
  - the cooperativity factor `alpha = exp(-W3/kT)` (kT ≈ 0.616 kcal/mol @310K);
  - an R-PASS-strong **demonstrator** flag (`|W3|>1.0 kcal/mol AND relative>0.15`), explicitly
    labeled "DFT feasibility, NOT the CCSD(T)/CBS pre-registered verdict";
  - the **contrast**: the same fragment scored by a pairwise-additive model yields `W3 ≡ 0`
    (computed/asserted analytically on the identical decomposition), making the representability
    point real, not just stated.
- Outputs (W3 summary + a JSON of the 7 energies + the fragment PDB) written under the scratch dir; result is finite and reproducible across two runs.
- verification: `python .agent/scratch/m_relativity_w3_prototype/compute_w3.py` runs to completion and emits the W3 summary block + `w3_result.json`.

## Triggers Matched (WORKFLOW.md §2)

- SLURM submission: **no** (direct CPU).
- ranking-semantics change: no.
- 4+ files in a project repo: no (scratch-only; ~1–3 files).
- FragMap scoring mode: no.
- local vs shared concurrent edits: no.
- new external dependency (pyscf): **yes** — noted as a constraint, not a hard gate.
→ No hard SLURM/ranking trigger. Exploratory scratch contract (this file).

## Resource Budget

- pyscf install: ~1–2 min (pip, CPU).
- DFT def2-SVP, ~40–90-atom fragment, 7 CP terms: minutes–~1 h on CPU. No GPU/SLURM.

## Implementation Steps (sketch — /write-plan will decompose)

1. install pyscf; parse 9NFR; identify A1BYX + nearest VAV1-side and CRBN-side residues by heavy-atom distance.
   verify: prints the 3 chosen bodies + contact distances.
2. extract + cap the fragment; assign charges/multiplicity; write fragment PDB.
   verify: fragment renders / atom count sane / net charge logged.
3. run the 7 DFT energies with a shared ABC ghost basis (counterpoise); assemble W3.
   verify: 7 finite energies; W3 finite; CP applied to all 7.
4. emit W3 / relative / alpha / R-PASS-demonstrator + pairwise-FF W3≡0 contrast + JSON.
   verify: the verification command above.
5. write a short results note + update the m-relativity baton.
   verify: note exists; baton Live truth points at it.

## Change Discipline

- simplest adequate approach: smallest real 3-body fragment that still spans the glue-mediated interface.
- new abstractions introduced: one self-contained script; no framework.
- unrelated code touched: none (scratch-only).

## Verification

- task-specific command: `python .agent/scratch/m_relativity_w3_prototype/compute_w3.py`
- manual check: W3 sign/magnitude sanity vs the interaction energy; charges logged; CP applied to all 7 terms; "feasibility not verdict" label present.

## Risks

- regression risk: none (scratch-only, no shared state).
- correctness risk: DFT W3 ≠ CCSD(T) W3 — must be labeled feasibility, not verdict; wrong charge/protonation can flip W3's sign; a 1-residue fragment may not capture the real cooperativity.
- integration risk: pyscf build/install on this env (mitigate: venv fallback).

## Rollback

- revert strategy: `rm -rf .agent/scratch/m_relativity_w3_prototype/` — nothing else is touched.
- containment strategy: pyscf is the only new dependency; install into a venv if env hygiene matters. No project source, no /mnt/data, no SLURM, no ranking artifact involved.

## Progress Log

- 2026-06-10: contract drafted via /brainstorm (purpose → "real computational prototype"; piece → W3 representability R-spine; fidelity → minimal fragment + 7-term CP at DFT). Status pending, awaiting approval.
- 2026-06-10: approved by user ("계획서 검토 및 이상 없으면 구현"). Implemented + run.
- 2026-06-10: **DONE.** Fragment {VAV1 Asp797 acetate −1, glue A1BYX neutral, CRBN His353 4-Me-imidazole} (54 atoms, net −1) extracted from 9NFR via CCD-bond protonation. 7-term counterpoise wB97X-V/def2-SVP (density-fit) ran to completion (exit 0).
  **Result: W3 = +0.572 kcal/mol** (ΔE_int = −11.90; rel 0.048; α 0.395). R-PASS-strong demonstrator = **reject** (below 1.0/0.15 bar on this minimal DFT fragment = honest null). **W3^FF = −5.7e-14 ≈ 0** proven numerically → force field structurally blind to W3 (the representability point made real). Full record: `.agent/scratch/m_relativity_w3_prototype/RESULTS.md` + `w3_result.json`.
  Caveats met/flagged: DFT-feasibility-not-verdict labeled; minimal fragment under-estimates full-interface W3; **runtime ≈3.7 h overran the ~1 h budget** (VV10 NLC cost — note for iteration). All "Done When" criteria satisfied.
