# Claude-Native Subagents

Custom subagent definitions for `/home/ubuntu`. Each `<name>.md` is a
Markdown file with YAML frontmatter (`name`, `description`, optional
`tools`, `model`, `permissions`). Claude delegates to a subagent
via the `Agent` tool with `subagent_type: <name>`.

| Agent | Purpose | Restriction signal |
|---|---|---|
| `slurm-status` | Read-only SLURM checks: `squeue`, `sacct`, `sinfo`, `scontrol show`. Job state, partition use, completion time. | Cannot `sbatch`, cannot edit. |
| `fragmap-diagnose` | Zero-compute FragMap diagnostics: read input YAML / scoring config, compute attractor positions, check constraint alignment vs ground truth. | Cannot submit SLURM, cannot write files outside `/tmp`. |
| `mmgbsa-stage-check` | Stage gate checks between MMGBSA stages 1-4. Verifies stage-N outputs exist and are sane before stage-N+1 can be approved. | Read-only access to shared workspace; cannot edit project repos. |

Choose a subagent over the generic `general-purpose` agent when the
task is repeatable and benefits from a narrow tool surface (less
context, fewer accidental writes, faster turnaround).
