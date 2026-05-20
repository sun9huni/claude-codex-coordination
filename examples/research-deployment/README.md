# Example: research deployment

This is one filled-in example of the
[claude-codex-coordination](../../README.md) harness. It is the
shape of a real research workspace running multiple data / model
pipelines on shared HPC infrastructure. Copy what's useful; ignore
what doesn't apply to you.

The names and content here are illustrative — no real project
secrets, no real compute paths. Use the **patterns**, not the
strings.

## Shape of this deployment

- **Workspace**: a shared `/workspaces/research/` directory used by
  Claude, Codex, Cursor, and the researcher.
- **Slices** (filled in `WORKFLOW.md §1`):
  - `data-pipeline` — ingest + clean
  - `model-train` — training runs (uses HPC)
  - `analysis` — post-hoc analysis
  - `infra` — SLURM scripts, environments
- **Approval gates active**:
  - `pre-bash-destructive-gate.sh` (always on, core)
  - `pre-bash-slurm-gate.sh` (HPC) — contract required for sbatch
  - `pre-bash-db-gate.sh` (results store) — DDL blocked
- **Custom subagents**:
  - `slurm-status` — read-only HPC inspector (haiku model, fast)
  - `input-config-diagnose` — zero-compute diagnostic for failed
    runs (opus, deep reading of YAML / configs)
  - `stage-gate-check` — verifies stage-N prereqs before stage-N+1

## What's in this directory

- `.claude/agents/` — the three example subagents
- `.claude/hooks/` — destructive-gate (core) + slurm-gate +
  db-gate (optional, enabled)
- `.agent/status/data-pipeline.md` — example status file
- `.agent/projects/data-pipeline-harness.md` — example harness file
- `WORKFLOW.md` — filled-in routing table (compare with the
  empty template at the top level)

## How to adopt this example

1. Copy the agents you want into your own `.claude/agents/`:
   ```bash
   cp examples/research-deployment/.claude/agents/<name>.md .claude/agents/
   ```
2. Adjust the `permissions.allow` / `permissions.deny` lists for
   your environment (binary paths, conda env names, etc.).
3. If you use HPC: copy the slurm-gate to `.claude/hooks/` and
   register in `.claude/settings.json`.
4. Update your `WORKFLOW.md §1` routing table inspired by the
   filled-in one here.

## Reference deployment notes

The original of this harness ran in a structural-biology research
workspace coordinating a Boltz-based ternary complex prediction
pipeline + MM/GBSA scoring + ensemble ranking. The 8-phase build
that produced this template is described in [docs/design.md](../../docs/design.md).
