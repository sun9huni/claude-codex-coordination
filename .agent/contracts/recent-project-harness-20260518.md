# Recent Project Harness Contract

Date: 2026-05-18

## Purpose

Identify projects active in Cursor during the last week and design detailed
Codex harness rules for those projects.

## Current State

The root Codex harness exists under `/home/ubuntu/.agent`. Cursor activity from
2026-05-11 to 2026-05-18 points primarily to FKSFold-Boltz work split across:

- local git repo: `/home/ubuntu/FKSFold-Boltz_Advancement`
- shared workspace: `/mnt/data/users/ubuntu/workspace/FKSFold-Boltz_Advancement_shared`
- Cursor plans/transcripts/canvases under `/home/ubuntu/.cursor`

## Assumptions And Questions

- "Projects" means active workstreams inferred from Cursor state and touched
  files, not only git repositories.
- Cursor environment skill/canvas SDK updates are tool context, not user
  project work.
- Design documents are the right first step; project-local `AGENTS.md` files can
  be added later with explicit approval because the FKSFold repo is already
  dirty.

## Constraints

- Do not revert or clean the dirty FKSFold worktree.
- Do not submit SLURM jobs.
- Do not edit shared output artifacts.
- Keep this pass to harness design and evidence capture.

## Non-Goals

- No ranking implementation changes.
- No FragMap steering implementation changes.
- No MMGBSA job submission.
- No project-local file edits inside FKSFold repos.

## Done When

- Recent Cursor activity is summarized with evidence.
- Active project/workstream harness docs exist under `.agent/projects/`.
- Each harness names paths, scope boundaries, verification gates, and stop
  conditions.
- Root project index points to the new docs.

## Implementation Steps

1. Inspect `.cursor` recent files, plans, transcripts, and ide state.
2. Cross-check active paths against local and shared workspaces.
3. Write project-specific harness design docs.
4. Run basic harness verification commands.

## Verification

```bash
find /home/ubuntu/.agent/projects -maxdepth 1 -type f -print
./scripts/verify.sh
./scripts/tool-audit.sh
```

## Risks

- Cursor transcripts are large and may include older context in files modified
  recently. Mitigation: use recent plans, ide state, and actual recent output
  files as stronger evidence.
- Shared workspace is not a git repo. Mitigation: treat it as production-like
  outputs/workflow space and require explicit manifests.

## Rollback

Remove the new `.agent/projects/*.md` docs and this contract if the inferred
project split is not useful.

## Progress Log

- 2026-05-18: Scanned `.cursor`, identified FKSFold-Boltz active workstreams,
  and added project harness design documents.
- 2026-05-18: Scanned actual local/shared project files, added project-local
  `AGENTS.md`, documented local/shared divergence, and refined harness gates
  from source files.
- 2026-05-18 (later): Re-scanned recent activity. Found two gaps:
  (a) `arl-threads-coscientist/` had no harness despite recent edits to
  `Makefile`, `CLAUDE.md`, `pyproject.toml`; (b) Cursor plan
  `original-backup-import_05f9a8a6` was unreferenced. Added
  `arl-threads-coscientist-harness.md`, registered it in
  `.agent/projects/README.md`, and folded `original-backup-import` into the
  MMGBSA harness as a workstream entry. Contract now satisfies "Done When":
  each active workstream has a harness or is explicitly absorbed into one.
