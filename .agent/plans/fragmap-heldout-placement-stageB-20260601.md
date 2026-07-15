---
contract: .agent/contracts/fragmap-heldout-placement-validation-20260601.md
slice: fragmap
status: done
outcome: "DONE = KILL (FKSFold 65a487f). All 10 tasks done; 36/36 cells generated (array 5911 +5961 requeue) + DockQ-scored. Frozen PROVE/KILL → KILL: nativeAB≥0.23 only 1/4, nativeAB NOT>baseline (9NYR steering harmful). Held-out placement = intrinsic-prior-driven; oracle steering neutral-to-harmful (enclosure≠recognition, non-circular). Positive: baseline medium on 2/4. Harness lessons en route: /home not shared→/mnt/data staging; GPU-collision (docker --gpus=device=0 vs cgroup)→per-task UUID selector; DockQ chain_map={native:model}. See STAGEB_RESULTS.md."
total_tasks: 10
estimated_total_min: 42
program: .agent/plans/fragmap-leverage-program-20260601.md (T2/D3, Stage B)
refreshed: "2026-06-01 — Option-1 refresh per parent AMENDMENT 2. Prior Phase-0 mechanism spike (old Task 1) is DONE/superseded by the recipe contract fragmap-heldout-steering-recipe-20260601 (mechanism decided = single-chain target-pocket steering + re-derived CRBN anchor; 9D0W comparability dropped). Old Task 2 (config) is now well-defined and becomes Task 1. Tasks renumbered; SLURM submit (now Task 7) remains the hard gate."
note: >
  Two gates: (1) this refreshed plan needs user approval (status:approved) to run
  the zero-GPU prep (Tasks 1-6); SEPARATELY (2) Task 7 (SLURM submit) needs an
  explicit "go" with a resource request (WORKFLOW §3). Frozen design + PROVE/KILL:
  parent contract §AMENDMENT 2 + PREREGISTER.md (incl. AMENDMENT 1 corrected
  positions). Mechanism inputs: STAGEB_RECIPE.md (§2.2 CRBN anchor table) +
  verify_heldout_anchor.py.
---

# Plan — Held-out placement validation, Stage B (Option-1 refresh)

> **Refresh provenance.** The original Phase-0 de-risk was elevated to its own
> brainstorm→contract (`fragmap-heldout-steering-recipe-20260601`), which returned
> BOUNCE: 9D0W's "AB" is inter-chain CRBN↔target crystal-pair steering (would make
> DockQ circular), so it is not comparable to the non-circular single-chain design.
> The user chose **Option 1** (best long-term): keep non-circular DockQ, drop 9D0W
> comparability (parent §AMENDMENT 2). The mechanism is now DECIDED — single-chain
> target-pocket steering (AMENDMENT-1 corrected) + the re-derived CRBN anchor
> (STAGEB_RECIPE §2.2, 4/4). This plan executes that.

Repo: `/home/ubuntu/FKSFold-Boltz_Advancement`; work dir:
`analysis/heldout_placement_20260601/`. Harness precedent:
`workflow/slurm_glueprint_gd_pilot_3x3_20260507.sh` + `analysis/pli_objective_pilot_20260601/PINS.md`.
DockQ recipe: `SOURCES.md §DockQ`. Phases: **A Configs+Inputs** → **B Harness** →
**C Smoke** → **D Gated gen + verdict**.

---

## Task 1: Build per-target generation configs (re-derived anchor + single-chain steering)

- **Status**: done (819d362 glueprint; AMENDED 16e68a6 — code-review found the parallel biophysical block also VAV1-specific: key_residues_A→[] (target off), key_residues_B→re-derived CRBN anchor. All 4 re-verified glueprint+biophysical.)
- **Prereq tasks**: none
- **Files touched**: `analysis/heldout_placement_20260601/configs/oracle_generation_heldout_<ID>.yaml` (4)
- **Change shape**: From `configs/vav1_pipeline/oracle_generation.yaml`, derive one
  config per held-out target: (a) set the CRBN-side glueprint anchor to the
  **re-derived** positions from STAGEB_RECIPE §2.2 / `verify_heldout_anchor.py`
  (w400 → 356/321/331/345 for 9NYR/9NGT/9NFQ/9OS2; anchor_patch + 14 CRBN-pocket
  positions per target); (b) **disable the VAV1-specific glueprint target-side
  term** (`target_key_residues` — VAV1 [15,16,18,19,37,39] is meaningless on
  held-out targets) by neutralizing it (empty list and/or `w_ligand_face: 0`), so
  the only target-side steering is the Boltz single-chain pocket constraint in the
  input YAML; (c) preserve gd_weight/gd_floor/w_glueprint/w_anchor_face and all
  energy params (config values only — no formula edits, per contract forbidden).
- **Verification**: each config parses; the FK superset loader accepts it without
  error — `python3 -c "import yaml; d=yaml.safe_load(open('<cfg>')); g=d['glueprint']; assert g['anchor_patch']==<re-derived> and not g.get('target_key_residues')"` per target; `diff` vs source shows only the intended anchor + target-term changes. (Optional: dry-load via `src/boltz_extension/steering/interface_steering_utils.py::_load_glueprint_config_from_biophysical_yaml` to confirm the disabled term loads cleanly.)
- **Estimated time**: 5 min
- **Rollback**: rm the configs/ dir.

## Task 2: Build wrongAB input YAMLs (4 targets)

- **Status**: done (237485d; contacts == fix_pocket_numbering wrongAB col, disjoint from nativeAB)
- **Prereq tasks**: none
- **Files touched**: `examples/heldout/<ID>_wrongAB.yaml` (4)
- **Change shape**: Copy each `examples/heldout/<ID>.yaml` (nativeAB) and replace the
  pocket `contacts` with the **AMENDMENT-1 corrected wrongAB** positions
  (9NYR 158…293 / 9NGT 20-24 / 9NFQ 156-158,173-178 / 9OS2 3,67,70,71,73,74,124).
  Sequences + ligand + CRBN unchanged; carry the convention comment.
- **Verification**: `python3 analysis/heldout_placement_20260601/fix_pocket_numbering.py` wrongAB column == the `contacts` in each `_wrongAB.yaml`; all parse; all contacts in 1..N; disjoint from the nativeAB contacts of the same target.
- **Estimated time**: 4 min
- **Rollback**: rm the 4 `_wrongAB.yaml`.

## Task 3: Build baseline input YAMLs (4 targets)

- **Status**: done (237485d; constraints removed, sequences+ligand identical to nativeAB)
- **Prereq tasks**: none
- **Files touched**: `examples/heldout/<ID>_baseline.yaml` (4)
- **Change shape**: Copy each nativeAB YAML and **remove the entire `constraints:`
  block** (no target-pocket steering) — the baseline condition per PREREGISTER.md /
  AMENDMENT 2. Sequences + ligand + CRBN unchanged. (Baseline still gets the CRBN
  W400 anchor via the Task-1 config + CLI, matching 9D0W's "baseline = warhead
  anchor only, no target-side AB" per STAGEB_RECIPE §1.3.)
- **Verification**: `for f in examples/heldout/*_baseline.yaml; do python3 -c "import yaml,sys;d=yaml.safe_load(open(sys.argv[1]));assert not d.get('constraints')" "$f"; done`; all parse; sequences identical to the nativeAB YAML (diff = only the constraints removal).
- **Estimated time**: 3 min
- **Rollback**: rm the 4 `_baseline.yaml`.

## Task 4: Adapt the generation SLURM array for the 36-job matrix

- **Status**: done (16e68a6; FK src pin, --array=1-36, per-target w400, 36/36 inputs+4/4 configs resolve, bash -n OK; w400 interface-range + vav1_residues REMOVED for non-circularity per STAGEB_RECIPE §5)
- **Prereq tasks**: 1, 2, 3
- **Files touched**: `workflow/slurm_heldout_placement_stageB_20260601.sh` (new, adapted from `slurm_glueprint_gd_pilot_3x3_20260507.sh`); `analysis/heldout_placement_20260601/stageB_jobs.tsv` (extend with resolved input+config columns if needed)
- **Change shape**: Adapt the canonical array: pin `src/boltz_extension` + `main.py`
  to the **FK repo** path (PINS §1); `--array=1-36`; read `stageB_jobs.tsv`
  (target, condition, seed) → resolve per row to input YAML
  `examples/heldout/<target>[_<condition>].yaml` (nativeAB = `<target>.yaml`) + the
  Task-1 per-target config; scratch `OUT_BASE` (NOT a repo path); keep the
  idempotent skip. Keep generation CLI flags per PINS §2; set the per-target
  `--w400_residue_index` to the re-derived value (356/321/331/345), NOT the VAV1
  default 355.
- **Verification**: `bash -n workflow/slurm_heldout_placement_stageB_20260601.sh`; a dry awk over `stageB_jobs.tsv` prints 36 resolved `(input_yaml, config, w400, seed, out_dir)` tuples with every input YAML + config path existing; `grep` confirms FK src bind + `--array=1-36` + per-target w400.
- **Estimated time**: 5 min
- **Rollback**: rm the new .sh; `git checkout` stageB_jobs.tsv.

## Task 5: Build the generated-pose → GT DockQ eval wrapper

- **Status**: done (96c2f39; score_one()+CLI, GT-vs-GT 1.0000 / +5Å 0.5346 reproduce SOURCES.md)
- **Prereq tasks**: none
- **Files touched**: `analysis/heldout_placement_20260601/score_heldout_dockq.py` (new)
- **Change shape**: Wrap the SOURCES.md §DockQ recipe: given a generated complex
  (FKSFold chains A=CRBN, B=target, C=ligand) + the held-out GT CIF, build clean
  2-chain protein-protein PDBs (CRBN + target, standard residues only), map
  generated chains → GT chains (gen A→GT B [CRBN]; gen B→GT target D[9NYR]/C[others]),
  run `run_on_all_native_interfaces` with `:BD`/`:BC` per target, emit per-(target,
  condition,seed) DockQ. Reuse `.agent/scratch/dockq_smoke_20260601/dockq_smoke.py`
  chain-cleaning.
- **Verification**: GT-vs-GT sanity (DockQ ≈ 1.0) + +5 Å perturbed GT (≈ 0.53) for one target reproduce the SOURCES.md smoke numbers; prints a tidy (target, condition, seed, DockQ) row.
- **Estimated time**: 5 min
- **Rollback**: rm score_heldout_dockq.py.

## Task 6: Static smoke of the full harness (no GPU, no submit)

- **Status**: done (Task-6 commit; 36/36 inputs + 4/4 configs, 4/4 DockQ GT-sanity 1.0000, ~6 GPU-hr est bounded 3-9, READY=yes; STAGEB_SMOKE.md)
- **Prereq tasks**: 4, 5
- **Files touched**: `analysis/heldout_placement_20260601/STAGEB_SMOKE.md` (new — record)
- **Change shape**: Dry validation WITHOUT submitting: (a) all 36 input YAMLs +
  4 configs referenced by the TSV exist + parse; (b) idempotent-skip path logic;
  (c) the Task-5 scorer runs on the GT sanity for all 4 targets; (d) the per-target
  w400 values are wired; (e) compute the GPU-hour estimate (36 jobs × npart × steps)
  for the Task-7 gate. NO sbatch, NO docker run.
- **Verification**: STAGEB_SMOKE.md shows 36/36 inputs + 4/4 configs present+parse, 4/4 GT DockQ sanity ≈ 1.0, per-target w400 correct, and a concrete GPU-hour estimate.
- **Estimated time**: 4 min
- **Rollback**: rm STAGEB_SMOKE.md.

## Task 7: SUBMIT the 36-job generation array — ⛔ STOP GATE (explicit "go")

- **Status**: done — array **5911** completed 35/36 + **5961** requeued the 1 transient OOM (9NGT_wrongAB_seed16) → 36/36. GPU fix (per-task UUID selector) verified on wave-1 (4 co-located 9NYR → 4 distinct GPUs, 0 collision). 3 harness bugs fixed en route: /home-not-shared (→/mnt/data staging), GPU-collision (→UUID selector), qos=high submit-limit (→batch).
- **Prereq tasks**: 1, 2, 3, 4, 5, 6
- **Files touched**: (none in repo — submits a SLURM array; outputs to scratch OUT_BASE)
- **Change shape**: **WORKFLOW §3 hard gate.** Do NOT run without an explicit user
  "go". Bring the Task-6 GPU-hour estimate + exact resource request (partition,
  --gres, --time, --array=1-36%K) to the user. On "go": `sbatch
  workflow/slurm_heldout_placement_stageB_20260601.sh` under the active contract
  `fragmap-heldout-placement-validation-20260601`. Capture the array job id.
- **Verification**: `squeue`/`sacct` shows the 36-task array under the job id; OUT_BASE begins receiving `<target>_<condition>_seed<seed>/` dirs.
- **Estimated time**: 3 min hands-on (+ GPU wall: per Task-6 estimate)
- **Rollback**: `scancel <jobid>`; rm scratch OUT_BASE. No repo state touched.

## Task 8: Score all 36 generated poses with DockQ

- **Status**: done (run_stageB_scoring.py, 36/36 → stageB_dockq_results.tsv; scorer chain_map fix {native:model})
- **Prereq tasks**: 7
- **Files touched**: `analysis/heldout_placement_20260601/stageB_dockq_results.tsv` (new)
- **Change shape**: After the array completes, run the Task-5 scorer over every
  output → per-(target,condition,seed) DockQ. Record any failed cells explicitly.
  Also record the circular-context lig-target contact-F1 (labelled secondary).
- **Verification**: `wc -l stageB_dockq_results.tsv` = 36 (+header) or fewer with failed cells logged; every row has a numeric DockQ in [0,1]; per-target medians computable.
- **Estimated time**: 5 min hands-on (+ eval wall)
- **Rollback**: rm the tsv (re-runnable from OUT_BASE).

## Task 9: Apply the frozen PROVE/KILL + T0 guardrails → verdict report

- **Status**: done (STAGEB_RESULTS.md; VERDICT=KILL; proxy-audit PASS; n=3/4 bounds; positive sub-finding = baseline intrinsic placement on 2/4)
- **Prereq tasks**: 8
- **Files touched**: `analysis/heldout_placement_20260601/STAGEB_RESULTS.md` (new)
- **Change shape**: Compute against the **frozen** PROVE/KILL (re-justified in parent
  §AMENDMENT 2, independent of 9D0W): (i) median nativeAB DockQ ≥ 0.23 on ≥3/4,
  (ii) nativeAB > baseline, (iii) nativeAB > wrongAB by margin. Report as a **bound**
  (per-target + panel; n=4 low power). Run `docs/proxy_audit_preflight.md`. State
  PROVE / KILL / INCONCLUSIVE verbatim. **Explicitly address the AMENDMENT-2 null
  framing**: if nativeAB ≈ baseline ≈ wrongAB, conclude "placement generalization is
  pocket-prior re-emission, not CRBN-relative recognition" (the enclosure≠recognition
  outcome) — an informative Charter-A result, not a failure. Include limitations
  (relative non-circularity / ligand-bridge coupling, oracle-only, contact-F1
  circular, reference resolution).
- **Verification**: STAGEB_RESULTS.md has the per-target DockQ table, the 3 PROVE conditions each pass/fail with numbers, the proxy-audit outcome, the null-vs-signal interpretation, and one explicit verdict line bound to the frozen thresholds.
- **Estimated time**: 5 min
- **Rollback**: rm STAGEB_RESULTS.md.

## Task 10: Commit + update contract/plan/baton/handoff

- **Status**: done (FKSFold 65a487f; parent contract + this plan → done; fksfold-core baton + handoff)
- **Prereq tasks**: 1,2,3,4,5,6,8,9
- **Files touched**: FKSFold commit (configs, wrongAB/baseline YAMLs, SLURM script, scorer, smoke/results md/tsv — scratch OUT_BASE NOT committed; respect *.csv/outputs* policy); workspace (parent contract status→done + Notes, this plan status→done, baton, index)
- **Change shape**: Surgical commits of git-trackable artifacts. Set parent contract
  `status: done` with a Notes paragraph citing STAGEB_RESULTS.md + verdict; this plan
  `status: done`; update `.agent/status/fragmap.md` baton + run
  `scripts/handoff.sh claude fragmap` + `scripts/status.sh index`.
- **Verification**: both repos `git status --porcelain <paths>` clean for tracked artifacts; parent contract + this plan show `done`; verdict recorded in the baton.
- **Estimated time**: 3 min
- **Rollback**: git revert.

---

## Two-gate reminder

1. **Plan approval** (status:approved) authorizes the zero-GPU prep (Tasks 1-6) +
   readiness for Task 7. It does NOT authorize the sbatch.
2. **SLURM "go"** (Task 7) is a separate WORKFLOW §3 gate requiring an explicit user
   go + the resource request from Task 6's estimate.
3. No improvised design: mechanism is frozen by parent §AMENDMENT 2 + the recipe
   contract. If any task reveals the frozen mechanism can't be implemented as
   written, STOP and route back — do not improvise.
