---
contract: .agent/contracts/fragmap-silcs-map-revival-20260601.md
slice: fragmap
status: done
total_tasks: 6
estimated_total_min: 24
revision: v3 (re-scoped after Task-1 finding — strong donor/acceptor channels ALREADY exist; no build needed, measure-only)
---

# Plan v3 — fragmap SILCS-Lite map revival (measure-only; channels already exist)

> **Task-1 finding (commit 44f80c5):** the frozen `ternary_r{1,2}_maps.npz` ALREADY contain
> strong, distinct atom-specific donor/acceptor channels — `grid_amide_donor`≠`grid_amide_acceptor`
> (GFEmin −2.2/−2.3, maxdiff 7.2), `grid_imidazole_donor/acceptor`, `grid_acceptor_ether`. The
> bug is only that the GENERIC `grid_donor==grid_acceptor==grid_probe_methanol` (weak, −0.413) and
> the consumer (`build_feature_matrix.py:191`) sums those into `polar`. GFE builder:
> `precompute_oracle_silcs_maps.py:121 occupancy_to_gfe` (GFE=−RT·ln(occ/rho_bulk), rho_bulk=
> median-of-nonzero, +5 cap). All on the `/mnt/data/users/kim/code/...` mirror.
>
> **Therefore: no NPZ build / no dcd re-derivation needed to TEST the hypothesis.** Score existing
> static poses with the existing strong channels (atom-type-matched) vs the current methanol-polar
> baseline. **All tasks read-only on /mnt/data; zero GPU; no NPZ writes.** Producing/repointing a
> production v2 NPZ is ADOPTION → deferred to a separate contract IF the effect is positive
> (already a Non-Goal here).

## Task 1: Recon gate — DONE (GO)
- **Status**: done (2026-06-02, FKSFold commit 44f80c5). RECON.md at
  `analysis/silcs_map_revival_20260601/RECON.md`. Finding re-scoped Tasks 2-6 (this plan v3).

## Task 2: Validate existing atom-specific channels (trustworthy to score with?)

- **Status**: done (2026-06-02, FKSFold commit; score-worthy = amide/imidazole/ether donor/acceptor + aromatic; retire methanol grid_donor; no per-rep maps → R1/R2 sanity only)
- **Prereq tasks**: 1
- **Files touched**: `analysis/silcs_map_revival_20260601/validate_channels.py` (new) + `CHANNELS.md` (new note)
- **Change shape**: Read-only script over the frozen `ternary_r1/r2_maps.npz`: for each candidate
  channel (`grid_amide_donor`, `grid_amide_acceptor`, `grid_imidazole_donor/acceptor`,
  `grid_acceptor_ether`, `grid_aromatic`, `grid_hydrophobe`) report: GFEmin, n(voxels<+5 cap),
  hotspot count below a threshold (e.g. <−1.0), and **R1-vs-R2 consistency** (the two independent
  ternary states as a convergence proxy — voxelwise sign/agreement on strong voxels). Contrast vs
  the buggy `grid_donor`(=methanol, −0.413). Flag any channel too sparse/weak to trust. If true
  per-replica maps exist on the mirror, add inter-replica agreement; else note R1/R2 is the
  available proxy. Write `CHANNELS.md` verdict (which channels are score-worthy).
- **Verification**: `python analysis/silcs_map_revival_20260601/validate_channels.py` → exit 0;
  `CHANNELS.md` lists per-channel GFEmin + R1/R2 consistency + a score-worthy YES/NO per channel.
- **Estimated time**: 6 min
- **Rollback (if this task only)**: `rm analysis/silcs_map_revival_20260601/{validate_channels.py,CHANNELS.md}`

## Task 3: Atom-type-aware LGFE scorer (existing channels)

- **Status**: done (2026-06-02, FKSFold commit; baseline parity EXACT; v2 routes acceptor→best-of amide/ether/imidazole. Caveat: poses need Kabsch align + most seed-pilot poses land near +5 cap → Task 4 must use well-placed poses + report coverage)
- **Prereq tasks**: 2
- **Files touched**: `analysis/silcs_map_revival_20260601/lgfe_atom_type_aware.py` (new)
- **Change shape**: Scorer that classifies each ligand heavy atom by H-bond role (donor /
  acceptor / aromatic / hydrophobe — via RDKit or the existing atom-typer used elsewhere in the
  repo) and computes per-pose LGFE against MATCHED channels, with `--mode`:
  `baseline_polar_sum` (reproduce current consumer: donors+acceptors both → `grid_donor+grid_acceptor`
  = methanol-polar) vs `v2_atom_typed` (donors→`grid_amide_donor`; acceptors→best of
  `grid_amide_acceptor`/`grid_acceptor_ether`; aromatic→`grid_aromatic`; hydrophobe→`grid_hydrophobe`;
  use only channels Task-2 marked score-worthy). Reads frozen npz read-only.
- **Verification**: 1-pose smoke prints per-atom-type contributions + total LGFE for BOTH modes;
  `baseline_polar_sum` reproduces the existing polar-sum value (sanity).
- **Estimated time**: 7 min
- **Rollback (if this task only)**: `rm analysis/silcs_map_revival_20260601/lgfe_atom_type_aware.py`

## Task 4: Effect run — baseline (polar-sum) vs v2 (atom-typed)

- **Status**: done (2026-06-02, FKSFold commit 1edb0ac; CSV local per *.csv policy). FINDING: coverage≈0 even on 113/125 well-placed (vav1_offset<5Å) poses — 1.4% atoms on signal, 44% in protein-vdW, 56% empty. Atom-type test UNTESTABLE on post-hoc poses (not a tuning issue). See checkpoint.
- **Prereq tasks**: 3
- **Files touched**: `analysis/silcs_map_revival_20260601/effect_comparison.csv` (new output)
- **Change shape**: Run the Task-3 scorer in BOTH modes over an EXISTING static pose set NOT in
  flight (the 143 panel poses and/or static held-out poses already on disk — NOT array-5911
  outputs). Emit `effect_comparison.csv`: per-pose baseline vs v2 LGFE + aggregate ranking
  (hits@K / Spearman vs DC50 where available) and active-vs-decoy separation per mode. Read-only
  on poses.
- **Verification**: `effect_comparison.csv` exists with baseline + v2 columns + an aggregate row
  (ranking/separation per mode); script exits 0.
- **Estimated time**: 5 min
- **Rollback (if this task only)**: `rm analysis/silcs_map_revival_20260601/effect_comparison.csv`

## Task 5: Report + recommendations (adoption? gap-a GPU?)

- **Status**: done (2026-06-02; REPORT.md written. Incorporates Fork-B crystal-ligand
  ceiling: frame ruled out, post-hoc null is structural [sparse field × NN sampling],
  recommendations (a) adopt=NO / (b) gap-a GPU=NOT JUSTIFIED; value=generation steering.)
- **Prereq tasks**: 4
- **Files touched**: `analysis/silcs_map_revival_20260601/REPORT.md` (new)
- **Change shape**: Summarize: did atom-type-matched scoring with the strong existing channels
  change ranking / separation vs the methanol-polar baseline? Honest effect size (null still
  plausible, but now a REAL null on STRONG channels — not a weak-buggy-channel artifact). Two
  explicit recommendations: (a) **adopt** the amide channels into production `grid_donor/acceptor`
  (a separate repoint/adoption contract) — YES/NO + why; (b) **gap-a GPU tier** (negative channel
  + pyridine) — justified or not. Link RECON.md + CHANNELS.md + effect_comparison.csv.
- **Verification**: `REPORT.md` has a baseline-vs-v2 results section + both recommendation lines.
- **Estimated time**: 4 min
- **Rollback (if this task only)**: `rm analysis/silcs_map_revival_20260601/REPORT.md`

## Task 6: Update fragmap baton + contract + handoff

- **Status**: done (2026-06-02; contract Status→done + Progress Log; plan status→done;
  fragmap baton updated; handoff.sh claude fragmap + status.sh index regen.)
- **Prereq tasks**: 5
- **Files touched**: `.agent/status/fragmap.md`; `.agent/contracts/fragmap-silcs-map-revival-20260601.md` (Progress Log + Status→done)
- **Change shape**: Record outcome (channels already existed; atom-type-aware effect = <result>;
  adoption recommendation = <y/n>; gap-a recommendation = <y/n>) in fragmap remaining_actions;
  flip contract Status→done + Progress Log. Then `./scripts/handoff.sh claude fragmap` +
  `./scripts/status.sh index`.
- **Verification**: `./scripts/status.sh index` → no stderr warnings; fragmap baton yaml valid +
  version bumped; contract Status: done.
- **Estimated time**: 3 min
- **Rollback (if this task only)**: revert `.agent/status/fragmap.md` + contract from git/handoff snapshot.
