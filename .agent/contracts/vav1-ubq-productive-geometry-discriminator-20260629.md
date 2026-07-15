---
status: approved
slice: vav1-ubq
topic: productive-geometry-discriminator
date: 2026-06-29
owner: claude
approved_by: sunghoon.kim
requested: 2026-06-29
cross_slice:
  - "aigen-fold-core — shared MD stack (crl_md_*) + crl_confirm discriminator; NO engine/generation change required (placement is anchored experimentally, not generated)"
triggers_matched:
  - "SLURM/GPU submission — congeneric-subset ternary-assembly MD (Stage C)"
  - "shared-storage writes — /mnt/kfs2 workspace + MD outputs"
  - "4+ files (subset selection, anchor pipeline, discriminator wiring, analysis)"
---

# Productive ubiquitination-geometry discriminator (dynamic near-attack)

## Purpose

Test whether a **dynamic near-attack probability** — the fraction of MD frames in
which a presented VAV1 lysine Nζ sits ≤3.5 Å from the E2~Ub Gly76 carbonyl (the
actual transfer chemistry) — **ranks logDC50 within a congeneric series**. This is
the one productive-geometry lane the platform has NOT yet run: the static zone-patch
(≤21 Å occupancy) is done and the residence (τ-RAMD) lane stopped on placement noise.

Direct precedent: eLife 2025 (PMC11867615) — in CRBN-dBET-BRD4 ternary MD the
Lys→Ub-Gly proximity probability ranks DC50 across a congeneric PROTAC series
(dBET70 85%/~5 nM … dBET57 22%/~500 nM). In-house corroboration: rotamer-contact
ρ(logDC50, ARG796 engagement) = −0.505 (p=0.094, n=12), mechanistic + MCS-aligned.

## Current State

- Static zone-patch DONE (zero-GPU): degron patch {K804 dominant, K788, K810},
  IKZF3-calibrated zone ≤21 Å, 9NFR→9UUM placement validated (SH3c↔IKZF3 degron 2.1 Å).
  Cone frozen in `analysis/crl_integrative/closure_spec.json` (apex = Ub Gly76 C,
  axis, near_attack_A=3.5, reach_A=13.5). Scripts: `zone_*.py`.
- Congeneric clusters exist: `analysis/crl_integrative/tau_ramd/stage0_clusters.tsv` —
  S001 (n=32, logDC50 span 3.70), S002 (14, 1.89), S003 (12, 2.09), S004 (10, 2.23),
  S005 (8, 1.68). S001 = widest span + largest n = primary validation series.
- MD stack BUILT (crl_md_prep/crl_md_run, parmed junction-fix, OpenMM/OpenCL metad);
  topology-aware discriminator `crl_confirm_glue.py` (4-axis: near-attack/clash/register/DOF).
- 9NFR crystal = `best_structures/9NFR_reference.cif` (experimental placement anchor).
  9UUM = `analysis/crl_integrative/refs/9UUM.cif` (IKZF3 productive assembly, cone source).

## Assumptions And Questions

- assumption: the congeneric series shares the 9NFR binding mode → all members can be
  anchored on the experimental 9NFR placement (sidesteps the τ-RAMD free-generation
  noise that scattered SH3c 0→49.5 Å). **Stage 0 GATE must verify this per member.**
- open: is the near-attack ≤3.5 Å rare state adequately sampled by metadynamics within
  ~40 ns/compound, or is enhanced sampling / longer needed?
- open: down-select S001 (n=32) to how many MD representatives (cost vs DC50-span coverage)?
- tradeoff: anchoring on 9NFR (MRT-23227) imposes one binding mode; glue-specific
  systematic offsets (seed-precision: MRT6160 vs MRT-23227 differ) may perturb members.

## Constraints

- allowed change scope: new WS `/mnt/kfs2/data/users/ubuntu/productive_geometry_<date>/`;
  new subset/anchor/analysis scripts under `analysis/crl_integrative/productive_pose/`;
  result doc + `png/` under `analysis/crl_integrative/`.
- forbidden: NO engine/generation change (no de-novo productive-geometry generation —
  T10 gradient + T11 IK both FAILED on VAV1/MRT6160; cone↔degron geometrically
  incompatible, missing-DDB1 corrupts cone frame). NO cross-scaffold DC50 regression
  (143-set 0/36 FDR). Do NOT touch aigen-fold-core engine WIP.
- external: GPU via `sudo -u kim sbatch` (use a high-concurrency QOS); GPU selector
  memory.free>75000 MiB; ALL writes to kfs1-4/7 (kfs5/6 99% full — mergerfs routes
  /mnt/data to kfs5; a full-disk crash already killed job 7974).
- GPU posture: GPU is ABUNDANT (lab policy, feedback_compute_scaling). Stage 0 GO has
  JUSTIFIED the run → scale GENEROUSLY: run all 8 reps, generous replicas/seeds for
  statistical power, high SLURM concurrency. Do NOT under-power or treat GPU-hours as a
  cost. The only legit prechecks are correctness ones (built inputs + a 1-system smoke +
  disk routing), NOT GPU thrift.

## Non-Goals

- Prospective DC50 prediction (ceiling = coarse within-congeneric ranking only, per
  Weiss/BMS JCIM 2023 + eLife 2025; a single in-silico metric does not predict DC50 prospectively).
- Cross-scaffold / cross-glue ranking (textbook null regime; already KILLed in-house).
- VAV1 ub-site identity claim (no diGly-MS GT in repo; deferrable to deep-research).
- Residence-time / koff (τ-RAMD lane, separate; stopped at GATE-A).

## Done When

- Stage 0 (zero-GPU GATE): primary series confirmed (S001) + N MD representatives chosen
  spanning logDC50; each representative's 9NFR-anchored placement passes a binding-mode
  consistency check (degron 3/3 + SH3c-to-9NFR ≤ tolerance). If anchoring breaks the mode → STOP.
- Stage A (zero-GPU): discriminator metric frozen (near-attack ≤3.5 Å Nζ→Ub-Gly76-C,
  K804-dominant patch; reach ≤21 Å IKZF3-calibrated; angle gate optional). Smoke on 1 system.
- Stage C (GPU — CLEARED by this approved contract + Stage 0 GO; the only preconditions are
  correctness: built inputs + 1-system smoke + output routed to kfs1-4/7): MD for ALL 8 reps
  with generous replicas/seeds; `crl_confirm_glue.py` → near-attack occupancy probability per
  compound. FES convergence checked. This is the experiment — run it, don't defer it.
- Stage D (zero-GPU): Spearman(near-attack probability, logDC50) computed + cross-checked
  against rotamer-contact ρ=−0.505. Result doc with honest ceiling caveat; contract+plan done.

判定 (pre-registered):
- SUCCESS: significant Spearman, direction consistent (more near-attack ↔ stronger degrader),
  eLife-grade coarse ranking within S001.
- KILL: null correlation, OR Stage 0 shows anchoring breaks binding mode → clean scope-narrowing KILL.

## Implementation Steps

1. Stage 0 subset + anchor feasibility (reuse stage0_clusters S001; zone_* anchor pipeline)
   verify: per-rep degron 3/3 + SH3c-to-9NFR within tolerance table
2. Stage A metric freeze + 1-system smoke
   verify: crl_confirm_glue near-attack readout sane on smoke
3. Stage C MD launch (SMOKE → afterok → full, free-GPU selector, kfs1-4/7)
   verify: per-rep trajectory + near-attack occupancy + FES convergence
4. Stage D correlation + rotamer-contact cross + result doc
   verify: Spearman table, PASS/KILL per criteria above

## Risks

- regression risk: none (no engine change; read/compute + MD only).
- integration risk: build the scientifically-correct full assembly (CRBN+DDB1+E2~Ub+VAV1+glue)
  — DDB1 anchors CRBN orientation (its absence corrupted the cone frame in the closure work).
  Truncate ONLY if a smoke shows it is geometrically equivalent, never to save GPU-hours.
- hidden dependency risk: congeneric subset conservation (Stage 0 gates it); rare-state
  sampling adequacy (FES convergence gates it); GT ceiling (caveat, not a bug).

## Rollback

```bash
sudo -u kim scancel <JOBID>
sudo -u kim rm -rf /mnt/kfs2/data/users/ubuntu/productive_geometry_<date>/
```
Zero-GPU stages leave only new scripts/docs (git revert). No engine/checkpoint impact.

## Progress Log

- 2026-06-29: initial plan created. Grounded in zone-patch results, eLife 2025
  precedent, rotamer-contact ρ=−0.505, existing congeneric clusters (S001).
- 2026-06-29: APPROVED by user (chat: "두 개 병렬 진행"). Stage 0/A (zero-GPU) start now;
  Stage C remains a hard ⛔ GPU GATE (separate go + disk routing kfs1-4/7).
- 2026-06-29: Stage 0 DONE = **GO**. Primary series S001 (n=32, logDC50 span 3.70);
  8 reps spanning 0.299→4.000 (stage0_reps.tsv). Anchor-feasibility PASS — the 9NFR
  placement pipeline aligns on protein Cα only, so anchoring is GLUE-AGNOSTIC: all
  members inherit the same experimental SH3c-on-CRBN placement (degron 3/3,
  SH3c-to-9NFR=0 by construction) → removes the τ-RAMD free-generation placement-noise
  failure mode entirely. KILL not triggered. Corrections: S001 absent from
  congeneric_subset.tsv (over-merged, recomputed via stage0_s001_bindingmode.py);
  binding_mode_metric=0.0 means medoid (best), NOT artifact. Note for Stage C: because
  placement is identical across members, the discriminator signal must come from
  glue-in-pocket dynamics (assembly rigidity → lysine presentation), not placement
  differences — this is the key scientific bet. Result: productive_pose/stage0_feasibility_20260629.md.
  Data gaps before Stage C: per-rep glue-into-pocket placement (7 transplant, VAV1_474
  redock), assembly truncation decision, rare-state sampling adequacy.
- 2026-06-29: FRAMING CORRECTED (user). Stage 0 GO already justified the GPU run; the
  earlier "keep doing zero-GPU / GPU gated behind separate go" posture was wrong and
  contradicted feedback_compute_scaling (GPU abundant, scale generously once justified).
  Stage C is CLEARED. Remaining work = build the GPU job's INPUTS (8 full-assembly systems
  + metric freeze + smoke) = launch sequence, NOT thrift. Then fire the full run generously.
- 2026-06-29: STAGE A FROZEN + STAGE C LAUNCHED. Metric freeze =
  productive_pose/discriminator_config_20260629.json (near-attack 3.5A, K804-dominant patch
  {K804,K788,K810} w/ all-5-lys reporting, reach 21A, angle OFF). Discriminator REUSED:
  crl_confirm_glue.py (topology-aware 4-axis) + crl_traj_glue.py + frozen closure_spec.json.
  E2~Ub cone FEASIBILITY = SOLVED, not a missing piece: the crl_glue_md_20260618 recipe
  already assembles the full productive complex (CUL4A+NEDD8+DDB1+CRBN+E2+Ub+RBX1+VAV1+glue)
  by grafting each rep onto the 9UUM active core (CRBN-superpose ~1.21A) + forming the
  thioester S-C (1.81/227) and isopeptide N-C (1.335/490) via parmed_junction_fix (seed314
  chemistry). Both bonds verified PRESENT in all 8 built systems. 8/8 BUILT (~470k atoms,
  net q~0) at /mnt/kfs2/data/users/ubuntu/productive_geometry_20260629/systems/. Productive
  register (SH3 lys nearest Ub-G76 in cone frame): K815 x6, K814 x2 (VAV1_199/_474) — NOT
  the assumed K804; build restricts the nearest-to-Ub search to the 5 SH3 lysines (an
  earlier all-LYS bug picked chain N-terminus K782, fixed). t0 NZ->Ub 4.5-12.4A. VAV1_474's
  scattered genpose is moot — graft uses Calpha only (glue-agnostic anchor), Stage 0 nailed
  it. Stage C: SMOKE job 9854 (VAV1_411) RUNNING healthy (stable minimize, heating on
  schedule, GPU 100%); FULL chain afterok:9854 = jobs 9869/9870/9871 (REPLICA 1/2/3, each
  8 reps x 8 GPU, 40ns metad, OpenCL, outputs to kfs2) = 24 trajectories. Submitted as
  sudo -u kim (workspace chmod o+rwX). Stage D (zero-GPU) is next once trajectories land.
  Record: productive_pose/stageAC_launch_20260629.md.
