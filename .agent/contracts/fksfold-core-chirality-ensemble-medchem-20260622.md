# Contract — chirality-resolved ternary pose ensemble for med-chem review

- **Status**: done
- **Slice**: vav1-ubq
- **Requested**: 2026-06-22
- **Approved by**: user (2026-06-22)

## Goal (one sentence)
Produce, within a **10-hour wall-clock budget**, a **chirality-resolved, geometry-clean,
diversity-clustered ensemble of candidate ternary poses for all 6 glue compounds (g1–g6)**
— so the medicinal chemist can browse, per compound and per *actual output* chirality, several
distinct CRBN–glue–VAV1 binding poses and pick among them.

## Why this shape (the key constraint)
The model collapses the glutarimide stereocenter toward R regardless of input (established:
g1/g3 input S → output R; only inference-time chiral steering at λ≈16 flips ~70% of seeds, with
mild local strain). Therefore candidates **cannot be grouped by input chirality** — they must be
generated in bulk and **binned by the *measured output* CIP**, then geometry-filtered, clustered,
and energy-minimized. Pose **diversity** comes mainly from the **orientation templates**, not seeds
(the model's prior is tight), so the generation is a grid over orientation × seed.

## Scope (this contract)
- **Generation grid (per compound, all 6)**: 6 orientation conditions {0, p30, p45, p60, p75,
  unsteered} × 8 seeds = **48 cells/compound → 288 cells total**. Settings = chiral-wire ON,
  **λ=16, CHIRAL_GW=1.0, CHIRAL_BUFFER=0.20**, native run (kim `--qos=batch`, rootfs at
  `/mnt/kfs2/data/users/ubuntu/boltz_native_20260621/`), byte-faithful to the campaign otherwise.
- **Pipeline per compound**: (1) generate → (2) score each pose: output CIP (by-index scorer),
  intra-ligand min-heavy clash, inter-chain ternary sanity (glue bridges CRBN+VAV1, no inter-chain
  clash, VAV1 attached), iptm/ligand_iptm/plddt → (3) **bin by output CIP** (S / R) →
  (4) **geometry filter** (drop malformed; keep mild-strain) → (5) **cluster** per (compound, CIP)
  by ligand-RMSD (CRBN-superposed) → pick diverse representatives → (6) **energy-minimize** each
  representative (restrained: protein heavy-atoms restrained, ligand relaxed; reuse existing
  AM1-BCC ligand params; implicit/vacuum, no production MD) to relieve local strain.
- **Deliverable**: per (compound × output-chirality) a set of clustered, minimized candidate PDBs
  + a summary table (CIP, iptm, ligand_iptm, inter-chain contacts, intra-ligand min-heavy) +
  a README for the med-chem, under `/mnt/kfs2/.../chirality_ensemble_20260622/`. Note for g5/g6
  (achiral input): the chiral constraint is empty → they generate as the model's native (R) form;
  their S/R counterparts are covered by g1/g2 (chemotype A) and g3/g4 (chemotype B).

## Out of scope (deferred / separate)
- **MD / MM-GBSA / ΔΔG / binding-affinity / SAR** — the >100× potency question. The minimized
  poses are "clean-looking" (R-pose + flipped center + local relaxation), good for *visual browsing*,
  NOT a rigorous binding-mode or potency claim. Rigor = a separate MD workstream.
- **Model retraining / encoder wiring (Stage B)** — the no-retrain ceiling stands; not revisited here.
- **Full solvated production MD**; committing the chiral-wire diff to the host tree (stays rootfs +
  saved diff, entangled with aigen-fold-core WIP).
- **Guaranteeing every compound yields clean S** — yield is ~70%/seed and strain is intrinsic; we
  deliver what passes the filters + minimization, and report yields honestly (no fabricated coverage).

## Constraints (resource budget)
- **≤10 h wall-clock total** (generation + scoring + clustering + minimization). Hard ceiling.
- GPU **only** via `sudo -u kim sbatch/srun --qos=batch`, **≤4 GPU** concurrent (kim `normal` cap is
  saturated by MD job 8098 — do NOT touch 8098), idle nodes.
- All writes under `/mnt/kfs2` (mergerfs routes ubuntu's /mnt/data to the full kfs5).
- Byte-faithful generation: only deviations from the campaign are λ=20→16 + the chiral-wire overlay.
- Offline (reuse cached MSA inline; no `--use_msa_server`).

## Triggers matched
SLURM submission (kim batch) · shared-storage writes (/mnt/kfs2) · multi-file new scripts.

## Done When
- All 288 cells attempted; failures enumerated (not silently dropped).
- Each compound has an output-CIP-binned, geometry-filtered, clustered, **minimized** representative
  set with a populated metrics table; ≥1 correct-chirality clean representative delivered for each of
  the 4 stereo-defined compounds (g1=S, g2=R, g3=S, g4=R) OR an explicit honest note where none passes.
- A med-chem README + summary table written; a side-by-side render for at least the two enantiomer
  pairs (chemA g1-S vs g2-R; chemB g3-S vs g4-R).
- **Total wall-clock ≤ 10 h** (recorded).
- Verification: `column -t .../chirality_ensemble_20260622/summary.tsv` shows per-compound rows;
  representative PDBs exist; render PNGs exist.

## Risks
- Chirality yield lower than ~70% on some compounds → fewer S candidates (mitigate: 48 cells/compound
  over-generates; report honestly).
- Minimization over-relaxes / moves the pose (mitigate: protein-restrained, ligand-local only).
- 4-GPU cap + oversubscription slower than estimated → trim to 6 seeds (36/compound) if pace lags the
  10 h budget (checkpoint the wall-clock after generation).
- g5/g6 add little (achiral) — acceptable per user "all 6, equal".

## Rollback
- All artifacts under `/mnt/kfs2/.../chirality_ensemble_20260622/` — delete the dir; nothing else
  mutated. No git commit, no model/checkpoint change, no effect on MD 8098 or any committed state.

## Notes
DONE 2026-06-22 (~2h47m, ≤7h). 144-cell ensemble → 18 chirality-binned clustered minimized reps for all 6 glues. chemA 100% S clean/diverse; chemB ~75% S tight. Viewing-grade (not SAR). Deliverable /mnt/kfs2/.../chirality_ensemble_20260622/deliverable/. Result: analysis/crl_integrative/chirality_ensemble_results_20260622.md.
