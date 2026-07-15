# Contract — learned chirality-aware generation (Stage B)

- **Status**: approved
- **Slice**: vav1-ubq (engine change coordinated with aigen-fold-core)
- **Requested**: 2026-06-22
- **Approved by**: sunghoon.kim (2026-06-29, chat: "두 개 병렬 진행")
- **Note (2026-06-29)**: Approved to start Stage 0 (corpus assembly + leakage check +
  base-model baseline, zero-GPU) in parallel with the productive-geometry contract.
  Stage 2 (finetune) stays a hard GPU GATE. The host-tree architecture wiring (Stage 1)
  is BLOCKED on coordinating with aigen-fold-core's live session (uncommitted
  `boltz_extension` WIP) — do NOT touch their dirty engine tree; land the chiral-wire
  host port only after that WIP is committed.
- **Predecessor**: `.agent/contracts/fksfold-core-chirality-aware-generation-20260621.md`
  (Stage A = inference-time chiral steering: SUCCESS at the CIP-label level but a
  rigorously-reached **geometric ceiling** — a late, local stereocenter flip cannot
  re-pose a ligand the model laid down R-optimal; multi-seed clean S = 0/16).

## Goal (one sentence)
Make the AIGEN-Fold (Boltz-2 fork) generator **natively respect ligand stereochemistry from
the start of diffusion** — by wiring the already-computed `ref_chirality` feature into the
model and **light-finetuning on a broad chiral-ligand corpus** — so the generator (the product,
upstream of all scoring) produces clean, geometry-valid, correct-handed ternary poses **at scale
and generalizably**, fixing a diagnosed core defect instead of patching it per-compound downstream.

## Why this shape
Diagnosis (2 multi-agent workflows + native experiments, high confidence): the model is NOT
architecture-blind to chirality — isomeric SMILES is preserved end-to-end and handedness reaches
the encoder via **signed `ref_pos`**. But `ref_chirality` (computed in `featurizerv2.py:1227-1232`,
emitted :1549) is **consumed by ZERO model code**, and Stage A's late steering hits a geometric
ceiling. Clean, generalizable correct-handed *generation* therefore requires chirality to be
**learned from the start** (feature wired into the forward pass + a light finetune), not steered
in at the end. Generation is the higher-leverage investment because it is the product, it is
upstream (garbage-in/garbage-out for any scorer), and it scales to libraries where MD cannot.

## Scope (this contract)
- **Architecture wiring (engine, host-tree)**: consume `ref_chirality` (and/or a signed-improper
  encoding) in the model forward pass so it conditions the denoiser, behind a **flag (default off
  → base behavior byte-identical)**. Touches `src/boltz` featurizer/model + `boltz_extension`.
- **Training corpus (zero-GPU data work)**: assemble a **broad chiral protein–ligand corpus** from
  PDB (ligands with ≥1 defined stereocenter), with a **leakage-safe held-out split**. The VAV1
  glues (g1–g6) and the g3/g4 enantiomer pair are **held OUT of training** so the g3/g4 test is a
  genuine generalization check, not memorization.
- **Light finetune (GPU)**: LoRA / few-epoch finetune on top of the **base checkpoint** with the
  chirality feature live, producing a **new, separately-named checkpoint** (base untouched). Native
  un-containerized infra (`boltz_native_20260621/rootfs`, kim `--qos=batch`/`normal`, idle A100s);
  MD job 8098 **untouched**. Direct campaign (no separate staged user-go gates) but with a standard
  in-run smoke (training loss decreases + a single held-out pair flips on overfit) as ML hygiene.
- **Evaluation**: (a) g3/g4 generation yield/quality; (b) held-out chirality-preservation rate vs
  the pre-Stage-B base-model baseline on the same held-out set.

## Out of scope (deferred / separate)
- **Activity / potency / SAR prediction** — placement ≠ potency (established, fragmap charter).
  Whether correct chirality predicts the >100× SAR is the **MD/ΔΔG oracle = Stage D**, separate.
- **Stage A inference steering** — done; ceiling recorded in the predecessor contract.
- **Full retrain from scratch** — only a light finetune on top of the base checkpoint.
- **Productive-geometry / ubiquitination competence** (integrative-CRL, MD 8098) — separate.
- **Committing the Stage-A chiral-wire diff to host tree** — its own deferred cleanup.

## Constraints (resource budget)
- **GPU only** via `sudo -u kim sbatch/srun --qos=batch` (≤4 GPU) or `--qos=normal` on idle nodes;
  **do NOT touch MD 8098**. Finetune budget **estimate ≤ ~200 GPU-hr** (LoRA/light, mostly-frozen
  backbone) — refine in /write-plan; flag if a run trends past it. Data assembly is zero-GPU.
- **Base checkpoint immutable**: the finetune writes a NEW checkpoint; base + campaign flags stay
  byte-faithful so the flag-off path is unchanged.
- **Engine entanglement**: the host-tree architecture change overlaps aigen-fold-core's uncommitted
  `boltz_extension` WIP — coordinate with that owner; land the change **flag-gated** and isolated.
- All writes under **`/mnt/kfs2`** (mergerfs routes ubuntu's /mnt/data to the full kfs5).
- **No data leakage**: held-out chiral ligands + VAV1 glues excluded from the training corpus
  (verified by an ID/InChIKey disjointness check before any GPU spend).

## Triggers matched
GPU/SLURM submission (finetune) · new model-checkpoint artifact · multi-file engine architecture
change (`src/boltz` + `boltz_extension`) · shared-storage writes (`/mnt/kfs2`) · cross-slice
coordination (aigen-fold-core engine). This is exactly the gate this contract exists for.

## Success criteria (Done When)
1. **g3/g4 enantiomer pair (held out of training)** — generated multi-seed with the chirality
   feature live: input-S g3 → **output S in ≥14/16 seeds**, each **intra-ligand min-heavy ≥1.2 Å**
   (geometric ceiling broken — Stage A was 0/16), **CIP preserved**, and **interface not degraded**
   (iptm within a small pre-registered margin of base); g4 control stays R.
   - Verify: `score_ensemble_cip.py` over the g3/g4 outputs → S-yield + intra-min-heavy + iptm table.
2. **Held-out generalization** — on a curated held-out chiral-ligand set (NOT in training), the
   output-preserves-input-stereochemistry rate **materially exceeds the base-model baseline** on the
   same set, by a **pre-registered threshold** (set in /write-plan against the measured baseline).
   - Verify: a chirality-preservation eval script over base-vs-Stage-B generations on the held-out set.
3. **Flag-off regression-free**: with the feature flag off, generation output is **byte-identical**
   to the current base behavior (md5 match on a fixed seed/case).
4. **Result doc** committed (diagnosis recap, baseline, the two yield numbers, honest caveats:
   placement≠potency, generalization scope, GPU spent); contract + plan marked done.

## Risks
- **Overfit to the small VAV1-relevant region** → fails held-out generalization (mitigate: broad
  corpus + leakage-safe held-out; baseline-relative threshold catches memorization).
- **Light finetune insufficient** to overcome the R-optimal prior (mitigate: in-run overfit smoke
  proves learnability before the full run; escalate epochs/unfreeze only if smoke passes but full lags).
- **Engine change destabilizes base behavior** (mitigate: flag-gated, default off, byte-identical
  flag-off regression test = criterion 3).
- **Corpus assembly cost/quality** (zero-GPU but real effort; stereocenter perception must be
  template-correct, not coordinate-reperceived — reuse the Stage 0 `lig_identity.py` lesson).
- **Budget overrun** past ~200 GPU-hr (mitigate: checkpoint/eval mid-run; the contract flags it).

## Rollback
- Code change is **flag-gated (default off)** → revert = flag off, base behavior restored; or
  `git revert` the engine commit. Finetuned checkpoint is a **separate named artifact** — delete it,
  base checkpoint untouched. All training/eval artifacts under `/mnt/kfs2/...` → delete the dir.
- No effect on MD 8098, no effect on committed base-generation behavior, no checkpoint overwrite.

## Notes
Pending /write-plan decomposition: (Stage 0) corpus assembly + leakage check + base-model baseline
measurement [zero-GPU]; (Stage 1) architecture wiring + flag-off byte-identical test [zero/low-GPU];
(Stage 2) light finetune w/ in-run smoke [GPU GATE]; (Stage 3) g3/g4 + held-out evaluation; (Stage 4)
result doc + baton. The MD/ΔΔG activity oracle (Stage D) is a separate contract.
