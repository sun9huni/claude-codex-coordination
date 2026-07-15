# Knowledge Layer

This directory stores persistent knowledge that Codex can reuse across sessions.

## Layout

- `raw/`: original source material. Do not edit derived meaning directly into these files.
- `wiki/`: compiled markdown knowledge that Codex can read quickly.
- `graphify-out/`: optional Graphify outputs such as `GRAPH_REPORT.md`, `graph.json`, and `graph.html`.
- `provenance.md`: source backing and confidence notes.

## Rules

- Put source material in `raw/`.
- Compile source material into `wiki/` or `graphify-out/`.
- Mark source-backed facts separately from inferred connections.
- Before broad architecture or domain exploration, read the report or wiki index first.
- Rebuild after large docs, transcripts, screenshots, or architecture changes.

## Suggested Commands

```bash
./scripts/knowledge-build.sh
```

If Graphify is available:

```bash
graphify . --update
graphify .agent/knowledge/raw --wiki --no-viz
graphify export callflow-html
```
