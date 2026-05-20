# Status: data-pipeline (as of 2026-05-20)

## Done
- ✅ Ingest from upstream API runs nightly via cron (`/scripts/ingest.sh`).
- ✅ Schema v2 (added `<col>`) shipped on 2026-05-15; backfill done.
- ✅ Cleaner v3 handles the `<edge case>` (covered by contract
  `data-pipeline-cleaner-v3-20260510.md`).

## In flight
- 🟡 Cleaner v4 prototype on a feature branch — gated behind contract
  `data-pipeline-cleaner-v4-20260518.md` (status: pending approval).

## Next action
1. Get user approval on the cleaner-v4 contract before merging.
2. Once merged, run the smoke eval on yesterday's data
   (`scripts/smoke-eval.sh`) before promoting to nightly.
3. Update this status file when v4 is in production.

## Open risks
- Cleaner v4 changes the output schema (added `<col2>`). Downstream
  consumers in `model-train` slice need a heads-up before promotion.

## Pointers
- contract: `.agent/contracts/data-pipeline-cleaner-v4-20260518.md`
- harness: `.agent/projects/data-pipeline-harness.md`
- code: `<project-repo>/etl/cleaner_v4.py`
