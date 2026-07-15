---
contract: .agent/contracts/chronobridge-gspt1-md-generation-20260714.md
slice: chronobridge
status: pending
total_tasks: 10
estimated_total_min: 55
---

# Plan: chronobridge GSPT1 6-system MD package (for B200 execution)

## Task 1: survey mmgbsa's existing ligand-parameterization + Zn-handling recipe

- **Status**: pending
- **Prereq tasks**: none
- **Files touched**: `.agent/scratch/chronobridge/phaseB/md_package/mmgbsa_recipe_notes.md`
  (new, read-only survey of mmgbsa's code — do not modify anything under mmgbsa's own
  directories)
- **Change shape**: Read `.agent/status/mmgbsa.md` and locate mmgbsa's actual GROMACS
  system-building scripts (protein+ligand topology, GAFF2 ligand parameterization via
  acpype/antechamber, and — critically — how it handles CRBN's structural Zn in a
  zinc-finger domain, since 5HXB/6XK9/9HNE's CRBN chain has the same Zn cofactor
  mmgbsa's own ternary-complex systems must already handle). Document: which scripts to
  reuse/adapt, the exact acpype/antechamber invocation pattern used, the force field
  choice (e.g. amber99sb-ildn + GAFF2 + TIP3P, confirm exact names), and the Zn
  treatment (bonded model / nonbonded / dummy atoms — whichever mmgbsa uses).
- **Verification**: `test -f .agent/scratch/chronobridge/phaseB/md_package/mmgbsa_recipe_notes.md && grep -qi 'zn\|zinc' .agent/scratch/chronobridge/phaseB/md_package/mmgbsa_recipe_notes.md`
- **Estimated time**: 5 min
- **Rollback (if this task only)**: `rm .agent/scratch/chronobridge/phaseB/md_package/mmgbsa_recipe_notes.md`

## Task 2: parameterize the 3 glue ligands (GAFF2)

- **Status**: pending
- **Prereq tasks**: 1
- **Files touched**: `.agent/scratch/chronobridge/phaseB/md_package/ligands/` (new: one
  subdir per glue with `.itp`/`.mol2`/charge files)
- **Change shape**: Using mmgbsa's recipe (Task 1), parameterize all 3 glues with GAFF2
  via acpype/antechamber (mmgbsa conda env): 85C (from 5HXB), V4M (from 6XK9), A1IWG
  (from 9HNE and the 9HNE-donor decoy — note: the 9HNE decoy's placed glue was renamed
  to the legacy-safe alias `A1I` in the structure file per `decoy_report_9hne.txt`, but
  the actual chemical identity is A1IWG — parameterize using the true A1IWG structure,
  not the truncated-name placeholder). Extract each glue's coordinates from its source
  PDB/CIF (or use a fresh SMILES/structure lookup from the PDB Chemical Component
  Dictionary if extracting from the deposited structure proves awkward for antechamber).
- **Verification**: `ls .agent/scratch/chronobridge/phaseB/md_package/ligands/*/*.itp 2>/dev/null | wc -l` → 3 (one per glue), each with a nonzero net-charge-neutral or documented-charge `.itp`.
- **Estimated time**: 10 min
- **Rollback (if this task only)**: `rm -rf .agent/scratch/chronobridge/phaseB/md_package/ligands/`

## Task 3: build protein+ligand+Zn topology for all 6 systems

- **Status**: pending
- **Prereq tasks**: 2
- **Files touched**: `.agent/scratch/chronobridge/phaseB/md_package/systems/<system>/` (new,
  one subdir per system: `5hxb`, `6xk9`, `9hne`, `decoy_a_6xk9glue_5hxbbb`,
  `decoy_b_5hxbglue_6xk9bb`, `decoy_c_9hneglue_5hxbbb` — pick clear, consistent naming
  and use it for all subsequent tasks)
- **Change shape**: For each of the 6 starting structures (3 native from
  `.agent/scratch/chronobridge/phaseB/pdb/`, 3 decoys from
  `.agent/scratch/chronobridge/phaseB/decoys/`), build a GROMACS topology: protein
  chains via `gmx pdb2gmx` (force field per Task 1's finding), merge in the
  appropriate glue `.itp` (per Task 2) at the correct residue position, and include
  the Zn per mmgbsa's established treatment (Task 1). Each system's glue comes from
  its own structure (e.g. the `decoy_a` system uses the 6XK9-donor glue's parameters
  since that's the glue physically present in that decoy).
- **Verification**: `for d in .agent/scratch/chronobridge/phaseB/md_package/systems/*/; do test -f "$d/topol.top" || echo "MISSING: $d"; done` prints nothing (all 6 have a `topol.top`), and each system's total atom count is sanity-checked against the expected protein residue counts from `sequence_check.md`/`pdb_notes.md`.
- **Estimated time**: 10 min
- **Rollback (if this task only)**: `rm -rf .agent/scratch/chronobridge/phaseB/md_package/systems/`

## Task 4: solvate + ionize all 6 systems

- **Status**: pending
- **Prereq tasks**: 3
- **Files touched**: `.agent/scratch/chronobridge/phaseB/md_package/systems/<system>/` (adds
  solvated+ionized `.gro`/updated `.top` per system)
- **Change shape**: For each of the 6 systems, solvate in a water box (TIP3P or
  whatever Task 1's recipe specifies) with adequate padding for the ternary complex
  size, then neutralize + add physiological ionic strength (`gmx genion`, mirroring
  mmgbsa's ion concentration convention).
- **Verification**: for each system, confirm net charge is 0 (e.g. `gmx grompp -maxwarn 0` on a minimal ions.mdp doesn't complain about a nonzero net charge, or a direct topology charge sum check) — 6/6 systems neutral.
- **Estimated time**: 8 min
- **Rollback (if this task only)**: revert each system dir to its pre-solvation state (or re-run from Task 3's output if kept)

## Task 5: minimization / equilibration / production mdp files

- **Status**: pending
- **Prereq tasks**: 4
- **Files touched**: `.agent/scratch/chronobridge/phaseB/md_package/mdp/` (shared
  templates: `minim.mdp`, `nvt.mdp`, `npt.mdp`, `production.mdp`) plus any per-system
  overrides under each system's own directory if needed
- **Change shape**: Write mdp files per `md_necessity.md`'s spec: energy minimization,
  staged NVT→NPT equilibration (~1-2 ns total), production (~20-30 ns), with output
  frequency chosen to yield several hundred to ~1000+ frames (per Phase A's own
  validated frame-density reference point, `phaseA/results.md` §2). Decoys get the
  same mdp files as natives (per `md_necessity.md`'s "closer monitoring, not more ns"
  finding) — no separate mdp needed for decoys, just note in the README (Task 7) that
  their equilibration logs deserve closer inspection once run.
- **Verification**: 4 mdp files exist, each with `nsteps`/`dt` consistent with the intended ns (e.g. production.mdp's `nsteps * dt` ≈ 20-30 ns).
- **Estimated time**: 5 min
- **Rollback (if this task only)**: `rm -rf .agent/scratch/chronobridge/phaseB/md_package/mdp/`

## Task 6: grompp verification for all 6 systems

- **Status**: pending
- **Prereq tasks**: 5
- **Files touched**: `.agent/scratch/chronobridge/phaseB/md_package/systems/<system>/em.tpr`
  (and equivalents) — CPU-only, no GPU needed
- **Change shape**: Run `gmx grompp` for each of the 6 systems (at minimum the
  minimization step, ideally chaining through to confirm the equilibration/production
  mdp files also grompp cleanly against the post-equilibration state where feasible)
  and confirm no errors. Warnings should be read and either resolved or explicitly
  justified (e.g. `-maxwarn` used only for genuinely benign warnings, documented
  which ones and why).
- **Verification**: 6/6 systems produce a `.tpr` with `gmx grompp` exit code 0 (or documented, justified `-maxwarn` use); a summary printed per system.
- **Estimated time**: 8 min
- **Rollback (if this task only)**: delete generated `.tpr` files, does not affect earlier stages

## Task 7: package + README

- **Status**: pending
- **Prereq tasks**: 6
- **Files touched**: `.agent/scratch/chronobridge/phaseB/md_package/chronobridge_gspt1_md_package.tar.gz`,
  `.agent/scratch/chronobridge/phaseB/md_package/README.md`
- **Change shape**: Tar+gzip the 6 systems' full build (topology, solvated/ionized
  structure, mdp files, tpr files) plus the ligand parameter files. Write a README
  with: exact `gmx mdrun` commands to run on B200 for each of the 6 systems in
  sequence (minimization → equilibration → production), the GROMACS version and CUDA
  version this was built with (from this workspace's `mmgbsa` env, e.g. GROMACS
  2025.4), a note that B200 (Blackwell) may need a newer CUDA/driver than this
  workspace's A100 (CUDA 12.2) and to verify compatibility there first, and the
  estimated GPU-hour budget per system from `md_necessity.md`.
- **Verification**: `test -f .agent/scratch/chronobridge/phaseB/md_package/chronobridge_gspt1_md_package.tar.gz && tar -tzf .agent/scratch/chronobridge/phaseB/md_package/chronobridge_gspt1_md_package.tar.gz | wc -l` shows a nonzero file count including all 6 system dirs; README contains runnable `gmx mdrun` command lines.
- **Estimated time**: 5 min
- **Rollback (if this task only)**: `rm .agent/scratch/chronobridge/phaseB/md_package/chronobridge_gspt1_md_package.tar.gz .agent/scratch/chronobridge/phaseB/md_package/README.md`

## Task 8: results document

- **Status**: pending
- **Prereq tasks**: 7
- **Files touched**: `.agent/scratch/chronobridge/phaseB/md_package_results.md`
- **Change shape**: Summarize what was built (6 systems, ligand parameterization
  approach, Zn treatment, grompp verification results per system, package location),
  explicitly restate the limitation that no actual MD run was performed or verified
  here (grompp success is the strongest local evidence available), and restate next
  steps (user transfers the package to B200 via scp/rsync, runs the README's commands,
  transfers trajectories back when done — analysis approach to be decided once file
  paths/manifest are provided, per the user's own choice in this contract's brainstorm).
- **Verification**: `test -f .agent/scratch/chronobridge/phaseB/md_package_results.md`
- **Estimated time**: 4 min
- **Rollback (if this task only)**: `rm .agent/scratch/chronobridge/phaseB/md_package_results.md`

## Task 9: update chronobridge slice status file

- **Status**: pending
- **Prereq tasks**: 8
- **Files touched**: `.agent/status/chronobridge.md`
- **Change shape**: Update `remaining_actions`/`contract_pointers`/body: 6-system MD
  package built and grompp-verified, packaged for B200. Next step is a
  BLOCKED/user-action item (not a Claude AGENT item): user transfers the package to
  B200, runs the MD there, and reports back trajectory file paths/manifest so a future
  session can scope the leave-one-out analysis contract.
- **Verification**: `grep -q 'chronobridge-gspt1-md-generation-20260714' .agent/status/chronobridge.md`
- **Estimated time**: 3 min
- **Rollback (if this task only)**: revert via git (tracked file)

## Task 10: handoff + regenerate index + close contract

- **Status**: pending
- **Prereq tasks**: 9
- **Files touched**: `.agent/status/chronobridge.md` (frontmatter bump via script),
  `.agent/handoffs/CURRENT.md` (regenerated), `.agent/handoffs/state/` (snapshot),
  `.agent/contracts/chronobridge-gspt1-md-generation-20260714.md` (`status: done`,
  Progress Log entry)
- **Change shape**: Run `./scripts/handoff.sh claude chronobridge`, then
  `./scripts/status.sh index`. Flip the contract's `status` to `done` and append a
  final Progress Log line.
- **Verification**: `./scripts/handoff.sh claude chronobridge && ./scripts/status.sh index` exit 0; `grep -q 'status: done' .agent/contracts/chronobridge-gspt1-md-generation-20260714.md`
- **Estimated time**: 2 min
- **Rollback (if this task only)**: manually revert the contract frontmatter edit and
  re-run `./scripts/status.sh index`
