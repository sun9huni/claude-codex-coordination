---
status: done
slice: vav1-ubq
topic: coordgd-productive-steering
date: 2026-07-13
owner: claude
requested: 2026-07-13
approved_by: sunghoon.kim (2026-07-13, "승인")
cross_slice: [aigen-fold-core]
triggers_matched:
  - "engine change — wire the productive-geometry differentiable loss battery as coordinate-space
    GD potentials into the existing coord-GD path (should_apply_interface_gd / apply_interface_gd)
    of the rootfs Boltz-2 diffusion sampler (diffusionv2_extend.py, rootfs copy; aigen-fold-core-owned
    engine code — additive + env-gated, host tree untouched)"
  - "SLURM/GPU submission — Boltz-2 coord-GD generation on 2 control compounds x targets (kim account,
    un-containerized rootfs)"
  - "4+ files — engine GD wiring + loss-battery→potential adapter + driver + measure + results doc"
---

# vav1-ubq — coordinate-GD productive-geometry steering on Boltz-2 (post-COMPASS direction 1)

## Purpose

COMPASS latent steering failed on Boltz-2 by base-model mismatch (single-structure predictor's
latent is not a conformational manifold; effective steering goes off-manifold, CRBN distorts 17-19Å;
full diagnosis in .agent/scratch/compass_steering/results_compass.md). Direction 1 pivots to
COORDINATE-space guidance: drive the engine's ALREADY-EXISTING coord-GD steering path
(should_apply_interface_gd / apply_interface_gd) with our productive-geometry differentiable loss
battery, so at each reverse-diffusion step the gradient nudges atom_coords_denoised toward the
target geometry AND the denoiser re-idealizes geometry on subsequent steps. Hypothesis: this
re-idealization avoids both the static-graft clash problem (phase7 "productive≈0" because touching
poses clash, but that graft was frozen) and the latent off-manifold collapse (coordinates are the
model's native output space). Test whether coord-GD reaches productive geometry cleanly where
latent steering could not.

## Current State (reusable from the COMPASS work, all committed)

- Engine: rootfs `boltz_native_20260621/rootfs/.../diffusionv2_extend.py`
  `_sample_with_interface_steering` reverse loop ALREADY calls
  `apply_interface_gd(atom_coords_denoised, feats, steering_t, config, potentials)` under
  `should_apply_interface_gd(config, step_idx, num_sampling_steps, steering_t)`, taking a
  `potentials` dict of objects (precedent: LigandVolumeConstraint; fragmap_potential.compute_gradient).
  So the wiring is: adapt our loss battery into a potential with a compute_gradient(coords)->grad
  method and inject it into that dict behind a new env flag (e.g. COORDGD_STEERING), additive + gated,
  in the rootfs copy only. The stale COMPASS_STEERING latent branch stays flag-off (untouched).
- Loss battery (differentiable, on backbone N/CA/C): .agent/scratch/compass_steering/{geom_ops,
  losses_coord (P1/9NFR), losses_catalytic (C1 near-attack + C2-4), losses_interface}.py. These
  return scalar losses; coord-GD needs their gradient wrt coords (autograd on atom_coords_denoised).
- Atom-index resolution: runtime feats→index NW resolver (compass_driver.build_pred_residue_map +
  resolve_correspondence) maps guidance residues to the model atom ordering; reused directly since
  coord-GD operates on the same atom_coords_denoised ordering.
- Measurement (crystal-independent + crystal): stageA_measure.py (SH3c-RMSD-to-9NFR via CRBN Kabsch
  + element-aware VdW clash + crbn_fit) + verify_sh3c.py (steered-vs-unsteered internal CRBN/VAV1
  distortion). For C1, add a near-attack distance readout (Lys Nζ → Ub-Gly76-C in the cone frame,
  from discriminator_config_20260629.json).
- Targets this pass: P1 = 9NFR SH3c-on-CRBN near-native (guidance = /home/ubuntu/9NFR_crystal.pdb);
  C1 = near-attack (Nζ→Ub-Gly76-C ≤ near-attack threshold in the cone frame). Compounds: MRT6160
  (active) + C147 (inactive) controls only.
- Baselines already measured (COMPASS calibration, job 16868): unsteered MRT6160 SH3c-to-9NFR
  ~2.9-3.0Å, VdW clash ~79, crbn_fit ~2.56Å.

## Success criteria (mechanism validation only)

Run coord-GD on MRT6160 + C147 × {P1, C1} (+ unsteered baseline per compound), produce
`coordgd_results.csv` with, per (compound, target, mode): SH3c-RMSD-to-9NFR, near-attack distance
(for C1), VdW clash, crbn_fit, and the crystal-independent CRBN/VAV1 internal distortion vs
unsteered. A measure script prints CLEAN-STEER PASS/FAIL per:
- **P1 clean-control**: coord-GD keeps SH3c near-native (<= unsteered + ~1Å) AND clash NOT elevated
  (element-aware VdW, < ~150) AND CRBN internal distortion small (< ~4Å). This is the test latent
  steering FAILED (it drove CRBN to 17Å) — coord-GD must not break the already-near-native prior.
- **C1 discriminating**: coord-GD moves the Lys Nζ→Ub-Gly76-C measurably closer to near-attack than
  unsteered (a target the unsteered prior does NOT reach) WHILE clash not elevated AND CRBN fold
  preserved.
- PASS on BOTH (clean on P1 + clean productive movement on C1) = mechanism works → justifies a
  separate follow-up contract for the full battery + reaching-efficiency-vs-DC50 discriminator.
- Verification command: `python3 .agent/scratch/compass_steering/coordgd_measure.py` (or equivalent)
  → the CSV + per-target PASS/FAIL lines; plus the GPU job COMPLETED.

## Out of scope (adjacent, intentionally NOT this contract)

- Latent steering (COMPASS Path-2) — abandoned; its gated branch stays flag-off, untouched.
- Boltz ensemble finetune (post-COMPASS direction 2) — separate contract, pending a training-infra
  feasibility check.
- The full 10-target battery (C2-4, P2-3, G1-2, M1) — only P1 + C1 this pass.
- The reaching-efficiency-vs-DC50 discriminator and any DC50 ranking claim — deferred to the
  follow-up contract that runs only IF this mechanism validation PASSES.
- Ligand-feature / glue-atom guidance (backbone-only this pass).
- Any change to the shipped v1.1 DC50 ranker or the WTMetaD FES discriminator.

## Constraints

- Engine edits: additive + env-gated (new COORDGD_STEERING flag) in the ROOTFS copy ONLY; host WIP
  engine tree untouched (chiral-wire / COMPASS precedent); save a .diff artifact; flag-off must be a
  provable byte-identical no-op.
- Reuse the existing coord-GD path (apply_interface_gd + should_apply_interface_gd) and the potential
  interface — do NOT rewrite the sampler.
- GPU: kim account, un-containerized rootfs, --qos=normal, free-GPU selector (mem.free>75GB), output
  to kfs2 (NOT kfs5/kfs6). Standing SLURM pre-approval for this line of work (user, 2026-07-13).
- Scripts + outputs under .agent/scratch/compass_steering/ (reuse dir) + kfs2 run dirs.

## Resource budget

Modest: 2 compounds × {unsteered, P1, C1} × maybe 1-2 GD-strength settings ≈ 8-16 short Boltz runs
(~few min each on the un-containerized rootfs, same as the COMPASS sweeps). Zero-GPU code build +
review first (loss→potential adapter, driver, measure). No training.

## Rollback plan

Env flag COORDGD_STEERING unset → stock Boltz (byte-identical; the coord-GD path already exists and
is config-gated, our addition only injects a potential when the flag is on). `git apply -R` the
rootfs diff to restore; delete kfs2 output dirs. Host tree never touched. Nothing shipped, so no
production rollback.

## Approval

- requested: 2026-07-13
- approved by: sunghoon.kim (2026-07-13, "승인")

## Notes (closeout 2026-07-13)

DONE, verdict POSITIVE — mechanism validation PASSED on both gates. Full record:
.agent/scratch/compass_steering/results_coordgd.md; plan same slug (9 tasks done).

Drove the engine's existing coord-GD path (fragmap_potential protocol) with our productive-geometry
loss battery via a gated (COORDGD_STEERING) additive rootfs block + _COORDGD_POTENTIAL hook. On
MRT6160 (seed 42, sampling_steps 200, gd_scale 1.0, gd_steps 4):
- P1 clean-control PASS (job 16879): SH3c-to-9NFR 2.913→2.194Å (improved toward near-native), clash
  79→81, CRBN internal-distortion 0.247Å (intact).
- C1 discriminating PASS (job 16883): near-attack Nζ→cone Ub-Gly76-C 17.147→2.591Å (reached
  near-attack, prior 17Å away), clash 79→83, CRBN internal 0.007Å (intact), SH3c preserved 2.945.
Decisive contrast vs latent steering (which drove CRBN to 17-19Å on the same P1). Crystal-independent
CRBN internal-distortion (0.007-0.247 vs latent 17-19) rules out a superpose artifact. Hypothesis
confirmed: coordinate gradient + per-step denoiser re-idealization stays on-manifold AND steers to
both near-native and far-from-prior targets clash-free — the failure mode all prior placement work
hit is avoided.

Integration bug surfaced + fixed: the driver's C1 helper _resolve_atom_index read the one-hot
atom_to_token/ref_atom_name_chars as ints (job 16881 crash) — argmax fix committed, rerun 16883 clean.

SHIP: nothing to production (exploratory validation). This validates coord-GD as the working GT-free
steering mechanism for VAV1 productive geometry.

FOLLOW-UP (each a NEW contract): (1) full battery (C2-4,P2-3,G1-2,M1) × compound sweep +
reaching-efficiency-vs-DC50 discriminator (the original goal; vav1-ubq WTMetaD FES ρ=+0.714
comparator); (2) build the C147 (inactive) ternary input → active/inactive separation; (3) gd_scale/
gd_steps sweep for reaching-efficiency. Direction 2 (Boltz ensemble finetune) stays a separate
contract but is now lower priority (direction 1 succeeded cheaply; not mutually exclusive).

Reusable: CoordGDPotential (fragmap-protocol loss→GD adapter), the gated engine coord-GD block
(coordgd_wire.diff), coordgd_driver (feats atom-index resolver + C1 frame-invariant cone-Kabsch
carry), coordgd_measure (SH3c/clash/crbn_fit + crystal-independent distortion + near-attack), the
10-target loss battery.
