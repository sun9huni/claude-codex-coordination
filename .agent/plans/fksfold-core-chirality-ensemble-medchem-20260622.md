---
contract: .agent/contracts/fksfold-core-chirality-ensemble-medchem-20260622.md
slice: vav1-ubq
status: done
total_tasks: 8
estimated_total_min: 540
---

# Plan — chirality-resolved ternary pose ensemble for med-chem (≤10h)

288-cell generation grid (6 compounds × 6 orientations × 8 seeds) at λ=16/GW=1.0 on the native
chiral-wire infra (kim --qos=batch ≤4 GPU), then bin-by-output-CIP → geometry filter → cluster →
minimize → deliver. Native infra: `/mnt/kfs2/data/users/ubuntu/boltz_native_20260621/` (rootfs with
chiral-wire; run_native_*.sh recipes; score_center3.py; boltz_cache). Out dir:
`/mnt/kfs2/data/users/ubuntu/chirality_ensemble_20260622/`. ★T2 crosses the GPU APPROVAL GATE.
HARD ceiling 10h wall — T2 records elapsed; T5/T6 trim if lagging.

## Task 1: Ensemble generation launcher (zero-GPU prep)
- **Status**: done (run_ensemble.sh; dry-run=288 cells, 36/36 yamls present, chiral-wire confirmed; injects shared cached MSA — protein chains sequence-identical across all 6 glues)
- **Prereq tasks**: none
- **Files touched**: `/mnt/kfs2/data/users/ubuntu/chirality_ensemble_20260622/run_ensemble.sh`
- **Change shape**: clone `boltz_native_20260621/run_native_lambdascan.sh` mechanics; grid =
  COMPOUNDS{g1..g6} × ORIENT{0,p30,p45,p60,p75,unsteered} × SEEDS{7,16,42,88,123,256,314,401} (8) =
  288 cells; per cell use the matching campaign input yaml `inputs/<g>_<orient>.yaml`, λ=16,
  CHIRAL_GW=1.0, CHIRAL_BUFFER=0.20, chiral-wire rootfs, offline MSA; out → `out/<g>/<orient>_seed<s>/`;
  idempotent skip; 4-GPU rolling pool; echo a wall-clock start stamp.
- **Verification**: `bash -n run_ensemble.sh`; a `--dry-run`/echo lists exactly 288 cells with correct
  input paths; confirm all 36 `inputs/<g>_<orient>.yaml` exist (enumerate any missing).
- **Estimated time**: 5 min
- **Rollback**: `rm -rf chirality_ensemble_20260622/`

## Task 2: ★GPU GATE — run the 288-cell generation
- **Status**: RUNNING (job **8165**, kim --qos=batch, 4 GPU, host-10-0-5-232). ★TRIMMED to 4 seeds (7,16,42,88) = **144 cells** per user (7h budget; observed pace ~5.7min/cell·0.7cell/min → 288 was ~6.8h gen alone). Grid now 6 compounds × 6 orient × 4 seeds. ~3.4h gen expected. History: 8163 FAILED(kim-perms→chowned), 8164 ran 288 then cancelled for trim (4 done cells reused idempotently).
- **Prereq tasks**: 1
- **Files touched**: `chirality_ensemble_20260622/out/<g>/<orient>_seed<s>/...` + `logs/`
- **Change shape**: `sudo -u kim sbatch --qos=batch` (≤4 GPU, idle node) the launcher; monitor; do NOT
  touch MD 8098. Record wall-clock elapsed on completion. Enumerate failed cells (retry once).
- **Verification**: count `*_model_0.pdb` ≈ 288 (failures listed); elapsed recorded; ★10h-budget
  checkpoint: if generation alone > ~6h, note it and flag T5/T6 to trim representatives.
- **Estimated time**: 6 min agent (job wall ~5h; re-invoked on completion)
- **Rollback**: `scancel`; `rm -rf out/`

## Task 3: Per-pose scoring (zero-GPU)
- **Status**: done (score_ensemble_cip.py per-compound by-index CIP — no multi-center noise)
- **Prereq tasks**: 2
- **Files touched**: `chirality_ensemble_20260622/score_ensemble.py`; `out/master_scores.tsv`
- **Change shape**: per pose emit: compound, orient, seed, output_CIP (by-index score_center3.py),
  intra_ligand_min_heavy, ternary metrics (A-B/A-C/B-C contacts + min inter-chain dist + VAV1-CRBN COM),
  iptm/ligand_iptm/plddt. Robust to parse failures (NA, never crash the sweep).
- **Verification**: `wc -l out/master_scores.tsv` ≈ 289 (header+cells); spot-check g4 rows = R + clean;
  columns populated.
- **Estimated time**: 12 min
- **Rollback**: `rm score_ensemble.py out/master_scores.tsv`

## Task 4: Bin by output CIP + geometry filter (zero-GPU)
- **Status**: done (filter_bin.py → binned.tsv; g1 27S, g2 24R, g3 18S/6R, g4 24R, g5/g6 R)
- **Prereq tasks**: 3
- **Files touched**: `chirality_ensemble_20260622/filter_bin.py`; `out/binned.tsv`
- **Change shape**: bin each pose by output_CIP (S / R / none); drop MALFORMED (inter-chain clash, or
  glue not bridging both proteins, or VAV1 detached); keep mild intra-ligand strain (minimization fixes).
  Emit per-(compound,CIP) survivor counts + the filtered pose list.
- **Verification**: printed table of per-compound S/R/none counts (raw → filtered); g1/g3 show a nonzero
  S bin, g2/g4 a nonzero R bin (or an honest "0 passed" note).
- **Estimated time**: 8 min
- **Rollback**: `rm filter_bin.py out/binned.tsv`

## Task 5: Cluster → diverse representatives (zero-GPU)
- **Status**: done (cluster_reps.py → 18 reps; chemA diverse 4-6, chemB tight 1)
- **Prereq tasks**: 4
- **Files touched**: `chirality_ensemble_20260622/cluster_reps.py`; `out/representatives.tsv`
- **Change shape**: per (compound, CIP) cluster survivors by ligand heavy-atom RMSD after CRBN
  superposition (e.g. agglomerative @ ~2Å); pick the medoid of each cluster as a representative; cap
  ~5-12 reps/bin (fewer if budget-flagged by T2). Emit representative pose paths + cluster sizes.
- **Verification**: `column -t out/representatives.tsv` → per-(compound,CIP) representatives with
  cluster sizes; total reps reasonable (~order 50-100 across all).
- **Estimated time**: 12 min
- **Rollback**: `rm cluster_reps.py out/representatives.tsv`

## Task 6: Energy-minimize representatives (CPU-preferred)
- **Status**: done (minimize_reps.py; 17/18 already clean ≥1.2, g3-S minimized 1.161→1.213, CIP/pose preserved)
- **Prereq tasks**: 5
- **Files touched**: `chirality_ensemble_20260622/minimize_reps.py`; `out/minimized/<...>.pdb`
- **Change shape**: per representative, restrained energy minimization (protein heavy-atoms restrained,
  ligand free) reusing existing AM1-BCC glue params from the MD build (chirality-invariant; rebuild
  topology for the rep's coords via tleap), implicit-solvent/GB or vacuum, no production dynamics. CPU
  (sander / OpenMM-CPU) to avoid a 2nd GPU gate; GPU only if needed for throughput. Batch over reps.
- **Verification**: each minimized PDB has intra-ligand min-heavy ≥ ~1.2 Å (strain relieved) AND
  ligand-RMSD vs pre-min < ~1.5 Å (pose preserved, didn't drift); failures enumerated.
- **Estimated time**: 60-120 min (batched; reuse params)
- **Rollback**: `rm -rf out/minimized/`

## Task 7: Assemble med-chem deliverable + renders (zero-GPU)
- **Status**: done (deliverable/ 18 reps + summary.tsv + README + 2 enantiomer-pair renders, sane ternary verified)
- **Prereq tasks**: 6
- **Files touched**: `chirality_ensemble_20260622/summary.tsv`; `README.md`; `render/*.png`
- **Change shape**: per (compound × output-CIP) collate the minimized representative PDBs + a
  `summary.tsv` (compound, CIP, n_candidates, per-rep iptm/ligand_iptm/contacts/min-heavy). README for
  the med-chem (what these are, the chirality caveat, that they're viewing-grade not SAR). PyMOL renders
  for the 2 enantiomer pairs (g1-S vs g2-R; g3-S vs g4-R), identical view per pair.
- **Verification**: `column -t summary.tsv` rows for all 6 compounds; representative PDBs present;
  render PNGs exist; README present.
- **Estimated time**: 20 min
- **Rollback**: `rm summary.tsv README.md; rm -rf render/`

## Task 8: Wall-clock check + result doc + baton (mixed)
- **Status**: done (total ~2h47m ≤10h/7h; analysis/crl_integrative/chirality_ensemble_results_20260622.md)
- **Prereq tasks**: 7
- **Files touched**: `analysis/crl_integrative/chirality_ensemble_results_20260622.md` (home repo)
- **Change shape**: record total wall-clock (assert ≤10h), per-compound yields (S/R/clean), the
  honest caveats (viewing-grade, ~70% chirality yield, g5/g6 achiral=R); link the deliverable dir.
  Commit the doc; update baton; mark plan+contract done.
- **Verification**: doc committed (`git log --oneline -1`); states total wall-clock ≤10h; contract+plan
  status done.
- **Estimated time**: 10 min
- **Rollback**: `git revert` the commit.
