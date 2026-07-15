---
owner_session: 
owner_label: 
owner_agent: claude
version: 5
last_updated: 2026-07-15
heartbeat: 
state: released
remaining_actions: []
contract_pointers:
  - .agent/contracts/boltz-jump-paper-repro-pilot-20260714.md
  - .agent/plans/boltz-jump-paper-repro-pilot-20260714.md
---
# boltz-jump

CLOSED (2026-07-15, user: "닫자"). Plan COMPLETE (all 22 tasks done across
3 GPU rounds); contract status: done. Verdict: **guided/steering demo is
a clean pass; unguided/free-folding demo is stable but still doesn't
fold — a different, lower-priority problem than the instability this
session's tuning work actually fixed, logged as a known limitation, not
pursued further.**

Three real GPU rounds. Round 1 (job 17175, sigma=2.0/delta=2.0/gamma=0.1,
paper's own unretuned values): both demos FAIL/PARTIAL, unguided Trp-cage
diverges to physically broken structures in both seeds, guided Abl-kinase
6XR6->6XR7 steering only sane at 1 of 4 tested lambda. CPU-only diagnostic
(diagnose_divergence.py) confirmed BAOAB integrator instability
(delta=2.0/mass=1.0 too hot for gamma=0.1 to dissipate), not a score/code
bug. Round 2 (job 17211, delta=0.05, n_steps=16000, finer jump_every, new
lam=0.0 control): guided demo's catastrophic blow-up resolved (4/5 lambda
now sane) but the zero-force core walk still diverged over a full
16000-step run (both unguided seeds + the new lam=0.0 control), delayed
onset not caught by a 20-step CPU diagnostic -- a real extrapolation-gap
lesson. Round 3 (job 17267, mass=16.0 retuned + clip-force=3.0 safety net,
validated first by a genuinely long 5000-step CPU sweep before spending
more GPU): the fix generalizes to the full 16000-step GPU run. Unguided
demo no longer diverges (bounded Rg 15.8-20.8A, no chain breaks/clashes,
both seeds) but never folds (helix_frac=0.000 throughout) -- stable, not
stuck-diverging, but stuck-unfolded. Guided demo now decisively passes:
all 4 nonzero lambda (0.3/1.0/3.0/10.0) converge RMSD-to-6XR7 from ~5.2A
to 0.33-0.56A within ~2000 steps and hold flat for the remaining ~14000,
secondary structure intact (helix_frac 0.28-0.33, matching the 0.25-0.31
native reference range), and the lam=0.0 control is finally clean (zero
convergence, zero instability) -- cleanly separating "steering causes
convergence" from Round 2's unresolved "maybe steering just happens to
stabilize" confound. Wall-clock speedup real throughout (9.4x round 1,
~3.6x rounds 2-3 -- the drop from round 1 is a reporting artifact of
n_steps/jump_every not scaling proportionally, not a method regression).
aigen-fold-core files untouched across all three rounds.

Full analysis: .agent/scratch/boltz_jump/results_pilot.md (original +
"Retest (job 17211)" + "Round 3 (job 17267)" sections, the last one with
the final Done-When verdict table and recommended next step). Full
plan/task history: .agent/plans/boltz-jump-paper-repro-pilot-20260714.md
(status: done). Contract: .agent/contracts/boltz-jump-paper-repro-pilot-20260714.md
(status: done, closed_by user 2026-07-15 "닫자").
