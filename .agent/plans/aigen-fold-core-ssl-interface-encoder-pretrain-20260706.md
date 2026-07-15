---
contract: .agent/contracts/aigen-fold-core-ssl-interface-encoder-pretrain-20260706.md
slice: aigen-fold-core
status: done
total_tasks: 8
estimated_total_min: 115
---

# Plan — self-supervised pretraining of the interface-latent encoder

Work dir: `.agent/scratch/vav1_degrad_head/phase6/` (phase5 is taken by the
MoSIR pilot). Reuses: `phase3/model.py` (BlockPMA-X `TokenProj`+`GroupPool`),
`phase3/data.py` (CV/labels), `phase2/rank_harness.py` (CV_SCHEMES, bootstrap),
and the PROVEN binary-latent extraction recipe at
`/mnt/kfs2/data/users/ubuntu/vav1_crbn_binary_latent_20260706/` (`binary_cell.sh`
+ `arr_binlat.sbatch`, CRBN sequence `crbn_chain_A.csv`, 14-residue pocket
constraint, `BOLTZ_DUMP_LATENT` env hook -> dense `[N,N,128]` `*.trunk.npz`).
Baselines to beat: v1.1 pooling+pairwise champion cross-scaffold 0.558
(`phase4/results_v3.md`); no-pretrain BlockPMA-X cross-scaffold 0.178
(`phase3/encoder_results.md`).

## Task 1: ChEMBL CRBN corpus puller
- **Status**: done (2026-07-07) — 299 targets enumerated, 4,223 unique CRBN-tagged
  molecules pulled; review found ~half lacked the canonical glutarimide/phthalimide
  warhead (e.g. L-DOPA) → user chose warhead-confirmed subset only. Final
  `phase6/crbn_corpus_raw.csv` = 2,127 rows (has_warhead=True), audit trail in
  `phase6/crbn_corpus_all_unfiltered.csv` (4,223 rows).
- **Prereq tasks**: none
- **Files touched**: phase6/pull_chembl_crbn.py
- **Change shape**: hit the public ChEMBL REST API directly (confirmed
  reachable: `curl https://www.ebi.ac.uk/chembl/api/data/activity.json` ->
  200) for every CRBN-tagged target (target_search by `gene_symbol=CRBN`,
  `organism=Homo sapiens` -> ~299 targets incl. `CHEMBL3763008` single-protein
  and ~280 `Cereblon/<neosubstrate>` PPI/complex targets). Paginate
  `activity.json?target_chembl_id=...`, collect `canonical_smiles` +
  `molecule_chembl_id`, dedup by `molecule_chembl_id`, drop non-drug-like
  entries (MW<150 or >900, or in a small denylist of known solvents/controls
  e.g. DIMETHYL SULFONE), canonicalize with RDKit. Write one CSV:
  `molecule_chembl_id,canonical_smiles,n_source_targets`.
- **Verification**: `python3 pull_chembl_crbn.py --dry-run-count` -> prints
  per-target activity totals + running unique-molecule count; then full run
  writes `phase6/crbn_corpus_raw.csv`, printed row count should land in the
  1,000-5,000 range per the contract's scouted estimate (report the actual
  number, do not force it into that range).
- **Estimated time**: 15 min
- **Rollback**: rm phase6/pull_chembl_crbn.py phase6/crbn_corpus_raw.csv

## Task 2: Boltz input builder for the pretrain corpus
- **Status**: done (2026-07-07) — `phase6/build_pretrain_inputs.py`; kfs2 bundle
  `vav1_crbn_pretrain_corpus_20260706/` built (2,127 YAMLs = compounds.txt lines
  = corpus rows, CRBN seq/pocket verified byte-identical to template, array
  width 48 (~44.3 compounds/task), 777 perms matching precedent). No sbatch run.
- **Prereq tasks**: 1
- **Files touched**: phase6/build_pretrain_inputs.py, new kfs2 bundle
  `vav1_crbn_pretrain_corpus_20260706/{input/,compounds.txt,binary_cell.sh,
  arr_binlat.sbatch,crbn_chain_A.csv}` (ubuntu-owned, chmod 777 for kim writes)
- **Change shape**: for every row in `crbn_corpus_raw.csv`, write a binary
  YAML byte-identical in structure to
  `vav1_crbn_binary_latent_20260706/input/*.yaml` (protein A = same CRBN
  sequence + msa csv, ligand B = this row's SMILES, same 14-residue pocket
  constraint), named `P<molecule_chembl_id>.yaml` (P-prefix to disambiguate
  from the existing V/G namespace). Copy `crbn_chain_A.csv` into the new
  bundle unchanged. Copy `binary_cell.sh` + `arr_binlat.sbatch` with only the
  `WORK=` path edited to point at the new bundle; widen `--array` from 0-7 to
  a width picked from the actual corpus size (target ~30-60 compounds per
  array task, same per-task throughput as job 15583). Write `compounds.txt`
  (one `P<id>` per line).
- **Verification**: `python3 build_pretrain_inputs.py --smoke` -> writes 5
  sample YAMLs, prints diff against the job-15583 template confirming only
  `sequences[1].ligand.smiles` and the file name change; then full run
  reports total YAML count == corpus row count.
- **Estimated time**: 12 min
- **Rollback**: `rm -rf /mnt/kfs2/data/users/ubuntu/vav1_crbn_pretrain_corpus_20260706`

## Task 3: Submit + verify latent extraction ⛔ GPU gate
- **Status**: done (2026-07-07) — smoke job 16177 COMPLETED (3/3), full job
  16178 (kim, `--array=0-47`, `--dependency=afterok:16177`) COMPLETED.
  2,089/2,127 trunk.npz landed (99.9%): 37 failures = 1 YAML-escaping bug in
  `build_pretrain_inputs.py` (SMILES backslash not escaped, Task 2 defect
  found post-hoc) + 36 Boltz-internal RDKit `AddHs(None)` parse failures
  (not chased, low-pri) + 1 additional file (`PCHEMBL182442`) that landed on
  disk but is unreadable at the storage layer (hangs even under raw `dd`,
  found while running Task 4-adjacent pooling — see `phase6/extraction_status.md`).
- **Prereq tasks**: 2
- **Files touched**: none (submits the array sbatch built in Task 2); a
  status note in phase6/extraction_status.md
- **Change shape**: smoke the cell script on 2-3 compounds first (same
  pattern as every prior SLURM launch this session), then submit the full
  array sbatch as kim `--qos=normal`. STOP and get explicit user go-ahead
  before the full-array submission even though the contract already covers
  the SLURM trigger (per standing /execute-plan practice on this slice).
- **Verification**: `find <bundle>/latent -name "*trunk.npz" | wc -l` equals
  the corpus row count, 0 FAIL lines in `<bundle>/logs/lat_*.log`.
- **Estimated time**: 10 min submit+verify (compute hours separate)
- **Rollback**: `sudo -u kim scancel <jobid>; rm -rf <bundle>/latent`

## Task 4: Raw LP-token extractor (pretrain format)
- **Status**: done (2026-07-07) — `phase6/{_extract_one.py,build_pretrain_pairs.py}`,
  per-file subprocess + 20s timeout + 16-way parallel (avoids the NFS-hang
  risk found in Task 3 cleanup). 2,089/2,090 available npz succeeded (only
  the known-unreadable PCHEMBL182442 failed, cleanly at the 20s timeout, no
  hang). `phase6/pretrain_pairs/P<id>.npz` (raw `lp_tokens` [n_lig_atoms*14,128])
  + `phase6/pretrain_pairs_manifest.csv`. Full run: 62s wall time.
- **Prereq tasks**: 3
- **Files touched**: phase6/build_pretrain_pairs.py
- **Change shape**: adapt `phase4/poolfeats_binary_lp.py`'s slicing
  (`z[np.ix_(lig, CRBN_POCKET)]`, `LIG_OFF=397`, same 14-residue
  `CRBN_POCKET` indices) but instead of collapsing to mean/std/median,
  write the RAW per-compound LP token cloud `[n_lig_atoms x 14, 128]` to
  `phase6/pretrain_pairs/P<id>.npz` (one array `lp_tokens`), plus a
  manifest.csv (id, n_tokens, source SMILES).
- **Verification**: `python3 build_pretrain_pairs.py --smoke` -> 5 compounds
  written, token-count sanity (matches `n_lig_atoms * 14` for each); full run
  reports matched/total against Task 3's npz count.
- **Estimated time**: 10 min
- **Rollback**: rm -rf phase6/pretrain_pairs phase6/build_pretrain_pairs.py

## Task 5: LP sub-encoder + self-supervised pretext head
- **Status**: done (2026-07-07) — `phase6/pretrain_model.py`, 12,664 params,
  smoke + edge-case stress test passed, code-reviewed APPROVE_WITH_NITS.
- **Prereq tasks**: none (parallel to 1-4; only needs the architecture, not
  the data)
- **Files touched**: phase6/pretrain_model.py
- **Change shape**: extract `TokenProj(128, 128, r=24, rank=4, n_group=3)` +
  `GroupPool(r=24, h=2, G=1)` from `phase3/model.py` as a standalone
  `LPSubEncoder` (single group, no pose-cond channel since the pretrain
  corpus has none -- `has_cf` always 0). Add a pretext head: mask a random
  30% of tokens per compound, feed the rest through the pool, predict the
  MASKED tokens' mean-128 target via a small linear head (masked-mean
  reconstruction, MSE loss) -- no label touches this, purely structural.
- **Verification**: `python3 pretrain_model.py --smoke` -> forward on a
  synthetic batch returns a reconstruction loss (finite, > 0); param count
  printed (expect similar order to BlockPMA-X's 34k, likely smaller since
  single-block).
- **Estimated time**: 15 min
- **Rollback**: rm phase6/pretrain_model.py

## Task 6: Pretraining loop
- **Status**: done (2026-07-07) — `phase6/pretrain_train.py`, CPU-only, AdamW,
  fixed-mask-seed val loss (fork_rng, isolates weight improvement from mask
  noise), checkpoints `model.encoder.state_dict()` on best val. Full run
  (2,089 compounds, 1880/209 train/val, 150-epoch cap, patience=10 never
  triggered): val loss 294.0 -> 1.596 monotonically, no NaN, 300.7s wall
  time. Checkpoint verified: `proj.main.weight` shape (24,128) as required
  for Task 7's transplant into `phase3.model.Encoder.pair.main`.
- **Prereq tasks**: 4, 5
- **Files touched**: phase6/pretrain_train.py
- **Change shape**: AdamW training loop over `phase6/pretrain_pairs/*.npz`
  (train/val split 90/10 by compound, no scaffold info needed -- this is
  unsupervised), early stop on val reconstruction loss, save
  `phase6/pretrain_ckpt.pt` (the `LPSubEncoder` state dict only).
- **Verification**: `python3 pretrain_train.py --epochs 5 --smoke` -> val
  loss decreases epoch over epoch, checkpoint file written, no NaN.
- **Estimated time**: 15 min dev + background training time (CPU/1-GPU,
  small model -- expect minutes given corpus size, not hours)
- **Rollback**: rm phase6/pretrain_train.py phase6/pretrain_ckpt.pt

## Task 7: Fine-tune wiring on VAV1 388
- **Status**: done (2026-07-07) — `phase3/train.py` gets an additive
  `load_lp_pretrain()` + `--init-lp-from` flag, narrowly scoped to
  `proj.main/ln -> model.pair.main/ln` only (dn/up/emb/pool.q untouched by
  design, verified via `phase6/finetune_eval.py` 3/3 PASS). Default no-flag
  path confirmed byte-identical (two runs, `DataFrame.equals`=True). Fold-0
  single-seed sanity: rho +0.204 (no-init) vs +0.200 (pretrain-init) — a
  wash at this tiny scale, NOT the real comparison (Task 8).
- **Prereq tasks**: 6
- **Files touched**: phase3/train.py (additive `--init-lp-from` flag only;
  no change to existing no-pretrain code path), phase6/finetune_eval.py
- **Change shape**: add an optional flag to `phase3/train.py` that, if set,
  loads `phase6/pretrain_ckpt.pt` into the existing `Encoder.pair`
  `TokenProj` weights (channel-compatible: both are 128-dim trunk-z ->
  r=24) before the normal VAV1-388 training loop runs unchanged. Then run
  the existing scaffold + large-scaffold OOF protocol
  (`phase3/eval_encoder.py`-style) with vs without the pretrain init.
- **Verification**: `python3 phase3/train.py --fold 0 --init-lp-from
  ../phase6/pretrain_ckpt.pt --epochs 20 --smoke` -> loads without shape
  errors, loss decreases, OOF preds written for fold 0.
- **Estimated time**: 15 min
- **Rollback**: `git diff phase3/train.py` revert (additive flag, easy to
  drop); rm phase6/finetune_eval.py

## Task 8: OOF comparison + results doc
- **Status**: done (2026-07-07) — `phase6/eval_pretrain.py` +
  `phase6/pretrain_results.md`. Real 4-run comparison (scaffold/large_scaffold
  x noinit/pretrain, seed 0, DEFAULT_HP), independently re-verified against
  the raw OOF CSVs: cross-scaffold noinit −0.098 -> pretrain +0.191, primary
  paired-bootstrap delta +0.289 CI[+0.072,+0.509] (real, CI-separated pretrain
  effect). vs historical no-pretrain BlockPMA-X (0.178): delta +0.014 CI spans
  zero (not CI-separated). vs v1.1 champion (0.558, reconstructed to 0.5584,
  independently re-verified): delta −0.361 CI[−0.544,−0.189] (clearly trails).
  **VERDICT: ESCAPE** per contract criteria — pretraining shows a real,
  well-isolated generalization effect but the 2,089-compound corpus (~5.4x
  VAV1) is 2-3 orders of magnitude too small to close the gap to v1.1. v1.1
  stays the shipped model. (Note: the earlier "zero-GPU CULTsum/confidence
  checks" mentioned in a prior version of this line were a SEPARATE
  investigation, into the rejected guide_score/semantic-object-model pivot —
  see contract Notes; they did not answer Task 8's actual question, this
  entry supersedes that mislabeling.)
- **Prereq tasks**: 7
- **Files touched**: phase6/eval_pretrain.py, phase6/pretrain_results.md
- **Change shape**: full scaffold + large-scaffold OOF Spearman with
  paired-bootstrap CI for three rows: {pretrain+finetune, no-pretrain
  BlockPMA-X (0.178 cross, from `phase3/encoder_results.md`), v1.1 pooling
  champion (0.558 cross, from `phase4/results_v3.md`)}. Write the PASS/ESCAPE
  verdict per the contract's success criteria, plus the FINAL corpus size
  actually used (Task 1's real number, for the CEO-facing honesty point).
- **Verification**: `phase6/pretrain_results.md` exists with the 3-row OOF
  table + CIs + explicit PASS/ESCAPE line.
- **Estimated time**: 10 min
- **Rollback**: rm phase6/eval_pretrain.py phase6/pretrain_results.md
