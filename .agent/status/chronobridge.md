---
owner_session: 00cca76a-adc4-4cd4-bc37-270fe95220cd
owner_label: 
owner_agent: claude
version: 4
state: active
last_updated: 2026-07-14
heartbeat: 2026-07-14T10:41:17Z
remaining_actions:
  - "DECISION: leave-one-out algorithm spec + 3-fold decoy set are done (loo_algorithm_spec.md, DESIGN COMPLETE) — cross-glue generalization test of the FP-detector, pass bar = 2-of-3 folds CI-excluding-zero. Decide whether to approve a follow-up MD-generation contract on the user's B200 server (near-blank env, files transferred by user via scp/rsync, not by Claude): 6 systems (3 native + 3 decoys), ~20-30ns each, ~60-160 GPU-hours (~100 central). This WILL need a real SLURM/GPU approval gate, unlike Phase A/B and this contract, all zero-GPU."
  - "AGENT: once approved, scope chronobridge-gspt1-md-generation-<date> via /brainstorm for the B200 MD run (env setup + 6-system execution), then apply loo_algorithm_spec.md's fit-calibration/score-out-of-sample FP-detector adaptation + per-ensemble ChronoBridge QC to the resulting trajectories."
contract_pointers:
  - .agent/contracts/chronobridge-apo-holo-benchmark-20260713.md
  - .agent/contracts/chronobridge-gspt1-leave-one-out-20260713.md
  - .agent/contracts/chronobridge-gspt1-loo-algorithm-20260714.md
---

# ChronoBridge — apo/holo dynamics + FP-detector method validation for CRBN molecular glues

**Scope**: validate "Robust ChronoBridge" (state-order/kinetics recovery from a structural
ensemble) and a false-positive detector on a CRBN-agnostic generic apo/holo MD benchmark,
before applying either to the CRBN molecular-glue ternary-complex staged roadmap the user
confirmed: GSPT1 → IKZF family → CK1α → VAV1. Deliberately does not reuse aigen-fold-core
assets (fresh implementation, per the contract's Non-Goals) — no cross-slice `depends_on`.

## Phase A verdict: PASS

7/7 evaluated metrics (FP-removal AUC/recall, Kendall tau order recovery, transition edge
recall, false-shortcut rate, committor-calibration MAE, MFPT rank error) beat the
random-order/random-score baseline with a bootstrap 95% CI on the delta excluding zero —
well past the contract's 1-of-2-metric bar. Adversarially confirmed via independent re-seed
reproduction (consistent magnitudes) and null-calibration (two independent random baselines
show 0/7 CI-excluding-zero, ruling out a leaky bootstrap). Full detail, dataset (ATLAS
`1k5n_A` + foreign-fold FP splice from `1r6w_A`), and method in
`.agent/scratch/chronobridge/phaseA/results.md`.

## Phase B verdict: BRANCH B (not a failure — deferred)

Fetched 3 GSPT1-CRBN-DDB1 ternary crystal structures (5HXB/CC-885, 6XK9/CC-90009,
9HNE/Compound-1); zero-GPU discovery confirmed no existing GSPT1 ternary MD/docking
ensemble exists anywhere in the workspace, so leave-one-ternary-out could not run
(needs a structural ensemble, not a single static pose, per structure). Built 2
reciprocal glue×backbone-swap FP decoys (5HXB/6XK9) — both show unresolved rigid-body
clashes (1.85Å/2.38Å min distance), informative but not proof of true basin instability.
Full detail: `.agent/scratch/chronobridge/phaseB/results.md`.

## Algorithm spec: DESIGN COMPLETE (2026-07-14)

Redefined leave-one-out as a cross-glue generalization test of the FP-detector (not
basin reconstruction — no such mechanism exists). 3-fold design (hold out 5HXB/6XK9/
9HNE in turn), all 3 decoys now built (Fold C's is structurally weaker — its decoy
backbone is 5HXB, a calibration system, not the held-out 9HNE, since 9HNE was only
used as glue donor). Sequence check confirmed CRBN/DDB1 identical across all 3
structures (safe to pool); GSPT1 has a numbering offset in 6XK9 (not used for
featurization, so irrelevant here). ChronoBridge's role scoped to per-ensemble QC
only. Full detail: `phaseB/loo_algorithm_spec.md`, `phaseB/loo_algorithm_results.md`.

## Next step

New GSPT1 MD (6 systems now, not 3 — see `remaining_actions`) is required before
leave-one-out can be attempted. This is a real GPU/SLURM approval gate (unlike
Phase A/B and the algorithm-spec work, all zero-GPU/exploratory) — needs a separate
B200 contract, files moved manually by the user (Claude has no access to that server).
