---
contract: .agent/contracts/fragmap-measurement-guardrails-v1-20260601.md
slice: fragmap
status: done
total_tasks: 8
estimated_total_min: 28
program: .agent/plans/fragmap-leverage-program-20260601.md (T0)
---

# Plan — Measurement Guardrails v1 (T0)

Decomposes the approved T0 contract. Phases: Core (library, Tasks 1-3) →
Tests (smoke, Task 4) → Docs (Tasks 5-7) → Handoff (Task 8). Tasks 1-3 share
`activity_eval_gates.py` so they chain; Tasks 5 and 7 are independent (parallel-safe).

All paths under FKSFold repo `/home/ubuntu/FKSFold-Boltz_Advancement/` unless noted.

## Task 1: Add `mw_mediation_fraction()` to the gates library

- **Status**: done (5be5ad2)
- **Prereq tasks**: none
- **Files touched**: `analysis/foundation/activity_eval_gates.py`
- **Change shape**: add a pure function `mw_mediation_fraction(score, y, mw, logp)` that returns `{"raw_rho": float, "partial_rho": float, "mediated_fraction": float}` where `partial_rho` reuses the existing `partial_spearman(score, y, covars=[mw, logp])` and `mediated_fraction = 1 - abs(partial_rho)/abs(raw_rho)` (guard raw≈0 → nan). No new imports.
- **Verification**: `python -m compileall analysis/foundation/activity_eval_gates.py` → exit 0; `python3 -c "import sys;sys.path.insert(0,'analysis/foundation');import activity_eval_gates as g;print(g.mw_mediation_fraction([1,2,3,4],[2,3,4,5],[100,110,120,130],[2,3,4,5]))"` → dict with 3 keys.
- **Estimated time**: 4 min
- **Rollback (if this task only)**: remove the function from the file.

## Task 2: Add `within_between_scaffold()` decomposition

- **Status**: done (1fc7acf)
- **Prereq tasks**: 1
- **Files touched**: `analysis/foundation/activity_eval_gates.py`
- **Change shape**: add `within_between_scaffold(metric, y, scaffolds)` returning `{"within_rho": float, "between_rho": float, "n_groups": int}`. between = Spearman of per-scaffold means (metric vs y across groups); within = mean of per-scaffold Spearman over groups with ≥3 members (nan if none). Reuse `_spearman`. This is the method that KILLed the induced-fit signal (무늬 4).
- **Verification**: `python -m compileall analysis/foundation/activity_eval_gates.py` → exit 0; quick `python3 -c` smoke that a planted within-only signal yields `between_rho`≈0.
- **Estimated time**: 5 min
- **Rollback (if this task only)**: remove the function.

## Task 3: Add `power_preflight()` / `n_needed()` (n≈350 floor)

- **Status**: done (394d238) — n_needed(0.15)=347 ✓; power_preflight(0.30,84)→False (n_needed=85), honest off-by-one in spec's expected value; function consistent w/ scan's min_rho(84)=0.301.
- **Prereq tasks**: 2
- **Files touched**: `analysis/foundation/activity_eval_gates.py`
- **Change shape**: add `n_needed(target_rho, power=0.80, alpha=0.05)` (Fisher-z: `n = ((z_a+z_b)/atanh(rho))**2 + 3`) and `power_preflight(target_rho, n, ...)` returning `{"n_needed": int, "adequately_powered": bool, "target_rho": float}`. Document that `n_needed(0.15)`≈347 is the corpus power floor (무늬 5).
- **Verification**: `python3 -c "...; print(g.n_needed(0.15))"` → integer in [340, 355]; `print(g.power_preflight(0.30, 84)['adequately_powered'])` → True.
- **Estimated time**: 4 min
- **Rollback (if this task only)**: remove both functions.

## Task 4: Extend `_smoke()` with 3 guardrail assertions

- **Status**: done (75512a3) — "SMOKE OK" w/ mediation/within-between/n_needed assertions
- **Prereq tasks**: 1, 2, 3
- **Files touched**: `analysis/foundation/activity_eval_gates.py`
- **Change shape**: in `_smoke()`, add assertions (NON-degenerate data — see note): (a) MW-mediated synthetic data where score↔y is driven by a shared MW (y = mw + noise, score = mw + indep noise) → `mw_mediation_fraction` returns `mediated_fraction` > 0.5 (raw high, MW-partial ≈ 0); (b) within-only planted signal (each scaffold anti-correlated, ≥3 members) → `within_rho` < −0.8; AND between-only planted signal (group means correlated) → `between_rho` > 0.8; (c) `340 <= n_needed(0.15) <= 355`. Keep existing random-data→KILL assertion.
- **Verification**: `python3 analysis/foundation/activity_eval_gates.py` → prints "SMOKE OK" (now covering the 3 new funcs).
- **NOTE (2026-06-01, execution-time fix):** original draft asserted `abs(between_rho) < 0.2` on within-only data — but identical per-group means make `between_rho` *undefined (nan)*, not 0 (Task 2 verification exposed this). Corrected to assert the components on non-degenerate data (within detection via `within_rho`<−0.8; between detection via `between_rho`>0.8). Task purpose (smoke covers the 3 new funcs) unchanged.
- **Estimated time**: 5 min
- **Rollback (if this task only)**: revert the `_smoke()` additions.

## Task 5: Write `docs/proxy_audit_preflight.md`

- **Status**: done (c35cd68)
- **Prereq tasks**: none
- **Files touched**: `docs/proxy_audit_preflight.md` (new)
- **Change shape**: 1-page checklist every new activity claim must pass: [declare proxy / declare real target / evidence they don't diverge] + [3 gates: mw_mediation_fraction reported, within_between_scaffold reported, power_preflight passes] + [inert-knob check: is this knob λ/seed/GD already proven inert? (무늬 1)] + [no-GT rule, per-compound metric, no top-K]. Reference the tapestry doc + the 3 gate functions.
- **Verification**: `test -f docs/proxy_audit_preflight.md && grep -qiE 'proxy|power_preflight|mw_mediation|inert' docs/proxy_audit_preflight.md` → exit 0.
- **Estimated time**: 4 min
- **Rollback (if this task only)**: delete the file.

## Task 6: Link the checklist from the measurement-foundation doc

- **Status**: done (2c2978c)
- **Prereq tasks**: 5
- **Files touched**: `docs/measurement_foundation_design_20260601.md`
- **Change shape**: add a one-line reference in the D1/methodology section pointing to `proxy_audit_preflight.md` as the enforced pre-flight for all activity claims.
- **Verification**: `grep -q proxy_audit_preflight docs/measurement_foundation_design_20260601.md` → exit 0.
- **Estimated time**: 2 min
- **Rollback (if this task only)**: remove the added line.

## Task 7: Charter A — confidence relabel + enclosure scope

- **Status**: done (c106991)
- **Prereq tasks**: none
- **Files touched**: `docs/platform_charter_A_20260601.md`
- **Change shape**: add to §2 (non-claims) / §3 (AD): (i) confidence/iptm = "geometric plausibility, NOT activity/quality" (무늬 2, LIMD1 control iptm 0.946); (ii) "enclosure plausibility, NOT specific-contact recognition" scope (무늬 3, wrongAB 0.857 > baseline 0.826). 2 lines, no claim reversal — refinement.
- **Verification**: `grep -qiE 'enclosure|기하 타당성|geometric plausibility' docs/platform_charter_A_20260601.md` → exit 0.
- **Estimated time**: 2 min
- **Rollback (if this task only)**: remove the 2 lines.

## Task 8: Commit + contract done + baton/handoff/index

- **Status**: done
- **Prereq tasks**: 1, 2, 3, 4, 5, 6, 7
- **Files touched**: FKSFold commit (library + 3 docs); workspace (contract status→done, baton, CURRENT.md)
- **Change shape**: surgical `git add` of the explicit FKSFold paths → commit; flip contract `status: done` + record result; `./scripts/handoff.sh claude fragmap`; `./scripts/status.sh index`; surgical workspace commit of baton+index+contract.
- **Verification**: `python3 analysis/foundation/activity_eval_gates.py` → SMOKE OK; both repos `git status --porcelain <touched paths>` → empty; contract status=done.
- **Estimated time**: 2 min
- **Rollback (if this task only)**: `git revert` the FKSFold commit (pure additive); revert workspace commit.
