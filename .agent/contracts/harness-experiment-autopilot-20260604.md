# harness-experiment-autopilot

**Status:** approved
**Slice:** harness
**Approval:** requested 2026-06-04 · approved by: user 2026-06-04

## Purpose

You are the manual integration layer at both ends of every SLURM science loop
(*design → submit → wait → analyze → diagnose → re-run → write up*), and again
when the result must become lab knowledge. FEA ("FKSFold Experiment Autopilot")
is one integrated, advisory/gated pipeline that validates inputs before GPU,
classifies failures and runs the analysis battery (regime-stratified) after, and
drafts the status/Notion/handoff write-up from that result — so the same finished
run that produces the science also produces its own lab record. Target: cut
manual post-SLURM analysis + preventable GPU waste + write-up time by ≥50%.

Approved plan: `/home/ubuntu/.claude/plans/typed-stirring-perlis.md`.

## Current State

- Post-SLURM analysis is hand-run: 4,300+ lines of one-off diagnostic scripts
  under `analysis/fragmap_spectral_discriminator/src/` invoked manually each run
  (~10–15 h/wk); silent fails (rc=0 + empty `predictions/`) and node faults
  found only by manual log tailing.
- No pre-submit input validation → wrong FragMap mode (`feature` vs
  `target_occupancy`, commit `37787a2`), off-by-one CRBN anchors, 5ns/20ns
  coupling mismatch, GPU-collision/ENOSPC plumbing — all caught post-submit
  (30–80 GPU-h + 20+ human-h lost per cluster of incidents).
- Pooled-median blindness flipped a fksfold-core verdict KILL→CONFIRM once
  regime-stratified; the lesson lives in prose, not code.
- Write-up (status baton, contract result, Notion payload, handoff) restates by
  hand facts the finished run already determined (~20–25% of active time).
- Existing reusable assets: `analysis/foundation/activity_eval_gates.py`,
  the fragmap battery, `verify_heldout_anchor.py`/`fix_pocket_numbering.py`,
  `mmgbsa_coupling`/`run_mmpbsa.py`, `scripts/status.sh`, `scripts/notion_sync.py`,
  subagents `slurm-status`/`mmgbsa-stage-check`/`fragmap-diagnose`,
  `.claude/hooks/pre-bash-slurm-gate.sh`.

## Assumptions And Questions

- assumptions: FEA orchestrates existing analysis scripts and lessons; it does
  not invent new metric/scoring science. GPU is abundant (`feedback_compute_scaling`)
  so the savings target is human time + preventable waste, not GPU thrift.
- open questions: exact battery subset per fragmap experiment type (resolve in
  /write-plan against `fragmap-diagnose`).
- tradeoffs: warn-only preflight first trades immediate enforcement for
  zero risk of a hook bug wedging all submissions.

## Constraints

- allowed change scope: new package `scripts/fea/` (`preflight.py`, `watch.py`,
  `postflight.py`, `results_card.py`, `capture.py`); additive wiring into
  `.claude/hooks/pre-bash-slurm-gate.sh`; reuse (not rewrite) of the assets above.
- forbidden change scope: no new analysis science; no rewrite of the existing
  battery or `activity_eval_gates.py` logic; no auto-`sbatch`/auto-resubmit;
  no headless Notion writes.
- external constraints: advisory/gated throughout — every actuator (`sbatch`,
  re-submit, Notion write, git commit) stops for user approval.
- behavioral: regime-stratified by default — pooled-median forbidden in code.

## Non-Goals

- **SLURM auto-submit / auto-resubmit** (explicitly out of scope; preflight
  validates only, submission stays human-gated).
- New analysis/scoring science — FEA orchestrates the existing battery only.
- Headless/automatic Notion writes — `capture` drafts payloads; the existing
  MCP + approval flow performs the actual write.

## Done When

- **Primary success criterion (observable):** `fea report <jobid>` on an
  already-completed fragmap job reproduces the last hand-done regime-stratified
  verdict, AND `fea capture` produces a `.agent/status/fragmap.md` baton draft
  the user accepts with only minor edits.
- `fea report` runs the fragmap battery regime-stratified (no pooled-median code
  path) and emits a Results Card with a per-cell failure manifest
  (success / OOM / hang / silent-fail / node-fault).
- `fea preflight` rejects the three known-bad historical configs (wrong FragMap
  mode; off-by-one CRBN anchor; 5ns/20ns coupling mismatch) each with its
  specific reason, and passes a known-good config — in **warn-only** mode wired
  into `pre-bash-slurm-gate.sh`.

## Triggers

- SLURM submission: NO direct submit; modifies the SLURM-submit **gate hook** → gate-relevant.
- 4+ files modified: YES (new `scripts/fea/` package + hook).
- Shared-storage writes: NO (reads only; writes drafts to `.agent/`).
- Ranking semantics: NO (orchestrates existing scoring unchanged).

## Resource Budget

- GPU: 0 for build + validation (validates against already-completed jobs).
- Human: contract → /write-plan → /execute-plan; pilot deliverable is Stage 3+4.

## Implementation Phases (decomposed in /write-plan)

1. Stage 3+4 on fragmap (postflight + capture) — highest ROI, build first.
2. Stage 1 preflight + warn-only hook wiring; regression-test on 3 known-bad configs.
3. Stage 2 watch (failure-signature monitor).
4. Generalize the four stages to mmgbsa (coupling gate) + fksfold-core
   (regime-stratify + CRBN/GPU-UUID preflight) — likely a follow-on contract.

## Risks

- regression risk: hook edit could block legitimate submissions → mitigated by
  warn-only first; flip to block only after trust is established.
- integration risk: battery scripts expect specific input layouts → validate on
  a real completed job before relying on it.
- hidden dependency risk: `notion_sync.py` payload schema drift → `capture`
  generates payloads through the existing script, not a parallel writer.

## Rollback

- revert strategy: `scripts/fea/` is a new, self-contained package — delete it to
  fully remove Stages 1–4 logic. The hook change is additive and warn-only, so
  reverting that one diff restores the prior gate exactly; no submission is ever
  blocked by an FEA bug during the pilot.
- containment strategy: warn-only preflight means a preflight bug degrades to a
  printed warning, never a wedged queue. No GPU jobs, /mnt/data writes, or Notion
  writes occur unprompted, so there is no external state to undo.

## Progress Log

- 2026-06-04: contract drafted via /brainstorm from approved plan
  typed-stirring-perlis. Decisions: integrated pipeline, advisory/gated,
  fragmap pilot, success = past-verdict reproduction + accepted baton draft,
  out-of-scope = SLURM auto-submit/resubmit, gate = warn-only first.
- 2026-06-04: **Phase 1 (Stage 3+4 on fragmap) SHIPPED** via plan
  `.agent/plans/harness-experiment-autopilot-phase1-20260604.md` (status: done,
  12/12 tasks, commits `96aec40`…`24dbac2`). `scripts/fea/` now provides
  `report` (classify_cells → load_metrics → scaffold-blocked run_gates →
  ResultsCard) and `capture` (gated baton + Notion payload drafts). **Primary
  success criterion MET**: reproduces the documented induced-fit-inverted KILL
  end-to-end (raw −0.305 / oof −0.117 / perm_p 0.73, n=84). pytest 4/4.
  Plan Amendment 1 (oracle: dc50-scan→induced-fit, scaffold-blocked) +
  Amendment 2 (house parser vs safe_load) recorded. Known follow-up: run_gates
  PROVE enforces only leg-(i) perm-significance (full 3-leg PROVE deferred).
  **Phases remaining**: Stage 1 preflight + warn-only gate wiring; Stage 2
  watch; mmgbsa/fksfold-core generalization → next plan(s) under this contract.
- 2026-06-04: **Phase 2a (fragmap Stage 1 preflight) SHIPPED** via plan
  `.agent/plans/harness-experiment-autopilot-phase2a-20260604.md` (status: done,
  8/8 tasks, commits `71696fb`…`6ff19c4`). `scripts/fea/preflight.py` +
  `fea preflight` CLI: forbidden-mode / NPZ+pdb existence / empty-channels
  (ERROR) + VAV1 pocket-vs-GT audit (WARN, ±1 tol). Warn-only advisory wired into
  `.claude/hooks/pre-bash-slurm-gate.sh` — **gate verdict provably unchanged**
  (self-contained regression test). pytest 9/9. Honest limitation logged: docker-
  wrapped `--fragmap_config` may not appear on the sbatch line (silent ≠ validated).
  **Phases remaining**: Stage 2 watch; mmgbsa (MD↔sampling coupling preflight) +
  fksfold-core (CRBN-anchor seq-walk + GPU-UUID preflight) generalization, which
  also complete the umbrella's "reject all three known-bad configs" criterion
  (Phase 2a covers the FragMap-mode one).
- 2026-06-04: **Phase 2c (mmgbsa coupling preflight) SHIPPED** via plan
  `.agent/plans/harness-experiment-autopilot-phase2c-mmgbsa-20260604.md`
  (status: done, 5/5 tasks, commits `72051d0`…`ce0ab26`).
  `scripts/fea/mmgbsa_preflight.py` + `fea preflight-mmgbsa`: reuses the committed
  `mmgbsa_coupling.py` arithmetic and adds the **coverage guard**
  (`coupling_undersampled`) that catches the first-Nns-of-Mns under-sampling bug
  `coupling_check` misses. **Did NOT touch the blocked `run_mmpbsa.py`** (B4 wiring
  stays the mmgbsa slice's deferred task). pytest 12/12. This completes the SECOND
  of the umbrella's "3 known-bad" criteria (coupling mismatch); the FragMap-mode
  one was Phase 2a — only the fksfold CRBN-anchor one remains.
  **Remaining**: Stage 2 watch; fksfold-core CRBN-anchor + GPU-UUID preflight;
  mmgbsa post-hoc run-dir audit (gmx check).
- 2026-06-04: **Phase 2d (fksfold CRBN-anchor preflight) SHIPPED** via plan
  `.agent/plans/harness-experiment-autopilot-phase2d-fksfold-20260604.md`
  (status: done, 5/5 tasks, commits `89aba60`…`0350730`).
  `scripts/fea/fksfold_preflight.py` + `fea preflight-fksfold`: PURE
  `verify_anchor_residues` + CIF adapter reusing `verify_heldout_anchor.modeled()`
  (Bio.PDB lazy). Catches the production `--w400_residue_index=355`→G/L/P/S bug;
  real-data integration test (9NGT 355→'L' FAIL, 321→W PASS). pytest 16/16.
  ★ **This COMPLETES the contract's "reject all three known-bad configs" success
  criterion**: FragMap-mode (2a) + MD↔sampling coupling (2c) + CRBN-anchor (2d).
  The core FEA system (preflight Stage-1 across all 3 slices + postflight/capture
  Stage 3+4 on fragmap + warn-only gate) is now SHIPPED.
  **Optional follow-ups remaining** (none blocking the success criterion): Stage 2
  watch; GPU-UUID submit-script check; mmgbsa post-hoc run-dir audit; run_gates
  full 3-leg PROVE.
