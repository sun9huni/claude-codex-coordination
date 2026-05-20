# Contract: <slice>-<short-topic>-<YYYYMMDD>

> Copy this file to `<slice>-<short-topic>-<YYYYMMDD>.md` and fill in
> every section. A contract is the written commitment that an agent
> (and the user) sign off on before non-trivial work proceeds.

## Status

`pending` | `approved` | `done` | `cancelled`

(Start at `pending`. The user marks `approved` before work proceeds.)

## Scope

What is in scope (one or two paragraphs). Be concrete: files,
features, behaviors.

### Out of scope

What is intentionally excluded so it does not creep in.

## Triggers matched (from WORKFLOW.md §2)

- `<trigger 1>` — evidence: `<path or fact>`
- `<trigger 2>` — evidence: `<path or fact>`

## Success criteria

How we will know this contract is satisfied. Observable, measurable:

- [ ] `<criterion 1>` — verification: `<command or check>`
- [ ] `<criterion 2>` — verification: `<command or check>`
- [ ] `<criterion 3>` — verification: `<command or check>`

## Resource budget

| Resource | Budget | Notes |
|---|---|---|
| Files modified | `<N>` |  |
| Wall-clock time | `<H>` h |  |
| Compute | `<GPU-h / API-$ / etc.>` |  |
| External services | `<list>` |  |

## Approval

- Requested: `<YYYY-MM-DD>`
- Approved by: `<user>` on `<YYYY-MM-DD>` — or `pending`.

## Rollback plan

If this goes wrong:

1. `<step 1>`
2. `<step 2>`

## Notes / decisions during execution

(Append as you go.)
