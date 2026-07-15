---
contract: .agent/contracts/vav1-ubq-coordgd-dc50-discriminator-20260713.md
slice: vav1-ubq
status: done
total_tasks: 16
estimated_total_min: 62
---

# Plan — coord-GD reaching-efficiency DC50 discriminator (direction-1 follow-up)

Staged per the contract's diagnose-before-scaling constraint: build the
discriminator machinery (sweep + min-steering extraction + analysis) on the
ALREADY-WIRED + validated targets (P1, C1), gate it on a control-subset GPU run,
THEN wire the remaining 8 targets and scale to the full matrix. C1 (near-attack)
is the direct generation-side analog of the WTMetaD FES-barrier discriminator
(ρ=+0.714) and is the load-bearing scientific deliverable; the other 9 targets
are exploratory scale-out.

Inventory established before planning:
- Stage-D 8 (VAV1_411/211/449/245/210/382/199/474) + MRT6160 stage-2 templated
  ternary inputs ALL EXIST at `/mnt/kfs2/.../vav1_2stage_alldock_20260702/stage2_input/`.
- Only C147 (inactive control) lacks a stage-2 input → Phase 1 builds it (one compound).
- coord-GD driver wires P1 + C1 only; compound choices hardcoded → Phase 2 generalizes.
- gd_scale is the primary min-steering knob (driver `--gd-scale`, launcher `GD_SCALE`).
- Frozen cross-compound choices (held fixed for a fair comparison, per the
  reaching≠validation caveat): lysine = K788 for all C-targets; seed = 42;
  sampling_steps = 200; gd_steps = 4; clean-structure gates clash < 150 AND
  CRBN internal-distortion < 4 Å (from the validated coord-GD gates).

Paths: scripts/outputs under `.agent/scratch/compass_steering/` + kfs2 run dirs.
GPU: kim, --qos=normal, un-containerized rootfs, free-GPU selector (mem.free>75GB),
output to kfs2 (standing SLURM pre-approval for this line, user 2026-07-13).

---

## Task 1: C147 stage-2 ternary input builder (CODE ONLY)

- **Status**: done
- **Prereq tasks**: none
- **Files touched**: `.agent/scratch/compass_steering/build_c147_input.py`, `.agent/scratch/compass_steering/build_c147_input.sh`
- **Change shape**: New builder that reproduces the 2-stage dock path for ONE
  compound (C147) to emit a `VAV1_C147_tmpl.yaml` byte-analogous to
  `VAV1_MRT6160_tmpl.yaml` (CRBN chain A + VAV1 chain B + C147 ligand SMILES from
  `AIGENFold/data/vav1_yamls/vav1_c147.yaml` + the same pocket contacts + a
  `templates: - cif:` pointing at a stage-1-derived template CIF). `.py` builds
  the stage-1 YAML, runs stage-1 (2 seeds) via the rootfs `predict_core`, picks
  the best pose by CULTsum (reuse `AIGENFold/api/pipeline.py` builders), writes
  the template CIF, and writes the stage-2 tmpl YAML. `.sh` is the kim/kfs2
  login-node stager that prints the submit command (NEVER auto-submits), same env
  pattern as `run_coordgd.sh`. Output dir `/mnt/kfs2/.../compass_coordgd_20260713/`.
- **Verification**: `bash .agent/scratch/compass_steering/build_c147_input.sh` on
  the login node → stages deps to kfs2 + prints the `sudo -u kim sbatch` line, no
  GPU exec; `python3 -c "import ast; ast.parse(open('.agent/scratch/compass_steering/build_c147_input.py').read())"` → no error.
- **Estimated time**: 5 min
- **Rollback (if this task only)**: `git rm` the two files; delete the kfs2 dir.

## Task 2: Build C147 stage-2 input on GPU (APPROVAL GATE — SLURM)

- **Status**: done (job 16893, best seed16 CULTsum 9.61Å; VAV1_C147_tmpl.yaml + .cif verified)
- **Prereq tasks**: 1
- **Files touched**: (no repo files; produces `/mnt/kfs2/.../vav1_2stage_alldock_20260702/stage2_input/VAV1_C147_tmpl.yaml` + `.../templates/VAV1_C147.cif` on kfs2)
- **Change shape**: Submit the Task-1 job (kim, --qos=normal). Stage-1 free-pred
  → CULTsum pick → template CIF → stage-2 tmpl YAML for C147. Monitor first cell
  proactively; report on completion.
- **Verification**: `test -f /mnt/kfs2/.../stage2_input/VAV1_C147_tmpl.yaml && python3 -c "import yaml,sys; d=yaml.safe_load(open('/mnt/kfs2/.../stage2_input/VAV1_C147_tmpl.yaml')); assert any('template' in str(k) for k in d); print('C147 tmpl OK')"` → prints OK; the referenced template CIF exists; the ligand SMILES matches C147.
- **Estimated time**: 3 min hands-on (+ GPU wall, async)
- **Rollback (if this task only)**: `scancel` the job; delete the produced YAML/CIF.

## Task 3: Generalize coord-GD driver for arbitrary compounds + --skip-unsteered

- **Status**: done
- **Prereq tasks**: none
- **Files touched**: `.agent/scratch/compass_steering/coordgd_driver.py`
- **Change shape**: Relax `--compound` from a hardcoded 2-choice to a free string
  (kept as a label); require `--yaml` when the compound is not in `COMPOUND_YAML`
  (Stage-D 8 all pass `--yaml`). Add `--skip-unsteered` so the sweep runs ONE
  unsteered baseline per (compound,target) + N steered at different gd_scale
  (saves ~half the GPU on the ~550-run matrix). No change to the P1/C1 potential
  build or the steered path; flag-default preserves current behavior.
- **Verification**: `python3 -c "import ast; ast.parse(open('.agent/scratch/compass_steering/coordgd_driver.py').read())"`; `python3 .agent/scratch/compass_steering/coordgd_driver.py --help` lists `--skip-unsteered` and no longer constrains `--compound` to choices; grep confirms the unsteered `run_once` is guarded by `not args.skip_unsteered`.
- **Estimated time**: 4 min
- **Rollback (if this task only)**: `git checkout` the driver.

## Task 4: Frozen reach-threshold config + DC50 label table

- **Status**: done
- **Prereq tasks**: none
- **Files touched**: `.agent/scratch/compass_steering/reach_thresholds.json`, `.agent/scratch/compass_steering/dc50_labels.csv`
- **Change shape**: `reach_thresholds.json` — per target (C1-4, P1-3, G1-2, M1) the
  frozen REACH criterion (metric name + threshold, e.g. C1 near-attack ≤ 4.5 Å;
  P1 SH3c-RMSD-to-9NFR ≤ unsteered+1 Å band; G2 bridge-span → 7.0 Å; M1 CA-CA
  separation band 8–12 Å; etc., sourced from `losses_catalytic`/`losses_interface`
  constants) + the shared CLEAN gates (clash < 150, crbn_internal < 4 Å).
  `dc50_labels.csv` — compound,logDC50,tier for the Stage-D 8 (from
  `productive_geometry_stage_d_results_20260701.md`) + MRT6160 (active, ≈-0.05) +
  C147 (inactive, 4.00).
- **Verification**: `python3 -c "import json; d=json.load(open('.agent/scratch/compass_steering/reach_thresholds.json')); assert set(d['targets'])>={'C1','C2','C3','C4','P1','P2','P3','G1','G2','M1'}; print(len(d['targets']),'targets')"` → `10 targets`; `python3 -c "import csv; r=list(csv.DictReader(open('.agent/scratch/compass_steering/dc50_labels.csv'))); assert len(r)>=10; print(len(r),'compounds')"`.
- **Estimated time**: 4 min
- **Rollback (if this task only)**: `git rm` the two files.

## Task 5: Min-steering sweep launcher (CODE ONLY)

- **Status**: done
- **Prereq tasks**: 3, 4
- **Files touched**: `.agent/scratch/compass_steering/run_coordgd_sweep.sh`
- **Change shape**: Generalize `run_coordgd.sh` into a sweep: iterate `GD_SCALE`
  ladder (default `1.0 0.5 0.25 0.125`) × `COMPOUNDS` list × `TARGETS` list; per
  (compound,target) run ONE unsteered baseline (`--skip-unsteered` off, gd_scale
  irrelevant) then N steered at each ladder value (`--skip-unsteered` on); call
  `coordgd_measure.py` per cell writing `_res_<cmp>_<tgt>_gs<scale>.csv`. Lists +
  ladder env-overridable (`COMPOUNDS`, `COORDGD_TARGETS`, `GD_SCALES`). Resolves
  each compound's `--yaml` from the alldock stage2_input dir (C147 from the
  Task-2 output). Login-node stager prints the submit command; never auto-submits.
- **Verification**: `COMPOUNDS="MRT6160 C147" COORDGD_TARGETS=C1 GD_SCALES="1.0 0.5" bash .agent/scratch/compass_steering/run_coordgd_sweep.sh` on the login node → prints the resolved cell grid (2 compounds × 1 target × {baseline, gs1.0, gs0.5}) + the submit line, stages deps, no GPU exec.
- **Estimated time**: 5 min
- **Rollback (if this task only)**: `git checkout` / `git rm` the launcher.

## Task 6: Reaching-efficiency extraction (zero-GPU)

- **Status**: done
- **Prereq tasks**: 4
- **Files touched**: `.agent/scratch/compass_steering/coordgd_reaching_efficiency.py`
- **Change shape**: Read the per-cell measure CSVs from a sweep out dir; per
  (compound,target) find the SMALLEST gd_scale that REACHES the target's frozen
  threshold (`reach_thresholds.json`) with a CLEAN structure (clash + crbn_internal
  gates); emit `reaching_efficiency.csv` with columns compound,target,min_scale,
  reached(bool),clean(bool),clash,crbn_internal,seed_note. `min_scale = inf`
  (never reaches clean) is a valid recorded value. Includes a `--selftest` on an
  in-repo fixture (synthetic per-cell rows) asserting the min-scale pick is correct.
- **Verification**: `python3 .agent/scratch/compass_steering/coordgd_reaching_efficiency.py --selftest` → `SELFTEST OK` (fixture: a compound reaching at 0.25 but not 0.125 → min_scale==0.25; a never-clean compound → inf).
- **Estimated time**: 5 min
- **Rollback (if this task only)**: `git rm` the file.

## Task 7: Discriminator analysis (zero-GPU)

- **Status**: done
- **Prereq tasks**: 6
- **Files touched**: `.agent/scratch/compass_steering/coordgd_dc50_analysis.py`
- **Change shape**: Join `reaching_efficiency.csv` with `dc50_labels.csv`; per
  target compute Spearman(min_scale, logDC50) with bootstrap CI over the
  DC50-labeled compounds (Stage-D 8 + MRT6160, n≈9), the active/inactive
  separation (MRT6160 vs C147 min_scale), and hold-fixed physical-validity +
  seed columns; apply a Benjamini-Hochberg multiple-testing note across the 10
  targets; print the best target's ρ next to the MD WTMetaD FES ρ=+0.714. Writes
  `coordgd_dc50_results.csv` (the per-target table) and prints the human table +
  the reaching≠validation caveat. `--selftest` on a fixture.
- **Verification**: `python3 .agent/scratch/compass_steering/coordgd_dc50_analysis.py --selftest` → `SELFTEST OK`; running it on a fixture reaching_efficiency.csv prints a per-target ρ+CI table incl. active/inactive + BH-adjusted p + the ρ=+0.714 comparison line.
- **Estimated time**: 5 min
- **Rollback (if this task only)**: `git rm` the file.

## Task 8: Control-subset sweep + extraction (APPROVAL GATE — SLURM; diagnose-before-scale)

- **Status**: done (job 16896; GATE VERDICT: extraction WORKS, signal NULL on C1/P1 — see below)
- **Gate result (2026-07-13)**: sweep C1·P1 × {MRT6160, C147, VAV1_211, VAV1_474} × ladder
  {1.0,0.5,0.25,0.125} COMPLETED (32 cells). reaching-efficiency extraction + discriminator
  analysis ran clean. C1 min_scale = 0.5 for ALL 4 compounds (reached clean at 0.5, not at 0.25);
  near_attack near-identical across the full potency span (MRT 2.591 / 211 strong 2.589 / 474 weak
  2.572 / C147 inactive 2.596 at gs1.0). P1 min_scale = 0.125 for all. Active-vs-inactive: no
  separation (0.5=0.5, 0.125=0.125). Spearman degenerate (zero variance). This is NOT a broken
  extraction (min_scale well-defined, gradient smooth, clash/crbn clean) — it is a well-measured
  NULL: coord-GD reaches near-attack equally regardless of glue potency (reaching≠validation made
  concrete). Contrasts the MD WTMetaD FES ρ=+0.714 (MD measures a thermodynamic barrier the system
  resists; coord-GD forces geometry by gradient, no resistance → signal vanishes). Per the gate's
  "all-equal → STOP and consult" rule, paused for a user scope decision (do NOT auto-wire 8 targets
  / run the 550-run matrix). Artifacts: kfs2 compass_coordgd_dc50_20260713/{coordgd_dc50_sweep.csv,
  reaching_efficiency.csv, coordgd_dc50_results_subset.csv}.
- **Prereq tasks**: 2, 5, 6, 7
- **Files touched**: (no repo files; produces sweep outputs on kfs2 + `reaching_efficiency.csv`/`coordgd_dc50_results.csv` for the subset)
- **Change shape**: Run the sweep on the control subset — targets {C1, P1} ×
  compounds {MRT6160, C147, VAV1_211 (strong), VAV1_474 (weak)} × the gd_scale
  ladder. Then run Tasks 6+7 on the subset outputs. This is the gate: if the
  min-steering extraction is degenerate (all-inf, all-equal, or direction
  nonsensical) STOP and route back — do NOT proceed to wire 8 targets / the full
  matrix.
- **Verification**: sweep jobs COMPLETED; `coordgd_reaching_efficiency.csv` for the
  subset has a defined (finite or inf) `min_scale` per cell AND at least one cell
  reaches clean at some scale; `coordgd_dc50_analysis.py` runs on the subset and
  prints C1 + P1 ρ (n=3 DC50-labeled here, indicative only) + MRT6160-vs-C147
  separation without error.
- **Estimated time**: 4 min hands-on (+ GPU wall, async)
- **Rollback (if this task only)**: `scancel`; delete the subset kfs2 out dir.

> **SCOPE DECISION (user, Task-8 gate, 2026-07-14):** C1/P1 reaching-efficiency
> is NULL across the full potency span on the control subset (all min_scale equal;
> active=inactive). Chosen next step = expand the VALIDATED C1/P1 discriminator to
> the full 9-compound DC50 panel (properly power the Spearman vs WTMetaD ρ=+0.714),
> and DEFER wiring the 8 exploratory targets. Therefore Tasks 9-12 are SKIPPED and
> Task 13 is re-scoped to the C1/P1 full-panel sweep. Rationale: with the
> mechanistically-grounded C1 target cleanly null, the exploratory targets (weaker
> grounding) are very unlikely to discriminate, and the ~550-run + 8-target-wiring
> cost is not justified to document that.

## Task 9: Wire catalytic targets C2/C3/C4 into the driver

- **Status**: skipped (user scope decision at Task-8 gate — exploratory targets deferred)
- **Prereq tasks**: 3, 8
- **Files touched**: `.agent/scratch/compass_steering/coordgd_driver.py`, `.agent/scratch/compass_steering/reach_thresholds.json`
- **Change shape**: Add `_build_potential` branches for C2 (near-attack +
  Bürgi–Dunitz angle, `losses_catalytic.c2_near_attack_bd`), C3
  (`make_c3_per_lysine`), C4 (`c4_cone_patch_occupancy`), reusing the C1
  cone-frame Kabsch carry + Nζ/patch atom resolution. Extend `--target` choices.
  Confirm each threshold entry exists in `reach_thresholds.json`.
- **Verification**: `python3 .agent/scratch/compass_steering/coordgd_driver.py --help` lists C2/C3/C4; a zero-GPU potential-build smoke (cached feats fixture or `_build_potential` unit path) returns a finite scalar loss on random coords for each of C2/C3/C4 → prints per-target `loss finite`.
- **Estimated time**: 5 min
- **Rollback (if this task only)**: `git checkout` the driver + config.

## Task 10: Wire interface targets P2/P3 into the driver

- **Status**: skipped (user scope decision at Task-8 gate — exploratory targets deferred)
- **Prereq tasks**: 3, 8
- **Files touched**: `.agent/scratch/compass_steering/coordgd_driver.py`, `.agent/scratch/compass_steering/reach_thresholds.json`
- **Change shape**: Add `_build_potential` branches for P2
  (`losses_interface.p2_degron_competence`) and P3 (`p3_contact_recovery`),
  reusing P1's `resolve_correspondence` to map the degron/contact residues to the
  prediction atom ordering. Extend `--target` choices + thresholds.
- **Verification**: `--help` lists P2/P3; zero-GPU potential-build smoke returns a finite scalar loss for each on random coords → `loss finite`.
- **Estimated time**: 5 min
- **Rollback (if this task only)**: `git checkout` the driver + config.

## Task 11: Wire 3-body targets G1/G2 into the driver

- **Status**: skipped (user scope decision at Task-8 gate — exploratory targets deferred)
- **Prereq tasks**: 3, 8
- **Files touched**: `.agent/scratch/compass_steering/coordgd_driver.py`, `.agent/scratch/compass_steering/reach_thresholds.json`
- **Change shape**: Add branches for G1 (`g1_glue_bridging`) and G2
  (`g2_bridge_span`, target 7.0 Å), resolving glue (ligand chain C) atoms + CRBN
  + VAV1 residues from feats for the bridging geometry. Extend `--target` +
  thresholds.
- **Verification**: `--help` lists G1/G2; zero-GPU potential-build smoke returns a finite scalar loss for each on random coords → `loss finite`.
- **Estimated time**: 5 min
- **Rollback (if this task only)**: `git checkout` the driver + config.

## Task 12: Wire manifold target M1 into the driver

- **Status**: skipped (user scope decision at Task-8 gate — exploratory targets deferred)
- **Prereq tasks**: 3, 8
- **Files touched**: `.agent/scratch/compass_steering/coordgd_driver.py`, `.agent/scratch/compass_steering/reach_thresholds.json`
- **Change shape**: Add the M1 branch (`m1_apo_broadening`, CA-CA separation band
  8–12 Å). M1's fit to the min-steering "reach" paradigm is the weakest of the
  battery (it targets ensemble broadening, not a single approach) — wire it but
  annotate it EXPLORATORY in the code + config so the analysis flags it as such.
  Extend `--target` + thresholds.
- **Verification**: `--help` lists M1; zero-GPU potential-build smoke returns a finite scalar loss on random coords → `loss finite`; the config marks M1 `exploratory:true`.
- **Estimated time**: 4 min
- **Rollback (if this task only)**: `git checkout` the driver + config.

## Task 13: C1/P1 full 9-compound panel sweep (RE-SCOPED; APPROVAL GATE — SLURM)

- **Status**: pending
- **Prereq tasks**: 8
- **Files touched**: (no repo files; produces per-cell measure CSVs on kfs2)
- **Change shape** (re-scoped per the Task-8 user decision): Run
  `run_coordgd_sweep.sh` over targets {C1, P1} × the 6 REMAINING Stage-D compounds
  (VAV1_411, VAV1_449, VAV1_245, VAV1_210, VAV1_382, VAV1_199) × the gd_scale
  ladder — the other 4 panel compounds (MRT6160, C147, VAV1_211, VAV1_474) are
  already done from Task 8, so the combined set = 8 Stage-D + MRT6160 + C147. This
  completes the C1/P1 min-steering panel to n=9 DC50-labeled (Stage-D 8 + MRT6160)
  + C147 for active/inactive. ~6×2×5 ≈ 60 short Boltz runs. Monitor proactively;
  log any dropped cells.
- **Verification**: sweep jobs COMPLETED; `_res_<cmp>_{C1,P1}_gs*.csv` present for
  all 6 new compounds (combined C1/P1 panel = 10 compounds); dropped cells logged.
- **Estimated time**: 4 min hands-on (+ ~1.5h GPU wall, async)
- **Rollback (if this task only)**: `scancel`; delete the new cells' kfs2 out dirs.

## Task 14: Full extraction + discriminator analysis

- **Status**: done (n=9 C1/P1 panel; C1 ρ=+0.137 CI[−0.315,+0.575] p=0.89; continuous ρ=−0.317 opposite sign; active=inactive → NULL)
- **Prereq tasks**: 13
- **Files touched**: (produces `.agent/scratch/compass_steering/coordgd_dc50_results.csv`)
- **Change shape**: Run Task-6 extraction over the full matrix → `reaching_efficiency.csv`;
  run Task-7 analysis → `coordgd_dc50_results.csv` + the printed per-target ρ+CI
  table, active/inactive separation, BH multiple-testing, and the WTMetaD ρ=+0.714
  comparison.
- **Verification**: `python3 .agent/scratch/compass_steering/coordgd_dc50_analysis.py` → a per-target table for all 10 targets with ρ+bootstrap CI, MRT6160-vs-C147 separation, BH-adjusted p, and the best-target-vs-0.714 line; `coordgd_dc50_results.csv` written with 10 target rows.
- **Estimated time**: 3 min
- **Rollback (if this task only)**: delete `coordgd_dc50_results.csv` + `reaching_efficiency.csv`.

## Task 15: Results writeup

- **Status**: done (.agent/scratch/compass_steering/results_coordgd_dc50.md)
- **Prereq tasks**: 14
- **Files touched**: `.agent/scratch/compass_steering/results_coordgd_dc50.md`
- **Change shape**: Honest report: per-target ρ+CI table, active/inactive
  separation, the reaching≠validation caveat (coord-GD reaches any defined target
  by construction), the multiple-testing correction, the explicit comparison of
  the best target's ρ to the MD WTMetaD FES ρ=+0.714, M1-exploratory flag, and an
  explicit statement that a NULL result (no target discriminates) is a valid,
  complete outcome (no-GT → measurement, not a perf gate). Follows the
  anti-AI Korean style.
- **Verification**: `test -f .agent/scratch/compass_steering/results_coordgd_dc50.md`; the doc cites `coordgd_dc50_results.csv` and addresses each contract success-criterion bullet (ρ+CI, active/inactive, physical-validity/seed, WTMetaD comparison, caveat, multiple-testing).
- **Estimated time**: 5 min
- **Rollback (if this task only)**: `git rm` the doc.

## Task 16: Baton + contract/plan close + handoff

- **Status**: done
- **Prereq tasks**: 15
- **Files touched**: `.agent/status/vav1-ubq.md`, `.agent/contracts/vav1-ubq-coordgd-dc50-discriminator-20260713.md`, `.agent/plans/vav1-ubq-coordgd-dc50-discriminator-20260713.md`
- **Change shape**: Set plan `status: done` + contract `status: done` + a Notes
  closeout paragraph; add the durable verdict to the vav1-ubq baton
  remaining_actions; run `./scripts/handoff.sh claude vav1-ubq` +
  `./scripts/status.sh index`.
- **Verification**: `head -8 .agent/status/vav1-ubq.md` shows today's `last_updated` + bumped version; contract + plan frontmatter both `status: done`; `./scripts/status.sh index` runs without stderr warnings.
- **Estimated time**: 3 min
- **Rollback (if this task only)**: revert the three files.
