# Knowledge Layer Checklist

Use this checklist when adding raw sources, refreshing architecture knowledge, or answering broad domain questions.

## Before Exploration

- Check whether `.agent/knowledge/graphify-out/GRAPH_REPORT.md` exists.
- If not, check `.agent/knowledge/wiki/index.md`.
- If both are stale or empty, inspect raw sources and update the knowledge layer.

## Ingest

- Add original material to `.agent/knowledge/raw/`.
- Keep raw material unmodified.
- Extract key concepts into `.agent/knowledge/wiki/`.
- Record source backing in `.agent/knowledge/provenance.md`.

## Graph

- If Graphify is installed, run `./scripts/knowledge-build.sh`.
- Review `GRAPH_REPORT.md` for god nodes, surprising connections, and suggested questions.
- Commit team-safe graph artifacts if the repository policy allows it.

## Answering Questions

- Prefer compiled wiki/graph reports before raw search.
- Use raw files when provenance is required or the compiled layer is stale.
- Label inferred conclusions clearly.

## Refresh Triggers

- new architecture document
- new meeting transcript
- new external research source
- large refactor
- new module or bounded context
- stale or contradictory wiki entry
