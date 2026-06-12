# Slices and routing

A **slice** is one workstream within the workspace, distinct enough
to have its own vocabulary, success criteria, and status snapshot.

## Why slices?

In a multi-stream workspace, the agent's first question is "which
workstream is this about?". Without an answer, it pre-reads
everything and pollutes context. Slices make that question explicit
and answer-able by reading one routing table.

## What makes a good slice

| Yes | No |
|---|---|
| Has its own success criteria | Generic "infrastructure" or "misc" |
| Lives in its own project repo (mostly) | Floats across repos arbitrarily |
| Has 2-10 active files at any time | Has 0 active files (dormant) or 200 (too broad) |
| Distinct technical vocabulary | Reuses the same terms as another slice |
| Has a clear owner (you or a teammate) | "Whoever has time" |

If you find yourself splitting a slice into sub-slices regularly,
split it permanently. If you find yourself never invoking a slice,
fold it into an adjacent one.

## Routing table (WORKFLOW.md §1)

The router is a single table, one row per slice. Columns:

- **Work signal**: concrete keywords / filenames / feature names.
- **Status file**: `.agent/status/<slice>.md`.
- **Harness file**: `.agent/projects/<slice>-harness.md`.
- **Critical reminder**: one-line caveat.

The `/route` slash command matches against column 1. The
match-by-keyword pattern is intentionally dumb — invisible
heuristics drift; visible keywords don't.

## Common pitfalls

- **Slice creep**: keep slice descriptions tight. A slice that
  "also does X" is two slices.
- **No reminder**: the "critical reminder" column exists for a
  reason. If it's blank, you'll get repeat failure modes. Common
  reminders: "verify before merging", "no force push", "shared is
  the active version".
- **Missing slice**: when a user request doesn't match any row,
  do NOT invent a slice silently. Ask, then add a row.

## Updating

The slice IS the `.agent/status/<slice>.md` filename — there is no
separate registry; the Stop hook and `status.sh` discover batons
automatically.

- New slice: `./scripts/init-slice.sh <name>`, then add the row to
  `WORKFLOW.md §1`.
- Renaming: edit `WORKFLOW.md §1`, rename `.agent/status/<old>.md`
  → `<new>.md`, rename `.agent/projects/<old>-harness.md`. If the
  slice appears in an archived snapshot, that's frozen history —
  leave it.
- Retiring: set `state: closed` in the baton (or
  `./scripts/handoff.sh --release <name>` for completed work) and
  remove the routing row; the index marks it 🔒/📦.
