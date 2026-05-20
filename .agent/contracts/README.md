# Contracts

A **contract** is the written intention + approval that gates a
non-trivial change. Triggers live in [WORKFLOW.md §2](../../WORKFLOW.md).
The `/contract-check` slash command walks them automatically.

## Naming

```
<slice>-<short-topic>-<YYYYMMDD>.md
```

Examples (these are illustrative — replace with your real slices):

```
backend-rate-limit-fix-20260520.md
ml-pipeline-retrain-sweep-20260520.md
infra-postgres-migration-20260520.md
```

## Lifecycle

```
draft (status: pending)
  └─ user reviews
  └─ user marks status: approved
     └─ work proceeds
        └─ on success: status: done + summary in Notes section
        └─ on cancel: status: cancelled + reason

For HPC users with optional/pre-bash-slurm-gate.sh:
  └─ The PreToolUse hook checks `find .agent/contracts ... -mtime -7`
     before allowing sbatch. Touch the contract file (or update it)
     to re-extend its activity window.
```

## Template

See [_template.md](_template.md).

## Past contracts

Move long-since-done contracts to a dated subdirectory like
`archive-2026-Q2/` to keep this directory readable. Contract history
is also in git, so deletion is fine too if you prefer a clean tree.
