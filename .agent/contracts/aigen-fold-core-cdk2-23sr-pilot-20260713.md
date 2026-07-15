---
status: approved
approved_by: claude (proceed signal from user 2026-07-13, "진행")
decisions:
  - Target = CDK2 (298aa kinase domain), E3 = CRBN (same core construct as VAV1_CONFIG,
    reused verbatim), ligand = compound B11 for smoke / all 32 SI compounds for full batch.
  - Reference structure = PDB 23SR (CRBN/DDB1/CDK2 + glue B11=A1E59, cryo-EM 2.85A,
    Pei et al. J. Med. Chem. 2026 "Selective CDK2 Degradation via Noncanonical Recruitment").
  - Pipeline = the EXISTING 2-stage ternary Boltz pipeline (api/pipeline.py builders),
    parametrized on a new CDK2_CONFIG (TernaryConfig instance) instead of the default
    VAV1_CONFIG. Zero changes to api/pipeline.py, api/jobs.py, api/ternary_config.py,
    api/server.py -- purely additive (new config module + new standalone driver script,
    since api.jobs.run_ternary_prediction is hardcoded to VAV1_CONFIG and modifying it
    is out of scope for a single-target pilot).
  - CDK2_CONFIG pocket/contact/register-pair fields derived PROGRAMMATICALLY from 23SR
    coordinates (gemmi, 5.0A heavy-atom cutoff) -- not copied from VAV1_CONFIG, not
    hand-tuned. Cross-validated against the SI CSV's own alanine-scanning mutant panel
    (6/7 positions land on derived contacts).
  - target_msa = "empty" (Boltz single-sequence mode; no pre-computed CDK2 MSA exists).
    e3_msa reuses VAV1_CONFIG's crbn_chain_A.csv verbatim (identical CRBN construct).
  - Smoke-first discipline (same as every prior contract in this repo): 1 compound
    (B11, the self-consistency case whose own crystal structure IS 23SR) before any
    multi-compound array.
slice: aigen-fold-core
topic: cdk2-23sr-pilot
date: 2026-07-13
owner: claude
---

# CDK2/23SR pilot -- run the 2-stage ternary pipeline on a new target via a new CDK2_CONFIG

## Purpose

User supplied `/home/ubuntu/jm6c01264_si_002.csv` (32-compound SAR + alanine-scanning
SI table from a J. Med. Chem. 2026 CDK2-degrader paper) and asked to predict structures
"based on PDB 23SR" using "our 2-step structure prediction" -- i.e. run this project's
existing, production 2-stage ternary Boltz pipeline on a brand-new target (CDK2) instead
of VAV1. This is exactly the "separate pilot" the aigen-fold-core baton already flagged
as the next open item after the semantic-object-layer refactor made the pipeline
target-parametric: "CDK2 (or any new target) execution needs real seq+pocket/template+
glue series; the config path CAN now express it, running one is a separate pilot."

## Current State

- `api/pipeline.py`'s `build_stage1_yaml`/`build_stage2_yaml`/`cultsum`/
  `build_template_cif` all accept `config: TernaryConfig` (default `VAV1_CONFIG`) --
  confirmed by direct read, this part of the library is already target-parametric.
- `api/jobs.py::run_ternary_prediction` (the actual REST-API orchestrator) does NOT
  accept a config parameter -- it calls the builders with no `config=` argument, so it
  is still hardcoded to VAV1_CONFIG. The server/orchestrator layer was explicitly
  deferred in the semantic-object-layer contract ("server.py SemanticObject route
  deferred, library-level only this round").
- 23SR confirmed via RCSB REST: chain A=DDB1(836aa), chain B=CRBN(477aa, tagged; core
  matches VAV1_CONFIG.e3_seq exactly for 382/397 residues -- last 15 C-term residues
  disordered/unmodeled in this cryo-EM density, irrelevant to the interface), chain
  C=CDK2 kinase domain (298aa, exactly matches canonical CDK2; the NanoLuc/GFP-
  chromoprotein portions of the biochemistry fusion construct are not resolved in this
  coordinate model). Nonpolymer entity 4 = CCD A1E59, whose name/SMILES matches CSV
  compound B11 exactly -- self-consistency confirmed (23SR IS the B11-bound structure).
- No prior work exists for this exact target+structure+pipeline combination. A DIFFERENT,
  unrelated, older CDK2 pilot exists (`fragmap-cdk2-9d0w-pilot-20260521.md`, PDB 9D0W,
  CDK2+CyclinE1, the OLD FragMap-steering single-shot generation pipeline, not this
  project's 2-stage REST pipeline) -- not reused, not superseded, orthogonal.
- Interface analysis done this session (zero-GPU, gemmi, read-only against a freshly
  downloaded 23SR.cif): CRBN-CDK2 contacts + CRBN/CDK2-glue contacts computed at a 5.0A
  heavy-atom cutoff. CRBN-side engagement uses the SAME canonical tri-Trp/glutarimide
  pocket as VAV1 (W400=local355, H357=local312, N351=local306 all direct glue contacts
  here too) -- the paper's "noncanonical recruitment" appears to refer to how CDK2 is
  presented, not an unusual CRBN pharmacophore. 6/7 alanine-scanning CDK2 mutant
  positions (L54A/E57A/N59K/N59R/L148A/F152A/V154A) land directly on the
  structurally-derived pocket/contact residues; only G27N (G-loop) does not, consistent
  with acting via conformational positioning rather than a direct contact.
- `CDK2_CONFIG` built (scratch-session file, to be adopted into this repo per Done-When
  below), all 32 SI-compound stage-1 YAMLs built + validated via the REAL (unmodified)
  `pipeline.build_stage1_yaml(smiles, config=CDK2_CONFIG)`.
- Compute-node filesystem constraint (confirmed via phase8/dock_driver.py's own header,
  same cluster): compute nodes do not mount /home/ubuntu (separate per-node local ext4,
  mode 0750 owned by ubuntu:ubuntu; kim is not in the ubuntu group) -- api/*.py + MSA
  must be mirrored to a kim-writable /mnt/kfs2 dir, same pattern as the 388/117-compound
  VAV1 production runs.
- Mirror + driver already staged this session at
  `/mnt/kfs2/data/users/ubuntu/cdk2_23sr_pilot_20260713/` (api_mirror/{api/{__init__,
  pipeline,ternary_config}.py, cdk2_config.py}, msa/crbn_chain_A.csv [reused verbatim
  from VAV1's], cdk2_driver.py, jm6c01264_si_002.csv). Mirrored pipeline.py/
  ternary_config.py verified byte-identical to source via `diff`. Import-chain dry-run
  (login node, no GPU) passed: `build_stage1_yaml` produces valid YAML end-to-end.

## Assumptions And Questions

Assumptions:
- The existing 2-stage YAML/pocket/template pattern (proven on VAV1's SH3-surface
  interaction) transfers to CDK2's buried ATP-adjacent interface without re-tuning the
  pipeline itself -- only the config's pocket/contact/register lists change per target.
  **Risk, flagged by the earlier (unrelated) 9D0W pilot notes too**: a much more buried
  interface could behave differently under the same interface-steering assumptions the
  pipeline was tuned against for VAV1. Mitigated by: smoke-first, and by this pilot's
  pocket/contact lists being independently structure-derived (not copied from VAV1).
- Single-sequence (`msa: empty`) CDK2 target is an acceptable starting point given CDK2
  is an extremely well-characterized canonical kinase fold (solved 100s of times);
  monomer geometry should be reliable even without MSA. Interface accuracy specifically
  may be somewhat less robust than with a real co-evolutionary MSA -- flagged as a known
  limitation, not silently assumed away. Upgrading to a real MSA (a cheap, optional,
  separate single-chain Boltz call with `use_msa_server=True`, mirroring
  `api/jobs.py::run_prediction`'s existing pattern) is a documented follow-up, not done
  in this contract.
- CDK2_CONFIG's pocket/contact/cult_pairs lists are a FIRST-PASS structural derivation
  (deterministic 5.0A cutoff rule against 23SR), analogous in ROLE to VAV1_CONFIG but
  without VAV1_CONFIG's multiple rounds of empirical refinement across many sessions.
  Treat as a pilot starting point; may need iteration if stage-1/stage-2 poses don't
  converge sensibly.

Open questions:
- Should `CDK2_CONFIG` be committed into `api/ternary_config.py` (as a second preset
  alongside `VAV1_CONFIG`, matching that file's own stated design intent: "so the same
  2-stage pipeline can be pointed at any E3/target pair") once this pilot validates, or
  kept as a separate module? Recommend: commit into `ternary_config.py` as an additive
  `CDK2_CONFIG` constant if the smoke succeeds structurally (same file, same pattern,
  zero risk to `VAV1_CONFIG`) -- decide after smoke, not before.
- Should the driver's logic (stage1->cultsum->template->stage2, parametrized on an
  arbitrary config) eventually be folded back into `api/jobs.py::run_ternary_prediction`
  as an optional `config:` parameter, so future non-VAV1 targets don't need a bespoke
  driver script each time? Out of scope for this pilot (single-target, additive-only);
  flag as a natural follow-up for the REST-API/server layer, not blocking here.

Tradeoffs:
- Tight, structure-derived pocket lists (this pilot) vs. wider/looser constraints:
  chose tight+derived, mirroring VAV1's own "corrected pattern" lesson (over-wide
  constraints slow convergence / under-constrain the docking).
- `msa: empty` now vs. blocking on a real-MSA warm-up job first: chose `empty` now
  (zero extra dependency, documented pattern already in this codebase) with the
  real-MSA upgrade path documented as optional/later, not gating the pilot.

## Constraints

Allowed change scope:
- New files only: `api_mirror/{api/{__init__,pipeline,ternary_config}.py [byte-identical
  copies], cdk2_config.py}`, `msa/crbn_chain_A.csv` [byte-identical copy],
  `cdk2_driver.py`, `run_cdk2_smoke.sh`, `run_cdk2_full.sh` (batch, drafted after smoke
  succeeds) -- all under `/mnt/kfs2/data/users/ubuntu/cdk2_23sr_pilot_20260713/`.
- This contract file.
- (Conditional, post-smoke, separate approval) an additive `CDK2_CONFIG` constant
  appended to `api/ternary_config.py` in the canonical repo, if the owner/user wants it
  adopted -- not done as part of this contract's Done-When.

Forbidden change scope:
- No changes to `api/pipeline.py`, `api/jobs.py`, `api/server.py`, `api/schema.py`,
  `api/semantic_object.py`, or `VAV1_CONFIG` (VAV1's shipped ranking/generation path
  stays byte-identical, per this project's own standing hard rule).
- No changes to `src/boltz_extension/steering/*` or any Boltz model code.
- No re-freezing or modification of any existing MSA CSV.

External constraints:
- SLURM submission requires this contract (PreToolUse hook auto-blocks `sbatch` without
  an active contract under `.agent/contracts/`, last 7 days) -- satisfied by this file.
- Submit as `kim` (project-wide hard rule for all GPU jobs): `sudo -u kim sbatch
  --qos=normal <script>`. kim's association only has QOS=normal (no batch/high),
  verified pattern from the 117-compound run's own header comment.
- Compute nodes cannot read `/home/ubuntu` -- all inputs mirrored to `/mnt/kfs2`.
- GPU environment: reuse the existing, already-validated un-containerized boltz rootfs
  at `/mnt/kfs2/data/users/ubuntu/boltz_native_20260621/rootfs` (byte-faithful
  py3.11/torch/cuda, offline MSA) -- same environment the 388- and 117-compound VAV1
  production runs used successfully. No new environment/image work.

## Non-Goals

- Not asserting anything about CDK2 degrader EFFICACY/potency from these structures --
  this is a STRUCTURE prediction pilot (pose generation), matching this project's
  standing "input contract, not an efficacy spec" discipline for `TernaryConfig`.
  Ranking the 32 compounds by predicted DC50 is explicitly out of scope here (no CULTsum-
  to-DC50 correlation claim is made by this contract).
- Not modifying `api/jobs.py` to add a generic `config:` parameter to
  `run_ternary_prediction` (flagged as a possible follow-up, not done here).
- Not generating a real MSA for CDK2 in this contract (flagged as an optional follow-up;
  `msa: empty` is the starting point).
- Not running all 32 compounds until the smoke (B11) succeeds structurally.

## Done When

1. Smoke (compound B11) completes: `sudo -u kim sbatch --qos=normal run_cdk2_smoke.sh`
   exits 0, produces 5 stage-2 PDBs (`stage2_seed{16,123,300,42,777}_model_0.pdb`) with
   chains {A,B,C} all present and non-empty.
2. Self-consistency check: overlay/compare the B11 stage-2 poses against 23SR's own
   CRBN-CDK2-glue arrangement (e.g. CRBN-CDK2 interface RMSD or contact recall vs. the
   23SR ground truth extracted this session) -- report the number, PASS/FAIL judgment
   left to a human/follow-up analysis, not silently declared here.
3. Decision recorded (open question above): adopt `CDK2_CONFIG` into the canonical
   `api/ternary_config.py`, or keep it scratch-only, based on smoke result.
4. If smoke passes structurally: full 32-compound array job drafted
   (`run_cdk2_full.sh`, mirroring `run_dock_117_full.sh`'s array pattern) and submitted
   ONLY after separate explicit go-ahead (not automatic/`afterok`-chained without a
   check-in, given this is a first-of-its-kind target, unlike the well-trodden VAV1
   batch path).
5. Status updated: `.agent/status/aigen-fold-core.md` + `.agent/handoffs/CURRENT.md`
   (via `./scripts/status.sh index`).

## Implementation Steps

1. [DONE, this session] Confirm 23SR chain/ligand identity via RCSB REST; confirm CSV
   compound B11 == 23SR's bound glue (SMILES/CCD cross-check).
   verify: RCSB `polymer_entity`/`nonpolymer_entity` REST calls, manual SMILES compare.
2. [DONE, this session] Download 23SR.cif; compute CRBN-CDK2 + CRBN/CDK2-glue interface
   contacts (gemmi, 5.0A heavy-atom cutoff); cross-check against the CSV's own
   alanine-scanning mutant panel.
   verify: `analyze_interface.py` + `build_config.py` output, mutant-position overlap
   report (6/7 covered).
3. [DONE, this session] Build `CDK2_CONFIG` (TernaryConfig instance); build + validate
   all 32 compounds' stage-1 YAML via the real `pipeline.build_stage1_yaml`.
   verify: `cdk2_config.py` loads; `build_yamls.py` reports 32/32 built+parsed;
   B11's YAML inspected in full.
4. [DONE, this session] Stage the compute-node mirror
   (`/mnt/kfs2/.../cdk2_23sr_pilot_20260713/{api_mirror,msa,cdk2_driver.py,csv}`);
   verify byte-identical copies; dry-run the import chain on the login node (no GPU).
   verify: `diff` against source files = identical; `build_stage1_yaml` call succeeds
   from the mirrored path.
5. [THIS CONTRACT] Submit smoke (B11) via SLURM as kim.
   verify: `sudo -u kim sbatch --qos=normal run_cdk2_smoke.sh`; monitor to completion;
   inspect stdout/stderr logs + output PDBs per Done-When #1.
6. Self-consistency check vs. 23SR ground truth (Done-When #2) -- zero-GPU, follow-up.
   verify: RMSD/contact-recall script against extracted 23SR coordinates.
7. Decide + record adoption (Done-When #3); if adopting, append `CDK2_CONFIG` to the
   canonical `api/ternary_config.py` as a new commit (separate from this pilot's
   scratch files).
   verify: `python -c "from api.ternary_config import CDK2_CONFIG"` from the canonical
   repo path.
8. Draft `run_cdk2_full.sh` (32-compound array, mirroring `run_dock_117_full.sh`); do
   NOT submit without a separate explicit go-ahead.
   verify: `bash -n run_cdk2_full.sh`.

## Change Discipline

- Simplest adequate approach: new config module + new standalone driver script, zero
  changes to any shared/existing file; reuses the CRBN sequence+MSA verbatim (no new
  MSA needed for the E3 side); reuses the existing, already-validated un-containerized
  boltz environment verbatim (no new image/env work).
- New abstractions introduced: one (`CDK2_CONFIG`, an instance of the ALREADY-EXISTING
  `TernaryConfig` dataclass -- not a new type, just a new value).
- Unrelated code touched: none.
- Pre-existing dead code noticed: none in scope.
- Request-to-diff trace: user supplied `jm6c01264_si_002.csv` + "23SR pdb 기준으로 우리
  2 step structure prediction으로 예측해줘" -> this contract (1 new config module + 1
  new driver script + 1 SLURM smoke script + this contract file; full-batch script
  drafted but gated on smoke success + separate approval).

## Verification

- Zero-GPU (already done, this session): `cdk2_config.py` loads; `build_yamls.py`
  32/32 pass; mirror `diff`-identical; import dry-run passes.
- Smoke (this contract): `sudo -u kim sbatch --qos=normal run_cdk2_smoke.sh`; check
  `squeue -u kim`; on completion inspect
  `logs/smoke_<jobid>.{out,err}` + `output/B11/stage2_seed*_model_0.pdb` (5 files,
  chains A/B/C present, nonzero size) -- same schema check pattern as
  `phase8/dock_driver.py`'s `_parse_pdb_chains`/`EXPECTED_CHAINS`.
- Manual check: overlay generated B11 poses vs. 23SR (CRBN-CDK2 interface).

## Risks

- Regression risk: none to the shipped VAV1 path (zero shared-file changes; `VAV1_CONFIG`
  untouched; `run_ternary_prediction`/server/REST API untouched).
- Integration risk: CDK2_CONFIG's pocket/contact lists are a first-pass structural
  derivation, not battle-tested like VAV1_CONFIG's (which went through multiple
  refinement rounds) -- smoke result may require iterating the config, not a pipeline
  bug, if poses look wrong.
- Hidden dependency risk: `msa: empty` for CDK2 is untested in THIS pipeline (VAV1_CONFIG
  always used a real MSA) -- if stage-1 poses look degenerate/low-confidence, the first
  thing to try is a real MSA (documented follow-up), before concluding the
  pocket/contact derivation itself is wrong.
- Compute cost: smoke = 1 compound x (2 stage-1 + 5 stage-2) = 7 Boltz calls, 1 GPU,
  bounded by the 2h SLURM time limit (VAV1's equivalent smoke, job 16537, completed in
  4:33 -- expect a similar order of magnitude). Full batch (32 compounds x 7 calls = 224
  calls) is NOT submitted by this contract without a separate go-ahead.

## Rollback

- Revert strategy: all new files, additive only. Delete
  `/mnt/kfs2/data/users/ubuntu/cdk2_23sr_pilot_20260713/` to fully remove; delete this
  contract file to close it out. If `CDK2_CONFIG` is later adopted into
  `api/ternary_config.py`, that commit can be reverted independently (additive, does
  not touch `VAV1_CONFIG`).
- Containment strategy: pilot outputs isolated to its own `/mnt/kfs2` directory; no
  shared state (jobs.db, MSA cache, etc.) is shared with the VAV1 production runs.

## Progress Log

- 2026-07-13: contract created; zero-GPU prep (structure analysis, config derivation,
  YAML build/validate, mirror staging, import dry-run) all completed this session.
  Smoke submission next.
- 2026-07-13: **Smoke (B11) submitted (job 16872, kim, qos=normal) and completed
  MECHANICALLY**: rc=0, 5/5 stage-2 PDBs, schema PASS (chains A/B/C present, 459350B
  each), elapsed 364s (comparable to the VAV1-equivalent smoke's 4:33). Boltz correctly
  ran CDK2 in single-sequence mode per the configured `msa: empty` (log: "Found explicit
  empty MSA for some proteins, will run these in single sequence mode").
  **Self-consistency check vs. 23SR (Done-When #2) run (`compare_to_23sr.py`, Kabsch
  superposition on CRBN Calpha, all 5 seeds) -- STRUCTURALLY DOES NOT YET PASS**:
  - CRBN self-fit RMSD: 1.23-1.30 A (consistent, correct fold) -- good.
  - **Glue centroid distance from true 23SR position: 1.62-1.73 A across all 5 seeds**
    -- excellent, reproducible; the CRBN-pocket-templated stage-2 docking correctly
    re-derives the true glutarimide/quinazolinedione binding pose.
  - **CDK2 CA RMSD in the CRBN-aligned frame: 24.20-25.31 A across all 5 seeds** --
    LARGE miss, consistent direction of failure (not seed noise: range is only ~1.1 A
    wide, i.e. the pipeline confidently converges on a WRONG placement, not a random
    scattered one).
  - Diagnostic follow-up: does CDK2 fold correctly as an independent domain, ignoring
    its position relative to CRBN? Checked (seed 16, 123): CDK2-alone self-superposition
    CA RMSD = 2.67-2.74 A -- **yes, CDK2's own fold is fine** (reasonable for a
    single-sequence/no-MSA canonical kinase domain prediction).
  - **Diagnosis: this is a rigid-body ORIENTATION failure, not a fold failure or a
    pipeline bug.** CRBN folds correctly; the glue sits correctly in the CRBN pocket;
    CDK2 itself folds correctly -- but CDK2's placement relative to CRBN is wrong,
    confidently and reproducibly so (all 5 seeds agree). This points at the
    orientation-determining fields of `CDK2_CONFIG` (most likely `s1_contacts` -- only
    4 soft max_distance=5.0A pairs, first-pass-derived, evidently not tight/specific
    enough to anchor the correct relative orientation the way VAV1_CONFIG's
    multiply-refined contacts do) rather than the pocket lists (which are wide and may
    also be too permissive, per the contract's own flagged risk).
  - **Per Non-Goals ("Not running all 32 compounds until the smoke (B11) succeeds
    structurally"): the 32-compound full batch is NOT submitted.** Smoke passed
    mechanically but not yet structurally -- this contract's Done-When #1 (mechanical)
    is met; Done-When #2's explicit "PASS/FAIL judgment left to a human/follow-up
    analysis" is: FAIL on structural accuracy, pending config iteration.
  - Next candidates (not yet attempted): (a) tighten `s1_contacts` to more/tighter
    orientation-anchoring pairs (or add a register-pair-style hard constraint akin to
    `cult_pairs`' role); (b) narrow `s1_pocket_target`/`s1_pocket_e3` from the current
    wide, union-derived lists to a tighter inner-shell subset (mirroring the old
    9d0w pilot's own recommendation: "tight (8) for pilot" over a wider 22-residue
    shell); (c) revisit whether a real MSA for CDK2 (vs. `msa: empty`) measurably
    improves interface orientation, independent of (a)/(b).
- 2026-07-13: **Config search (v2-v5, P1-P4, 9 variants total) -- orientation error
  NEVER resolved via stage-1 contact/pocket tuning.** Tried: tighter contacts +
  triangulation (v2), spread across 5 epitopes (v3), redundant-core+new-epitopes
  union (v4), lever-arm-optimized anchor placement (v5), and a fast small-seed
  factorial screen isolating pocket-width vs. contacts (P1-P4). Best case (P1
  seed16) hit 4.46A CDK2-rmsd but was a one-off seed-specific anomaly (also showed
  an unrelated 15.7A ligand-tail defect via RDKit substructure analysis); every
  other cell of the design space stayed in the 12-42A miss band. Comprehensive
  stage1-vs-stage2 analysis (`comprehensive_analysis.py`, 47 structures) showed the
  orientation error is already present at stage-1 and stage-2's soft template
  guidance neither reliably fixes nor worsens it -- pointing at stage-1 pose
  generation/CULTsum selection as the root cause, not stage-2 itself.
- 2026-07-13: **Decisive diagnostic: true-template test (job 16895).** Built a
  stage-2 template DIRECTLY from 23SR ground-truth coordinates (`true_template.cif`,
  CRBN auth46-427 + CDK2, protein-only, no ligand) instead of a Boltz stage-1
  output, and ran stage-2 (B11, all 5 seeds) against it, skipping stage-1 entirely.
  Result: **CDK2 CA RMSD 2.38-3.06A across all 5 seeds** -- matching the established
  VAV1/9NFR benchmark accuracy (~2.9A) and far better than any prior attempt.
  **Conclusion: stage-2's templated re-docking is fundamentally sound; every prior
  failure (v1-v5, P1-P4) was 100% attributable to stage-1 never producing (or
  CULTsum never selecting) an accurate enough template.**
- 2026-07-13: **Full 32-compound batch via true-template + ligand-swap (user
  proposal, executed same session): "template을 주고 ligand만 바꿔서 만들면 되는거
  아냐?"** Since `true_template.cif` is protein-only, the SAME B11-derived template
  was reused for all 32 CSV compounds, swapping only the ligand SMILES per
  compound via `pipeline.build_stage2_yaml`, stage-1 skipped entirely for all 32.
  Rationale: all 32 are SAR analogs sharing the glutarimide-CRBN warhead: the
  degron engagement (and thus the overall complex orientation) is expected to be
  common across the series; this is a structural self-consistency check under a
  shared-binding-mode assumption, not an independent ab initio prediction per
  analog, and makes no efficacy/potency claim (per Non-Goals).
  - Submitted as SLURM array job 16897 (0-31%16, P3 config: wide pocket, zero
    explicit contacts, full 5-seed stage-2 panel). 29/32 succeeded first pass; 3
    (B2, B4, B13) failed on transient CUDA OOM (confirmed via UUID-level GPU check
    to be isolated per-node GPU contention from other cluster tenants, NOT a
    pipeline/config bug -- concurrent tasks on the same node were correctly bound
    to distinct physical GPUs at ~8.6/80GB each). Retried individually as job
    16929 (array 0-2) -- all 3 succeeded. **Final: 32/32 compounds, 5/5 seeds each,
    zero mechanical failures.**
  - Batch structural analysis (`batch_analysis.py`, vectorized clash-distance calc
    after an initial pure-Python nested-loop version proved far too slow --
    160 structures at ~0.5s/structure once fixed): **per-compound mean CDK2 CA
    RMSD ranges 2.54-2.79A across all 32 compounds (median 2.67A, mean 2.68A) --
    0/32 compounds exceed 5A.** Generic SMARTS-based glutarimide-ring centroid
    check (not tied to one compound's atom indices, verified to match all 32
    SMILES exactly once) confirms CRBN-warhead anchoring holds series-wide: mean
    0.61-0.84A per compound, essentially identical to B11's own 0.65A.
  - **This resolves Done-When #2 (self-consistency vs. 23SR) for the full
    compound set, via a different route than originally scoped (fixed true
    template + ligand swap, not a per-compound CULTsum-selected stage-1 template)
    -- PASS, with the explicit caveat that this validates the SHARED-orientation
    hypothesis for the SAR series rather than independently re-deriving each
    analog's pose from scratch.** Full per-seed/per-compound table in
    `full_batch_results.txt` (scratchpad).
- 2026-07-14: **Diffusion-trajectory mechanism check (user curiosity, GPU
  cheap).** Monkeypatched (this-process-only, zero rootfs edits) the vanilla
  `diffusionv2.AtomDiffusion.sample` loop our production runs actually use
  (predict_core's own `enable_trajectory_recording` plumbing only fires on a
  DIFFERENT, interface-steering code path we don't use) to dump the model's
  per-step denoised-coordinate estimate at every one of the 50 sampling steps
  (B11, seed16). Result: CRBN-fit RMSD is flat (~0.79-0.85A) from step 0 --
  the template's influence is present in the model's structure estimate from
  the noisiest possible input, not something that gradually emerges; CDK2
  placement is already in the right basin by step 0 and locks to exactly
  2.64A once sigma drops below ~1 (step ~35+). Confirms "soft guidance, not
  hard copy" mechanistically, not just from the final-RMSD>0 inference.
  Artifacts: `/home/ubuntu/cdk2_23sr_diffusion_trajectory/` (plots +
  `trajectory_driver.py` + per-step analysis scripts).
- 2026-07-14: **Generalization sweep -- does true-template+ligand-swap work
  for OTHER targets? Tested on 7 targets total (CDK2 + 6 new).** Built the
  SAME true-template-from-ground-truth method for VAV1/9NFR (own production
  target, glue A1BYX), IKZF1/6H0F (lenalidomide), NEK7/9NFQ (glue A1BX6),
  NEK7/9H59 (glue A1ISP, SAME target as 9NFQ but a DIFFERENT crystal with a
  different CRBN gap), CK1a/9OTY, PRDM1/9Q33 -- sequences/offsets pulled
  directly from each target's own ground-truth CIF (all already present in
  `/home/ubuntu/AIGENFold/examples/heldout/`, a pre-existing 40+-structure
  set from the fragmap/heldout-placement work), ligand SMILES fetched from
  RCSB's chemcomp REST API, CRBN offset=45 re-verified per structure
  (residue-identity spot check; PRDM1/9Q33 needed the same CRBN_AUTH_LO=46
  tag-filter fix as the original CDK2 true-template bug -- a single leaked
  auth=45 residue caused the same "Alignment mismatch!" gemmi error).
  **Initial hypothesis ("CRBN template must be gap-free") REFUTED**:
  IKZF1/6H0F has a perfectly gap-free CRBN (374/397, more complete than
  VAV1's 353/397) yet gave the WORST result of all 7 (CRBN-fit 11.26A,
  target 18.78A, confirmed non-seed-specific across all 5 standard seeds,
  std=0.04A on CRBN-fit -- systematic, not bad luck). **Real driver found:
  target (neo-substrate) domain SIZE**, near-perfectly monotonic with final
  RMSD across all 7: CDK2(298aa)=2.64A, NEK7/9NFQ(281aa)=4.60A,
  NEK7/9H59(280aa)=4.28A, CK1a/9OTY(261aa)=6.56A, PRDM1/9Q33(160aa)=11.64A,
  VAV1/9NFR(58aa)=16.77A, IKZF1/6H0F(32aa)=18.78A. The NEK7 twin-structure
  comparison is the cleanest evidence: SAME target, two different crystals
  with different CRBN gaps (9NFQ gap near C-term, 9H59 gap at the classic
  209-219 loop) -> nearly IDENTICAL result (4.60 vs 4.28A) -- gap location/
  presence barely matters when target identity/size is held fixed.
  Mechanistic read: stage-2 has ZERO explicit target-position constraint
  (only a ligand-E3 pocket constraint, confirmed earlier this contract) --
  a large folded domain gets sterically "boxed in" near the ligand pocket by
  its own bulk, a small domain (ZnF, SH3) has much more rotational freedom
  and doesn't reliably lock in even with a perfect template. Practical
  triage rule going forward: check target domain size (>~200 resolved
  residues = good candidate) before CRBN template completeness when deciding
  whether to use this shortcut for a new target. Artifacts:
  `/home/ubuntu/cdk2_23sr_diffusion_trajectory/{diffusion_trajectory_compare3.png,
  target_size_correlation.png}` + `survey_targets.py`, `build_new_targets.py`,
  `analyze_new_targets.py` (scratchpad).
- 2026-07-14: **Independent structural validation via B11's alanine-scan
  mutant panel (SI CSV, 19 positions: 8 CDK2 + 11 CRBN; only B10/B11/B12 have
  any mutant EC50s, only B11 has the FULL panel).** Non-circular check using
  real mutagenesis data (not just geometric RMSD): computed each mutated
  residue's min heavy-atom distance to the partner chain, in both the 23SR
  ground truth and our predicted B11 structures (5-seed average). Found and
  fixed a numbering-frame bug first (the unified-convention reference file
  `00_reference_23SR.pdb` preserves RAW AUTH numbers for its CRBN chain,
  while predicted structures use LOCAL (auth-45) numbers -- coincidentally
  invisible on the CDK2 side since target offset=0 there). After the fix,
  predicted and GT interface distances agree closely (e.g. N351A: GT 3.33A
  vs predicted 2.99A; H353A: 2.72 vs 3.03A), and both show the expected
  negative correlation between EC50 fold-change and interface distance
  (Spearman -0.39 GT, -0.21 predicted -- critical mutants sit closer to the
  interface). Bonus series-wide check: E57 (one of the strongest hotspots,
  L54A/E57A both >72x EC50 shift) sits at a near-identical CRBN distance
  (2.59-3.09A, std=0.11A) across ALL 32 predicted compounds, not just B11 --
  the shared-binding-mode assumption underlying the whole 32-compound batch
  holds up against independent experimental data, not just internal RMSD
  consistency. Artifacts: `/home/ubuntu/cdk2_23sr_diffusion_trajectory/
  {validate_mutant_panel.py, mutant_panel_validation_results.txt}`.
- 2026-07-14 (continued, same day): **8th target (IKZF3/9UUM) + DDB1-augmented
  template test + full IKZF1 root-cause investigation.**
  - **IKZF3/9UUM added to the sweep**: Aiolos ZF2-ZF3 tandem zinc finger
    (55aa, glue=mezigdomide/CCD=QFC, fetched+verified via RCSB chemcomp REST),
    CRBN chain C in 9UUM is gap-free (380/397 after the CRBN_AUTH_LO=46 tag
    filter). Result: CRBN-fit 1.55A (good) but target RMSD 22.92A -- WORST of
    all 8 targets despite gap-free CRBN. Further disproves "gap-free predicts
    success"; tandem-ZnF may be even floppier than single-ZnF (IKZF1) despite
    nominally more residues, suggesting domain RIGIDITY matters alongside raw
    size.
  - **DDB1-augmented template (user-proposed)**: stage-2's only constraint is
    a ligand-E3 pocket contact (established earlier this contract) -- no
    target-position constraint at all. Hand-built a 3-chain (DDB1+CRBN+target)
    YAML bypassing `pipeline.build_stage2_yaml` (2-protein-chain limit),
    sourcing DDB1's real coordinates from each target's own ground-truth CIF.
    DDB1_SEQ = full UniProt Q16531 (1140aa), offset=0 verified (0/1119
    mismatches vs 9NFR's own DDB1 chain). Tested on the 3 worst 2-chain
    performers: VAV1 16.77->8.97A (IMPROVED), IKZF3 22.92->2.26A (DRAMATIC,
    worst-of-8 to best-of-8), IKZF1 18.78->18.99A (NO CHANGE). Verified
    NOT seed-luck: full 5-seed panel for all 3 (VAV1 std=0.07A, IKZF3
    std=0.18A, IKZF1 std=0.17A on target RMSD; CRBN-fit std<=0.05A each) --
    user explicitly asked to check this given the dramatic single-seed
    swings, confirmed robust.
  - **IKZF1/6H0F root-cause investigation** (user: "파고들어", "다른 예측을
    잘 못한 구조들도 그 이유야?"): systematically ruled out three candidate
    causes before finding the real one. (1) Wrong ligand: 6H0F's real HETATM
    is Y70=S-Pomalidomide, not lenalidomide (used by mistake, sourced from an
    older contract's notes without re-verifying against THIS structure) --
    fixed via RCSB chemcomp REST, re-ran, ZERO change (CRBNfit/targetRMSD
    identical to 2 decimal places). (2) Altloc duplicate atoms: 6H0F chain B
    has 2 disordered residues (HIS378 full A/B altloc conformers, occ
    0.64/0.36) -- copying both altlocs when building the template created
    residues with duplicate atom names; added an altloc filter (keep
    blank/'\x00'/'A' only), re-ran -- output was BYTE-IDENTICAL (md5 match)
    to the unfixed version, meaning gemmi/boltz already dedupes internally;
    not the cause. (3) Per-residue error breakdown (the actual diagnostic
    that cracked it): CRBN's N-domain (Lon-N+HBD, local 24-263, n=240)
    self-fits at 1.52A after its OWN Kabsch fit; C-domain (CULT, local
    264-397, n=134, WHERE THE LIGAND POCKET RESIDUES LIVE) self-fits at
    4.82A -- each domain individually is fine, but the RELATIVE ROTATION
    between the two domains' independent best-fit frames is 83.4 degrees.
    This is an inter-domain hinge misassignment, not a folding failure --
    naturally explains why the whole-chain rigid Kabsch fit gave the
    misleading aggregate 11.2A. DDB1 does not touch this (hinge 83.4->83.8
    deg with DDB1 present, statistically unchanged). Ruled out crystal-copy
    heterogeneity: 6H0F has 4 copies in its asymmetric unit (chains
    A/B/C, D/E/F, G/H/I, J/K/L); pairwise hinge angle between copies is only
    1.8-2.6 deg -- the crystal itself is NOT flexible/heterogeneous here.
    **Decisive test**: computed the same N-vs-C-domain hinge angle for ALL 8
    ground-truth structures, relative to a common CDK2/23SR reference frame.
    7/8 (CDK2, VAV1, IKZF3, NEK7x2 both crystals, CK1a, PRDM1) agree with
    each other to within 1.5-11.8 degrees -- effectively ONE shared "common"
    CRBN hinge conformation across every other target tested. ONLY 6H0F
    diverges, at 93.4 degrees from that common conformation -- a genuine,
    reproducible (consistent across all 4 of its own asymmetric-unit copies)
    but RARE structural outlier. The model's OWN prediction for IKZF1/6H0F
    sits only 3.0 degrees from the common conformation -- i.e. the model
    effectively ignored 6H0F's unusual true template and reverted to its
    learned "typical CRBN fold" prior instead. This is the SAME phenomenon
    this exact slice already documented once before, in the pre-latent-lane
    DDB1/assembly-closure work on VAV1-CRBN geometry ("Boltz's prior for the
    novel VAV1-CRBN geometry overrides the correction every step," see this
    slice's status baton "Prior lane" section) -- independently reconfirmed
    here for a structurally unrelated target (CRBN's own internal hinge
    rather than an external target-protein orientation), which strengthens
    confidence this is a real, recurring model limitation rather than a
    one-off fluke.
  - **User follow-up ("데이터 부족 문제 아니야?")**: distinguished the two
    failure modes explicitly, since they have different remedies and
    different relationships to training data. The 7/8 size/wobble failures
    are NOT a training-data problem -- proven by the fact that giving the
    SAME, already-trained, unmodified model MORE INFERENCE-TIME CONTEXT
    (DDB1 coordinates) fixed them; the underlying task (stage-2's
    pocket-only constraint) is genuinely underdetermined for small domains
    regardless of how well-trained the model is. The IKZF1 prior-override
    failure is more genuinely data/design-related: it reflects the TRUE
    prevalence skew of CRBN conformations in whatever the model was trained
    on (a "properly trained" model on the same real-world-skewed
    distribution would still learn a peaked prior for the common fold), and
    is entangled with an algorithmic/design choice (how strongly template
    conditioning is weighted against the learned prior -- currently soft,
    not hard-enforced). Neither is fixable by "just add more data" as a
    blanket fix; the first needs more INPUT information (not more training),
    the second needs either rebalanced training-data representation of rare
    conformations or a harder template-enforcement mechanism (a training-
    objective/architecture decision).
  - **CONCLUSION on the full 8-target sweep**: two independent, distinct
    failure modes identified and mechanistically characterized. (A)
    Constraint-completeness gap (7/8 targets: CDK2 unaffected since large;
    VAV1/IKZF3/PRDM1/CK1a/NEK7x2 all show the same "small target floats near
    an otherwise-correct CRBN" signature) -- FIXABLE at inference time via
    DDB1-augmented templates, no retraining, now validated on 3 targets
    across 5 seeds each. (B) Prior-dominance gap (1/8, IKZF1/6H0F only):
    CRBN's own internal domain hinge reverts to the model's learned "common"
    conformation when the true template represents a rare outlier state --
    NOT fixable by adding external context (DDB1 tested, no effect); would
    need either training-data rebalancing or harder template enforcement.
    Artifacts: `/home/ubuntu/cdk2_23sr_diffusion_trajectory/` (all analysis
    scripts: `build_ddb1_templates.py`, `analyze_ddb1_results.py`,
    `analyze_ddb1_multiseed.py`, hinge-angle diagnostics run inline) + kfs2
    mirror `true_template_ddb1_*.cif`, `true_template_IKZF1_6H0F_v3.cif`,
    `work_traj/{VAV1_9NFR_DDB1,IKZF1_6H0F_DDB1,IKZF1_6H0F_DDB1_v2,
    IKZF3_9UUM_DDB1,IKZF1_6H0F_v2,IKZF1_6H0F_v3}/`.
  - **Session paused here on user request** ("일단 여기까지"). OPEN DECISIONS
    for next session: (a) adopt true-template (+ DDB1-augmented variant) into
    the canonical `api/ternary_config.py`/`pipeline.py` as a documented,
    reusable capability -- now backed by an 8-target sweep and mechanistic
    understanding of both failure modes, a much stronger case than at the
    32-compound-batch stage; (b) whether the IKZF1 prior-override finding
    warrants a dedicated follow-up (e.g. a harder-template-enforcement
    pipeline feature) or should stand as a documented, known limitation; (c)
    whether/how to write up the full arc (structure pilot -> diffusion
    mechanism -> 8-target generalization -> DDB1 rescue -> prior-override
    root cause) formally.
