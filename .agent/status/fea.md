---
owner_session: dd735f8a-d308-479a-8faa-6ee35d28d2d4
owner_label: 
owner_agent: claude
version: 3
last_updated: 2026-06-26
heartbeat: 2026-06-26T13:51:54Z
state: active
remaining_actions:
  - "AGENT: C2 proactive-monitoring COMPLETE — fea watch + baton-drift branch(C) + OS crontab */15 (scripts/fea/watch_cron.sh; headless system-python3, self-clearing marker, sparse error log at .agent/handoffs/state/fea-watch.log). Disable via `crontab -e` (delete the 'FEA proactive watch' 2-line block)."
  - "AGENT: C1 cross-slice deps SHIPPED (minimal) — scripts/baton-deps.py (file= condition, multi-repo-aware) + baton-drift branch(D) + README schema; 6 tests in scripts/tests/. Real mmgbsa→aigen-fold-core:run_mmpbsa.py edge resolves DEP-READY today. ADOPTION: mmgbsa owner can add the depends_on edge to its baton (1 line) for the cleared-dependency nudge. C3/C4 still deferred. Rationale: .agent/scratch/fea/self_driving_harness_design_20260626.md."
  - "OPS (live, unowned): /mnt/kfs5 98% + /mnt/kfs6 99% FULL now — new /mnt/data-routed output silently lands on a near-full branch. Same failure that killed job 7974. Point large runs at kfs1/2/3/4/7."
contract_pointers:
  - .agent/contracts/harness-experiment-autopilot-20260604.md
  - .agent/plans/harness-experiment-autopilot-phase1-20260604.md
  - .agent/plans/harness-experiment-autopilot-phase2a-20260604.md
---
# FEA — AIGEN-Fold Experiment Autopilot (slice)

## What this slice is

FEA = one advisory/gated pipeline wrapping every SLURM science loop
(preflight → watch → postflight → capture): validate inputs before GPU,
monitor live runs, classify failures + run the analysis battery after, and
draft the status/Notion/handoff write-up. Every actuator (sbatch/Notion/commit)
stays human-gated.

## Where we are

- SHIPPED: Phase 1 (postflight+capture) + Phase 2a (fragmap preflight) +
  2c (mmgbsa coupling preflight) + 2d (fksfold CRBN-anchor preflight) +
  **Phase 2 "Stage-2 watch" (C2 proactive monitoring), 2026-06-26**:
  `scripts/fea/watch.py` (`fea watch --once`) — `job_dead` (sacct terminal-
  failure) + `disk_full` (per-branch /mnt/kfs*, NOT the union — the 7974 lesson).
  Surfaced at session-start/pre-compact via `baton-drift.sh` branch (C) AND
  between sessions via OS crontab */15 (`watch_cron.sh`, verified in a
  stripped-env cron sim). 13 hermetic tests; advisory/read-only (never scancel/sbatch).
- Design + scoped decision: deferred C1/C3/C4 (over-built for lab size per
  adversarial review). Record: `.agent/scratch/fea/self_driving_harness_design_20260626.md`.

## Next action

Optional: wire the cron/loop periodicity route (user opt-in). Else DECISION on
whether to build any deferred capability (default = defer per design).

## Live truth

- Code: `scripts/fea/watch.py` (+ `tests/test_watch.py`), `scripts/fea/watch_cron.sh`,
  `scripts/baton-drift.sh` branch (C). CLI: `python -m scripts.fea watch --once [--write-marker]`.
- Cron: `crontab -l` shows the `*/15` FEA-watch block; marker
  `.agent/handoffs/state/proactive-watch-findings`, log `…/fea-watch.log`.
- Contract: `.agent/contracts/harness-experiment-autopilot-20260604.md`
  (watch.py in allowed scope; auto-submit/resubmit explicitly forbidden).
- First live run flagged /mnt/kfs5 98% + /mnt/kfs6 99% full.
