# data-pipeline harness

## Mental model

The data pipeline has three stages: ingest → clean → publish.

```
upstream API  ─ ingest ─→ raw/   ─ clean ─→ cleaned/   ─ publish ─→ shared/
```

- **Ingest** runs nightly. Idempotent. If it fails, the cron retries
  with the same window.
- **Clean** is the workhorse. Versioned (v1, v2, v3, ...). One
  cleaner is "current" — older ones are kept for reproducibility.
- **Publish** writes to shared storage. Downstream slices
  (`model-train`, `analysis`) read from there.

## File map

- `<project-repo>/etl/ingest.py` — ingest stage.
- `<project-repo>/etl/cleaner_v<N>.py` — versioned cleaners.
- `<project-repo>/etl/publish.py` — publish stage.
- `<project-repo>/etl/configs/<env>.yaml` — per-env config.
- `<shared-storage>/raw/`, `<shared-storage>/cleaned/`,
  `<shared-storage>/published/` — outputs.

## Common workflows

### Adding a new cleaner version

1. `/contract-check` — this will trigger because cleaner change can
   affect schema and downstream slices.
2. Branch in `<project-repo>` (`feature/cleaner-v<N>`).
3. Write `cleaner_v<N>.py` with the new logic.
4. Update `etl/configs/<env>.yaml` to point to v<N>.
5. Run `scripts/smoke-eval.sh` on one day of recent data.
6. PR with the smoke results in the description.
7. After merge, update `.agent/status/data-pipeline.md`.

### Investigating a failed ingest

1. `Agent(subagent_type="slurm-status", prompt="last ingest job
   status and log path")`.
2. Read the log path from the report.
3. If it's a transient upstream error, no action — the cron will
   retry tonight.
4. If it's our code, file a bug under the slice's contract dir.

## Pitfalls

- **Don't bump cleaner version silently**. Always behind a contract.
  Downstream eats schema changes loudly.
- **Don't write to `<shared-storage>/raw/`**. It's the ingest's
  output; manual writes break invariants.
- **Don't share conda envs across slices**. Use per-slice env files.

## Verification

- Smoke eval: `scripts/smoke-eval.sh` (runs in <2 minutes).
- Full eval: `scripts/full-eval.sh` (HPC, ~30 minutes — contract
  required).
- Schema check: `scripts/check-schema.sh <env>` (compares produced
  schema against `etl/schemas/<env>.json`).
