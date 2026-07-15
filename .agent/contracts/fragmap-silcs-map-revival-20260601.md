# fragmap-silcs-map-revival

**Status:** done
**Slice:** fragmap (SILCS-Lite map build + scoring)
**Approval:** requested 2026-06-01 · approved by: user 2026-06-01 · closed 2026-06-02

## Purpose

Revive the frozen (2026-04-30) SILCS-Lite chemistry map by closing two of its
gaps using **zero-GPU re-processing of EXISTING 5-replica trajectories** — donor/
acceptor separation and validation of the already-collected MGD-relevant
atom-specific channels — and then **measure whether the richer/independent
channels change any downstream effect**. The measurement is the diagnostic gate
that decides whether the harder GPU gaps (negative channel, new probes) are worth
the compute (diagnose-before-scale; lesson #4 = FragMap ~0 on 9NFR / fine-tune-only
on 143-set).

## Current State

- Frozen production assets (2026-04-30): `ternary_r1_maps.npz`, `ternary_r2_maps.npz`
  (5-rep expanded ternary, under `data/silcs_oracle_real/`). **These are consumed by
  `fragmap_steering.py` and every AB/held-out run** — including fksfold-core's T2/D3
  **array 5911 currently RUNNING**.
- Gap (b) — donor/acceptor NON-independent: **confirmed via channel_summary**,
  `grid_donor == grid_acceptor == grid_probe_methanol` (identical grids = methanol copied).
- Gap (c, zero-GPU part) — existing atom-specific channels (formamide N–H/C=O, DME,
  imidazole, acetone) were collected in the 5-rep expanded run but reached only
  diagnostic stage, not promoted/validated as usable independent channels.
- **Recon file names were WRONG** (do NOT rely): `convert_grandlig_traj_to_npz.py` /
  `finalize_grandlig_atom_specific_channels.py` DO NOT EXIST. Real GCMC scripts =
  `prepare_grandlig_ternary_inputs.py` + `run_grandlig_charge_pair_gcmc.py`; the
  dcd→FragMap(GFE) builder is unconfirmed → **plan Task 1 locates it**. Raw `traj.dcd`
  per replica + `atom_specific_channel_manifest.json` EXIST → zero-GPU re-derivation
  plausible. **donor/acceptor must be RE-DERIVED (per-atom-type occupancy re-bin +
  per-atom-type GFE normalization vs that atom-type's own bulk), NOT relabeled/copied.**

## Assumptions And Questions

- assumptions: the 5-rep `traj.dcd` that fed the 04-30 maps are on disk (CONFIRMED) and
  per-atom-type occupancy + per-atom-type bulk reference are re-derivable from them
  without re-running GCMC (Task 1 confirms).
- open questions: can a per-atom-type **bulk reference** be computed from the dcd
  zero-GPU? If NOT, gap (b) becomes GPU → escalate, do not proceed silently. Donor
  source = formamide N–H vs methanol O–H (decide in Task 1 from data availability).
- tradeoffs: re-derivation reuses existing sampling (no new statistics) and HALVES
  per-channel counts when splitting one probe into 2 atom-types → noisier GFE
  (convergence check required); it separates what was sampled, not deepens sampling.

## Constraints

- allowed change scope: NEW analysis/derivation scripts under
  `analysis/silcs_map_revival_20260601/` (re-derivation wrapper, validation,
  atom-type-aware LGFE scorer, effect comparison) that CALL the real FragMap builder
  located in Task 1 (do NOT edit frozen-map production code in place); a NEW versioned
  NPZ output; a new analysis/report dir. CPU only.
- forbidden change scope: any GCMC / SLURM / GPU run; ANY write to or overwrite of
  the frozen `ternary_r1/r2_maps.npz`; re-freeze of the consumed assets while a
  downstream PROVE/KILL is open (T2/D3 array 5911); adding NEW probes that require
  GCMC (pyridine, acetate/formate).
- external constraints: must not touch fksfold-core / T2/D3 / steering engine; must
  not disturb array 5911 or its inputs.

## Non-Goals

- Gap (a) negative channel (acetate/formate GCMC) — GPU, **deferred**; revisit only
  if the downstream-effect measurement justifies GPU spend.
- New probe **pyridine** (genuinely new → new GCMC → GPU) — **deferred** to the same
  GPU tier as gap (a).
- Adopting the new NPZ as the live steering input (this contract only PRODUCES +
  MEASURES; adoption + downstream re-validation is a separate contract).
- Any change to the frozen 04-30 production assets or to fksfold-core.

## Done When

1. **Independent donor/acceptor confirmed score-worthy** — Task 1 (GO, commit 44f80c5) found
   `grid_amide_donor`≠`grid_amide_acceptor` (+`grid_imidazole_donor/acceptor`,
   `grid_acceptor_ether`) ALREADY exist in the frozen npz (maxdiff 7.2, GFEmin −2.2/−2.3); the
   bug was only generic `grid_donor==grid_acceptor==grid_probe_methanol` (weak, −0.413). So NO
   new NPZ is built here. (Producing/repointing a production v2 NPZ = ADOPTION → separate
   contract per Non-Goals, only if Done-When #3 shows positive effect.)
2. The existing atom-specific channels (`grid_amide_donor/acceptor`, `grid_imidazole_donor/acceptor`,
   `grid_acceptor_ether`) are **validated as score-worthy** directly from the frozen npz —
   validation = GFE depth + n(<cap) + **R1-vs-R2 consistency** (independent-state convergence
   proxy); too-sparse/weak channels flagged not-score-worthy. (GFE-protocol parity automatic —
   same frozen npz/builder.)
3. A **downstream-effect report using ATOM-TYPE-AWARE LGFE** (critical): the current
   consumer SUMS `polar = grid_donor + grid_acceptor`, so separation is downstream-inert
   unless scored by atom type. Classify each ligand atom (donor / acceptor / aromatic /
   hydrophobe) → score against the MATCHED channel; compare baseline (polar-sum) vs v2
   (atom-type-matched) on an existing static pose set NOT in flight → report ranking /
   active-vs-decoy separation. **A null effect is valid** (now a REAL null, not a
   summing artifact) — reporting it IS the done-line.
4. The report states explicit recommendations: (a) **adopt** the amide channels into production
   `grid_donor/acceptor` (separate repoint/adoption contract) — yes/no; (b) **gap-a GPU tier**
   (negative channel + pyridine) — justified or not.
5. All steps zero-GPU, **read-only on /mnt/data, NO NPZ writes**; frozen `ternary_r1/r2_maps.npz`
   untouched.

## Triggers Matched (WORKFLOW §2)

- **§2 new FragMap scoring channel/mode = YES** (donor/acceptor split + newly-exposed
  atom-specific channels are new scoring channels) → this contract.
- §3 SLURM submission = NO (zero-GPU).
- 4+ files possibly touched (finalizer + validation script + report + new NPZ) — all
  within fragmap; covered by §2.

## Resource Budget

Zero GPU. CPU finalizer re-processing of EXISTING 5-rep trajectories + analysis.
Estimate: small (hours, local/CPU). No SLURM, no /mnt/data production writes beyond
the new versioned NPZ + analysis dir.

## Verification

- `python -c "import numpy as np; ..."` on each new NPZ → assert
  `max(|grid_donor - grid_acceptor|) > 0` and listed channels present & non-empty.
- Frozen-asset guard: `stat` mtime of `ternary_r1/r2_maps.npz` unchanged before/after.
- Downstream-effect report file exists with baseline-vs-new comparison + recommendation.
- `git status` shows only fragmap-scope files (no fksfold-core / engine files).

## Risks

- regression risk: NONE to running work — new NPZ, frozen assets + all consumers
  untouched; nothing adopts the new NPZ within this contract.
- integration risk: deferred — only materializes if/when a later contract adopts the
  new NPZ as steering input (then downstream must re-validate).
- hidden dependency risk: re-key correctness — must confirm the finalizer reads the
  correct atom-specific gfe arrays and that raw arrays still exist (step 1).

## Rollback

- revert strategy: delete the new versioned NPZ + new analysis dir; `git revert` any
  committed finalizer/validation code. Frozen assets + all downstream consumers are
  untouched, so rollback has **zero downstream impact**.
- containment strategy: nothing in flight depends on the new NPZ until a separate
  adoption contract; the running array 5911 reads only the frozen assets.

## Progress Log

- 2026-06-01 HH:MM: initial spec drafted via /brainstorm (status: pending).
- 2026-06-01: approved by user → proceeding to /write-plan.
- 2026-06-01: SILCS-expert re-review → plan v2. Method refined (re-derivation not
  relabel; atom-type-aware LGFE effect test; convergence + GFE-protocol-parity gates;
  recon file-names corrected — convert/finalize scripts do not exist). Scope/triggers
  UNCHANGED; Current State + Assumptions + Constraints + Done-When 1-3 amended to match.
- 2026-06-02: Task 1 (GO, commit 44f80c5) found strong distinct donor/acceptor channels
  (amide/imidazole/ether) ALREADY in frozen npz → user-approved re-scope to plan v3
  (measure-only; no NPZ build/dcd re-derivation; read-only). Recon file-names were in fact
  correct — sources live on /mnt/data mirror, not /home working copy. Done-When 1/2/4/5
  re-scoped; NPZ build/repoint deferred to adoption. Scope/intent unchanged.
- 2026-06-02: Tasks 2-4 done (commits 600e655/6c31b97/1edb0ac). Task 4 effect run over 125
  well-placed AB poses → coverage≈0 (heavy-atom mean 2.3%/median 0%, 48% in protein-vdW,
  LGFE base/v2 both pinned at +5 cap = no discrimination). Atom-type-matched scoring
  untestable post-hoc; two mechanisms (frame vs pose) left open → user-gated Fork B.
- 2026-06-02: **Fork B (zero-GPU crystal-ligand ceiling) DONE → lane CLOSED.** Frame
  hypothesis RULED OUT (map source equil.pdb: 408/408 CA in exclusion; ref-pdb B/C chains
  raw-RMSD 0.00 vs equil = alignment target IS map frame). Crystal ligand A1B (ground truth,
  map frame, no align): coverage **0/21**, LGFE +5.0 both modes, nearest-signal median
  **2.26 Å** (17/21 within 3 Å). Mechanism pinned: sparse GFE field × NN point-sampling caps
  even at ground truth — independent of channel/pose/frame; needs ~3 Å soft pooling = what
  STEERING does. **Done-When #3/#4 satisfied (real null + both recommendations):
  (a) adopt amide channels into post-hoc consumer = NO; (b) gap-a GPU tier = NOT JUSTIFIED.**
  Value = generation steering → handed to fksfold-core. Report:
  analysis/silcs_map_revival_20260601/REPORT.md; Fork-B script crystal_ligand_ceiling.py.
  Status → done.
