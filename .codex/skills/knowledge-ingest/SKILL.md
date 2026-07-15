---
name: knowledge-ingest
description: Compile raw documents, transcripts, screenshots, and architecture notes into a persistent Codex-readable wiki or graph-backed knowledge layer.
license: MIT
---

# Knowledge Ingest

Use this skill when adding or refreshing repository knowledge that should persist across sessions.

## Workflow

1. Put original sources under `.agent/knowledge/raw/`.
2. Inspect existing `.agent/knowledge/wiki/index.md` and `provenance.md`.
3. If Graphify is available, run `./scripts/knowledge-build.sh`.
4. If Graphify is not available, synthesize concise wiki pages manually.
5. Mark every important fact as `source-backed`, `extracted`, `inferred`, or `ambiguous`.
6. Update `.agent/knowledge/provenance.md`.
7. Add stale or missing areas to `.agent/knowledge/wiki/index.md`.

## Output

Produce or update:

- `.agent/knowledge/wiki/index.md`
- topic pages under `.agent/knowledge/wiki/`
- `.agent/knowledge/provenance.md`
- `graphify-out/GRAPH_REPORT.md` when Graphify is available

## Guardrails

- Do not edit raw sources.
- Do not treat inferred relationships as facts.
- Do not make broad architecture claims without source backing.
- Prefer a compact navigational map over long copied excerpts.
