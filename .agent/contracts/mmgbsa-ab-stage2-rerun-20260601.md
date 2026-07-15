# mmgbsa-ab-stage2-rerun — recover AB Stage 2 after mergerfs ENOSPC, rerun 76, proceed to decomp

- **Status:** superseded (2026-06-01) by
  [.agent/contracts/mmgbsa-stable-pipeline-20260601.md](mmgbsa-stable-pipeline-20260601.md)
  — the narrow disk-fix + 76-rerun is subsumed; the VAV1-decomp rerun is
  deferred as a downstream consumer of the hardened pipeline (out of scope there).
- **Slice:** mmgbsa
- **Approval:** requested 2026-06-01 · approved by: n/a (superseded before approval)
- **Supersedes/extends:** continuation of
  [.agent/contracts/mmgbsa-ab-stage1-4-20260527.md](mmgbsa-ab-stage1-4-20260527.md)
  (same AB pipeline; this contract adds the infra-fix + rerun after the
  Stage 2 ENOSPC failure of job 5809).

## Purpose

AB Stage 2 MMGBSA (job 5809) died on a **mergerfs branch saturation**
(`No space left on device`), not a science fault: branches
`/mnt/kfs6` (99%) and `/mnt/kfs5` (94%) are full while the `/mnt/data`
pool reports 49T free (concentrated on empty branches kfs1·3·4·7).
node1's output tree was pinned to a full branch → infinite mdrun retry
loop → only ~13 of 76 mmpbsa_prod trajectories completed before the
3-day walltime. This contract fixes the branch imbalance
**non-destructively** and re-runs all 76 ready compounds to a
statistically-sufficient completion, then proceeds to Stage 3→4 VAV1
decomp analysis.

## Current State

- 5809 hit walltime (3-00:00 limit) ~2026-06-01 08:34 UTC; killed.
- OUT_BASE (read-only baseline of partial run):
  `/mnt/data/users/ubuntu/mmgbsa_outputs/norm143_ab_seed16_stage1_20260527_182206/`
  - `ready_for_mmpbsa_prod.tsv` = 76 data rows (the rerun input set)
  - `failed_stage.tsv` = 174 data rows; `md_done.tsv` = header only
    (worker status-tracking bug + ENOSPC append failures — do NOT gate on it)
  - ~13 `mmpbsa_prod` trajectories completed (node0 RunA ~58–66 MB,
    node1 RunB ~40 MB) — full-length, salvageable.
- Stage 3 decomp prep already done: `workflow/mdp/gb_decomp.in`,
  `GB_IN` env override, VAV1 = AMBER residues 398–458 (chain B, 61 res).
- mergerfs mount: `mergerfs-data on /mnt/data` (fuse.mergerfs), union of
  `/mnt/kfs1..7`. Create policy not yet captured — must record before change.

## Assumptions And Questions

- assumptions:
  - With both nodes healthy (no ENOSPC), throughput ≈ doubles vs the
    node0-only ~13 observed — but this is unverified.
  - The 76 `ready_for_mmpbsa_prod` set is still valid input (topologies
    intact on disk).
- open questions:
  - **Walltime fit (critical):** last run did ~13 in 3 days with one
    node dead. Does 76 fit in a single 3-day window with both nodes, or
    must the run be chunked / resubmitted? Resolve with a throughput
    estimate from node0's completed runs BEFORE submitting.
  - Pin OUT_BASE to which empty branch — `/mnt/kfs7` (3.8T) vs
    `/mnt/kfs1·3·4` (~15T each)? Prefer the 15T branches for trajectory volume.
- tradeoffs:
  - Global mfs policy change helps all future writes but is system-wide
    state (must be reverted on rollback); path-pinning is local-only.

## Constraints

- allowed change scope:
  - Set mergerfs create policy to most-free-space (mfs) **and/or** pin
    the new run's OUT_BASE to an empty branch. Record the original
    mount opts / create policy to `.agent/scratch/` before any change.
  - New rerun in a NEW timestamped OUT_BASE; old run preserved read-only.
  - Reuse existing AB Stage 2 script
    (`slurm_normtest143_stage2_md_multidir_seed777.sh`), 16× A100,
    2 nodes, `ExcNodeList=host-10-0-5-232` (hardware fault).
- forbidden change scope:
  - **No deletion or moving of any data** to free space — especially
    other users' data (e.g. `/mnt/data/users/kim/`). kfs5/6 contents
    left untouched.
  - No changes to Stage 1, steering/generation/ranking params, or
    scoring direction (ESMFold2/Boltz held per 2026-05-29 decision).
- external constraints:
  - SLURM per-job walltime 3-00:00; `/mnt/data/users/ubuntu` writes need
    `sudo -u ubuntu`.

## Non-Goals

- Re-running Stage 1 (the 76 are already the survivors).
- Fixing the worker `md_done.tsv` status-tracking bug (separate track:
  [.agent/contracts/mmgbsa-worker-status-bug-20260526.md](mmgbsa-worker-status-bug-20260526.md));
  here we only avoid gating on `md_done`.
- Globally rebalancing existing data across mergerfs branches.
- Touching the 5331 corrected-YAML baseline or its re-interpretation.

## Done When

- **Primary (statistical sufficiency, not a fixed %):** enough completed
  RunA VAV1-containing `mmpbsa_prod` + decomp trajectories that the
  DC50 correlation n is adequate — target **n ≥ 40** (matching Stage 1's
  DC50 n=44). Completion percentage is secondary.
- `FINAL_DECOMP_MMPBSA.dat` produced for the completed set (Stage 3→4).
- VAV1 (AMBER 398–458, chain B) per-residue decomp ΔG summed per
  compound and **Pearson vs logDC50 computed and written** (full ΔΔG in
  parallel), with completion count reported as-is.
- verify: `sudo -u ubuntu tail -n +2 <NEW_OUT_BASE>/ready_for_mmpbsa_prod.tsv | wc -l`
  and count of valid per-compound `FINAL_DECOMP_MMPBSA.dat` ≥ n target;
  rerun did NOT emit `No space left on device` in its `.err`.

## Implementation Steps

1. Capture mergerfs create policy + per-branch free space to
   `.agent/scratch/`; estimate node0 throughput to decide walltime fit.
   verify: snapshot file exists; throughput → projected 76-compound wall-time.
2. Apply non-destructive disk fix (mfs policy and/or OUT_BASE pinned to
   empty branch); confirm new writes land off kfs5/6.
   verify: test write to NEW_OUT_BASE resolves onto a low-usage branch.
3. Submit AB Stage 2 rerun for the 76 (chunked if step 1 says >3 days).
   verify: `squeue` shows job; `.err` clean of ENOSPC after first wave.
4. On sufficient completion, submit Stage 3 (decomp, `GB_IN`) → Stage 4 merge.
   verify: `FINAL_DECOMP_MMPBSA.dat` present.
5. Compute VAV1 decomp ΔG vs logDC50 Pearson; update
   `.agent/status/mmgbsa.md` + handoff.
   verify: correlation written; n reported.

## Change Discipline

- simplest adequate approach: pin OUT_BASE to an empty branch; only add
  global mfs policy change if pinning alone is insufficient.
- new abstractions introduced: none (reuse existing scripts).
- unrelated code touched: none expected.
- request-to-diff trace: ENOSPC diagnosis (5809) → infra fix + rerun.

## Verification

- task-specific command: see Done When verify lines.
- manual check: `df -h | grep kfs` before/after to confirm new writes
  avoid kfs5/6.

## Risks

- regression risk: global mfs policy change affects other users' writes
  → prefer path-pin; if policy changed, revert on completion/rollback.
- integration risk: 76 may not fit one 3-day walltime → chunk/resubmit.
- hidden dependency risk: some of the 76 topologies may have been on a
  full branch and be truncated — validate inputs before submit.

## Rollback

- revert strategy: `scancel` the rerun job; revert mergerfs create
  policy to the recorded original; delete ONLY the new timestamped
  OUT_BASE. Old `...182206` OUT_BASE and all kfs5/6 data untouched.
- containment strategy: new run isolated in its own OUT_BASE; no
  in-place mutation of prior artifacts.

## Progress Log

- 2026-06-01 08:xx: contract drafted from /brainstorm after 5809 ENOSPC
  diagnosis (mergerfs kfs6 99% / kfs5 94%, pool 49T free but imbalanced).
