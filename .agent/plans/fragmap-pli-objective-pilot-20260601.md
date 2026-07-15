---
contract: .agent/contracts/fragmap-pli-objective-pilot-20260601.md
slice: fragmap
status: done
total_tasks: 9
outcome: "T1a KILL-by-diagnostic (zero-GPU). Baseline AB poses already near-native PLI (LDDT-PLI 0.88-0.93) → no headroom → SLURM not submitted. Category problem confirmed at pose level. T1b not entered. Next = T2/D3 (held-out structure). See T1A_RESULTS.md."
estimated_total_min: 41
program: .agent/plans/fragmap-leverage-program-20260601.md (T1)
note: "STAGED. Tasks 1-9 decompose T1a (POC). T1b (145-batch + activity) is a GATED MILESTONE at the bottom — own write-plan round only if T1a PROVEs. SLURM submit (Task 6) is a STOP gate: separate user go required."
---

# Plan — PLI-as-objective pilot, phase T1a (POC)

Phases: Recon (pin the moving parts, Tasks 1-3) → Config (Tasks 4-5) →
Submit [STOP] (Task 6) → Eval/Verdict (Tasks 7-9). Recon tasks are first
because the execution specifics (which src/ SLURM mounts, baseline pose
locations, the LDDT-PLI tool) must be pinned before a credible run — each
produces a verifiable artifact. Repo: /home/ubuntu/FKSFold-Boltz_Advancement
unless noted; shared = /mnt/data/users/ubuntu/workspace/FKSFold-Boltz_Advancement_shared.

## Task 1: Pin the SLURM src/ copy + glueprint pilot script

- **Status**: done (e90be03) — pinned FK src/; pilot=SLURM array/glueplex-v2/jobs-TSV
- **Prereq tasks**: none
- **Files touched**: `analysis/induced_fit_inverted_signal_20260601/`-style new dir `analysis/pli_objective_pilot_20260601/PINS.md` (record only)
- **Change shape**: read `shared/workflow/slurm_glueprint_gd_pilot_3x3_20260507.sh`; record (a) which `src/boltz_extension` it mounts (3 copies exist), (b) whether it uses the FK superset loader (gd_floor), (c) the generation entrypoint + per-compound loop. Decide & document the pinned src/ (prefer FK superset). Write findings to PINS.md.
- **Verification**: `grep -nE 'BASE=|mount|src/boltz_extension|--bind' shared/workflow/slurm_glueprint_gd_pilot_3x3_20260507.sh` → mount path identified; PINS.md records the chosen src/ + rationale.
- **Estimated time**: 5 min
- **Rollback**: delete PINS.md.

## Task 2: Select 5-compound T1a set + locate matched baseline poses

- **Status**: done (e90be03) — 5 cpd/5 scaffolds, AB-139batch baselines (single-seed 16; PINS §5)
- **Prereq tasks**: none
- **Files touched**: `analysis/pli_objective_pilot_20260601/t1a_manifest.csv` (new)
- **Change shape**: pick 5 DC50-bearing compounds spanning ≥4 distinct Murcko scaffolds (use `activity_eval_gates.murcko_scaffolds` on the 84-cpd snapshot) that ALSO have existing glueprint-OFF baseline structures (139-batch / multiseed pool) for paired comparison; record 3 seeds each. Write manifest: compound, scaffold, dc50_nM, baseline_pdb_path(s), seeds.
- **Verification**: `python3 -c "import pandas as pd;d=pd.read_csv('analysis/pli_objective_pilot_20260601/t1a_manifest.csv');print(len(d), d.scaffold.nunique())"` → 5 rows, ≥4 scaffolds; every baseline_pdb_path exists on disk.
- **Estimated time**: 6 min
- **Rollback**: delete manifest.

## Task 3: Identify + smoke the LDDT-PLI / ligand-RMSD evaluator

- **Status**: done (26e07c9) — MGD_eval/eval.py vs examples/9nfr/9NFR.cif
- **Prereq tasks**: none
- **Files touched**: `analysis/pli_objective_pilot_20260601/PINS.md` (append)
- **Change shape**: locate existing MGD_eval / recovery code that computes LDDT-PLI and ligand-RMSD vs a reference ligand pose (search shared for `lddt_pli|ligand_rmsd|LDDT-PLI|DockQ`). Confirm it runs on ONE existing baseline structure vs the 9NFR crystal ligand pose. Record the tool path + invocation in PINS.md. If none exists, record that a small evaluator must be written (becomes an added task).
- **Verification**: the evaluator runs on 1 structure and prints an LDDT-PLI + ligand-RMSD number; PINS.md records path + command.
- **Estimated time**: 6 min
- **Rollback**: revert PINS.md append.

## Task 4: Create the ligand-term-isolated glueprint config

- **Status**: done (689b090) — oracle_gen_t1a_ligand_isolated.yaml
- **Prereq tasks**: 1
- **Files touched**: `configs/vav1_pipeline/oracle_gen_t1a_ligand_isolated.yaml` (new, derived from `oracle_generation_gluemap_strong.yaml`)
- **Change shape**: copy the gluemap_strong glueprint block; set `w_anchor_face: 0.0`, `w_leak: 0.0` (isolate the ligand-contact term so the PLI readout isn't confounded by protein-protein anchor/leak), keep `w_ligand_face` high, set `gd_weight` boosted (0.5; gd_weight is a norm-ratio). Keep `ligand_contact_threshold/sigma` at defaults. Document each non-default in a header comment.
- **Verification**: `python3 -c "import yaml;c=yaml.safe_load(open('configs/vav1_pipeline/oracle_gen_t1a_ligand_isolated.yaml'));g=c['glueprint'];print(g['w_anchor_face'],g['w_leak'],g['w_ligand_face'],g['gd_weight'])"` → `0.0 0.0 <hi> 0.5`.
- **Estimated time**: 5 min
- **Rollback**: delete the config.

## Task 5: Stale-cache guard — per-compound glueprint rebuild

- **Status**: NOT NEEDED — prereq for the submit (Task 6), which was cancelled by the pre-submit ceiling diagnostic. Moot.
- **Prereq tasks**: 1
- **Files touched**: the pinned `src/boltz_extension/steering/interface_steering_utils.py` (or a tiny wrapper) — ONLY if Task 1 found the batch loop reuses `_glueprint_pot_cached` across compounds
- **Change shape**: confirm whether the 5-cpd loop rebuilds `_glueprint_pot_cached` / target-residue indices per compound. If it caches stale across compounds, add a per-compound reset (clear `config._glueprint_pot_cached`). If already per-compound-safe, NO-OP this task and record "no fix needed" in PINS.md.
- **Verification**: code inspection note in PINS.md; if a fix was made, `python -m compileall` on the edited file → exit 0.
- **Estimated time**: 4 min
- **Rollback**: git revert the edited steering file (diagnostic-only; or NO-OP).

## Task 6: [STOP — separate user go] Submit T1a generation (SLURM)

- **Status**: NOT SUBMITTED — pre-submit baseline diagnostic (Task 7 OFF arm) showed a PLI ceiling (all 5 baselines LDDT-PLI 0.88–0.93), breaking the premise. Submitting would burn ~1–2 GPU-hr on a foregone result. User decision 2026-06-01: close T1, do not submit. GPU saved.
- **Prereq tasks**: 2, 4, 5
- **Files touched**: `workflow/slurm_t1a_pli_pilot.sh` (new, adapted from the pinned pilot script) — submit only after explicit user "go"
- **Change shape**: adapt the glueprint pilot SLURM script to the 5-cpd manifest × 3 seeds, ligand-isolated config, pinned src/, output to a scratch OUT_BASE. If glueprint-OFF baselines from Task 2 are reusable, run ON only; else also run a matched OFF arm. **DO NOT sbatch without explicit user go (WORKFLOW §3 + GPU). Print the exact resource request and wait.**
- **Verification**: (pre-submit) `bash -n workflow/slurm_t1a_pli_pilot.sh` clean + resource request printed for approval. (post-go) job IDs returned; on completion, `predictions/*.pdb` count == 5×3 (×2 if OFF arm).
- **Estimated time**: 4 min prep (run is GPU wall-time, ~1–2 GPU-hr)
- **Rollback**: cancel job (`scancel`); discard scratch OUT_BASE.

## Task 7: Compute LDDT-PLI + ligand-RMSD (baseline vs on)

- **Status**: done-partial — OFF arm computed on all 5 (the pre-submit diagnostic, t1a_baseline_off_pli.csv, gitignored; table in T1A_RESULTS.md). ON arm not run (Task 6 not submitted). The OFF arm alone settled the verdict.
- **Prereq tasks**: 3, 6
- **Files touched**: `analysis/pli_objective_pilot_20260601/t1a_pli_results.csv` (new)
- **Change shape**: run the Task-3 evaluator on baseline (off) and steered (on) structures for all 5 cpd × 3 seed; compute LDDT-PLI and ligand-RMSD vs the 9NFR crystal ligand pose; write per-(compound,seed,arm) rows + per-compound deltas.
- **Verification**: `python3 -c "import pandas as pd;d=pd.read_csv('analysis/pli_objective_pilot_20260601/t1a_pli_results.csv');print(d.shape, d.columns.tolist())"` → rows for 5 cpd × {off,on}, columns include lddt_pli, ligand_rmsd, arm.
- **Estimated time**: 5 min (CPU eval)
- **Rollback**: delete the results CSV.

## Task 8: Apply frozen T1a PROVE/KILL + write verdict report

- **Status**: done — KILL-by-diagnostic. Report: analysis/pli_objective_pilot_20260601/T1A_RESULTS.md. (Ceiling = no headroom → KILL; near-native pose + null activity = category problem confirmed at pose level.)
- **Prereq tasks**: 7
- **Files touched**: `analysis/pli_objective_pilot_20260601/T1A_RESULTS.md` (new)
- **Change shape**: compute median ΔLDDT-PLI and median Δligand-RMSD (on−off) + per-compound direction count; apply the FROZEN T1a rule (PROVE = median ΔLDDT-PLI ≥ +0.05 AND/OR median Δligand-RMSD ≤ −0.5 Å, same direction ≥3/5; else KILL). Report as bound; state the 9NFR-reference-coupling + fixed-oracle-residue caveats from the contract.
- **Verification**: report states the two medians, the per-compound direction count, and PROVE/KILL vs the frozen thresholds.
- **Estimated time**: 4 min
- **Rollback**: delete the report.

## Task 9: Commit T1a + update plan/contract/baton

- **Status**: done — T1 closed KILL (not PROVE), so T1b milestone NOT entered.
- **Prereq tasks**: 1,2,3,4,5,7,8 (6 = run, its outputs are scratch)
- **Files touched**: FKSFold commit (config, eval script, analysis dir, any src fix); workspace (plan statuses, contract progress, baton, index)
- **Change shape**: surgical commits of the git-trackable T1a artifacts; record T1a verdict in the contract Progress Log; baton + handoff + index. If T1a KILL → mark contract done (T1b not entered). If T1a PROVE → leave contract open, proceed to T1b milestone.
- **Verification**: both repos `git status --porcelain <paths>` empty; contract Progress Log has the T1a verdict.
- **Estimated time**: 2 min
- **Rollback**: git revert the commits.

---

## MILESTONE — T1b (145-batch + activity), GATED

- **Entry gate**: Task 8 verdict = **PROVE** + explicit user go. If T1a KILL, T1b does NOT run (cheap stop; contract done).
- **Why separate**: T1b is conditional, needs its own SLURM submit gate (~8 GPU-hr) and its own task decomposition.
- **Shape (for the future /write-plan round)**: 145-cpd generation with the ligand-isolated config → scaffold-blocked OOF DC50 ranking under ALL T0 guardrails (mw_mediation_fraction + within_between_scaffold + power_preflight + permutation null + descriptors-only + proxy_audit_preflight checklist). Frozen PROVE/KILL already set in the contract (PROVE → category-problem refuted → escalate; KILL → category-problem confirmed at generative-objective level).
- **Action when reached**: run `/write-plan` again on the contract for the T1b phase (or extend this plan with a T1b task block), then a separate SLURM go.
