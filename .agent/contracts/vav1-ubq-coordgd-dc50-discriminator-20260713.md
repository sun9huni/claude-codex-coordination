---
status: done
slice: vav1-ubq
topic: coordgd-dc50-discriminator
date: 2026-07-13
owner: claude
requested: 2026-07-13
approved_by: sunghoon.kim (2026-07-13, "다음 계획 진행")
cross_slice: [aigen-fold-core]
triggers_matched:
  - "SLURM/GPU submission — (a) build stage-2 ternary inputs for Stage-D 8 + C147 via the 2-stage dock
    pipeline, then (b) a large coord-GD min-steering sweep: ~10 targets x ~11 compounds x N gd_scale
    steps (kim account, un-containerized rootfs). Large GPU campaign, user-justified broad scope."
  - "ranking-adjacent semantics — a candidate DC50 discriminator (coord-GD reaching-efficiency =
    minimum steering) is evaluated against logDC50 / active-inactive; compared to the vav1-ubq WTMetaD
    FES-barrier discriminator (rho=+0.714)."
  - "4+ files — input-build driver/launcher + coord-GD min-steering sweep launcher + reaching-efficiency
    extraction + discriminator analysis + results doc."
---

# vav1-ubq — coord-GD reaching-efficiency DC50 discriminator (direction-1 follow-up)

## Purpose

coord-GD productive-geometry steering is now mechanism-validated (contract
vav1-coordgd-productive-steering-20260713: P1 clean-control + C1 near-attack both PASS, on-manifold,
CRBN intact). Execute the original goal: test whether coord-GD REACHING-EFFICIENCY discriminates
degradation potency — a per-compound-cheap, generation-side analog of the 40ns-MD WTMetaD FES-barrier
discriminator (rho=+0.714 p=0.047 n=8, 474-fragile). Central caveat (held fixed, written into
Done-When): coord-GD reaches ANY defined target by construction (proven at C1: Nζ 17→2.6Å), so
"reached" is NOT evidence a target is the right notion of productive. Target validity is adjudicated
ONLY by external signal held fixed across all targets: reaching-efficiency vs logDC50, active/inactive
separation, physical validity (clash / CRBN-VAV1 internal distortion), and seed convergence.

## Current State (reusable, all committed)

- coord-GD engine block (rootfs, env COORDGD_STEERING + hook _COORDGD_POTENTIAL; coordgd_wire.diff),
  CoordGDPotential adapter, coordgd_driver (feats atom-index NW resolver + C1 frame-invariant
  cone-Kabsch carry, --gd-scale / --gd-steps / --target / --compound), coordgd_measure
  (SH3c/clash/crbn_fit + crystal-independent internal-distortion + near-attack), the 10-target
  differentiable loss battery (losses_coord P1 / losses_catalytic C1-4 / losses_interface P2-3,G1-2,M1).
- reaching-efficiency = MINIMUM STEERING: per (compound, target), sweep gd_scale down and record the
  smallest gd_scale that still REACHES the target threshold with a CLEAN structure (clash not elevated
  + CRBN internal distortion small). Lower min-scale = reaches with less push = more "productively
  predisposed" = candidate stronger-degrader signal. Each target's "reach threshold" comes from its
  loss/config (e.g. C1 near-attack ≤ 4.5Å; P-targets an SH3c/interface Å threshold; etc. — frozen per
  target before the sweep).
- Compound set: Stage-D 8 (DC50 spread, the WTMetaD FES rho=+0.714 comparator; identities from the
  vav1-ubq Stage-D work) + MRT6160 (active) + C147 (inactive). Targets: full battery
  (C1-4, P1-3, G1-2, M1) = 10.
- ★PREREQ (GPU): coord-GD needs a per-compound stage-2 templated ternary input YAML (like
  VAV1_MRT6160_tmpl.yaml). Only MRT6160 exists; Stage-D 8 + C147 stage-2 inputs must be BUILT via the
  existing 2-stage dock pipeline (api/pipeline.py / the phase8 dock driver). This input-build is part
  of scope (a GPU sub-campaign preceding the sweep). Inventory which already exist first.
- Baselines: unsteered per compound gives the SH3c/near-attack/clash reference for "reached + clean".

## Success criteria (measurement + honest report; NO performance gate — no-GT regime)

Produce `coordgd_dc50_results.csv` + a discriminator analysis with, per target (10):
- Spearman(min-steering-efficiency, logDC50) with bootstrap CI over the DC50-labeled compounds
  (Stage-D 8 + MRT6160; n≈9), reported WITH the CV/n regime and a multiple-testing note across the
  10 targets.
- active/inactive separation: MRT6160 (active) vs C147 (inactive) min-steering-efficiency.
- physical-validity + seed-convergence columns held fixed across targets (clash, CRBN internal
  distortion, seed spread of min-scale).
- an explicit comparison of the best target's rho to the MD WTMetaD FES rho=+0.714.
DONE = the table + analysis are produced with CIs + the reaching≠validation caveat + the
multiple-testing correction, honestly reporting which target(s) (if any) show signal. A NULL result
(no target discriminates) is a valid, complete outcome — this is a validation measurement, not a
gate. Verification command: `python3 .agent/scratch/compass_steering/coordgd_dc50_analysis.py`
→ the per-target rho+CI table + active/inactive + caveat; plus the sweep GPU jobs COMPLETED.

## Out of scope (adjacent, intentionally NOT this contract)

- Boltz ensemble finetune (post-COMPASS direction 2) — separate contract.
- Deploying this discriminator as a production DC50 predictor or changing the shipped v1.1 ranker /
  the WTMetaD FES discriminator — this is a validation measurement only.
- Ligand-feature / glue-atom guidance (backbone + Nζ targets as in the validated battery).
- New target-loss definitions beyond the existing 10-battery.
- Prospective (new-compound) prediction — retrospective on the DC50-labeled set only.

## Constraints

- Reuse the validated coord-GD engine/driver/measure/battery unchanged (only add a min-steering sweep
  wrapper + input-build + analysis); any engine touch stays additive + env-gated in the rootfs copy.
- GPU: kim account, un-containerized rootfs, --qos=normal, free-GPU selector (mem.free>75GB), output
  to kfs2 (NOT kfs5/kfs6). GPU is abundant and this broad scope is user-justified; standing SLURM
  pre-approval for this line of work (user, 2026-07-13). Diagnose-before-scaling: validate the sweep +
  efficiency extraction on C1 + 2-3 compounds BEFORE the full 10x11xN matrix.
- Scripts + outputs under .agent/scratch/compass_steering/ + kfs2 run dirs.

## Resource budget

Large but justified. Input-build: dock Stage-D 8 + C147 (~9 x 2-stage) if missing. Sweep: ~10 targets
x ~11 compounds x N gd_scale (e.g. 5) x (1 seed first) ≈ up to ~550 short Boltz runs + baselines,
backfilled across free GPUs. Staged: control-subset sweep first (C1 x {MRT6160, C147, 2-3 Stage-D})
to validate the min-steering extraction, then scale to the full matrix. Analysis zero-GPU.

## Rollback plan

No production change (validation measurement; nothing shipped). `scancel` any running array; delete
kfs2 output dirs; the coord-GD engine flag stays off by default (byte-identical stock). Analysis/
scripts are scratch. Built stage-2 inputs are reusable artifacts (kept, not rolled back).

## Approval

- requested: 2026-07-13
- approved by: sunghoon.kim (2026-07-13, "다음 계획 진행")

## Notes (closeout 2026-07-14)

DONE, verdict NULL. Full record .agent/scratch/compass_steering/results_coordgd_dc50.md;
plan same slug done (16 tasks: 1-8,13-16 done; 9-12 SKIPPED per the user scope decision below).

Built the discriminator machinery (C147 stage-2 input builder + generalized coord-GD driver
[--skip-unsteered] + frozen reach-threshold/DC50 config + min-steering sweep launcher + reaching-
efficiency extraction + pure-stdlib Spearman/perm-p/bootstrap-CI/BH analysis), all /code-review-gated
+ selftest. Ran the control-subset GPU gate (job 16896, C1·P1 × {MRT6160,C147,VAV1_211,VAV1_474}):
GATE VERDICT = extraction WORKS but signal NULL (all min_scale equal across the potency span). User
scope decision at the gate (2026-07-14): expand the validated C1/P1 discriminator to the full
9-compound DC50 panel (properly power the WTMetaD ρ=+0.714 comparison) and DEFER wiring the 8
exploratory targets (C2-4/P2-3/G1-2/M1) — with the mechanistic C1 target null, exploratory targets
unlikely to help; ~550-run + wiring cost not justified. Panel completed via 6 GPU-parallel jobs
(16953-16957 + control subset).

RESULT (n=9 = Stage-D 8 + MRT6160): C1 reaching-efficiency does NOT discriminate logDC50 —
Spearman ρ=+0.137, perm_p=0.89, 95% CI [−0.315,+0.575]; ladder-independent continuous min-steering
ρ=−0.317 (OPPOSITE sign = noise, not a discretization artifact); active(MRT6160)=inactive(C147)
min_scale 0.5 (no separation); P1 all min_scale 0.125 (zero variance). Clean 9/9 (extraction sound).
MECHANISM: coord-GD forces geometry by gradient (no thermodynamic resistance) so reaching-efficiency
is dominated by pipeline/geometry, not glue chemistry — contrasts MD WTMetaD FES (ρ=+0.714) which
measures the free-energy barrier the system resists. reaching≠validation, made concrete + quantified.

SHIP: nothing to production (validation measurement; NULL is a valid, complete no-GT outcome). coord-GD
stays validated for productive-geometry GENERATION (direction 1, results_coordgd.md) but is NOT a DC50
discriminator. potency signal, if needed, remains with the MD WTMetaD FES path (expensive, 40ns/cmpd).
Reusable: the full discriminator harness (sweep + extraction + analysis + sensitivity) generalizes to
any coord-GD target; 8 exploratory targets re-openable as a separate contract if ever justified.
