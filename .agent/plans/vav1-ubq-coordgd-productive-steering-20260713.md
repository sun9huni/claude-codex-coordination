---
contract: .agent/contracts/vav1-ubq-coordgd-productive-steering-20260713.md
slice: vav1-ubq
status: done
total_tasks: 9
estimated_total_min: 45
---

# Plan: coordinate-GD productive-geometry steering on Boltz-2 (post-COMPASS direction 1)

Pivot from latent steering (failed, off-manifold) to coordinate-space guidance: drive the engine's
existing coord-GD path (should_apply_interface_gd / apply_interface_gd, + the fragmap_potential
compute_gradient precedent) with our differentiable productive-geometry loss battery, so the
gradient nudges atom_coords_denoised each reverse step and the denoiser re-idealizes geometry after.
Test P1 (9NFR near-native, a clean-control latent steering broke) + C1 (near-attack, far from prior)
on MRT6160 (active) + C147 (inactive). Engine edits are ADDITIVE + env-gated (COORDGD_STEERING) in
the rootfs copy only; scripts under .agent/scratch/compass_steering/ (reuse dir). Heavy reuse of the
COMPASS assets: loss battery, feats→atom-index NW resolver, SH3c/clash/crbn_fit measure. Phase A
(Tasks 1-5) is zero-GPU. Task 6 (Stage-0 smoke) is the HARD GPU gate. Tasks 6-7 are GPU (standing
pre-approval for this line of work per the contract; /execute-plan still logs each submit).

## Task 1: Loss→coord-GD potential adapter

- **Status**: done (commit c39e3af9; CoordGDPotential mirrors engine fragmap_potential protocol
  [compute_parameters/compute/compute_gradient], detach-clone-enable_grad-backward-nan_to_num-mask-
  gd_scale matching `coords -= guidance_weight·grad`; P1/C1 builders + near-attack readout; selftest
  finite-diff descent PASS for both P1 and C1 + atom-mask check; code-review APPROVE)
- **Prereq tasks**: none
- **Files touched**: `.agent/scratch/compass_steering/coordgd_potential.py` (new)
- **Change shape**: a `CoordGDPotential` (or factory) wrapping a battery loss (P1 = compass_coord_loss
  vs 9NFR; C1 = losses_catalytic near-attack) as a coord-GD potential exposing
  `compute_gradient(coords) -> grad` (mirrors the engine's fragmap_potential.compute_gradient
  interface): autograd-backprop the loss wrt the passed atom_coords_denoised, return the (optionally
  scaled) gradient, plus a `compute_parameters(steering_t)`-style weight schedule hook if the engine
  expects one. Backbone/atom indices + guidance are injected by the driver (partial-applied), same as
  the COMPASS loss_fn. Include a near-attack distance readout helper for C1.
- **Verification**: `python3 .agent/scratch/compass_steering/coordgd_potential.py --selftest` → on
  fake coords with a P1-style and a C1-style target, `compute_gradient` returns a finite, nonzero
  grad whose negative direction reduces the loss (finite-difference check); prints `COORDGD_POT OK`.
- **Estimated time**: 5 min
- **Rollback (if this task only)**: delete coordgd_potential.py.

## Task 2: Engine wiring — inject the coord-GD potential (rootfs, env-gated, additive)

- **Status**: done (commit 07e3474f; rootfs diffusionv2_extend.py COORDGD_STEERING-gated block +
  coordgd_wire.diff [+45/-1, 0 content deletions]. Reads _COORDGD_POTENTIAL via globals().get,
  mirrors the fragmap GD block exactly [compute_parameters→guidance_weight→interface_gd_steps loop→
  atom_coords_denoised -= w*grad] at the same no_grad loop site after fragmap. Triple-guard
  [flag/hook-None/weight>0], announce-once. AST gate-isolated [gate 902, body 908-929, no COORDGD
  token outside], flag-off no-op, COMPASS branch untouched, .pre_coordgd.bak saved; GPU byte-identity
  deferred to Task 6. code-review APPROVE.)
- **Prereq tasks**: 1
- **Files touched**: rootfs `boltz_native_20260621/rootfs/.../diffusionv2_extend.py` +
  `.agent/scratch/compass_steering/coordgd_wire.diff` (new saved diff)
- **Change shape**: inside `_sample_with_interface_steering`, add an env-gated
  (`COORDGD_STEERING`) block that reads a module hook (`_COORDGD_POTENTIAL`, set by the driver) and
  applies its coordinate gradient to `atom_coords_denoised` each step — mirroring the existing
  `fragmap_potential.compute_gradient` application block (same loop location, after denoising / before
  the coordinate update; respect `config.interface_gd_steps` and a steering_t weight schedule).
  Additive; flag-off = provable byte-identical no-op; separate from and not touching the (flag-off)
  COMPASS_STEERING latent branch. Regenerate the .diff.
- **Verification**: `python3 -c "import ast; ast.parse(open('<rootfs file>').read())"` exit 0; an
  AST-gate check shows every new COORDGD token is inside the `COORDGD_STEERING` gate (flag-off no-op);
  `patch --dry-run` of coordgd_wire.diff against the backup applies clean; report +/- counts.
- **Estimated time**: 5 min
- **Rollback (if this task only)**: `git apply -R` coordgd_wire.diff to the rootfs file; delete diff.

## Task 3: Driver — build potential, resolve atoms, run steered+unsteered

- **Status**: done (commit f7057792; coordgd_driver.py reuses compass_driver rootfs-import + feats-
  capture monkeypatch + NW atom resolvers + coordgd_potential. P1 = compass_coord_loss vs 9NFR; C1 =
  per-step frame-invariant CRBN-Kabsch carry of 9UUM CONE_APEX into the pred frame (chain-C ref onto
  pred chain-A, CRBN detached, Nζ-only grad), default lysine K788 (register not figure-confirmed →
  --lysine overridable). Sets _COORDGD_POTENTIAL + COORDGD_STEERING=1 steered / None+unset unsteered;
  predict_core with use_interface_steering=True + interface_gd_steps (the ONLY config field the block
  consumes — it is a fragmap sibling, NOT gated by enable_interface_gd/should_apply_interface_gd, so
  that path stays off). gd_scale default 1.0 (likely too large, sweep knob). Verified: ast OK; MRT6160
  input stat-OK; offline C1 Kabsch/frame-invariance unit test PASS (loss invariant under random rigid
  transform, Kabsch err 2e-6, Nζ-only grad). code-review APPROVE. ★C147 has NO prebuilt ternary input
  → first pass runs MRT6160 × {P1,C1} only; C147 input build deferred (active/inactive separation is
  secondary to the P1-clean + C1-reach mechanism test).)
- **Prereq tasks**: 1
- **Files touched**: `.agent/scratch/compass_steering/coordgd_driver.py` (new)
- **Change shape**: reuse compass_driver's rootfs import + feats→atom-index NW resolver + MRT6160/
  C147 input handling. For a chosen target (P1 or C1): resolve the guidance atom indices (P1 = 9NFR
  interface backbone; C1 = the VAV1 Lys Nζ + carry the cone-frame near-attack target point into the
  prediction CRBN frame via Kabsch), build the CoordGDPotential, set `diffusionv2_extend._COORDGD_POTENTIAL`,
  set `COORDGD_STEERING=1`, run Boltz predict; also run an unsteered baseline (flag off). Args:
  `--compound {MRT6160,C147}`, `--target {P1,C1}`, `--gd-scale`. Emit the steered + unsteered
  model_0.pdb to per-run dirs.
- **Verification**: `python3 -c "import ast; ast.parse(...)"` exit 0; the MRT6160 + C147 input paths
  stat-confirmed; grep-show the hook set (`_COORDGD_POTENTIAL`) + COORDGD_STEERING toggling + the C1
  cone-frame Kabsch carry; atom-index resolution reuses build_pred_residue_map (shown).
- **Estimated time**: 5 min
- **Rollback (if this task only)**: delete coordgd_driver.py.

## Task 4: Measure — SH3c/clash/crbn_fit + near-attack + CLEAN-STEER gates

- **Status**: done (commit 63bdf95f; coordgd_measure.py reuses stageA_measure SH3c/clash/crbn_fit +
  verify_sh3c crystal-independent internal-distortion (inline, since verify_sh3c analyzes at import) +
  driver c1_readout cone-Kabsch near-attack (measured==optimized). CLEAN-STEER gates: P1 sh3c≤uns+1 ∧
  clash<150 ∧ crbn_internal<4; C1 near_attack<uns−0.3 ∧ clash<150 ∧ crbn_internal<4. Dual single-shot/
  batch mode → coordgd_results.csv. Offline on real COMPASS PDBs REPRODUCES known values (unsteered
  SH3c 2.913 / clash 79 / crbn_fit 2.561; clamp0.5 crbn_internal 18.017 / sh3c 26.803), both gates
  correctly FAIL on distorted structures. code-review APPROVE.)
- **Prereq tasks**: none
- **Files touched**: `.agent/scratch/compass_steering/coordgd_measure.py` (new)
- **Change shape**: reuse stageA_measure's SH3c-RMSD-to-9NFR (CRBN Kabsch) + element-aware VdW clash
  + crbn_fit + the verify_sh3c crystal-independent internal-distortion (steered vs unsteered CRBN/
  VAV1). Add a near-attack distance readout for C1 (VAV1 Lys Nζ → cone-frame Ub-Gly76-C, from
  discriminator_config_20260629.json). Write `coordgd_results.csv` (compound,target,mode,sh3c,
  near_attack,clash,crbn_fit,crbn_internal_vs_unsteered) and print per-target CLEAN-STEER PASS/FAIL:
  P1 = SH3c ≤ unsteered+1Å AND clash < 150 AND crbn_internal < 4Å; C1 = near_attack closer than
  unsteered AND clash < 150 AND crbn_internal < 4Å.
- **Verification**: `python3 .agent/scratch/compass_steering/coordgd_measure.py --selftest` (or run
  offline on the EXISTING job-16867 smoke pdbs) → sensible SH3c/clash/crbn_fit + a CSV row + gate
  lines; prints `COORDGD_MEASURE OK`.
- **Estimated time**: 5 min
- **Rollback (if this task only)**: delete coordgd_measure.py.

## Task 5: SLURM launcher

- **Status**: done (commit c… ; run_coordgd.sh kim --qos=normal, un-containerized rootfs, free-GPU,
  kfs2 out compass_coordgd_20260713/. Stages 9 py [incl transitive compass_driver/stageA_measure] +
  4 data [9NFR_crystal.pdb, 9UUM.cif, discriminator_config, closure_spec]. MRT6160 × TARGETS (env
  COORDGD_TARGETS, default "P1 C1"; smoke=P1); GD_SCALE env knob default 1.0; each driver run =
  unsteered+steered (self-baselined); C147 arm file-gated + SKIP. measure→coordgd_results.csv +
  CLEAN-STEER table. compute-node env/GPU block diff-identical to run_stageA_9nfr.sh; login prints
  submit cmd, no auto-submit. code-review APPROVE.)
- **Prereq tasks**: 2, 3, 4
- **Files touched**: `.agent/scratch/compass_steering/run_coordgd.sh` (new)
- **Change shape**: kim `--qos=normal`, un-containerized rootfs, free-GPU selector, kfs2 out
  `compass_coordgd_20260713/`. Stage coordgd_driver.py + coordgd_potential.py + coordgd_measure.py +
  losses_*.py + geom_ops.py + 9NFR_crystal.pdb + discriminator_config. Loop {MRT6160,C147} ×
  {unsteered,P1,C1} (+ optional 1-2 gd-scale), per-cell dir, then coordgd_measure → coordgd_results.csv.
  Reuse the COMPASS launcher staging/env-strip/cache pattern.
- **Verification**: `bash -n run_coordgd.sh` exit 0; grep-confirm staged deps, `--qos=normal`, kfs2
  out, per-cell dirs matching the measure step, login-node staging prints the submit command (no
  auto-submit).
- **Estimated time**: 5 min
- **Rollback (if this task only)**: delete run_coordgd.sh + the kfs2 dir.

## Task 6: Stage-0 SLURM smoke — 1 compound × P1 (HARD GPU GATE)

- **Status**: done (PASS — job 16879, MRT6160 × P1. [COORDGD] block fired (guidance_weight=1.0,
  steps=4). CLEAN-STEER(P1-control) PASS: SH3c 2.194Å steered vs 2.913Å unsteered (0.72Å IMPROVEMENT
  toward 9NFR near-native), clash 81 (≈ unsteered 79, not elevated), crbn_internal 0.247Å (CRBN fold
  INTACT). Decisive contrast vs latent steering which drove CRBN to 17-19Å on the same target. Same
  config for both runs (only COORDGD_STEERING differs) → improvement attributable to coord-GD.
  Hypothesis confirmed: coordinate-space guidance + per-step denoiser re-idealization stays
  on-manifold AND steers effectively. kim --qos=normal, standing pre-approval.)
- **Prereq tasks**: 5
- **Files touched**: (none new — runs Task-5 launcher on 1 cell) + append smoke note to a scratch log
- **Change shape**: kim SLURM smoke: MRT6160 × P1 coord-GD (+ its unsteered). **GPU gate — standing
  pre-approval for this line of work; /execute-plan logs the submit.** Confirms coord-GD runs
  end-to-end in the wired engine.
- **Verification**: job COMPLETED; the coord-GD gradient is nonzero (coords moved: steered md5 ≠
  unsteered) AND the output is produced AND clash is not catastrophic (element-aware VdW not wildly
  above the unsteered baseline). If gradient zero or job crashes → stop, diagnose (as the COMPASS
  smoke surfaced integration bugs).
- **Estimated time**: 5 min (submit + inspect; GPU wall-clock separate)
- **Rollback (if this task only)**: `scancel`; delete the smoke output dir; rootfs diff stays.

## Task 7: Full run — 2 compounds × {P1, C1} + baselines (GPU)

- **Status**: done (MRT6160 × {P1 (job 16879), C1 (job 16883)} + unsteered baselines; C147 skipped, no
  input. One-hot bug in the driver's C1 helper _resolve_atom_index surfaced by run 16881 [atom_to_token
  /ref_atom_name_chars argmax], fixed + committed + rerun 16883. coordgd_results.csv complete with all
  4 rows. C147 arm deferred [active/inactive separation secondary to the mechanism test].)
- **Prereq tasks**: 6
- **Files touched**: kfs2 `compass_coordgd_20260713/` outputs (no repo files)
- **Change shape**: run the full Task-5 grid (MRT6160 + C147 × {unsteered, P1, C1}, + optional
  gd-scale). **GPU gate — standing pre-approval; log the submit.**
- **Verification**: all cells COMPLETED; each produced a model_0.pdb consumed by the measure step;
  no silent drops (log any failed cell).
- **Estimated time**: 5 min (submit + monitor setup; GPU wall-clock separate)
- **Rollback (if this task only)**: `scancel`; partial outputs harmless (Task 8 consumes what completed).

## Task 8: Analysis — CLEAN-STEER verdict (reported, zero-GPU)

- **Status**: done (coordgd_results.csv + CLEAN-STEER verdict, BOTH PASS. P1 clean-control: SH3c
  2.913→2.194 (improved toward 9NFR), clash 79→81, crbn_internal 0.247Å (crystal-independent, CRBN
  intact). C1 discriminating: near_attack 17.147→2.591Å (reached near-attack, prior 17Å away), clash
  79→83, crbn_internal 0.007Å, SH3c preserved 2.945. VERDICT = coord-GD steers on-manifold to BOTH a
  near-native (P1) and a far-from-prior (C1) target with no clash/distortion — the decisive contrast
  vs latent steering (CRBN 17-19Å). Crystal-independent crbn_internal (0.007-0.247 vs latent 17-19)
  confirms it is not a whole-CRBN-superpose artifact. Mechanism PASS → justifies the battery+DC50
  follow-up contract.)
- **Prereq tasks**: 7
- **Files touched**: `.agent/scratch/compass_steering/coordgd_results.csv` (output) + the
  crystal-independent re-check
- **Change shape**: run coordgd_measure over all completed cells → coordgd_results.csv + per-target
  CLEAN-STEER PASS/FAIL (P1 clean-control + C1 discriminating, per contract gates), plus the
  crystal-independent internal-distortion re-check (steered vs unsteered CRBN/VAV1) so the verdict is
  not a whole-CRBN-superpose artifact. Contrast the P1 result against the latent-steering failure
  (CRBN 17-19Å) explicitly.
- **Verification**: `python3 coordgd_measure.py --sweep-root <kfs2 out> ...` → the CSV + PASS/FAIL
  table; every number carries the crystal-independent cross-check; verdict stated.
- **Estimated time**: 5 min
- **Rollback (if this task only)**: delete coordgd_results.csv.

## Task 9: Results doc + baton + close contract/plan (docs)

- **Status**: done (commit 2f24194c; results_coordgd.md = pivot rationale + method [drive existing
  coord-GD path with battery loss] + P1/C1 results + latent-vs-coordGD contrast + mechanism PASS +
  battery/DC50 follow-up justification. Contract → done + Notes; plan → done; vav1-ubq baton additive
  entry.)
- **Prereq tasks**: 8
- **Files touched**: `.agent/scratch/compass_steering/results_coordgd.md` (new), the vav1-ubq baton
  (additive), the contract + plan (status edits)
- **Change shape**: results doc (phase-house style): the coord-GD-vs-latent contrast, P1 clean-control
  + C1 near-attack outcome with the crystal-independent verification, and the go/no-go for a follow-up
  battery+DC50 contract (only if PASS). Baton: additive top entry (cross-slice, coordinate w/ vav1-ubq
  owner). Contract approved→done + Notes; plan in-progress→done, Task 9 done.
- **Verification**: results doc present with the CLEAN-STEER verdict + crystal-independent table;
  `grep 'status: done'` matches contract + plan; vav1-ubq baton YAML re-parses.
- **Estimated time**: 5 min
- **Rollback (if this task only)**: `git checkout` baton/contract/plan; delete results doc.
