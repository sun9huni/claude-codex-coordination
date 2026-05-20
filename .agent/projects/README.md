# Project Harness Files

One file per slice (and optionally one per date-stamped snapshot).
Deeper than `.agent/status/<slice>.md` — these are the *workflow
designs* an agent reads when the status file is not enough.

## When to read

- A new agent is taking over a slice and needs to learn the pipeline
  vocabulary, key files, and pitfalls.
- The work is about to hit a non-trivial decision point that the
  status file does not cover.

## Naming

```
<slice>-harness.md                  # stable, evergreen workflow detail
<slice>-<topic>-<YYYYMMDD>.md       # time-stamped snapshots (e.g. activity logs, file maps)
```

## Suggested structure

```markdown
# <slice> harness

## Mental model
- Pipeline stages
- Vocabulary unique to this slice
- Where each kind of file lives

## File map
- `<key dir 1>`: <what's there>
- `<key dir 2>`: <what's there>

## Common workflows
- "How to add a new ..."
- "How to investigate a failure of ..."

## Pitfalls (avoid these)
- ...

## Verification
- How to know the slice is healthy
- Smoke / eval / regression checks
```

## Distinction from `.agent/contracts/`

- Harness = workflow design (durable).
- Contract = single-change commitment (ephemeral, lifecycle ends).

A harness can reference contracts (which past contracts shaped the
current design); contracts can reference the harness (which workflow
they extend or modify).
