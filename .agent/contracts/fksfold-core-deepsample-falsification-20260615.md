# Contract — deep-sampling falsification of the prior-amplifier mechanism

- **slice**: aigen-fold-core
- **status**: done
- **approval**: requested 2026-06-15 · approved by: user ("highQOS ubuntu로 돌려") 2026-06-15

## Scope

Test whether the crystal-free split mechanism finding holds under heavy sampling:
the claim is *anchor+w400 is a prior amplifier, not a basin creator — a target it
cannot rescue (pocket-dependent collapse) is one whose sequence prior lacks a
near-native basin, and no amount of sampling will find what isn't there.*

Run **anchor-only (crystal-free, NO pocket constraint)** with deep multi-seed
sampling (N=64 seeds/target) over 7 targets:
- collapse 4: Nek7 (9H59), PDE6D (9DWW), G3BP2 (9OS2), ENL (9DUR)
- near-miss 1: 9Q03
- positive controls 2: CK1α (9OTY), PRDM1 (9Q33) — basin-present reference curve

Reuse the router-staged `*_anchoronly.yaml` inputs + `oracle_generation_heldout_*.yaml`
configs (identical to the n=3 ablation, only seed count expands 3→64).

## Out of scope

- particle/diffusion-step sweep (within-run search depth) — optional v2 follow-up,
  NOT this run. v1 is seed-only (samples the prior's basin mass directly).
- pocket-ON arm (already have WITH-pocket from ablation/ood-enrichment).
- new targets / corpus expansion (RCSB exhausted — separate, dead).
- WEE1 map-fit (separate decision, deferred).

## Triggers matched

- SLURM submission (GPU array) → PreToolUse sbatch gate (this contract satisfies it).
- shared-storage writes under /mnt/data/users/ubuntu/workspace/.

## Success criteria

Per-target **best-of-64 anchor-only DockQ** (scored vs heldout GT, CRBN–target interface):
- **Mechanism CONFIRMED** if the 4 collapses + 9Q03 stay best-of-64 < 0.10 (prior
  limit is real; anchor cannot synthesize an absent basin) AND positive controls
  CK1α/PRDM1 keep hitting their basin (best-of-64 ≥ their n=3 values, sanity).
- **Mechanism REFUTED / re-stated** if any collapse target reaches best-of-64 ≥ 0.23
  (or a monotone rising best-of-N curve) → basin exists but is rare; "amplifier vs
  creator" dichotomy must be rewritten as a sampling-depth axis.
- Power: N=64 detects a ≥5% per-seed basin-hit rate with ~96% probability
  (1−0.95^64), so a null is a meaningful "basin absent," not under-sampling.

Verification: `analysis/heldout_placement_20260601/collect_*` style best-of-N table
+ best-of-N curve per target.

## Resource budget

7 × 64 = 448 Boltz-2 ternary predictions, gpu:1 each (~5–10 min). QOS **high**
(ubuntu: gpu=16 cap), throttle array %16 → ~4 h wall. Physical GPUs ample (56,
5 nodes idle). Fallbacks if high submit/jobs limit (submit=15/jobs=5) rejects the
448-element array: (a) batch QOS gpu=4, (b) resubmit as kim (batch). Account for
running jobs — vav1-ubq 7207 is on `normal` QOS (does not consume high budget).

## Rollback

Pure compute, no state mutation beyond output dir
`/mnt/data/users/ubuntu/workspace/deepsample_falsification_20260615/`. Cancel via
`scancel <jobid>`; delete output dir (sudo -u ubuntu) to undo. No scorer fork, no
shared-config edit, no sibling-slice touch.

## Result (2026-06-16) — CONFIRMED

447/448 scored. Clean collapses Nek7(9H59) best-of-64=0.016, PDE6D(9DWW)=0.008,
near-miss 9Q03=0.027 — all 0/64 clear 0.10 (mechanism CONFIRMED: prior-blind targets
not rescuable by ~20× sampling). Positive controls CK1α 0.759 (62/64 ≥0.23), PRDM1
0.510 (53/64). Sharpest evidence: CK1α hit rate 33%(baseline)→97%(anchor) at unchanged
ceiling ~0.76 = amplifier-not-creator, quantified. Excluded: 9OS2 (input chain missing),
9DUR (PROTAC). Caveat: no baseline-64 control arm (PRDM1 amplify-vs-improve unresolved;
collapse conclusion independent). Report: crystalfree_split_mechanism_20260615.md
§Falsification; metrics_deepsample.tsv.
