---
contract: .agent/contracts/vav1-ubq-ikzf3-gt-methodology-validation-20260714.md
slice: vav1-ubq
status: in-progress
total_tasks: 12
estimated_total_min: 52
---

# Plan — CRBN-neosubstrate productive-geometry methodology validation on IKZF3 GT

Validate whether the 2-stage CRBN-neosubstrate prediction reproduces the 9UUM crystal productive
geometry (CRBN conformation + IKZF3 lysine ~17-21 Å placement), quantify DDB1's effect (±DDB1), then
(staged) refine coord-GD against GT + extend to multi-glue. CORE = Tasks 1-7 (9UUM ±DDB1 structure
reproduction). SECONDARY/staged = Tasks 8-10 (coord-GD refinement, multi-glue). Close = 11-12.

Inventory established before planning:
- 9UUM held locally (analysis/crl_integrative/refs/9UUM.cif): CRBN=chain C (glue het QFC), IKZF3=chain
  I (55 aa, lys K158/172/175), DDB1=chain B (1108 aa), ubiquitin=chain U (Gly76 = attack carbonyl).
- GT already measured: IKZF3 K158 Nζ→Ub-Gly76-C = 17.3 Å, K172 = 20.6 Å (productive resting geometry).
- TernaryConfig (api/ternary_config.py) is fully parametric (target_seq/e3_seq/pockets/s1_contacts/
  cult_pairs/msa/seeds) → an IKZF3_CONFIG is buildable. CRBN-IKZF3 interface = 16 Cα<8 Å pairs.
- DATA GAPS (front-loaded as tasks): (a) QFC glue SMILES (not in the cif coords; from the cif's
  chem_comp descriptor or user); (b) IKZF3 + DDB1 MSAs (VAV1 used precomputed; IKZF3/DDB1 have none →
  build via msa_server if reachable, else single-sequence fallback, documented).

Paths: scripts/outputs under `.agent/scratch/ikzf3_gt/` + kfs2 `/mnt/kfs2/data/users/ubuntu/ikzf3_gt_20260714/`.
GPU: kim, --qos=normal, un-containerized rootfs, free-GPU selector, kfs2 out (standing SLURM pre-approval).

---

## Task 1: Extract + measure the 9UUM crystal GT reference

- **Status**: done
- **Prereq tasks**: none
- **Files touched**: `.agent/scratch/ikzf3_gt/gt_reference.py`
- **Change shape**: Read 9UUM; extract the GT reference sub-structures — CRBN(C)+glue(QFC)+IKZF3(I)
  and CRBN(C)+glue+IKZF3+DDB1(B) — writing them as PDBs (the crystal targets to compare predictions
  to). Measure + record the frozen GT metrics to a JSON: CRBN chain sequence/numbering, IKZF3 lysine
  Nζ→Ub-Gly76-C distances (K158 17.3 / K172 20.6), IKZF3 CA coords (placement ref), CRBN CA coords
  (conformation ref). Zero-GPU (gemmi/numpy).
- **Verification**: `python3 .agent/scratch/ikzf3_gt/gt_reference.py` → writes `gt_9uum_CRBN_IKZF3.pdb`,
  `gt_9uum_CRBN_IKZF3_DDB1.pdb`, `gt_metrics.json`; prints IKZF3 K158→Ub 17.3 Å ± 0.1 (matches the
  measured GT).
- **Estimated time**: 5 min
- **Rollback (if this task only)**: `git rm` the script; delete outputs.

## Task 2: Obtain the QFC glue SMILES

- **Status**: done (QFC = Mezigdomide, C32H30FN5O4, cif-formula exact match)
- **Prereq tasks**: none
- **Files touched**: `.agent/scratch/ikzf3_gt/qfc_smiles.py`, `.agent/scratch/ikzf3_gt/qfc.smiles`
- **Change shape**: Extract the QFC ligand SMILES for the prediction input. Try, in order: (a) a
  `_pdbx_chem_comp_descriptor` / `_chem_comp` SMILES block in 9UUM.cif; (b) a local gemmi/CCD monomer
  entry; (c) reconstruct from the QFC coordinates via RDKit bond perception (fallback). Write the
  resolved SMILES to `qfc.smiles` with a provenance note. If none resolve, write a `NEEDS_USER` marker
  and stop (the glue SMILES is user-providable).
- **Verification**: `python3 .agent/scratch/ikzf3_gt/qfc_smiles.py` → prints the SMILES + source, writes
  `qfc.smiles`; `python3 -c "from rdkit import Chem; assert Chem.MolFromSmiles(open('.agent/scratch/ikzf3_gt/qfc.smiles').read().strip())"` parses (or the NEEDS_USER marker is present + reported).
- **Estimated time**: 5 min
- **Rollback (if this task only)**: `git rm` the two files.

## Task 3: Acquire IKZF3 + DDB1 MSAs (or documented fallback)

- **Status**: done (msa_server reachable → --use_msa_server; CRBN reuse; single-seq fallback documented)
- **Prereq tasks**: none
- **Files touched**: `.agent/scratch/ikzf3_gt/build_msa.sh`, `.agent/scratch/ikzf3_gt/msa_status.md`
- **Change shape**: Provide MSAs for the IKZF3 (55 aa) + DDB1 (1108 aa) chains (CRBN reuses the
  existing alldock crbn MSA). Try msa_server reachability from a compute node; if reachable, generate
  + cache the CSVs to kfs2; if blocked (like RCSB), fall back to single-sequence mode and DOCUMENT the
  degradation in `msa_status.md`. The script probes + records which path was taken (no silent choice).
- **Verification**: `bash .agent/scratch/ikzf3_gt/build_msa.sh --probe` → reports `MSA_SERVER: reachable`
  or `blocked → single-sequence fallback`, writes `msa_status.md`; if reachable, the IKZF3/DDB1 MSA CSVs
  exist on kfs2.
- **Estimated time**: 4 min hands-on (+ MSA build wall if server reachable)
- **Rollback (if this task only)**: delete the MSA CSVs + `git rm` the script/status.

## Task 4: IKZF3_CONFIG + DDB1-chain support in the input builders

- **Status**: done
- **Prereq tasks**: 1, 2
- **Files touched**: `.agent/scratch/ikzf3_gt/ikzf3_config.py`, `.agent/scratch/ikzf3_gt/build_inputs.py`
- **Change shape**: Define an `IKZF3_CONFIG` (a `TernaryConfig`) — CRBN e3_seq (from Task-1 reference,
  reconciled numbering), IKZF3 target_seq, QFC SMILES (Task 2), CRBN pocket + IKZF3 pocket, s1_contacts
  (pick ~4 from the 16 CRBN-IKZF3 Cα pairs, mapped to the config numbering), msa paths (Task 3), cult
  pairs (IKZF3 degron register or omit). `build_inputs.py` wraps `api.pipeline.build_stage1_yaml`
  to emit two inputs: **−DDB1** (CRBN+IKZF3+glue) and **+DDB1** (adds DDB1 as a 3rd protein chain +
  its MSA). Do NOT modify api/pipeline.py's VAV1 path — DDB1 injection is additive in the wrapper.
- **Verification**: `python3 .agent/scratch/ikzf3_gt/build_inputs.py` → writes `ikzf3_noddb1.yaml` +
  `ikzf3_ddb1.yaml`; both parse (`yaml.safe_load`), have IKZF3 target + QFC ligand + s1_contacts, and
  the +DDB1 one has the extra DDB1 protein chain; VAV1_CONFIG path unaffected (spot-check import).
- **Estimated time**: 5 min
- **Rollback (if this task only)**: `git rm` the two files.

## Task 5: Prediction runner + launcher (±DDB1, stock path)

- **Status**: done
- **Prereq tasks**: 3, 4
- **Files touched**: `.agent/scratch/ikzf3_gt/run_ikzf3.sh`
- **Change shape**: A kim/kfs2 launcher (mirror run_stock_native.sh) that runs the ±DDB1 IKZF3 inputs
  through the rootfs Boltz `predict_core` with `use_interface_steering=False` (pure stock), seed set,
  200 steps, output to `ikzf3_gt_20260714/out/<variant>_s<seed>/`. Login-node stager makes dirs
  kim-writable (chmod o+rwX as owner), prints the resolved run grid (2 variants × N seeds) + the
  submit line; never auto-submits.
- **Verification**: `bash .agent/scratch/ikzf3_gt/run_ikzf3.sh` (login) → stages deps, prints the grid
  (noddb1/ddb1 × seeds) + the `sudo -u kim sbatch` line, no GPU exec; `bash -n` clean.
- **Estimated time**: 5 min
- **Rollback (if this task only)**: `git rm` the launcher.

## Task 6: Run 9UUM CRBN-glue-IKZF3 ±DDB1 (APPROVAL GATE — SLURM)

- **Status**: done (smoke 17034 + jobs 17035-17041; 8 cells ±DDB1×4seeds; noddb1 CRBN 1.73±0.08Å, ddb1 1.72±0.02Å; IKZF3 lys ~15Å vs GT 17-21Å)
- **Prereq tasks**: 5
- **Files touched**: (no repo files; produces predicted PDBs on kfs2)
- **Change shape**: Submit the Task-5 runs: ±DDB1 × a few seeds (e.g. 4) on GPU, parallel per seed.
  Monitor first cell proactively; log any failures (no silent drop).
- **Verification**: jobs COMPLETED; `*_model_0.pdb` present for both variants across seeds
  (`find out -name '*_model_0.pdb' | wc -l` = variants×seeds).
- **Estimated time**: 3 min hands-on (+ GPU wall, async)
- **Rollback (if this task only)**: `scancel`; delete the out dirs.

## Task 7: GT-reproduction analysis + verdict (CORE done)

- **Status**: done (native 2-stage reproduces 9UUM: CRBN 1.73Å, IKZF3 placement ~7Å, lysine zone ~15Å vs GT 17-21Å; DDB1 no improvement)
- **Prereq tasks**: 1, 6
- **Files touched**: `.agent/scratch/ikzf3_gt/gt_reproduce_analysis.py`, `.agent/scratch/ikzf3_gt/results_ikzf3_gt.md`
- **Change shape**: For each predicted variant/seed, superpose on the 9UUM CRBN (Kabsch) and compute vs
  the Task-1 GT: CRBN conformation Cα-RMSD, IKZF3 neosubstrate placement Cα-RMSD, IKZF3 lysine Nζ→Ub-
  Gly76-C distance (vs GT 17-21 Å). Aggregate ±DDB1 (mean/spread over seeds) + the ±DDB1 delta. Write
  `gt_reproduce_analysis.py` (pure-stdlib+gemmi) + `results_ikzf3_gt.md` with the per-variant table +
  the verdict on (i) does the native prediction reproduce the crystal productive geometry, (ii) does
  DDB1 materially improve it. Anti-AI Korean style.
- **Verification**: `python3 .agent/scratch/ikzf3_gt/gt_reproduce_analysis.py` → the ±DDB1 reproduction
  table (CRBN RMSD, IKZF3 placement RMSD, lysine→Ub vs GT) + the DDB1-delta verdict; `results_ikzf3_gt.md`
  written citing it.
- **Estimated time**: 5 min
- **Rollback (if this task only)**: `git rm` the two files.

## Task 8: coord-GD GT-anchored refinement (C2 angle + NAC band + sidechain-relaxed)

- **Status**: pending
- **Prereq tasks**: 7
- **Files touched**: `.agent/scratch/compass_steering/coordgd_driver.py`, `.agent/scratch/ikzf3_gt/coordgd_refine_notes.md`
- **Change shape**: Add a refined coord-GD target: wire C2 (`c2_near_attack_bd` = distance + Bürgi-
  Dunitz angle, already in losses_catalytic), a NAC distance BAND (penalize both too-far and too-close,
  target ~3.0-3.5 Å not unbounded pull), and a sidechain-relaxed atom mask (Lys CB-CG-CD-CE-NZ instead
  of Nζ-only). Additive to the driver (new `--target C2` + `--nac-band` + `--mask sidechain` opts);
  P1/C1 unchanged. Note in `coordgd_refine_notes.md` that this is GT-anchored (target = reproduce the
  GT productive geometry, not the crude near-attack jam).
- **Verification**: `python3 .agent/scratch/compass_steering/coordgd_driver.py --help` lists the new
  opts; a zero-GPU potential-build smoke returns a finite C2 loss on random coords + the sidechain mask
  covers 5 atoms; P1/C1 build path unchanged (spot-check).
- **Estimated time**: 5 min
- **Rollback (if this task only)**: `git checkout` the driver; `git rm` the notes.

## Task 9: Run refined coord-GD on 9UUM vs GT (APPROVAL GATE — SLURM)

- **Status**: pending
- **Prereq tasks**: 8
- **Files touched**: (no repo files; produces refined-coord-GD PDBs on kfs2)
- **Change shape**: Run the refined coord-GD (C2 + band + sidechain-relax) on the 9UUM IKZF3 system,
  gd_scale swept, and measure the resulting geometry vs the GT (lysine→Ub, BD angle ~107°, backbone
  perturbation) — does refined coord-GD reach a GT-consistent / geometrically-sensible pose (unlike
  the crude C1 jam at 2.05 Å, 73°)?
- **Verification**: jobs COMPLETED; the refined-pose measure table (lysine→Ub, BD angle, backbone RMSD
  vs unsteered) produced + compared to the C1-jam baseline.
- **Estimated time**: 3 min hands-on (+ GPU wall, async)
- **Rollback (if this task only)**: `scancel`; delete the out dirs.

## Task 10: Multi-glue IKZF3 extension (staged; gated on user-provided structures)

- **Status**: pending
- **Prereq tasks**: 7
- **Files touched**: `.agent/scratch/ikzf3_gt/multiglue_manifest.md`
- **Change shape**: IF the user provides 9UUQ/9V0C/9V0E/9V0F (RCSB fetch blocked in-sandbox): for each,
  extract the GT (Task-1 pattern), build the input (Task-4 pattern, glue-specific SMILES), run (Task-6
  pattern), analyze (Task-7 pattern). If NOT provided, record in `multiglue_manifest.md` exactly what
  files are needed + the reproduction-across-glues + potency-ordering plan, and mark this task
  deferred-pending-structures (do NOT block core completion).
- **Verification**: either the multi-glue reproduction table is produced, OR `multiglue_manifest.md`
  lists the needed structures + the plan and the task is marked deferred.
- **Estimated time**: 4 min (manifest) / more if structures provided
- **Rollback (if this task only)**: `git rm` the manifest / delete multi-glue out dirs.

## Task 11: Results writeup (consolidated)

- **Status**: pending
- **Prereq tasks**: 7, 9, 10
- **Files touched**: `.agent/scratch/ikzf3_gt/results_ikzf3_gt.md`
- **Change shape**: Consolidate into the results doc: the core 9UUM ±DDB1 GT-reproduction verdict, the
  DDB1-necessity finding, the refined-coord-GD-vs-GT result, the multi-glue status, and the implication
  for the VAV1 transfer (whether the method is GT-validated enough to trust on VAV1). Anti-AI Korean
  style; cites all artifacts + GPU job IDs.
- **Verification**: `test -f .agent/scratch/ikzf3_gt/results_ikzf3_gt.md`; the doc addresses each
  contract success-criterion bullet (CRBN RMSD, IKZF3 placement, lysine→Ub vs GT, ±DDB1 delta) + the
  secondary tracks.
- **Estimated time**: 4 min
- **Rollback (if this task only)**: revert the doc.

## Task 12: Baton + contract/plan close + handoff

- **Status**: pending
- **Prereq tasks**: 11
- **Files touched**: `.agent/status/vav1-ubq.md`, `.agent/contracts/vav1-ubq-ikzf3-gt-methodology-validation-20260714.md`, `.agent/plans/vav1-ubq-ikzf3-gt-methodology-validation-20260714.md`
- **Change shape**: Set plan + contract `status: done` + a Notes closeout; add the durable verdict to
  the vav1-ubq baton remaining_actions; run `./scripts/handoff.sh claude vav1-ubq` +
  `./scripts/status.sh index`.
- **Verification**: `head -8 .agent/status/vav1-ubq.md` shows today's date + bumped version; contract +
  plan frontmatter `status: done`; `./scripts/status.sh index` no stderr warnings.
- **Estimated time**: 3 min
- **Rollback (if this task only)**: revert the three files.
