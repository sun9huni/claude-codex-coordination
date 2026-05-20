# WORKFLOW (research-deployment example)

This is what `WORKFLOW.md` looks like once the routing table is
filled in for a real project. Compare with the empty template at the
repo root.

## 0. Session start (3 steps, every session)

Same as the template — see [/WORKFLOW.md](../../WORKFLOW.md) §0.

## 1. Which slice

| Work signal | Status | Harness | Critical reminder |
| --- | --- | --- | --- |
| dataset ingest, ETL, raw → cleaned | `.agent/status/data-pipeline.md` | `.agent/projects/data-pipeline-harness.md` | Verify schema before re-running cleaners; cleaned data is shared |
| training run, model checkpoint, hyperparameter sweep | `.agent/status/model-train.md` | `.agent/projects/model-train-harness.md` | SLURM submission requires contract; checkpoints are immutable |
| post-hoc analysis, eval, plots | `.agent/status/analysis.md` | `.agent/projects/analysis-harness.md` | Plot outputs go under analysis/figures, not project repo |
| SLURM scripts, conda env, infrastructure | `.agent/status/infra.md` | `.agent/projects/infra-harness.md` | Test env changes on a single node before broadcasting |
| (does not match) | ask the user | do NOT invent a slice | |

## 2. Contract required?

Create a contract under `.agent/contracts/<slice>-<topic>-<YYYYMMDD>.md`
if ANY of these is true:

- New / modified SLURM submission (training run, eval batch).
- Changing scoring or ranking semantics.
- ≥ 4 files modified in one logical change.
- Touching `data-pipeline` and `model-train` together.
- Adding a new mode to the experiment-config registry.

`pre-bash-slurm-gate.sh` enforces the SLURM trigger automatically.
`/contract-check` walks the rest.

## 3. Stop and request approval before

- Submitting any sbatch.
- Deleting / overwriting outputs under shared storage.
- Changing production-defaults configs (the one ranked-first
  defaults users depend on).
- Importing files from a backup branch into the active branch.
- Synchronizing shared storage with `--delete` semantics.
- Force pushes, hard resets, branch -D.

## 4. End of session

- Verification: slice-specific check + `scripts/verify.sh`.
- Handoff: `./scripts/handoff.sh <next-agent>` + fill in
  `CURRENT.md` (use `/handoff`).
- Status refresh: overwrite the active slice's
  `.agent/status/<slice>.md` to ≤ 25 lines.

## 5. When this router cannot answer

Edge case — read the relevant harness directly and update §1
afterward so the next session does not hit the same edge.
