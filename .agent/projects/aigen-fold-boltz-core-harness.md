# AIGENFold Core Harness

Project path: `/home/ubuntu/AIGENFold`
Symlink (backward compat): `/home/ubuntu/FKSFold-Boltz_Advancement` → `AIGENFold`
Related shared path: `/mnt/data/users/ubuntu/workspace/FKSFold-Boltz_Advancement_shared`
Detected active window: 2026-05-11 through 2026-05-18

## Purpose

This harness governs code and config changes to the FKSFold-Boltz source tree:
Boltz/FK steering code, VAV1 generation configs, ranking scripts, docs, tests,
and workflow scripts.

## Current State

- The local repo is a dirty git worktree on `platform-versioning-r20260417`.
- There are many tracked deletions, tracked modifications, and untracked
  experiment assets.
- The shared workspace mirrors much of the code but is not a git repository.
- The local repo has `pyproject.toml`, `tests/`, and `workflow/Snakefile`.
- The project-local `AGENTS.md` now defines active surfaces and verification
  gates.
- The shared workspace currently contains active files that are deleted in the
  local git worktree, including `scripts/vav1_ensemble_rank.py`.

## Ownership Boundaries

Core code:

- `src/boltz/`
- `src/boltz_extension/steering/`

Project configs:

- `configs/vav1_pipeline/`
- `examples/9nfr/`

Evaluation and analysis:

- `analysis/`
- `docs/`
- `scripts/`

Workflow:

- `workflow/`
- `workflow/scripts/`
- `workflow/mdp/`

Do not mix these boundaries in a single change unless the task explicitly spans
them. For example, a ranking-only task should not touch diffusion internals.

## Planning Rules

Create a contract under `.agent/contracts/` before implementation when a task:

- changes diffusion sampling, steering potentials, or score scaling
- changes ranking semantics or production defaults
- touches SLURM workflow scripts
- changes benchmark definitions or acceptance metrics
- modifies more than 4 files
- changes both local repo and shared workspace

Use the contract template at `.agent/contracts/_template.md`.

### Anti-busywork / valid-test guardrail (added 2026-06-16 after a wasted cycle)

A "cheap zero-GPU falsification gate" is a TRAP when a valid version of the gate
itself needs real machinery. Apply before building any discrimination/validation test:

1. **Sanity vs established impossibility.** If a test result would imply a known-
   unsolved problem is actually easy, it is almost certainly a test ARTIFACT, not a
   finding — diagnose the artifact, do NOT build more scaffolding to re-confirm the
   already-known truth. *Concrete 2026-06-16 miss:* a pairwise shape-complementarity
   score "discriminated" the native ternary placement from decoys at AUROC 0.90–0.95.
   Impossible at face value — if shape complementarity discriminated placement, OOD
   ternary placement would be solved (it is not; Boltz best-of-64 = 0.016 on blind
   targets). The 0.95 was a weak-decoy artifact. A whole cycle (ΔBSA on random-rotation
   decoys) was burned producing and then proposing to "fix-and-re-run" the obvious.

2. **A discrimination test's power lives ENTIRELY in its negatives and its observable.**
   Easy decoys or a toy observable (e.g., ΔBSA as a "non-additive" term when surface
   burial is near-additive) make pass/fail meaningless. If constructing VALID hard
   negatives requires the very capability under test (a pose generator, a real
   non-additive scorer), the cheap gate does NOT exist — it is a research program. Say
   so; do not run the toy and treat its number as signal.

3. **Cheap-gate red-flag checklist** — all must be YES before running a validation test:
   - non-circular negative set that a null hypothesis would actually fail on?
   - observable is a faithful (not toy) proxy of the real quantity?
   - a positive result UNLOCKS the next step (vs merely re-derives the obvious)?
   Any NO → it is busywork. Stop and re-scope.

4. **Brainstorm-spiral time-box.** If ≥2 rounds of spec refinement pass with no runnable
   DECISIVE experiment, the work is a research program, not a quick win. Stop: resource
   it as a program (name the dependency, e.g. FMO/quantum = m-relativity slice) or park
   it. Do NOT keep generating elaborate plans under time pressure.

5. **Verify the EFFECTIVE objective composition every run — config-set ≠ working.**
   (2026-06-16 teardown: "biophysical_hybrid" steering was operationally iPTM-ONLY — the
   total_score normalized to `0.65·base/0.65 = base = iPTM-threeway`, with dist_score=0
   (structural: `key_residues_A=[]` → no_interface_fallback), elec=0, glueprint
   target-side=0, and interface_gd a no-op (`w400_interface_range_enabled` default False).
   The config LOOKED right (w_dist=0.35, glueprint enabled) but the EFFECTIVE objective was
   pure iPTM. We had run dozens of "biophysical" jobs this way; the logs printed
   `Dist=0.0000, Total=Base` at every step in plain sight.) RULE: before trusting any
   steering/scoring run, decompose from the LOGS which terms actually contributed to the
   objective (weight × nonzero component) — a nominal config weight is 0 in effect if its
   residue list is empty or its GD path is a no-op. Auditing config files + outcome metrics
   is NOT enough; audit the live objective. Report `run_objective_teardown_20260616.md`.

## Required Preflight

Before edits:

```bash
git -C /home/ubuntu/AIGENFold status --short --branch
```

Then inspect the relevant slice:

- Steering: `src/boltz_extension/steering/`, `src/boltz/model/modules/`
- Ranking: `scripts/vav1_ensemble_rank.py`, `configs/vav1_pipeline/*ranking*.yaml`
- MMGBSA workflow: `workflow/scripts/run_mmpbsa.py`, `workflow/mdp/`, `scripts/mmgbsa_16gpu_multidir/`
- 9NFR/FragMap: `analysis/compare_*9nfr*.py`, `analysis/*fragmap*.py`, `workflow/slurm_fragmap_9nfr*.sh`

For exact file routing, read `aigen-fold-actual-file-map-20260518.md`.

## Verification Gates

Use the smallest gate that matches the blast radius.

General syntax/import checks:

```bash
python -m compileall src scripts analysis workflow/scripts
```

Unit tests, when dependencies are available:

```bash
python -m pytest tests -q
```

Steering/config changes:

```bash
python -m compileall src/boltz_extension/steering
python -m compileall analysis
```

Ranking changes:

```bash
python -m compileall scripts/vav1_ensemble_rank.py
python scripts/vav1_ensemble_rank.py --help
```

If `scripts/vav1_ensemble_rank.py` is absent locally, do not treat the local
repo as the ranking source of truth until the shared copy has been reconciled.

Workflow changes:

```bash
bash -n workflow/*.sh
bash -n workflow/scripts/*.sh
```

For SLURM scripts, use `bash -n` first and submit only after an explicit user
request or approval when it would consume cluster resources.

## Completion Report

Always report:

- local repo path and shared path touched
- whether the dirty git tree had unrelated changes
- exact verification commands run
- whether outputs were generated or only code/docs changed
- any remaining risk around GPU, SLURM, Docker, or unavailable dependencies

## Immediate Harness Improvement

Add a project-local `AGENTS.md` after the user approves modifying the local repo.
It should point back to this harness and define:

- dirty worktree caution
- no production SLURM without approval
- steering/ranking/MMGBSA slice boundaries
- required verification by task type
