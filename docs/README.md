# docs/

Human-maintained source of truth. Distinct from `.agent/`, which holds the
agent operating harness.

| Subdir | Owner | Holds |
| --- | --- | --- |
| `product/` | humans | product requirements, domain glossary, exception cases |
| `architecture/` | humans | system structure, dependency direction, core invariants |
| `adr/` | humans | architectural decision records (one file per decision) |
| `runbooks/` | humans | operational procedures: deploy, rollback, on-call, recovery |
| `qa/` | humans | manual QA scripts, acceptance criteria pinned by product |

## Rules

- Edit these files directly. They are not regenerated.
- `.agent/knowledge/` is the agent-readable compiled view; do not duplicate
  authoritative content here into that tree by hand — let
  `scripts/knowledge-build.sh` (or the `knowledge-ingest` skill) compile it.
- ADRs are append-only. Supersede with a new ADR rather than rewriting history.
- Keep each file short and link liberally to neighbors.

If a doc lives nowhere natural, default to `architecture/` and link from
`README.md`.
