# Contract — glue MD productive-geometry discriminator (dynamics escalation)

- **Status**: approved
- **Slice**: vav1-ubq
- **Requested**: 2026-06-18
- **Approved by**: user (2026-06-18)

## Goal (one sentence)
Re-evaluate the 6 VAV1 glue candidates (g1–g6) for *productive ubiquitination geometry*
using **dynamics (well-tempered metadynamics MD)** — because the static-graft screen was
method-negative (KILL-gate FAIL: active MRT6160 did not separate from inactive C147; static
graft cannot make "reach + clash-free" simultaneously) — applying the **same method already
used for MRT6160/seed314** (dual-register pose selection → crl_rebuild → crl_md_prep → metad),
with C147/MRT6160 controls validating that MD actually discriminates active from inactive.

## Scope (this contract, FULL per user 2026-06-18)
- **Stage 0 (zero-GPU)**: extend the pose scan to dump **all-5-lysine dual-register** (per-lysine
  Nζ→Ub-G76-C *and* →Cys85-Sγ, per pose) → determine the **productive lysine PER CHEMOTYPE**
  (resolve the within-group inconsistency: the 3 stereo-forms of A should share a productive
  lysine, likewise B; aggregate the ensemble over the chemotype, not per individual pose) +
  select **representative starting pose(s)** by a FIXED rule (productive-register reaching +
  ensemble support, same rule MRT6160/seed314 used). Same rule applied to MRT6160 + C147.
- **Stage 1 (GPU, internal gate)**: build + run **C147 inactive-control metad** (MRT6160 active
  already done = seed314, K810→Ub 2.72 Å clash-free). Assess active/inactive separation on the
  MD verdict (below). PASS = MD discriminates; FAIL = method-negative even under MD (surface
  weakly, 음성 자동선언 금지) — but per user "전체", the 6 still run; the gate qualifies TRUST.
- **Stage 2 (GPU)**: all **6 candidates** metad, each with its glue-specific CV lysine +
  representative pose(s); same byte-faithful seed314 metad setup.
- **Per-compound verdict = 4-axis MD readout**: (1) clash relief (severe block↔scaffold
  pre-min → trajectory median), (2) register (does the productive lysine reach the thioester,
  dual-register), (3) FES shape (near-attack a low basin vs a forced high-energy wall),
  (4) ternary integrity (VAV1↔CRBN stays intact, no complex blow-apart). → productive /
  non-productive / method-limited call, trust-qualified by the Stage-1 separation gate.

## Out of scope (deferred — revisit after this round, per user)
- **Lysine-agnostic generalized metric** (thioester attack ANGLE, multi-lysine scoring,
  lysine-agnostic cross-glue comparison framework) — discussed, DEFERRED to a later round.
- FES convergence to publication quality / 200 ns completion (preliminary FES suffices for the call).
- MMGBSA / ternary binding-affinity quantification (separate axis; only qualitative ternary watch).
- Cell-based / DC50 activity validation (no GT this round).
- Re-running the static orientation campaign (768 poses already done; reused as input).

## Compound structure (objectively determined, InChIKey 2026-06-18) — REFRAMES the experiment
The 6 "candidates" are NOT 6 independent glues — they are **2 chemotypes × 3 stereo-forms each**:
- **Chemotype A** (skeleton `RIFDPWJLHNZGEX`, **FLEXIBLE** — glutarimide on a rotatable methine):
  **g1** (one enantiomer), **g2** (other enantiomer), **g5** (stereo-unspecified parent).
- **Chemotype B** (skeleton `BNPXZVKFXBHEKC`, **RIGIDIFIED** — glutarimide locked in a spiro/fused ring):
  **g3, g4** (enantiomer pair), **g6** (stereo-unspecified parent).
So the real question = **flexible (A) vs rigidified (B) scaffold, and whether chirality matters**,
with the 3 stereo-forms per chemotype as a **built-in internal consistency control** (they should
behave alike under MD if the method is robust; static graft already gave g1/g2→K810 but g5→K814
for the SAME molecule = static noise to resolve).

## Inputs / current state (acquired)
- 768 grafted poses + `glue8_pose_scan.csv` (Task 5) — closest-lysine dual-register; Stage 0
  extends to all-5. 8 grafted_best PDBs + `glue8_top_poses.tsv` (top dual-register pose/ligand) saved.
- Pipeline harnesses: `crl_pose_scan.py`/`crl_rebuild.py` (graft + dual-register),
  `crl_md_prep.py` (System build → prmtop), metad driver (`crl_md_run.py`/seed314 setup),
  `crl_confirm.py` (--t0 + --traj --fes, 4-trap readout).
- Positive control DONE: MRT6160 seed314 metad (40 ns, K810 2.72 Å clash-free, FES min ~3.64 Å).
- Free-GPU lesson locked ([[reference-slurm-free-gpu-selection]]): select GPUs by memory.free,
  verify clean node.

## Triggers matched
- SLURM/GPU submission (metad jobs) → ★APPROVAL GATE (each sbatch needs active contract <7d +
  explicit user go). DB: none. /mnt/data writes: yes. Multi-file analysis additions: yes.
  Ranking semantics (productive/non-productive calls): yes.

## Success criteria (concrete + verification)
1. **Stage 0 table** — per-compound × 5-lysine dual-register ensemble stats + selected productive
   lysine (CV) + representative pose id(s), selection rule applied UNIFORMLY (controls included).
   Verify: `column -t <dual_register.tsv>` shows 8 compounds with per-lysine d_ub/d_cys summary +
   a `cv_lysine` + `start_poses` column; rule is the same string for all rows.
2. **Stage 1 separation gate** — C147 metad completes; active/inactive separation assessed on the
   4-axis MD verdict. Verify: a `SEPARATION(MD): PASS|FAIL` line with the 4-axis comparison
   MRT6160 vs C147; FAIL → method-negative recorded (not auto strong-negative).
3. **Stage 2 per-CHEMOTYPE calls** — flexible-A and rigidified-B each get a 4-axis
   productive/non-productive MD call, trust-qualified by #2; the 3 stereo-forms per chemotype
   serve as a **consistency check** (do enantiomers + parent agree?) AND a chirality readout
   (do g1 vs g2 differ?). Verify: per-compound verdict table grouped by chemotype + the 4-axis
   evidence row each + a within-chemotype-consistency note; "non-productive"/"method-limited" valid.
4. **Anti-bias**: representative poses chosen by the FIXED registered rule (not raw-min best pose);
   verdict by pre-registered 4-axis criteria; best-pose-min never the verdict.
5. **Result doc committed** under `analysis/crl_integrative/`.

## Resource budget (set by user 2026-06-18)
- Stage 0: zero-GPU (~1–2 h, PyMOL scan re-dump + per-chemotype selection).
- Stage 1 (build): CPU (crl_rebuild/crl_md_prep/tleap), 8 systems.
- Stage 2 (metad): **8 compounds (g1–g6 + MRT6160 + C147), each 40 ns (same as seed314),
  1 GPU per compound, all 8 in PARALLEL on one 8-GPU node** → ~48 h wall (seed314 rate ~40 ns/48 h
  OpenCL) = ~8 GPU × 48 h ≈ ~384 GPU-h, ONE job. high QoS (≤3-day walltime OK). free-GPU selector
  + clean-node check ([[reference-slurm-free-gpu-selection]]). 1 representative pose per compound
  (the stereo-replicates within each chemotype already give the consistency control).
  MRT6160 re-run FRESH from the same Stage-0 pipeline (apples-to-apples; the existing seed314 run
  stays as a cross-check reference). ★GPU APPROVAL GATE satisfied: contract approved + user go.

## Rollback
- `scancel` metad jobs; delete `/mnt/.../crl_glue_md_*/` outputs (regenerable). Analysis/build
  additions are new files (git-revert). No source/ranking-semantics state changed by the run.
  Stage-1 gate prevents committing the full candidate GPU spend to a triage that MD can't trust.

## Assumptions / caveats
- A1: metad tests *catalytic geometry given a formed ternary*; if a compound's inactivity is
  driven by *ternary formation/binding* (likely for C147 at 10000 nM), the metad-from-formed-
  ternary may bypass that failure mode → the ternary-integrity axis (#4) partially guards this,
  but a true binding axis (MMGBSA/unbiased MD) is out of scope this round.
- A2: metad bias is strong (can force a distorted approach) → verdict uses the 4-axis readout,
  not "did the CV reach" alone.
- A3: N=1–2 representative poses per compound is a screen, not a converged ensemble (caveat in doc).
- A4: productive lysine determined per glue by dual-register (existing method); the lysine-agnostic
  refinement is deferred (Out of scope).
- A5: the 6 candidates = 2 chemotypes × 3 stereo-forms, so the effective N is 2 scaffolds (+ chirality),
  not 6 independent glues; budget/verdict treat them as 2 groups with stereo-replicate consistency
  as an internal control. Chirality genuinely can shift activity, so g1-vs-g2 (and g3-vs-g4) is a real
  comparison, not pure replication.
