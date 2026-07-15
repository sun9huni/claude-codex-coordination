---
contract: .agent/contracts/fksfold-core-chirality-aware-generation-20260621.md
slice: vav1-ubq
status: in-progress
total_tasks: 11
estimated_total_min: 95
---

# Plan — chirality-aware structure generation (Stage 0 → A → B)

Cheapest-first, gated. **Stage 0 (T1–T4)** is zero-GPU and unconditional. **Stage A (T5–T7)**
strengthens the existing chiral steering (no retrain); T6/T7 cross the ★GPU APPROVAL GATE.
**Stage B (T8–T11)** wires `ref_chirality` into the encoder + light finetune; runs **ONLY IF
T7 = NO-GO**; T9/T10 cross the ★GPU GATE. Diagnosis + evidence:
`.agent/scratch/chirality_diagnosis_and_plan_20260621.md`. Runtime featurizer = docker image
`fksfold-boltz:steering-v3` (`/app/src/boltz`); fork model/steering = host working tree.
Campaign inputs/outputs: `/mnt/data/users/ubuntu/workspace/glue6_orientation_campaign_20260617/`.

## Task 1: Authoritative input-graph ligand identity (zero-GPU)
- **Status**: done (build/lig_identity.py; /mnt = not a git repo, no commit; verified g3=S/DEOSSOPVSA, g4=R/XMMPIXPASA)
- **Prereq tasks**: none
- **Files touched**: `/mnt/data/users/ubuntu/workspace/crl_glue_md_20260618/build/lig_identity.py` (new)
- **Change shape**: small util: read a ligand isomeric SMILES (from a campaign `inputs/<g>_*.yaml`
  ligand entity), `MolFromSmiles` → `AssignStereochemistry(cleanIt,force)` → emit `MolToInchiKey`
  + per-stereocenter CIP. NO coordinate re-perception, NO PDB read. Writes `identity.json`.
- **Verification**: `python lig_identity.py g3_0.yaml g4_0.yaml` → g3 `BNPXZVKFXBHEKC-DEOSSOPVSA-N`
  (S), g4 `BNPXZVKFXBHEKC-XMMPIXPASA-N` (R) — distinct parity blocks.
- **Estimated time**: 5 min
- **Rollback**: `rm build/lig_identity.py`

## Task 2: Remove coordinate stereo re-perception in param_tleap (zero-GPU)
- **Status**: done (param_tleap.py: line-105 removed + warn-only stereo-honesty check; /mnt, no commit, .bak kept). FINDING: collapse is inherited from lig_raw.pdb (Boltz output both R) at AssignBondOrdersFromTemplate, NOT line 105; build now WARNS on input!=pose mismatch (g3 warns, g4 silent). Recovering S needs Stage A/B (fix the pose), not the build.
- **Prereq tasks**: none
- **Files touched**: `/mnt/data/users/ubuntu/workspace/crl_glue_md_20260618/build/param_tleap.py`
- **Change shape**: delete the `AssignStereochemistry(mol, force=True)` at line ~105 that re-derives
  stereo from the (collapsed) 3D coords AFTER `AssignBondOrdersFromTemplate`; rely on the
  template-assigned stereo instead. Surgical, single call removed.
- **Verification**: re-run `make_ligand` for g3 and g4 (CPU antechamber); the resulting ligand mol
  InChIKey matches its INPUT identity from Task 1 (g3=S, g4=R), not a collapsed single key.
- **Estimated time**: 5 min
- **Rollback**: `git -C <repo> checkout build/param_tleap.py` (NOTE: confirm tracked/committed first;
  if uncommitted, restore the single deleted line manually).

## Task 3: Chirality-sensitive pose metric module (zero-GPU)
- **Status**: done (commit 14803af)
- **Prereq tasks**: none
- **Files touched**: `analysis/crl_integrative/crl_chirality.py` (new)
- **Change shape**: given a ligand pose (coords + the input-template mol via
  `AssignBondOrdersFromTemplate`), compute (a) signed scalar-triple-product volume at the
  stereocenter, (b) signed improper dihedral, (c) template-correct CIP from 3D
  (`AssignStereochemistryFrom3D`). Pure-geometry, no symmetry alignment.
- **Verification**: on a hand-built R and S tetrahedron (or g3 vs g4 INPUT conformers) the signed
  metrics return OPPOSITE signs and correct CIP labels.
- **Estimated time**: 12 min
- **Rollback**: `rm analysis/crl_integrative/crl_chirality.py`

## Task 4: Wire metric into glue8_pose_scan + measure current collapse (zero-GPU)
- **Status**: done (commit e23ed59; g3/g4 both pose_CIP=R, g3 mismatch=True/g4 False — collapse exposed)
- **Prereq tasks**: 1, 3
- **Files touched**: `analysis/crl_integrative/glue8_pose_scan.py`
- **Change shape**: add 3 columns (signed_vol, signed_improper, pose_CIP) from `crl_chirality`, plus
  an `input_vs_pose_mismatch` WARNING flag comparing pose_CIP to the Task-1 input identity. Keep the
  existing Kabsch RMSD but demote it from the operative chirality readout.
- **Verification**: run on existing g3/g4 campaign outputs → both report pose_CIP = R while inputs are
  S/R respectively; the mismatch WARNING fires for g3. CSV has the 3 new columns populated.
- **Estimated time**: 10 min
- **Rollback**: `git checkout analysis/crl_integrative/glue8_pose_scan.py`

## Task 5: Steering-override knob + empty-tensor pre-check (zero-GPU prep)
- **Status**: done (potentials.py CHIRAL_GW/CHIRAL_BUFFER env override default-OFF + scripts/chiral_precheck.py). NOT committed: pre-existing aigen-fold-core uncommitted WIP in boltz_extension + formatter churn; Stage A consumes the edit via overlay-mount, commit deferred.
- **Prereq tasks**: none
- **Files touched**: `src/boltz_extension/steering/potentials.py` (env-var read; default-OFF)
- **Change shape**: make `ChiralAtomPotential` guidance_weight + buffer overridable via env vars
  (e.g. `CHIRAL_GW`, `CHIRAL_BUFFER`), defaulting to the current 0.10 / 0.524 when unset. Add a tiny
  standalone check that `chiral_atom_index.shape[1] != 0` for the g3/g4 featurized inputs.
- **Verification**: `bash -n`/import OK; with no env set, params read 0.10/0.524 (unchanged); pre-check
  prints `chiral_atom_index` count > 0 for g3 and g4 (else Stage A is a no-op → STOP, upstream issue).
- **Estimated time**: 8 min
- **Rollback**: `git checkout src/boltz_extension/steering/potentials.py`

## Task 6: ★GPU GATE — 3-tier chiral-steering smoke (g3+g4)
- **Status**: RUNNING (job 8123, kim --qos=batch, host-10-0-5-73). UNBLOCKED via path B (un-containerize): extracted glueplex-v2 fs to /mnt/kfs2/data/users/ubuntu/boltz_native_20260621/rootfs, ran boltz NATIVELY (kim --qos=batch sidesteps docker+assoc block; idle-node A100). Validation PASSED (job 8122 rc=0, baseline g3 pose_CIP=R=reproduces collapse=env faithful; offline, reused cached MSA). Sweep = g3/g4 × tiers baseline/0.5-0.30/1.0-0.20/2.0-0.10. Launcher run_native_sweep.sh. NEXT: read scored pose_CIP per tier → lowest tier where g3→S & g4→R = winning tier → T7.
- **Status(old)**: READY, BLOCKED-on-GPU. Launcher built byte-faithful at `/mnt/data/users/ubuntu/workspace/chirality_smoke_20260621/` (potentials_chiral_override.py = glueplex-v2 baked + 5-line CHIRAL_GW/CHIRAL_BUFFER env edit; run_chirality_smoke.sh g3/g4 seed314, tiers baseline/0.5-0.30/1.0-0.20/2.0-0.10; score_chirality_smoke.sh). Fire: `bash .../run_chirality_smoke.sh && bash .../score_chirality_smoke.sh`. BLOCKER: no free 80GB card (this docker-host's 8 GPUs run eunhak job 8114 ~10GB/card→~70GB free<80; np=8 needs full card); idle nodes reject ubuntu SSH; ubuntu sbatch=assoc lost; kim=no docker. Guard exits 1 until a full card frees.
- **Prereq tasks**: 4, 5
- **Files touched**: `analysis/crl_integrative/chirality_smoke/` (launcher + logs)
- **Change shape**: overlay-mount the edited `potentials.py` into `fksfold-boltz:steering-v3`; run g3
  and g4 single-seed (seed314) per tier — A: GW0.5/buf0.30, B: GW1.0/0.20, C: GW2.0/0.10 — score each
  output with `crl_chirality`. ★STOP for user go before sbatch.
- **Verification**: per-tier table of sign(g3) vs sign(g4) + pose_CIP; identify the lowest tier where
  g3→S and g4→R (sign flip) without obvious geometry blow-up.
- **Estimated time**: 6 min agent (job ~0.2 GPU-hr)
- **Rollback**: `scancel`; `rm -rf chirality_smoke/outputs`

## Task 7: ★GPU GATE — winning-tier 16-seed sweep + GO/NO-GO
- **Status**: GO (Stage A SUCCESS via a WIRING fix — the initial T6 'NO-GO' was because the chiral potential was never applied in the interface sampler, NOT because steering can't work). Diagnosis (zero-GPU): _sample_with_interface_steering bypasses the stock chiral-potential path. FIX (validated, job 8138): inject get_potentials(score_type='chirality') gradient into the interface sampler's per-step GD (~93-line additive diff, saved diffusionv2_extend.chiralwire.diff). RESULT seed314: g3(input S)→S at CHIRAL_GW=1.0 (was stuck R), g4 control stays R; interface PRESERVED (iptm 0.960→0.954, ligand_iptm 0.989→0.985, plddt unchanged); md5 proves outputs now move (prior fb00e6 all-identical → wired all differ). NO retrain, NO encoder surgery. REMAINING: multi-seed ≥14/16 confirm; port diff to host tree (entangled WIP); Stage D SAR. [OLD interim NO-GO note below superseded.]
- **Status(superseded interim)**: NO-GO (decided at T6, no 16-seed sweep needed). T6 sweep (job 8123, COMPLETED) ran g3/g4 × 4 tiers (CHIRAL_GW 0.10/0.5/1.0/2.0). RESULT: g3 output **byte-IDENTICAL (md5 fb00e6…) across ALL tiers**, g4 likewise — a 20× chiral-weight change produced ZERO output change. g3 stays pose_CIP=R (input S, WRONG), g4 stays R (input R, ok). Verified the cause is NOT a wiring bug: chiral constraint IS present+correct in processed/constraints npz (center atom 3712, is_r=S, 4 entries); override DOES read CHIRAL_GW (potentials.py:725); --use_potentials DOES set physical_guidance_update=True (main.py:1704). So the ChiralAtomPotential is enabled with a valid target and increasing weight — yet contributes ~zero effective gradient on this quaternary spiro glutarimide center (flat-bottom improper doesn't bite here / interface_lambda20 fully determines geometry). **⇒ Stage A (config-only, no-retrain chiral fix) cannot flip this chemotype's handedness. Escalate to Stage B (encoder ref_chirality + light finetune) — GATED on user go (finetune cost ~8-32 GPU-hr).** Native run infra (path B) fully working: /mnt/kfs2/.../boltz_native_20260621/ (kim --qos=batch, idle A100, byte-faithful, offline MSA).
- **Prereq tasks**: 6
- **Files touched**: `analysis/crl_integrative/chirality_smoke/sweep_verdict.md`
- **Change shape**: run the winning tier for g3 + g4 over 16 seeds; tabulate handedness-tracks-input
  fraction + interface health (iptm + key-residue contacts vs the baseline 0.10 run). ★STOP for go.
- **Verification**: verdict file: **GO** if ≥14/16 track input AND interface not degraded (skip Stage B);
  **NO-GO** with evidence (can't flip, or interface collapse) → proceed to Task 8.
- **Estimated time**: 6 min agent (job ~1 GPU-hr)
- **Rollback**: `scancel`; `rm -rf` sweep outputs.

## Task 8: Encoder ref_chirality wiring + zero-init ckpt surgery (CONDITIONAL: T7=NO-GO)
- **Status**: SKIPPED (T7=GO; Stage B finetune not needed — the no-retrain wiring fix corrects chirality)
- **Prereq tasks**: 7
- **Files touched**: `src/boltz/model/modules/encodersv2.py`; `scripts/ckpt_chirality_surgery.py` (new)
- **Change shape**: one-hot the already-emitted `ref_chirality` (`featurizerv2.py:1549`) and concat it
  LAST in the AtomEncoder feature vector; zero-init-widen `embed_atom_features` (388→395) in BOTH
  `input_embedder.atom_encoder` and `diffusion_conditioning.atom_encoder`; ckpt zero-pad surgery on a
  COPY of `boltz2_conf.ckpt`. Production ckpt never mutated in place.
- **Verification**: (g1) surgically-widened ckpt loads and pre-finetune predicted coords are
  BIT-IDENTICAL to baseline on one input; (g2) `ref_chirality` reaches the encoder (last dim == 7) and
  differs g3 vs g4 at the stereocenter atom row.
- **Estimated time**: 18 min
- **Rollback**: discard the ckpt copy; `git checkout encodersv2.py`; `rm scripts/ckpt_chirality_surgery.py`

## Task 9: ★GPU GATE — short conditioning finetune (CONDITIONAL: T7=NO-GO)
- **Status**: SKIPPED (T7=GO; Stage B finetune not needed — the no-retrain wiring fix corrects chirality)
- **Prereq tasks**: 8
- **Files touched**: `scripts/finetune_chirality/` (config + launcher)
- **Change shape**: short conditioning finetune of the widened model on a chirality-enriched ligand
  set (enantiomer pairs + general PDB ligands to avoid catastrophic forgetting), with the winning/Tier-C
  steering still applied. ★STOP for user go before sbatch.
- **Verification**: finetune runs to the planned step budget; chiral-relevant loss decreases, no NaN;
  checkpoint written.
- **Estimated time**: 6 min agent (job ~8–32 GPU-hr)
- **Rollback**: `scancel`; discard finetuned weights (original ckpt untouched).

## Task 10: ★GPU GATE — post-finetune re-measure (decisive g3 gate) (CONDITIONAL)
- **Status**: SKIPPED (T7=GO; Stage B finetune not needed — the no-retrain wiring fix corrects chirality)
- **Prereq tasks**: 9
- **Files touched**: `analysis/crl_integrative/chirality_finetune_verdict.md`
- **Change shape**: rerun g3 + g4 over 16 seeds with the finetuned model; `crl_chirality` must FLIP sign
  g3 vs g4 (g3→S, g4→R) ≥14/16; confirm held-out non-chiral lDDT/RMSD does not regress vs baseline.
- **Verification**: verdict file with sign-flip fraction + non-chiral regression check. GO → Task 11;
  persistent collapse → recommend a separate Stage C contract (out of scope here).
- **Estimated time**: 6 min agent (job ~1 GPU-hr)
- **Rollback**: `scancel`; `rm` verdict outputs.

## Task 11: Result doc + commit + close
- **Status**: done (analysis/crl_integrative/chirality_results_20260621.md). Contract core satisfied via Stage A wiring fix; multi-seed confirm + host-tree port remain as follow-ons.
- **Prereq tasks**: 7 (if GO at A) or 10 (if Stage B ran)
- **Files touched**: `analysis/crl_integrative/chirality_results_20260621.md`
- **Change shape**: doc = corrected diagnosis recap + Stage 0 measurement fix + Stage A verdict
  (+ Stage B verdict if run) + the explicit limit (pose ≠ SAR; Stage D deferred). Commit all Stage-0/A
  (and B if run) files; mark plan + contract done; flag Stage C/D as gated follow-ons.
- **Verification**: doc committed (`git log --oneline -1`); contract+plan `status: done`.
- **Estimated time**: 7 min
- **Rollback**: `git revert` the commit.
