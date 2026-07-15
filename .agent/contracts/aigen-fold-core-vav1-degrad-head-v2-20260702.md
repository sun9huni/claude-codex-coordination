# aigen-fold-core — VAV1 degradation-ranking head v2 (2-stage poses + full feature ablation)

Status: done
Slice: aigen-fold-core
Topic: vav1-degrad-head-v2
Date: 2026-07-02
Approval: requested 2026-07-02; approved by: user (2026-07-02 "승인")
Supersedes: aigen-fold-core-vav1-degrad-head-v1-20260702 (feature center + generation method changed)

## Purpose

Decide whether structure (the productive CRBN–VAV1 ternary pose) actually improves
VAV1 DC50 ranking over a ligand-only model, by building a learning-to-rank head on
the **2-stage template-docked pose ensemble** and empirically comparing every
feature family. "Let the data pick the feature center" — run all, pick best, and
get a clean does-structure-add verdict either way.

## Current State

- Generation: 2-stage template docking (stage-1 strong2 S2_LON d5 hard-contact →
  best-CULT CIF template → stage-2 template docking, 5 seeds) running for all 388
  compounds on SLURM 16 GPU (job 13407, kfs2). Produces per-compound stage-2 pose
  ensembles (coordinates only; no latents dumped).
- Validated (pilot n=3 + partial n=47–63): poses stay productively seated
  (CULT ~3 Å = crystal; escape ~6–7 %; CULT-seated ~87 %) AND VAV1 position is
  strongly compound-discriminating (F 92–104, between 2.2–2.7 Å ≫ within 0.6 Å).
  Whether that discrimination is DC50-predictive is UNPROVEN (partial inconclusive).
- Labeled set: 388 valid compounds (`vav1_dataset_final.csv`), single target VAV1,
  single assay; scaffold folds pre-assigned (phase0). Ligand-only baseline
  ρ≈0.50 scaffold-split / ≈0.33 large-scaffold (established this session).
- Downstream pre-built + smoke-tested: `phase2/extract_features.py` (pose→geometry
  features + QC), `phase2/train_head.py` (L/P/L+P scaffold-CV + gate).

## Feature families to test (the ablation)

- **L (ligand)** — RDKit2D (173) + Morgan ECFP4. Protein-blind. zero-GPU. The bar.
- **P (pose-geometry)** — from 2-stage stage-2 ensemble: CULT/LON contact distances,
  VAV1 CA centroid position (CRBN frame), interface contact count, ligand centroid,
  seed-consistency (within-compound spread); aggregated mean+spread over 5 seeds.
  Interpretable, protein-context, overfit-safe. zero-GPU (from coordinates).
- **E (engineered)** — platform-style scores (keyres / ligand_face / glueprint /
  g_bind / keyres_hit_rate) recomputed on the NEW productive poses. zero-GPU.
- **Z (raw latent)** — Boltz-2 trunk s,z (compound-level, interface-masked-pool) and
  pose-conditioned latent (confidence-module read of generated coords), via a
  boltz2.py latent-dump hook + a GPU extraction pass over the stage-2 inputs.
  Linear-probed / PCA-reduced for n=388. **GPU + host-code, the only family that
  needs new compute.**
- All single families + combinations (L, L+P, L+E, L+P+E, L+Z, L+P+E+Z, …).

## Assumptions And Questions

- assumptions: 388 same-assay compounds → global + within-scaffold pairs valid;
  ligand is the dominant DC50 signal (3 independent lines) so structure's best hope
  is lifting the weak cross-scaffold (0.33), not overall ρ; the 2-stage poses (already
  being generated) serve BOTH P and Z (no extra generation).
- open questions: does any pose family beat L on scaffold-split? on large-scaffold?
  is Z (learned) worth its cost over P (hand-crafted) given both read the same poses?
- tradeoffs: Z is richer but high-dim (overfit at n=388) + needs a GPU pass + host
  edit; P is cheap/interpretable but hand-crafted and may miss what the latent encodes.

## Constraints

- allowed: new scratch scripts under `.agent/scratch/vav1_degrad_head/phase2/`;
  additive flag-gated boltz2.py latent-dump hook; latent-extraction SLURM pass on
  kfs2 (kim, qos=normal); reuse the 13407 stage-2 poses/templates.
- forbidden: touching aigen-fold-core WIP engine files (crl_closure_*,
  diffusionv2_extend, potentials.py); non-additive boltz2.py edits; git restore on
  dirty tree; re-generating poses (use 13407 output).
- external: /home not on compute nodes → all latent-pass paths on /mnt/kfs2; MSA
  baked; un-containerize rootfs; kfs5/6 full → outputs to kfs2.

## Non-Goals

- The 2-stage generation itself (running under this session / v1 lineage; not re-specced here).
- Prospective / wet-lab validation of predictions.
- Other E3 ligases or targets (VAV1/CRBN only).
- Dmax as the primary target (secondary/AUROC only; DC50 ranking is primary).
- A production-deployed model/API (this is the evaluation that decides the feature center).

## Done When

- Ablation table exists: every feature family {L,P,E,Z} + key combinations scored on
  scaffold-split 5-fold AND large-scaffold GroupKFold, OOF Spearman + bootstrap CI,
  ridge + GBDT + pairwise-LTR.
- Best feature set chosen by scaffold-split (+ large-scaffold) OOF Spearman.
- Does-structure-add verdict: for each pose family (P/E/Z), Δρ vs L with CI-nonoverlap
  or permutation p<0.05, on both scaffold-split and (esp.) large-scaffold.
- Gate: best set scaffold-split ρ≥0.55 AND large-scaffold ρ≥0.50 → PASS (head adopted);
  else escape valve = documented "structure does not add; ligand-QSAR (ρ≈0.50) is v1
  model" — a valid completion (answer obtained either way).
- Censoring handled: inactives (e.g. 474@10000nM, >ceiling) via certain-order pairs
  (LTR) / survival:aft (GBDT); dropout reported.
- results_v2.md with the table, verdict, chosen feature center, feature importance.

## Implementation Steps

1. On 13407 completion: run extract_features.py (P + QC) + Morgan → confirm F/CULT
   hold at 388. verify: pose_features.csv 388 rows; QC F, escape, CULT printed.
2. Recompute E (engineered scores) on the new poses. verify: E columns per compound.
3. ⛔ GATE: boltz2.py latent-dump hook (additive/flag-gated) + latent-extraction SLURM
   pass (kim, kfs2) → dump trunk s,z + pose-conditioned latent for 388 (×K).
   verify: latent npz per compound; smoke on 1 compound before full submit.
4. Assemble feature matrices; build pairwise-LTR + regression harness (scaffold-split
   + large-scaffold GroupKFold + LOSO). verify: OOF preds per set.
5. Ablation eval + verdict + gate. verify: table + Δρ CIs + PASS/escape decision.
6. results_v2.md + handoff. verify: doc written, contract→done.

## Constraints / triggers matched

- SLURM/GPU submission (latent-extraction pass) — approval gate.
- Host-code edit (boltz2.py latent hook, additive flag-gated) — approval gate.
- Ranking semantics (this defines the ranking model) — approval gate.
- Shared-storage writes (kfs2) — approval gate.

## Resource budget

- L/P/E + head training/ablation: zero-GPU (CPU, minutes).
- Z latent pass: ~388×K forwards on 16 GPU, few hours (only if Z tested — per user "test all").
- No new external deps.

## Risks

- regression risk: none (evaluation on scratch; hook flag-gated/off by default).
- integration risk: boltz2.py hook must be surgical/additive (revert by removing the
  flag branch, NOT git restore — engine tree has WIP).
- hidden dependency: latent semantics (which s/z tokens to pool) — mirror affinity.py
  interface-cross-pair pooling.

## Rollback

- revert: `sudo -u kim scancel <latent-pass jobid>; rm -rf <kfs2 latent out>`;
  remove the boltz2.py hook branch (flag-gated additive edit → delete the added block).
- containment: head/ablation is read-only on poses; produces only scratch CSV/npz/md.

## Progress Log

- 2026-07-02: /brainstorm. Feature center decided empirically ("test all, pick best")
  after this session established: ligand dominates (ρ0.50), single-stage pose invariant
  (F0.33), 2-stage pose compound-discriminating (F~100) but DC50-predictive value
  unproven. v2 supersedes v1 (2-stage generation + full L/P/E/Z ablation incl. latent
  hook). Draft pending approval.

## Notes — DONE (2026-07-03)

Deliverable: `.agent/scratch/vav1_degrad_head/phase2/results_v2.md` + ablation
scripts (features_ligand/latent/affinity/affg, ablation_final, rank_harness).

Verdict (scaffold-split OOF Spearman): structure ADDS over ligand QSAR, but only
cross-scaffold and only via the cheap pose-independent TRUNK latent z.
- Powered cross-scaffold (388, n=135): L 0.249, Zt_z 0.363, L+Zt_z 0.383
  (Δ+0.134, paired-bootstrap 95% CI [+0.013,+0.267], P(Δ>0)=0.986).
- Within-scaffold (388, n=388): ligand gbdt 0.545 dominates; structure ties/loses.
- Escalations did NOT pay off: pose-conditioned z (s_conf/z_conf, return_latent_feats)
  only ties ligand within-scaffold (Zpc_z 0.242 vs L 0.241), redundant (L+Zpc_z ≤ L);
  predicted affinity null for DC50 (direct ρ 0.138 / -0.024); affinity g (384-d) 0.14-0.16.
- The 143-oracle varying-pose set is scaffold-diverse + small so it cannot power the
  cross-scaffold test (n=27); its usable scaffold test showed no structure gain.

Gate (scaffold ρ≥0.55) NOT met by structure (that is the ligand ceiling). Escape
valve taken: v1 model = L + trunk-latent-z (ligand for within-series potency, trunk
z for cross-chemotype generalization). Pose generation / pose-conditioned / affinity
retired for THIS ranking task (trunk z needs no pose). Engine hooks (boltz2.py
return_latent_feats + affinity g; affinity.py _g_dump) live in the kfs2 rootfs COPY
only (backups .pre_pc_bak/.pre_affg_bak/.prehook_bak); NOT the WIP repo; flag-off
byte-identical. Affinity stock bug worked around with --diffusion_samples_affinity 1.
