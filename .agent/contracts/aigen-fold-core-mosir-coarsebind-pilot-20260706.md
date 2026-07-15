---
status: done
slice: aigen-fold-core
topic: mosir-coarsebind-pilot
date: 2026-07-06
owner: claude
approved_by: sunghoon.kim (2026-07-06, "승인")
requested: 2026-07-06
cross_slice: []
triggers_matched:
  - "ranking semantics — MoSIR changes how the cross-scaffold DC50 ranking representation is learned (same class as latent-interface-encoder-20260704 / vav1-degrad-head-v2-20260702)"
  - "SLURM/GPU submission (conditional) — CoarseBind inference pass, only if code/checkpoint turns out to be public"
  - "4+ files — new phase5 scripts (feature adapt, train, eval, results doc)"
  - "shared-storage writes (conditional) — kfs2 outputs if CoarseBind gate passes"
---

# aigen-fold-core — MoSIR invariant-representation pilot + CoarseBind affinity-null re-check (ICML2026 follow-up)

## Purpose

Follow-up on the 2026-07-06 ICML2026 paper survey (229 papers, 5 themes). Two cheap, falsifiable
pilots targeting our two live open questions, chosen because they map directly onto blockers
already logged in this slice's baton rather than generic "try a new paper's idea":

1. **Cross-scaffold ranking ceiling.** v1.1 (phase4, pairwise ranking loss) lifted cross-scaffold
   0.383→0.558; within-scaffold stays capped at ligand-gbdt 0.545. Every lever tried so far kept
   the same L+Zt feature matrix and swapped estimator/loss/pooling/censoring/PCA/stacking (all
   documented, several are NULLs). Not yet tried: an explicit invariant-vs-environment
   representation split. MoSIR (ICML2026, prototype-constrained bi-level min-max) does exactly
   this — projects entangled embeddings into a learnable semantic-prototype space, isolates
   scaffold-sensitive variation, and optimizes a min-max objective that simulates plausible
   scaffold shifts to enforce invariance.
2. **Affinity-derived features were null for DC50** in our own extraction this session
   (direct affinity ρ 0.138/-0.024; affinity-g 384-d ρ 0.14-0.16). CoarseBind (ICML2026) claims
   16-20% better Pearson correlation than Boltz-2 on affinity prediction (CASP16 + 18 private
   assays). Worth checking whether our null reflects a genuine "affinity doesn't predict DC50"
   fact, or a Boltz-2-affinity-module weakness specifically — but ONLY if CoarseBind's code or
   checkpoint is actually public. Research step first; GPU step is conditional and gated.

## Current State

- v1.1 model card (`phase4/v1_model_card.md`): L(ligand-gbdt)=0.545 within; L+Zt_z pairwise=0.558
  cross (paired-bootstrap Δ+0.173 [+0.056,+0.297] P=0.998 vs old B).
- Feature matrices + eval harness already built and reusable:
  `.agent/scratch/vav1_degrad_head/phase{2,3,4}/` (features_ligand/latent/affinity/affg,
  ablation_final, rank_harness, poolfeats/sweep/pairwise_ranker scripts).
- NULLS already ruled out on this same feature matrix (do not re-litigate): censoring-aware,
  Dmax co-train, seedbag ensemble, A/B rank-stack (hurts, cross P=0.013), PCA-dim (within only).
- Boltz2 affinity hook (`BOLTZ_DUMP_AFFG`, rootfs kfs2 copy) already dumped affinity-g for all
  388 compounds — the null result this contract wants to double-check.
- CoarseBind (arXiv 2602.07735, ICML2026 poster): code/checkpoint public status **unknown** —
  first deliverable of this contract, not an assumption.

## Assumptions And Questions

- assumptions: existing L+Zt tabular features are reusable for MoSIR without regenerating
  latents/poses; MoSIR's objective is implementable purely on the tabular feature matrix (no
  Boltz2 engine code touched).
- open questions: does MoSIR's bi-level min-max overfit at n=388 (its own benchmarks are much
  larger)? is CoarseBind's code/weights actually released, or is this an ICML poster with
  camera-ready-only code (common)?
- tradeoffs: MoSIR pilot is CPU/sklearn/pytorch-scale, cheap, zero engine risk. CoarseBind, if
  code exists, needs a real GPU inference pass (ESM-2 + their model) on our existing structures —
  genuine new-dependency and compatibility risk, gated behind the availability check.

## Constraints

- allowed: new scratch scripts under `.agent/scratch/vav1_degrad_head/phase5/`; reuse existing
  phase2-4 feature CSVs/joblib artifacts; install CoarseBind into an isolated venv/conda env if
  public (no pollution of the boltz_extension repo); GPU inference only for CoarseBind (no
  fine-tuning/training).
- forbidden: touching aigen-fold-core WIP engine files (crl_closure_*, diffusionv2_extend.py,
  potentials.py, boltz2.py/affinity.py rootfs hooks); no SLURM submission until the CoarseBind
  code-availability check (step 3) is confirmed AND reported to the user; no re-generating
  poses/latents (reuse existing 388-compound artifacts).
- external: any GPU pass runs via kim `--qos=normal`/`batch` (hard rule, even smokes); outputs to
  kfs2 (kfs5/6 full).

## Non-Goals

- Not re-running the full phase4 estimator/loss sweep — additive on top of it, not a repeat.
- Not a decision on the IKZF1/GSPT1 external-data transfer contract — ReCoG-style context-graph
  transfer stays a noted follow-on idea for that separate, larger-scope contract, not in here.
- Not committing to CoarseBind adoption — this is a verification check of our own affinity-null
  finding, not a model swap or new dependency in production.
- Not synthesis planning (Pareto-Optimal Synthesis Planning / Retro-Expert) — sar slice's decision,
  out of scope here.

## Done When

- **MoSIR**: scaffold-split 5-fold + large-scaffold GroupKFold OOF Spearman for the MoSIR
  representation vs the v1.1 pairwise baseline, with paired-bootstrap CI. PASS = CI-nonoverlap
  improvement on cross/large-scaffold; documented null is also a valid completion.
- **CoarseBind**: code/checkpoint availability determined and reported before any further step.
  IF public: affinity predictions extracted for the 388-compound set (inference only), correlated
  with DC50, compared to our existing null. IF not public: contract closes at that finding, zero
  GPU spent.
- Results doc (`.agent/scratch/vav1_degrad_head/phase5/results_v5.md`) + baton update either way.

## Implementation Steps

1. MoSIR: adapt the existing L+Zt feature matrix into MoSIR's prototype-constrained bi-level
   min-max training objective (reuse phase3/4 harness, no re-extraction).
   verify: training converges without crash; produces OOF predictions per fold.
2. MoSIR: scaffold-split 5-fold + large-scaffold GroupKFold eval, paired-bootstrap vs the v1.1
   pairwise baseline.
   verify: comparison table with CI printed; no silent point-estimate-only comparison.
3. CoarseBind: check for a public code/checkpoint release (paper page, GitHub, HuggingFace —
   research only, zero compute cost).
   verify: explicit yes/no reported to the user before proceeding to step 4.
4. ⛔ GATE (only if step 3 = yes): install in an isolated env; run inference-only pass on the
   388 compounds' existing structures.
   verify: predictions extracted; no engine files touched; env is isolated/removable.
5. CoarseBind: correlate predictions with DC50; compare to the existing affinity-null finding.
   verify: ρ + comparison table against the prior null.
6. Results doc + baton update; contract → done.

## Resource budget

- MoSIR: CPU only, minutes-to-low-hours.
- CoarseBind: zero cost unless step 3 passes; if it does, a single GPU inference pass (no
  training), estimated <1 GPU-hour for 388 compounds (no diffusion sampling).

## Risks

- regression risk: none — both tracks are additive evaluation-only, no existing artifacts modified.
- integration risk: CoarseBind may be code-unavailable or have incompatible deps/checkpoint gating
  (common for ICML posters pre-camera-ready) — mitigated by the explicit gate at steps 3/4.
- hidden dependency risk: MoSIR's bi-level min-max may be unstable at n=388 (its benchmarks are
  larger) — mitigated by requiring bootstrap CI rather than a point-estimate comparison.

## Rollback

- MoSIR: delete `phase5/` scratch scripts; no shared-state changes to revert.
- CoarseBind: `conda env remove` / delete the isolated venv; no engine or repo files were ever
  touched.

## Progress Log

- 2026-07-06: ICML2026 paper survey (229 papers) → MoSIR + CoarseBind selected as the two most
  directly falsifiable proposals against the open cross-scaffold ceiling and affinity-null
  questions. User approved proceeding ("MoSIR,CoarseBind 진행"). Contract drafted via
  /contract-check (ranking-semantics + 4-files + conditional-SLURM triggers matched).
  Status: pending approval.
- 2026-07-06: user approved ("승인"). CoarseBind step 3: the ICML page's title ("CoarseBind")
  is stale — actual paper is **TerraBind** (arXiv 2602.07735, Terray Therapeutics Inc./EMMI
  Predict). No arXiv preprint comments, GitHub, or HuggingFace mention of code/checkpoints —
  confirmed proprietary (COATI-3 ligand encoder is also their own prior proprietary work).
  Gate = NO → step 4 (GPU inference) does not proceed. **CoarseBind/TerraBind track CLOSED,
  zero GPU spent**, as anticipated by the contract's own dual-outcome design.
- 2026-07-06: MoSIR pilot run (`phase5/mosir_pilot.py`). v1 (prototype + domain-confusion
  only, no DC50 signal in the encoder loss) collapsed the representation — rho ~0 or
  negative on every cell, P(beats baseline)=0.000 everywhere. Diagnosed as a real design
  gap (encoder had zero task supervision), not a fair test → v2 adds a pairwise-ranking
  task loss into the same encoder objective. v2 results (train-local PCA(32) → MoSIR
  encoder 32→16, 8 prototypes, env=pre-assigned scaffold `fold` groups → same
  pairwise-logistic head, same `oof_pairwise` harness/splits/bootstrap as phase4/sweep.py):
  L+Zt within 0.334 vs baseline 0.442 (P=0.006, worse); L+Zt cross 0.415 vs 0.535 (P=0.058,
  CI spans 0); L+poolMSD within 0.365 vs 0.429 (P=0.082, CI spans 0); L+poolMSD cross 0.309
  vs 0.558 (P=0.000, decisively worse). **Verdict: NULL** — no cell shows a CI-nonoverlap
  win over the existing v1.1 pairwise-ranker; 2/4 cells are decisively worse. Does not beat
  the shipped v1.1 model; added complexity (bi-level min-max, small-n instability,
  "cross" CV trains each fold on only ~107 rows) is not justified. Scope-limited null: this
  refutes our from-scratch approximation at n=388 on top of an already-strong baseline, not
  MoSIR's paper on its own (larger) benchmarks. Results: `phase5/results_v5.md`.
  Contract → **done**, both tracks closed.
