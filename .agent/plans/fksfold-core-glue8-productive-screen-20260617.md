---
contract: .agent/contracts/fksfold-core-glue8-productive-screen-20260617.md
slice: vav1-ubq
status: in-progress
total_tasks: 11
estimated_total_min: 47
---

# Plan — glue8 productive-geometry screen (orientation campaign, up to before MD)

Campaign dir: `/mnt/data/users/ubuntu/workspace/glue6_orientation_campaign_20260617/` (CAMP).
GPU tasks (3, 4) cross the ★APPROVAL GATE — /execute-plan pauses there for user go (contract active <7d). All else zero-GPU.

## Task 1: Add MRT6160 + C147 input YAMLs (8 compounds × 6 angles = 48)
- **Status**: done
- **Prereq tasks**: none
- **Files touched**: `CAMP/inputs/` (add g_mrt6160_*, g_c147_* ; 12 new YAMLs)
- **Change shape**: extend the YAML generator to include g_mrt6160 (SMILES `O=C1N(C2=CC=C(C3=C(Cl)C(C4C(NC(CC4)=O)=O)=CC=C3)C=C2)C=CC=C1`) and g_c147 (`O=C1CC[C@@H](C(=O)N1)c1c(F)ccc(c1F)c1ccc(cc1)Cn1ccccc1=O`), same 6 angle-configs, container-visible template paths.
- **Verification**: `ls CAMP/inputs/*.yaml | wc -l` → 48; `for f in CAMP/inputs/g_c147_0.yaml CAMP/inputs/g_mrt6160_0.yaml; do grep smiles $f; done` shows correct SMILES; each ligand passes glutarimide substructure (obabel `-s "O=C1CCCC(=O)N1"`).
- **Estimated time**: 4 min
- **Rollback**: `rm CAMP/inputs/g_mrt6160_* CAMP/inputs/g_c147_*`

## Task 2: Wire launcher to 8 compounds + shared MSA + walltime
- **Status**: done
- **Prereq tasks**: 1
- **Files touched**: `CAMP/run_glue6_orientation_scan.sh`
- **Change shape**: GLUES=(g1..g6 g_mrt6160 g_c147); add `-v ${SHARED_MSA}:/app/shared_msa:ro` + reference shared MSA so MSA isn't recomputed 768×; reconcile `#SBATCH --time` to ~14:00:00 (real ~8–10h + headroom).
- **Verification**: `bash -n CAMP/run_glue6_orientation_scan.sh` exit 0; `grep -c 'g_mrt6160\|g_c147' CAMP/run...sh` ≥1; shared MSA mount line present.
- **Estimated time**: 4 min
- **Rollback**: `git -C <campaign not in repo> ` n/a — restore prior launcher from this task's diff snapshot.

## Task 3: SMOKE gate — 1 cell + faithfulness diff vs original ★GPU GATE
- **Status**: done
- **Prereq tasks**: 2
- **Files touched**: `CAMP/outputs/g1_p60_seed314/` (run artifact); `CAMP/SMOKE_DIFF.md` (verdict)
- **Change shape**: `SMOKE=1` submit ONE cell via the gate; capture its steering log; diff signature (num_particles 8, `/app/pipeline_configs/oracle_generation.yaml`, Lever 1–5, interface_gd potentials ligand_volume+clash, interface_lambda 20, gd_start_t 0.5) against an original `mrt6160_orientation_scan_20260609` orient log; lock interface_gd_steps + oracle-config questions.
- **Verification**: `CAMP/SMOKE_DIFF.md` records signature match (all lever/config/particle lines identical) → PASS; model_0.pdb produced.
- **Estimated time**: 5 min agent (job wall ~5 min)
- **Rollback**: `scancel` smoke job; `rm -rf CAMP/outputs/g1_p60_seed314`

## Task 4: Full campaign — 768 poses ★GPU GATE
- **Status**: done
- **Prereq tasks**: 3
- **Files touched**: `CAMP/outputs/` (768 cells)
- **Change shape**: submit full grid (8 × 6 angles × 16 seeds) on an 8-GPU node; monitor via srun (not login mtime); enumerate failed cells.
- **Verification**: `find CAMP/outputs -name '*_model_0.pdb' | wc -l` ≈ 768 (failures explicitly listed in a run-summary, not silently dropped).
- **Estimated time**: 4 min agent (job wall ~8–10h; re-invoked on completion)
- **Rollback**: `scancel` job; `rm -rf CAMP/outputs/<failed cells>` and resubmit subset.

## Task 5: Graft + 5-lysine in-line dual-register scan (all poses)
- **Status**: done
- **Prereq tasks**: 4
- **Files touched**: `analysis/crl_integrative/glue8_pose_scan.py`; `CAMP/glue8_pose_scan.csv`
- **Change shape**: extend `crl_pose_scan` to iterate all campaign poses: CRBN-superpose onto 9UUM, per pose record 5-lysine Nζ→Ub-Gly76-C AND →Cys85 (dual-register), min-over-5, closest-lysine id, block↔scaffold clash.
- **Verification**: `wc -l CAMP/glue8_pose_scan.csv` ≈ poses+1; columns include compound, angle, seed, min5, closest_lys, d_ub, d_cys, clash; spot-check MRT6160 row near known 5.46 Å.
- **Estimated time**: 5 min agent (scan runs over poses)
- **Rollback**: `rm analysis/crl_integrative/glue8_pose_scan.py CAMP/glue8_pose_scan.csv`

## Task 6: Orientation-MARGINAL per compound (not best-pose)
- **Status**: done
- **Prereq tasks**: 5
- **Files touched**: `analysis/crl_integrative/glue8_marginal.py`; `CAMP/glue8_marginal.tsv`
- **Change shape**: from the per-pose CSV compute per-compound MARGINAL = fraction of orientation ensemble presenting an in-line clash-free lysine (dual-register thresholds), with per-seed spread; best-pose min reported SEPARATELY (flagged non-verdict).
- **Verification**: `column -t CAMP/glue8_marginal.tsv` shows 8 rows (g1..g6, mrt6160, c147) with marginal_frac + spread + best_pose_min columns; marginal ≠ best-pose-min (distinct columns present).
- **Estimated time**: 4 min
- **Rollback**: `rm analysis/crl_integrative/glue8_marginal.py CAMP/glue8_marginal.tsv`

## Task 7: Active/inactive separation KILL-gate (pre-registered)
- **Status**: done (FAIL → STOP)
- **Prereq tasks**: 6
- **Files touched**: `analysis/crl_integrative/glue8_separation_gate.py`; appends verdict to `CAMP/glue8_marginal.tsv` notes
- **Change shape**: one-sided test on the marginal metric: MRT6160(active) vs C147(inactive). Emit PASS (separated, active > inactive) or FAIL (→ STOP: triage not trusted, report method-negative; 음성 자동선언 금지 = surface, not auto-strong-negative).
- **Verification**: script prints `SEPARATION: PASS|FAIL` with the two marginal values + gap; verdict recorded.
- **Estimated time**: 3 min
- **Rollback**: `rm analysis/crl_integrative/glue8_separation_gate.py`

## Task 8: Circularity ablation — 9UUM-frame reach vs Boltz-internal null
- **Status**: pending
- **Prereq tasks**: 6
- **Files touched**: `analysis/crl_integrative/glue8_null_ablation.py`; `CAMP/glue8_null.tsv`
- **Change shape**: collect Boltz iPTM/confidence per pose (from confidence json); test whether marginal-reach separation adds signal OVER a Boltz-confidence-only baseline (does 9UUM-frame reach beat the generator's own null).
- **Verification**: `cat CAMP/glue8_null.tsv` shows reach-separation vs iPTM-baseline-separation; a one-line verdict "9UUM-frame adds / does-not-add over Boltz".
- **Estimated time**: 4 min
- **Rollback**: `rm analysis/crl_integrative/glue8_null_ablation.py CAMP/glue8_null.tsv`

## Task 9: Survivor gate (Tier-1 SEMI ≤18Å) per compound
- **Status**: pending
- **Prereq tasks**: 5
- **Files touched**: `analysis/crl_integrative/glue8_survivors.py`; `CAMP/glue8_survivors.tsv`
- **Change shape**: apply the Tier-1 swept-reach SEMI gate (≤18 Å rotamer+receptor, `reach_envelope.md`) to each pose; list survivors per compound. C147 expected none (valid).
- **Verification**: `column -t CAMP/glue8_survivors.tsv` lists per-compound survivor count + pose ids; "no survivor" rows allowed (not errors).
- **Estimated time**: 4 min
- **Rollback**: `rm analysis/crl_integrative/glue8_survivors.py CAMP/glue8_survivors.tsv`

## Task 10: MD-ready prmtop for compounds with ≥1 survivor
- **Status**: pending
- **Prereq tasks**: 9
- **Files touched**: `CAMP/md_systems/<compound>/` (prmtop/inpcrd per survivor)
- **Change shape**: run `crl_md_prep` per surviving pose (GAFF2/AM1-BCC ligand param + tleap + solvate) → MD-ready prmtop. Skip compounds with no survivor (record as such).
- **Verification**: for each survivor compound, `ls CAMP/md_systems/<c>/*.prmtop` exists; `crl_confirm.py --t0` style sanity (finite, K810/closest-lys distance sane) on one built system.
- **Estimated time**: 5 min agent (param/tleap per survivor)
- **Rollback**: `rm -rf CAMP/md_systems/`

## Task 11: Result doc + commit
- **Status**: pending
- **Prereq tasks**: 7, 8, 9, 10
- **Files touched**: `analysis/crl_integrative/glue8_screen_results_20260617.md`
- **Change shape**: marginal triage table (8 rows) + separation-gate verdict + null-ablation result + survivor list + MD-prep status + static-reach induced-fit caveat + provenance. Commit (analysis files + doc).
- **Verification**: doc committed (`git log --oneline -1` shows the commit); doc contains all 5 sections; contract+plan marked done.
- **Estimated time**: 5 min
- **Rollback**: `git revert` the commit.
