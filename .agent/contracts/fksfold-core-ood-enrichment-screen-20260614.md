---
status: done
slice: aigen-fold-core
topic: ood-enrichment-screen
date: 2026-06-14
owner: claude
approved_by: user (2026-06-14, "진행")
triggers_matched:
  - "SLURM/GPU evaluation run"
  - "multi-target benchmark criteria"
  - "local repo + shared execution workspace"
---

# OOD-enrichment screen — find more clean AIGEN rescues

## Goal

The 12-target benchmark left exactly ONE clean full rescue (9DWW PDE6D:
baseline median 0.005 → AIGEN 0.472, 3/3 accept). That single case is the
bottleneck of the "AIGEN rescues OOD placement" claim. 9NFR is NOT a clean
rescue (A-b 2026-06-14 showed the only accept-crossing arm was circular —
templated on the 9NFR crystal). Random CRBN curation only adds co-success
(of the 5 newly-curated targets, 4 were Boltz-2 0.76–0.89 baseline).

This contract runs a TWO-PHASE diagnose-before-scale screen to enrich for
genuine OOD cases and add 2–4 more clean rescues:

- **Phase 1 (baseline screen)**: pure Boltz-2 co-fold (sequences only, NO
  pocket constraint, NO steering, `--num_particles 1`) over 15 curated
  candidates × 3 seeds. KEEP only targets whose **median baseline DockQ <
  0.23** (Boltz-2 genuinely collapses = real OOD). Discard co-success.
- **Phase 2 (steer survivors)**: run `aigen_biophysical_hybrid` (p8,
  interface_lambda=20, w400) on the OOD survivors × 3 seeds. Score DockQ.
  A clean rescue = baseline median <0.23 AND AIGEN median ≥0.23.

## Candidate pool (15, self-DockQ=1.0 validated 2026-06-14)

Curated from RCSB cereblon (UniProt Q96SW2) entries, biased to novel/large
globular targets (more likely OOD) + a few degron controls. Distinct from the
13 panel PDBs. CRBN/target chains + glue CCD from RCSB GraphQL; GT chain maps
in `score_heldout_dockq.GT_CHAIN_MAP`.

- Novel/large (OOD-likely): 9YA9 BCL6, 9Q03 BCL6, 9Q33 PRDM1, 8UH6 PTPN2,
  9OTY CK1α, 8G66 CK1α, 9H59 Nek7 (diff glue vs 9NFQ), 9DWV PPIL4, 9SAI BRD4,
  8TNR MBP-SD40 fusion.
- Degron controls: 9OUK Ikaros, 9Q22 Helios, 9NWT SALL4, 9E2U Helios(long),
  9Y7D Ikaros(long).
- Dropped 6XK9 (no glue-pocket contacts on its target chain in the AU).

## Conditions

- `boltz2_baseline`: sequences only, no constraints, no steering, num_particles=1.
- `aigen_biophysical_hybrid`: interface_scoring_type=biophysical_hybrid,
  interface_lambda=20, num_particles=8, interface_resampling_interval=3,
  w400 conditioning (A=CRBN, B=target), biophysical config per target.
- Seeds: 42, 16, 123 (median over 3).

## SLURM Plan

- OUT_BASE: `/mnt/data/users/ubuntu/workspace/ood_enrichment_screen_20260614`
- Code mounts: stage/src (copy of validated multitarget stage src; fragmap
  wiring present — main.py + diffusionv2{,_extend}.py + boltz_extension).
- Image: `fksfold-boltz:glueplex-v2`. QoS batch, 1 node, array `%8`, 2 h walltime.
- Phase 1 manifest: stage/manifest_baseline.tsv (45 rows). Submit FIRST.
- Phase 2 manifest: stage/manifest_aigen.tsv (45 rows) — submit only the
  OOD-survivor subset after Phase 1 scoring.
- `PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True` (allocator defrag).

## Required Output Columns

- case_id, target_id, condition, seed, output_pdb, confidence_json
- DockQ, DockQ_status, iptm, complex_ipde, protein_iptm, confidence_score
- generation_status, notes

## Done When

- Phase 1: 45 baseline rows generated; DockQ scored vs GT; per-target median
  computed; OOD survivors (median<0.23) listed explicitly.
- Phase 2: survivors steered + scored; clean-rescue count reported.
- Both phases' manifests/outputs/logs exist under OUT_BASE; summary TSV written.
- Co-success (median≥0.23) targets are labeled and excluded from the rescue claim.

## Verification

- `bash -n` on the SLURM script; dry-run manifest count before submit.
- After generation: count completed `*_model_0.pdb` + `confidence_*_model_0.json`.
- DockQ scorer on every row (GT chain maps self-DockQ=1.0 pre-validated).
- Report missing/failing rows explicitly; no silent drops.

## Risks

- Repo is dirty; touch only new OOD files, never existing dirty files.
- Glue-pocket constraint is crystal-derived (same info class as the panel's
  aigen arm; NOT the DockQ rigid-body endpoint) — non-circular, but state it.
- Confidence metrics (iPTM/ipDE) are guardrails, not success metrics
  (overconfident on OOD; proven on 9NFQ).
- Some targets are short resolved constructs (crystallographic disorder);
  self-DockQ=1.0 already confirms each CRBN-target interface is scorable.

## Rollback

- `scancel <jobid>` if the array misbehaves.
- Remove only the new OUT_BASE after explicit user approval.
- Revert local harness/scoring edits if wrong; do not touch existing dirty files.

## Progress log

- 2026-06-14 staged: 15 targets, self-DockQ=1.0 all. Stager
  scripts/stage_ood_enrichment_20260614.py; baseline+aigen manifests (45+45).
  GT chain maps added to score_heldout_dockq.GT_CHAIN_MAP. Curation provenance
  /tmp/chosen_meta.json (RCSB GraphQL). Phase 1 SLURM next.
- 2026-06-14 **Phase 1 baseline screen DONE (job 6970, 44/45; 1 transient OOM =
  9H59 seed123)**. enrichment 가설 적중: 큰 globular 비-degron 타깃 붕괴, 짧은 degron
  대조 co-success. **OOD survivor 7** (baseline median DockQ<0.23): 9OTY CK1α 0.007,
  9H59 Nek7 0.010, 9E2U Helios-long 0.015, 8UH6 PTPN2 0.024, 9YA9 BCL6 0.026, 9Q03
  BCL6 0.027, 9Q33 PRDM1 0.173. co-success 8 제외 (8G66 CK1α 0.861, 9Q22 Helios 0.890,
  9NWT SALL4 0.867, 9DWV PPIL4 0.817, 9Y7D Ikaros 0.780, 9OUK Ikaros 0.680, 9SAI BRD4
  0.356, 8TNR fusion 0.257). 흥미: 동일 타깃도 construct/glue로 갈림 (CK1α 9OTY OOD vs
  8G66 co-success; Helios short 9Q22 co-success vs long 9E2U OOD).
- 2026-06-14 **Phase 2 steering DONE (job 7015, 21/21; steering engage 로그 확인 =
  silent-disable 아님)**. baseline→steered median (3 seed):
    9OTY CK1α  0.007→**0.736** (3/3 accept)  ✅ CLEAN RESCUE
    9H59 Nek7  0.010→**0.580** (3/3)         ✅ CLEAN RESCUE
    9Q33 PRDM1 0.173→**0.455** (3/3)         ✅ CLEAN RESCUE
    9Q03 BCL6  0.027→0.223 (1/3, max 0.339)  ◐ borderline (med 0.007 short)
    9YA9 BCL6  0.026→0.145 (0/3)             ↑ lift, sub-accept
    8UH6 PTPN2 0.024→0.017 (0/3)             ✗ no rescue (큰 포스파타제, pocket만으론 부족)
    9E2U Helios-long 0.015→0.015 (0/3)       ✗ no rescue
  **VERDICT: +3 NEW clean rescues (+1 borderline). TOTAL clean rescues = 4 (9DWW PDE6D
  + 9OTY + 9H59 + 9Q33), 기존 1개 병목에서 4배.** 목표(+2-4 clean) 달성. NON-CIRCULAR:
  진짜 OOD(baseline 붕괴 사전확인) + 크리스털 템플릿 없음 + glue-pocket constraint만(패널
  aigen arm과 동일 정보류, DockQ rigid-body endpoint 비구속) → 9NFR A-b의 circular 없음.
  iPTM 과신 재확인: 비-rescue도 steered mean_iptm 0.80-0.90 (8UH6 0.849@DockQ0.017,
  9E2U 0.900@0.015) → iPTM≠success metric. 산출물:
  analysis/heldout_placement_20260601/reports_ood_enrichment/{metrics,summary}_{baseline,aigen}.tsv;
  collector collect_ood_enrichment_20260614.py.
