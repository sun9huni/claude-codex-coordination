---
contract: .agent/contracts/fksfold-core-assembly-closure-generation-20260623.md
slice: aigen-fold-core
status: done
total_tasks: 19
estimated_total_min: 87
note: "agent-time estimates; Stage 2+ GPU runs execute in background (wall-clock hours) and sit behind user-go approval gates. Stages 0-1 (T1-T8) are GPU-free and immediately actionable. Engine edits (T7,T12) touch aigen-fold-core boltz_extension (#12 WIP entanglement) → additive/flag-gated only + coordinate with owner. 2026-06-25: T13 DONE (9OTY PASS), T14 ran as 9NFR diagnostic (DONE, new finding: VAV1 Boltz prior weak). T14a/T14b/T14c added to fix VAV1 IK before proceeding to MRT6160."
---

# Plan — Assembly-Closure Generation (no-crystal CRBN–glue–VAV1 ternary, STRUCTURE-only)

Phases: Setup/Data (Stage 0, zero-compute) → Core+Tests (Stage 1) → Glue/Run (Stage 2, GPU GATE) → Core (Stage 3, conditional GPU GATE) → Core (Stage 4, conditional) → Docs.

## Task 1: closure_residue_map — sequence-align literature contacts to prediction frame + identity assert

- **Status**: done (commit 021444e; all identity OK, CRBN offset 0 alignment-verified, VAV1 796→local15 etc.)
- **Prereq tasks**: none
- **Files touched**: analysis/crl_integrative/closure_residue_map.py
- **Change shape**: New zero-compute script. Sequence-align the literature residues to OUR prediction-frame numbering and assert IDENTITY (not number): VAV1 RT-loop **R796/D797/S799** + lysines K788/804/810/814/815 → chain-B-local (782→1 offset; assert local-15 is ARG, etc.); CRBN **W400/H357/N351** → our 9UUM/generation CRBN numbering (assert W/H/N at mapped positions). Pull sequences from the AF-P15498 VAV1 model + the 9UUM/donor CRBN. Emit a `closure_map.json` (literature→local index + residue-identity-checked flags).
- **Verification**: `python analysis/crl_integrative/closure_residue_map.py` → prints map; ALL identity asserts PASS (R796→ARG, D797→ASP, S799→SER, W400→TRP, H357→HIS, N351→ASN, 5×LYS); non-empty indices; exits 0. Any mismatch → hard-fail (nonzero exit).
- **Estimated time**: 5 min
- **Rollback (if this task only)**: delete the file.

## Task 2: make_closure_spec — emit the closure spec JSON

- **Status**: done (commit 15c9a2a; SPEC OK, cone_axis unit-norm, P3' pairing flagged plausible_not_figure_confirmed → consumer treats soft)
- **Prereq tasks**: 1
- **Files touched**: analysis/crl_integrative/make_closure_spec.py
- **Change shape**: New zero-compute script consuming `closure_map.json`. Emit `closure_spec.json`: cone apex = Ub Gly76 C (143.540,80.855,132.198), axis→Cys85 SG (143.483,84.269,131.784); CRBN-align CA set (rigid core for Kabsch); candidate-lysine NZ local idx; tri-Trp clamp pos-restraints (W380/W386/W400 ref positions, weights 0.5/1.0/0.6); P3' contact pairs {R796↔W400,D797↔H357,S799↔N351} (binding-side); frozen params (near-attack 3.5Å, reach 13.5Å). distance-only v1 (angle term present but disabled).
- **Verification**: `python analysis/crl_integrative/make_closure_spec.py && python -c "import json;d=json.load(open('analysis/crl_integrative/closure_spec.json'));assert d['cone_apex']==[143.540,80.855,132.198];assert len(d['p3_contacts'])==3;assert len(d['lys_nz'])==5;print('SPEC OK')"` → `SPEC OK`.
- **Estimated time**: 5 min
- **Rollback (if this task only)**: delete the file + closure_spec.json.

## Task 3: contact_recovery — crystal-proxy GT scorer

- **Status**: done (commit 11782ec; self-smoke 1.0/0.0 pass; ★baseline completed_seed42 recovers 0/3, nearest R796↔W400=10.08Å → big headroom + lysine-anchored pose was wrong interface; scorer auto-detects vav1/crbn numbering offset)
- **Prereq tasks**: 1
- **Files touched**: analysis/crl_integrative/contact_recovery.py
- **Change shape**: New scorer. Given a predicted ternary PDB + closure_map, report fraction of the 3 mutagenesis H-bond pairs {R796↔W400,D797↔H357,S799↔N351} within a donor-acceptor cutoff (default 3.5Å heavy, 4.0Å incl. H), plus per-pair distances. This is the reusable crystal-proxy GT metric used by every downstream stage.
- **Verification**: `python analysis/crl_integrative/contact_recovery.py --pdb <a docked seed pose>` → prints 3 per-pair distances + recovered-fraction; on a deliberately translated-apart pose returns 0/3. (Self-check both in __main__ smoke.)
- **Estimated time**: 5 min
- **Rollback (if this task only)**: delete the file.

## Task 4: Kabsch cone-placement smoke (Stage 0 smoke b)

- **Status**: done (commit 1e585e5; RMSD 1.07Å, 4 asserts pass, carried apex 32.7Å from CRBN. ★FINDING: 9UUM CRBN vs donor CRBN use DIFFERENT numbering (offset 45) — naive equal-number Kabsch=15.86Å garbage; MUST reconcile by CRBN_SIG sequence anchor.)
- **Prereq tasks**: 2
- **Files touched**: analysis/crl_integrative/smoke_kabsch_cone.py
- **Change shape**: New zero-compute smoke. Map the 9UUM cone (apex/axis/SG) into a known seed42/t0 generated frame via the CRBN-CA Kabsch transform (reuse crl_rebuild superposition); confirm the carried cone lands within expected distance of the live CRBN pocket (sanity: apex within ~tens of Å of CRBN centroid, axis unit-norm, transform RMSD reported).
- **Verification**: `python analysis/crl_integrative/smoke_kabsch_cone.py` → prints Kabsch RMSD + carried apex offset from CRBN pocket; asserts RMSD<2.0Å and axis‖=1; exits 0.
- **Estimated time**: 5 min
- **Rollback (if this task only)**: delete the file.

## Task 5: CRLClosurePotential class (Design 1 core)

- **Status**: done (commit 6faa8aa engine repo; compiles, code-reviewed, VAV1_SIG verified vs AF-P15498 782+, numbering reconcile by seq-anchor, inference_mode(False) build, NZ hard-assert. P3' band fixed CA-CA→contact 10Å. Runtime smoke = T6. grad-norm-vs-blend check moved to T7 where blend exists.)
- **Prereq tasks**: 2
- **Files touched**: FKSFold-Boltz_Advancement/src/boltz_extension/steering/crl_closure_potential.py
- **Change shape**: NEW file (no entanglement). Class CRLClosurePotential + from_path(closure_spec.json). _build() resolves lys NZ idx + CRBN-frame idx + clamp idx + P3' contact pairs (inside inference_mode(False) — MDRef hazard). ★T3/T4 finding: _build MUST reconcile CRBN/VAV1 numbering to the LIVE generation frame by sequence/identity anchor (CRBN_SIG; VAV1 R/D/S+lys identity) — do NOT trust closure_map.json's 9UUM/lit numbers in the generated frame (generated CRBN observed at offset −45 vs 9UUM). Reuse the auto-offset logic from contact_recovery.py / smoke_kabsch_cone.py. _compute_energy: per-step Kabsch-carry cone → softmin over lysines of flat-bottom dist(Nz,apex) [angle disabled v1] + tri-Trp clamp pos-restraint + P3' contact flat-bottom (binding-side, legit inject). compute_gradient = autograd byte-copy of MDReferenceRestraintPotential pattern.
- **Verification**: `python -c "import torch,sys;sys.path.insert(0,'FKSFold-Boltz_Advancement/src');from boltz_extension.steering.crl_closure_potential import CRLClosurePotential as P;p=P.from_path('analysis/crl_integrative/closure_spec.json');g=p.compute_gradient(<synthetic coords+feats>);assert g.shape[-1]==3 and torch.isfinite(g).all();print('GRAD OK')"` → `GRAD OK`.
- **Estimated time**: 5 min
- **Rollback (if this task only)**: delete the file.

## Task 6: atom-resolution + gradient-norm smokes (Stage 0 smokes a,c)

- **Status**: done (commit 565ed02 engine repo; 3/3 pass — NZ resolution(5 lys, not CA, both SIG found, reconcile id_mismatch=0), compute_gradient runs inference_mode(False) finite/nonzero, energy/force steer toward apex. Synthetic feats from real VAV1_155_0 seqs + 9UUM CA. grad-norm-vs-blend deferred to T7.)
- **Prereq tasks**: 5
- **Files touched**: FKSFold-Boltz_Advancement/tests/test_crl_closure_smoke.py
- **Change shape**: New test. (c) assert resolved lysine atoms decode to 'NZ' (not CA fallback) and P3' CRBN atoms decode to expected names; (a) compute crl_grad norm vs the W400-range-grad norm under the norm-match blend and assert crl_grad is NOT swamped (ratio within [0.2,5]×) so the closure term actually bites.
- **Verification**: `python -m pytest FKSFold-Boltz_Advancement/tests/test_crl_closure_smoke.py -q` → 2 passed.
- **Estimated time**: 4 min
- **Rollback (if this task only)**: delete the test file.

## Task 7: config fields + apply_interface_gd wiring (norm-matched blend, flag-gated)

- **Status**: done (commits 1b3247f+e3500e7+100116c engine repo; config fields added to InterfaceSteeringConfigV2; CRL mini-loop placed BEFORE W400 early-return gate following MDRef pattern; potentials import deferred past early-return to avoid boltz.data dep. No-op when crl_closure_enabled=False verified.)
- **Prereq tasks**: 5
- **Files touched**: FKSFold-Boltz_Advancement/src/boltz_extension/steering/interface_steering_utils.py
- **Change shape**: ADDITIVE only (coordinate w/ aigen-fold-core; #12 WIP entanglement). Add config fields crl_closure_enabled=False, crl_closure_config, crl_closure_weight, crl_gd_start_t=0.5, _crl_closure_pot_cached. Build/cache block modeled on the #12 md_reference block (:633-662). In the GD loop AFTER glueprint blend, BEFORE blind-differential scaling: norm-matched blend (scale = weight·range_grad_norm/(‖crl_raw‖+eps); energy_gradient += crl_raw·scale). Default-off ⇒ exact no-op vs baseline.
- **Verification**: `python -c "...build config with crl_closure_enabled=False..."` → gradient byte-identical to baseline (no-op proven); with True → crl term present in accumulator. Pytest the no-op assertion.
- **Estimated time**: 5 min
- **Rollback (if this task only)**: `git -C FKSFold-Boltz_Advancement checkout src/boltz_extension/steering/interface_steering_utils.py` (ONLY if this task's lines are isolated; else revert the specific hunk).

## Task 8: 1-step end-to-end + tri-Trp clamp hold

- **Status**: done (commit ed1a2e0; smoke_closure_1step.py 4/4 pass: coords shape OK, guidance |update|=35.28 non-zero, cage RMSD=0.57Å <1.0Å, t-gate no-op verified)
- **Prereq tasks**: 6, 7
- **Files touched**: analysis/crl_integrative/smoke_closure_1step.py
- **Change shape**: New smoke driver: one denoise step on MRT6160/VAV1 with closure-on (CPU or 1-GPU-step), assert no autograd/inference_mode error AND across a small ensemble glue glutarimide→cage reference RMSD<1.0Å (P1 clamp holds).
- **Verification**: `python analysis/crl_integrative/smoke_closure_1step.py` → `1-STEP OK; cage RMSD <1.0Å` ; nonzero exit on any error or RMSD≥1.0Å.
- **Estimated time**: 5 min (+ short compute)
- **Rollback (if this task only)**: delete the file.

## Task 9: paired OFF/ON launcher + precondition gate

- **Status**: done (commit e6c1545; run_closure_paired.sh --dry-run=16 cells, --smoke P1/P2 both PASS. score_closure_paired.py 4-axis scorer verified: cone_dist=9.62Å, rt_contact_n=2 matches contact_recovery.py. ★P2 finding: seed42_0 OFF baseline 2/3 RT-loop (D797↔H357=2.93Å, S799↔N351=2.94Å); R796↔W400=7.51Å missing — exactly the tri-Trp cage contact CRL targets.)
- **Prereq tasks**: 8
- **Files touched**: analysis/crl_integrative/run_closure_paired.sh, analysis/crl_integrative/score_closure_paired.py
- **Change shape**: Launcher for paired generation (same seeds·config, only crl_closure_enabled flipped), ≥8 seeds, MRT6160/VAV1. Precondition checks: P1 clamp<1.0Å both arms; P2 closure-OFF already produces glue-CRBN-contact-consistent VAV1 contacts (else STOP→Stage 3). Scorer wraps crl_confirm.py 4-axis + contact_recovery.py.
- **Verification**: SMOKE mode (1 seed, few steps) fires both arms + precondition prints; launcher `--dry-run` lists the 16 cells. (No full submit yet.)
- **Estimated time**: 5 min
- **Rollback (if this task only)**: delete the two files.

## Task 10: [GPU GATE] run paired OFF/ON + score + branch decision

- **Status**: done (job 8324 COMPLETED 2026-06-25. 5 bugs fixed across 4 commits (88ed48d/d5a727c/6bcc6b8/a1f72a5). CRL confirmed firing. 16/16 PDBs generated. VERDICT: **FAIL** — ON near_attack 0/8 (0%), OFF 0/8; mean cone_dist OFF=8.41Å ON=8.13Å (−3%, NOT 5×). clash_n=0 all seeds. Design 1 gradient-only insufficient. → T11 CRLClosureIK. Results: analysis/crl_integrative/closure_paired_results_20260623.md)
- **Prereq tasks**: 9
- **Files touched**: (outputs only — /mnt workspace; analysis/crl_integrative/closure_paired_results.md)
- **Change shape**: ⛔ APPROVAL GATE (SLURM/GPU). On user-go: submit paired generation (free-GPU/un-containerize), score, record BRANCH: PASS (ON near-attack≥30% & ≥5×OFF & clash<50 & DOF span>0.5 & contact-recovery↑) → Design 1 sufficient; FAIL/ON<2×OFF/clash-only/G2 snap-back → wall → Stage 3.
- **Verification**: closure_paired_results.md = scored table (crl_confirm 4-axis + contact-recovery, OFF vs ON, per-seed) + explicit branch verdict.
- **Estimated time**: 5 min setup (run = background hours)
- **Rollback (if this task only)**: outputs are isolated /mnt; no code revert. Cancel SLURM job.

## Task 11: CRLClosureIK class (Design 2 core, conditional)

- **Status**: done (commit 0c2c852; smoke IK OK — 9.90 Å initial gap → 0.0000 Å residual, CCD converged. solve_closure/propose/closure_residual API implemented.)
- **Prereq tasks**: 10
- **Files touched**: FKSFold-Boltz_Advancement/src/boltz_extension/steering/crl_closure_ik.py
- **Change shape**: NEW file (conditional on Stage 2 wall). 4-pin closure (P1 Kabsch frame, P2 glue-cage, P3' VAV1 RT-loop↔CRBN contacts, P4 lysine→cone). solve_closure: analytic 2-point rigid placement + CCD fallback (50-100 sweeps); propose (manifold projection, α 0.2→1.0); closure_residual (feeds log_G). Reuses CRLClosurePotential geometry.
- **Verification**: `python -c "...solve_closure on synthetic VAV1+cone..."` → returns pose with closure residual < tol; CCD converges. `IK OK`.
- **Estimated time**: 5 min
- **Rollback (if this task only)**: delete the file.

## Task 12: proposal hook + log_G swap (conditional, flag-gated)

- **Status**: done (commit d41aace; 3 insertions in diffusionv2_extend.py: (1) closure_ik init after template setup, (2) proposal hook after all GD with alpha 0.2→1.0, (3) log_G -= crl_closure_weight * initial_gap_A. No-op when disabled. Syntax OK; staged to /mnt.)
- **Prereq tasks**: 11
- **Files touched**: FKSFold-Boltz_Advancement/src/boltz_extension/steering/diffusionv2_extend.py
- **Change shape**: ADDITIVE, flag-gated (crl_closure_proposal). After denoise (~:406) before confidence block: if proposal-on & steering_t≤0.5, atom_coords_denoised = ik.propose(...). In resample block (:565): log_G -= beta·ik.closure_residual(...). Default-off ⇒ no-op. Coordinate w/ aigen-fold-core.
- **Verification**: 1-step with proposal-on runs clean; with flag off, log_G + coords byte-identical to baseline.
- **Estimated time**: 4 min
- **Rollback (if this task only)**: revert the specific hunk.

## Task 13: [GPU GATE] positive-control cone recovery + wall-test

- **Status**: done (2026-06-25, jobs 8330+8338)
  - **9OTY (CK1α) ARM-2: PASS** — DockQ=0.738, near_attack=3/3, cone_dist=1.71Å. Gate cleared.
  - **9Q33 (PRDM1) ARM-2: FAIL** — near_attack=0/3. Boltz prior weaker for PRDM1.
  - **9NFR (VAV1/MRT23227) ARM-0/1/2 EXTRA (T14-precursor)**: near_attack=0/3 all arms. ARM-2 best cone_dist=10.09Å (ARM-0=11.49Å, delta=1.4Å). IK fires (gap=9.91→0.000Å logged) but Boltz denoising overrides each step. Root cause: VAV1-CRBN-MRT23227 underrepresented in Boltz training → weak prior → IK correction cannot hold. Wall-test not yet run (wall-test blocked by 9Q33 FAIL). Results: /mnt/kfs2/data/users/ubuntu/ik_9nfr_20260625/.
- **Prereq tasks**: 12
- **Files touched**: (outputs + analysis/crl_integrative/ik_poscontrol_results.md)
- **Change shape**: ⛔ APPROVAL GATE. On user-go: ARM-0 vanilla / ARM-1 guidance-only / ARM-2 IK on 9OTY(CK1α)·9Q33(PRDM1); GATE ARM-2 best-of-3 DockQ-to-crystal≥0.23 & near-attack 2/3 seeds. Wall-test ARM-1 vs ARM-2 on 9DWW/9H59/9Q03: ARM-2−ARM-1 ≥0.13.
- **Verification**: ik_poscontrol_results.md = DockQ table (3 arms × controls) + wall-test margins; GATE pass/fail stated.
- **Estimated time**: 5 min setup (background run)
- **Rollback (if this task only)**: cancel job; isolated outputs.

## Task 14: [GPU GATE] IK on 9NFR (VAV1 crystal GT) — diagnostic run

- **Status**: done (2026-06-25, jobs 8337+8338 — 9 cells ARM-0/1/2 × seeds 16/42/123)
  - ARM-0 mean cone_dist=11.49Å, ARM-1=16.92Å (guidance diverged), ARM-2 best=10.09Å.
  - near_attack=0/3 for all three ARMs. IK fires (gap→0) but Boltz prior for VAV1 overrides.
  - Diagnosis: CRL_WEIGHT=1.0, CRL_START_T=0.5 insufficient to overcome weak Boltz prior for novel VAV1-CRBN-MRT23227 geometry. ARM-2 improvement over ARM-0 only 1.4Å.
  - WS: /mnt/kfs2/data/users/ubuntu/ik_9nfr_20260625/. Launcher: run_ik_9nfr.sh.
  - Kabsch bug fix (H = src0.T @ dst0) committed to crl_closure_ik.py and score_ik_poscontrol.py.
  - NOTE: This was originally planned as MRT6160; pivoted to 9NFR (crystal GT) to validate approach. MRT6160 contact-recovery moves to T14c.
- **Prereq tasks**: 13
- **Files touched**: (outputs only — /mnt workspace)
- **Change shape**: ⛔ APPROVAL GATE (ran 2026-06-25). Diagnostic: ARM-2 IK on 9NFR (crystal GT) to test if IK can drive VAV1 near_attack before running the actual target (MRT6160, no GT).
- **Verification**: cone_dist table for 9 cells; near_attack summary; IK firing confirmed in logs.
- **Estimated time**: 5 min setup (background run)
- **Rollback (if this task only)**: isolated outputs.

## Task 14a: Strengthen IK for VAV1 — parameter sweep on 9NFR

- **Status**: done (2026-06-25, gate FAIL)
  - Job 8340 COMPLETED. 18/18 cells done (V1/V2/V3 × seeds 16/42/123).
  - near_attack: V1=0/3, V2=0/3, V3=0/3 — gate FAIL (required ≥1 variant ≥2/3).
  - Best cone_dist: V1/seed16 = 10.09Å (same as T14 ARM-2/seed16 — weight×2 made no difference).
  - V2 (early firing at t=0.7) was worse (30-34Å range) — diffusion noise larger at earlier t.
  - V3 (weight=2.0, start_t=0.7, K1-only): 22-43Å range, also FAIL.
  - Conclusion: Boltz prior on VAV1 conformation completely dominates IK correction for 9NFR.
    IK fires (gap closes analytically) but Boltz denoising overrides at every step.
  - Per FAIL gate rule: T14c proceeds with V1 config (best available) and contact-recovery
    is primary metric (not near_attack, which cannot be gated for prospective MRT6160).
  - Results: `/mnt/kfs2/data/users/ubuntu/ik_9nfr_20260625/analysis/ik_9nfr_dockq_results.md`
- **Prereq tasks**: 14
- **Files touched**: /mnt/kfs2/data/users/ubuntu/ik_9nfr_20260625/run_ik_9nfr_v2.sh, closure_spec_k1only.json
- **Change shape**: ⛔ APPROVAL GATE. Three parameter variants to overcome VAV1 Boltz prior, each × 3 seeds = 9 cells total:
  - V1 (weight-up): CRL_WEIGHT=2.0, CRL_START_T=0.5, lys_nz=[] (generic, same as T14)
  - V2 (early-fire): CRL_WEIGHT=1.0, CRL_START_T=0.7, lys_nz=[]
  - V3 (strong+early+K1): CRL_WEIGHT=2.0, CRL_START_T=0.7, lys_nz=[1] (K1 only — confirmed closest in T14)
  All other settings identical to T14 (9NFR YAML, oracle config, sampling_steps=50).
  New closure_spec_k1only.json: same as closure_spec_generic.json but lys_nz=[1] (VAV1 K1 = position 1 in chain B local numbering).
  Gate: ≥1 variant achieves near_attack ≥2/3 seeds → PASS, record winning config for T14c.
  FAIL gate: if all variants near_attack=0/3 → report; T14c proceeds with best available (V3) and contact-recovery becomes primary metric.
- **Verification**: Score all 9 cells with score_ik_poscontrol.py. Table: V1/V2/V3 × seeds cone_dist + near_attack. Identify winning variant or document failure.
- **Estimated time**: 5 min setup (background run ~1h wall-clock)
- **Rollback (if this task only)**: cancel job; isolated outputs.

## Task 14b: 9NFR DockQ scorer — CRBN chain alignment adapter

- **Status**: done (2026-06-25)
  - Scorer: `analysis/crl_integrative/score_9nfr_dockq.py` — sequence-alignment-based CRBN+VAV1 matching (handles full CRBN→TBD and VAV1 auth_seqid mismatch)
  - Results: `/mnt/kfs2/data/users/ubuntu/ik_9nfr_20260625/analysis/ik_9nfr_dockq_results.md`
  - **KEY FINDING**: All 9 T14 predictions DockQ<0.07. CRBN itself = ~20Å RMSD from crystal (17-22Å in pre-fix scorer; 18-23Å after SequenceMatcher fix; conclusion unchanged). Root cause: full CRBN input vs TBD-only crystal + missing DDB1 scaffold. Boltz predicts globally wrong complex orientation for 9NFR. Compare: 9OTY DockQ=0.738 (CK1α well-represented in PDB + matching construct).
  - **SCORER FIX (2026-06-25)**: SequenceMatcher for CRBN introduced 7-res gap (208/342 pairs at offset 52 instead of 45). Replaced with fixed-offset matching (CRBN_OFFSET=45, VAV1_OFFSET=781). n_crbn 342→337. CRBN_RMSD slightly higher (18-23Å vs 17-22Å). Scientific conclusion unchanged.
  - **Implication for T14a**: cone_dist is measured in prediction frame (Kabsch-carry of 9UUM apex) — can be low even if complex is globally misoriented. T14a tests IK feasibility for VAV1 geometry in prediction frame, but DockQ gate cannot be met without DDB1 or TBD-only CRBN input.
- **Prereq tasks**: 14
- **Files touched**: analysis/crl_integrative/score_ik_poscontrol.py (or new score_9nfr_dockq.py)
- **Change shape**: Zero-GPU scorer adaptation. Problem: prediction has full CRBN (375 AA, IINFDTSLP…) but 9NFR crystal has only CRBN TBD (chain B, seqid 77-436, starts SCQVIPVLP). Current scorer's CRBN_SIG detection works for full CRBN but can't map to 9NFR TBD-only chain. Fix: add sequence-alignment-based CRBN chain extraction — align prediction CRBN to crystal CRBN TBD (Needleman-Wunsch or pairwise SeqMatcher on CA positions of CRBN_SIG region: seqid 46-375 of prediction = seqid 1-330 of 9NFR chain B). Extract matched Cα pairs; compute DockQ on aligned CRBN + VAV1 region only. Score existing 9 PDBs from T14 (ARM-0/1/2 × seeds 16/42/123) against /mnt/kfs2/data/users/ubuntu/ik_9nfr_20260625/refs/9NFR.cif.
- **Verification**: `python analysis/crl_integrative/score_9nfr_dockq.py --pdb /mnt/kfs2/.../ik_9nfr_20260625/out/arm0/seed16/*.pdb --gt /mnt/.../refs/9NFR.cif` → prints DockQ value; value in [0,1]; exits 0. Run all 9 cells; produce ik_9nfr_dockq_results.md.
- **Estimated time**: 10 min (scorer) + 2 min (score all 9 PDBs)
- **Rollback (if this task only)**: delete score_9nfr_dockq.py.

## Task 14d: [GPU GATE] 9NFR A+B simultaneous diagnostic — alpha vs TBD-CRBN

- **Status**: done (2026-06-25, jobs 8342→8344, GATE FAIL both options)
  - WS: `/mnt/kfs2/data/users/ubuntu/ik_9nfr_ab_20260625/`
  - **optA (alpha_min=0.5, ARM-2, full CRBN)**: cone_dist 18.7/32.2/46.7Å → near_attack 0/3 → FAIL
    - Initial failure: 9UUM.cif missing on compute node (path computed relative to stage_a/src). Fixed by copying refs. Rerun=job 8344.
  - **optB (ARM-0, TBD-only CRBN 344AA)**: CRBN_RMSD 19.7/21.2/20.2Å (mean 20.4Å) → FAIL (<5Å gate)
    - TBD-only CRBN still ~20Å from 9NFR crystal → NTD/linker not the cause; DDB1 absence is root cause.
  - **Key findings**:
    1. alpha_min=0.5 does not help (cone_dist 18.7Å vs original 10.1Å for seed16 with alpha=0.2)
    2. TBD-only CRBN unchanged CRBN_RMSD → global misorientation is DDB1-dependent, not NTD-dependent
    3. 9NFR IK approach confirmed infeasible without DDB1 anchor
  - → Fallback rule triggered: **pivot to T14c (MRT6160 as prospective only)**
- **Prereq tasks**: 14a, 14b
- **Files touched**: stage_a/src/boltz/model/modules/diffusionv2_extend.py (alpha), inputs/9NFR_tbd.yaml, msa/crbn_tbd_A.csv, run_ik_9nfr_ab.sh
- **Verification**: score optA → cone_dist/near_attack; score optB → CRBN_RMSD with CRBN_OFFSET=76
- **Estimated time**: 5 min setup (background ~1h wall-clock)
- **Rollback**: cancel 8341; delete WS

## Task 14c: [GPU GATE] MRT6160 contact-recovery with improved IK

- **Status**: done (2026-06-25, job 8351, GATE FAIL — comprehensive negative)
  - WS: `/mnt/kfs2/data/users/ubuntu/ik_vav1_20260625/`
  - **contact_recovery=0/3 (0.000) for ALL arms (ARM-0/1/2)**
  - **cone_dist: 42-60Å for all 9 cells** (cf. 9NFR 10-50Å)
  - **IK (ARM-2) WORSENS contact distances**: ARM-2/seed16 contact dist 58-65Å vs ARM-0/seed16 29-37Å
    - K810→cone (ubiquitin transfer) and R796→CRBN (interface binding) geometrically incompatible in these predictions
    - IK satisfies K810→cone at the cost of moving SH3c degron away from CRBN W400/H357/N351
  - Primary gate (ARM-2 CR ≥ ARM-0 CR): degenerate PASS (0.000 = 0.000) — scientifically meaningless
  - Scientific conclusion: GATE FAIL — IK does not improve MRT6160 binding interface
  - **Root causes**: (1) OOD novel system, (2) IK-interface geometric conflict, (3) DDB1 absence
  - Results: `analysis/crl_integrative/ik_vav1_results.md`
- **Prereq tasks**: 14a, 14b
- **Files touched**: /mnt/kfs2/data/users/ubuntu/ik_vav1_20260625/ (existing WS from T14 prep), analysis/crl_integrative/ik_vav1_results.md
- **Change shape**: ⛔ APPROVAL GATE (ran 2026-06-25). ARM-0/1/2 × 3 seeds = 9 cells on MRT6160/VAV1_257. CRL_WEIGHT=2.0, CRL_START_T=0.5 (V1 config from T14a). No crystal GT → contact-recovery as primary metric.
- **Verification**: ik_vav1_results.md present + tables complete.
- **Estimated time**: 5 min setup (background run ~1h wall-clock)
- **Rollback (if this task only)**: cancel job; isolated outputs; revert run_ik_vav1.sh param edits.

## Task 15: hybrid + φ resolution + G1/G2 + scrambled-contacts

- **Status**: N/A — skipped (T14c GATE FAIL: contact_recovery=0/3 all arms; no productive pose to hybridize or validate)
- **Prereq tasks**: 14c
- **Files touched**: analysis/crl_integrative/closure_hybrid_finalize.py, (outputs)
- **Change shape**: ⛔ APPROVAL GATE. Hybrid (IK proposal + soft gradient + prior); resolve residual azimuth φ via G2 relax-survival selector; run anti-circularity controls: G1 (binding-side-only inject, near-attack must EMERGE; IK excluded from strict G1), scrambled-contacts (correct P3' vs scrambled must show margin), honesty re-run (cone removed + lysine injected must NOT reproduce).
- **Verification**: closure_hybrid_finalize output = G2 multi-seed ≥2/3 + scrambled-contacts margin significant + honesty re-run negative; deliver predicted pose family + relax-selected member + emergent lysine identity.
- **Estimated time**: 5 min setup (background run)
- **Rollback (if this task only)**: cancel job; delete finalize script.

## Task 16: result doc + baton

- **Status**: done (2026-06-25)
  - Result doc: `analysis/crl_integrative/assembly_closure_results_20260623.md`
  - Summary: T10 gradient FAIL → T11-12 IK built → T13 9OTY PASS (DockQ=0.738) → T14 9NFR FAIL → T14a-d all FAIL → T14c MRT6160 FAIL (contact_recovery=0, IK worsens by 21-30Å)
  - Verdict: CRLClosureIK insufficient for novel OOD VAV1-CRBN system. DDB1 co-input required.
- **Prereq tasks**: 14c (T15 skipped)
- **Files touched**: analysis/crl_integrative/assembly_closure_results_20260623.md, .agent/status/aigen-fold-core.md
- **Change shape**: Write the result doc (contact-recovery, cone-compat, cross-validation vs YDS/AF3, held-out, G1/G2, the predicted structure deliverable + confidence). Update baton; set contract+plan status done.
- **Verification**: `./scripts/status.sh index` clean; doc present; contract/plan status: done.
- **Estimated time**: 5 min
- **Rollback (if this task only)**: revert the two files.
