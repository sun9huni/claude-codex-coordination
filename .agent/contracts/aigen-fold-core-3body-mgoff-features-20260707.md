---
status: done
slice: aigen-fold-core
topic: 3body-mgoff-features
date: 2026-07-07
owner: claude
approved_by: sunghoon.kim (2026-07-07, "이거 두 개 실험해보자")
requested: 2026-07-07
cross_slice: []
triggers_matched:
  - "ranking semantics — two new structural feature families added to the VAV1 DC50 cross-scaffold ranking model (same class as latent-interface-encoder / mosir / ssl-pretrain, all of which took contracts)"
  - "4+ files — shared pose→feature extractor + 2 feature CSVs + eval script + results doc"
---

# aigen-fold-core — 3-body CRBN–MG–VAV1 hypergraph features + MG-on/off counterfactual (zero-GPU)

## Purpose

Two structural feature families that are GENUINELY untried, tested against the exhausted-
representation backdrop. Four representation-side levers this session all failed to beat the
v1.1 champion (cross 0.5584): learned BlockPMA-X encoder (0.178), set-kernel (negative),
MoSIR prototype+invariance (NULL), SSL pretrain on 2,089 CRBN-glue compounds (ESCAPE, real
mechanism but data-starved). ALL four were pooled or pairwise representations of the latent z.
Neither of the two here is:

1. **3-body hypergraph geometry.** Explicit (CRBN residue, glue atom/fragment, VAV1 residue)
   hyperedges from the docked ternary pose — the many-body signal a pairwise/pooled
   representation cannot see: does one glue atom SIMULTANEOUSLY bridge a CRBN residue and a
   VAV1 residue (composite-surface formation), and with what geometry (bridge span, angle,
   per-side distances). Distinct from the null Track1 (contact-GATED pooling of latent z — it
   pooled latents, not explicit geometry) and null Track3 (geom_proxy — lysine→glue/pocket
   distances, ubiquitination geometry, not the CRBN–VAV1 interface).

2. **MG-on/off counterfactual.** Per-compound contrast on the SAME existing pose: glue-mediated
   CRBN–VAV1 bridging vs the direct (glue-deleted) CRBN–VAV1 contact that survives. A productive
   glue forms a composite interface (mostly glue-bridged, little direct contact); a
   glue-independent false positive shows direct CRBN–VAV1 contact. Zero-GPU static counterfactual
   (delete chain C from the pose, re-score the residual interface) — NOT a fresh generation.

Expectation is deliberately LOW given the 0-for-4 track record; the value is a clean, honest
answer on two axes never measured, with a documented null being a fully valid outcome.

## Current State

- Per-388 docked ternary poses: `/mnt/kfs2/.../vav1_2stage_alldock_20260702/latent_out_pc388/
  VAV1_<cid>_tmpl/.../VAV1_<cid>_tmpl_model_0.pdb`. Chain A=CRBN(397), B=VAV1 SH3c(61), C=glue.
- Verified chain/token mapping already established in phase4/poolfeats_contact.py (reuse).
- Champion + honest comparison machinery: phase6/eval_pretrain.py (champion_v11_oof cross=0.5584,
  rho_ci, paired_boot_on_overlap); phase4/sweep.py (oof_pairwise, feature_registry["L+poolMSD"]);
  phase2/rank_harness.py (build_matrix, CV_SCHEMES, load_labels).
- Already-null structural features for collinearity checks: phase4/geom_proxy_388.csv,
  phase4/Zpool_contact_388.csv, phase6/cultsum_388.csv, phase6/confidence_388.csv.

## Assumptions And Questions

- assumptions: the single Boltz model_0 pose per compound is a usable geometry snapshot (same
  assumption all prior pose-feature work made); chain A/B/C identities hold across all 388.
- open questions / RISKS: (a) all 388 are glue-templated 2-stage poses, so the interface is
  glue-bridged BY CONSTRUCTION — MG-off contrast may be near-constant (like CULTsum's 91%
  near-zero variance) and uninformative; (b) 3-body geometry may be collinear with the already-
  null contact/geom features. Both risks are checked by a ZERO-COST gate (variance + univariate
  rho + collinearity) BEFORE any modeling — diagnose before scaling.
- tradeoffs: static MG-off (glue-atom deletion) is cheap but is a proxy for the true "regenerate
  without glue" counterfactual (which is GPU and physically odd for an obligate-glue system);
  documented as a proxy, not the literal apo re-fold.

## Constraints

- allowed: new scripts under .agent/scratch/vav1_degrad_head/phase7/; reuse existing pose PDBs +
  phase2/4/6 harness; CPU/gemmi/sklearn only.
- forbidden: touching engine files (boltz2.py/affinity.py hooks, crl_closure_*, diffusionv2_extend,
  potentials.py); re-generating poses; any SLURM/GPU; modifying existing phase0-6 artifacts.
- external: none (fully local, zero-GPU).

## Non-Goals

- Not beating v1.1 as a precondition for value (an honest null is a valid completion).
- Not a fresh glue-free generation pass (GPU) — MG-off is the static-deletion proxy only.
- Not the leak-taxonomy relabeling (needs CRBN-binary / ternary-only assays we do not have — the
  sar slice's SPR is still pending; out of scope).
- Not the diffusion/consistency/NFE/quantization/agentic-DMTA program from the uploaded plan —
  those target foundation-model retraining/deployment, which is not our layer.

## Done When

- Both feature CSVs (hyper3_388.csv, mgoff_388.csv) built for the 388 set + a zero-cost gate
  report (variance, univariate Spearman vs logDC50, collinearity vs geom_proxy/contact/CULTsum).
- Primary eval (reusing eval_pretrain machinery): oof_pairwise on L+poolMSD+{feature} vs the
  L+poolMSD champion, paired-bootstrap Δ on the SAME folds (isolates the feature; estimator/CV
  fixed), cross AND within, plus standalone-feature and L-only references. Verdict per feature:
  CI-separated positive add over champion = real; else documented null.
- Any positive Δ ADVERSARIALLY VERIFIED (independent re-derivation, permutation null, feature-
  ablation, collinearity-vs-null, leave-one-scaffold-out) before being reported as real.
- results_v7.md + baton update; contract → done.

## Implementation Steps

1. Shared pose→feature extractor (phase7/extract_features.py): load pose, build CRBN/VAV1/glue
   heavy-atom sets, emit hyper3_388.csv (bridging counts, hyperedge geometry stats) + mgoff_388.csv
   (glue-mediated vs direct contact contrast). verify: 388 rows each, no all-NaN/all-zero columns.
2. Zero-cost gate (phase7/gate.py): per-feature variance, univariate Spearman vs logDC50,
   collinearity (|Pearson|) vs geom_proxy_388 / Zpool_contact / cultsum / confidence. verify:
   printed table; flag near-constant or |r|>0.95-collinear-with-null features.
3. Primary eval (phase7/eval_features.py, reuse eval_pretrain.rho_ci / paired_boot_on_overlap /
   champion_v11_oof): each feature set + combined, oof_pairwise on L+poolMSD±feature, cross+within.
   verify: comparison table with paired-bootstrap CI vs champion; no point-estimate-only claims.
4. IF any positive: adversarial-verification workflow (multi-lens). verify: finding survives ≥
   majority of independent kill-attempts, else downgraded.
5. results_v7.md + baton + contract done. verify: doc present; scripts reproducible.

## Resource budget

- CPU only. Extraction over 388 small poses (joblib), minutes. Eval seconds-to-minutes. Zero GPU.

## Risks

- regression risk: none — additive evaluation-only scratch, no existing artifact modified.
- integration risk: none — no engine/repo files touched.
- hidden dependency risk: chain A/B/C assumption — asserted per-pose in the extractor (skip+log
  any pose failing the assert rather than silently mis-parsing).

## Rollback

- delete phase7/; no shared-state changes.

## Progress Log

- 2026-07-07: scoped inline (poses confirmed for 388; both ideas confirmed distinct from null
  Track1/Track3; champion + paired-boot machinery located). Contract drafted via /contract-check
  discipline (ranking-semantics + 4-files). User authorized both experiments ("이거 두 개
  실험해보자") → approved. Zero-GPU, proceeding.
- 2026-07-07: DONE. Extractor + gate + eval built (phase7/), poses parsed 388/388. Gate: no
  near-constant, no >0.95-collinearity-with-null; only strong univariate hit = glue-size confound.
  Primary eval: MG-off inert (Δ+0.002), 3-body block hurts cross on original split (Δ-0.128).
  First-pass writeup called it a clean null. Adversarial verification (wf_fa84c28d-5dd, 4 parallel
  lenses) CORRECTED that: Lens2 forward-scan found bridge_span_mean = CI-separated positive add
  over champion (0.558→0.587, Δ+0.028 [+0.002,+0.057]); I reproduced it to 4 decimals + ran a
  pre-registered reseed test = positive 10/10 fresh cross-scaffold splits (CI-sep 4/10) → real,
  not peeking. Lens1/4 showed the BLOCK "HURTS" is fragile (better stated "at best inert"); Lens3
  confirmed the standalone hyper3 signal is glue-size-driven (redundant with L). VERDICT: MG-off
  NULL; 3-body block unusable; bridge_span_mean = small robust candidate v1.2 add pending one
  clean nested-CV/held-out confirm. Ship model UNCHANGED (v1.1, cross 0.558). Strategic conclusion
  intact (data is the lever). Writeup phase7/results_v7.md. Contract → done.
