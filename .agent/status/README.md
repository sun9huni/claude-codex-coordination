# Slice Status Files

One file per slice defined in `WORKFLOW.md §1`. Filename matches the
slice name: `.agent/status/<slice>.md`.

## Purpose

A human-written, ~25-line snapshot of where the slice is. Read at
session start when entering / resuming that slice. Updated at session
end (overwritten, not appended — git keeps the history).

## Suggested structure

```markdown
# Status: <slice-name> (as of <YYYY-MM-DD>)

## Done
- ✅ <recent milestone>
- ✅ <another>

## In flight
- 🟡 <thing being worked on, link to contract>

## Next action
1. <concrete next step>
2. <second priority>

## Open risks
- <risk + mitigation>

## Pointers
- contract: `.agent/contracts/...`
- harness: `.agent/projects/<slice>-harness.md`
- relevant project repo: `<path>`
```

## Decay

- If mtime > 7 days, the SessionStart hook warns. Refresh it or move
  to a live scan.
- If the slice is dormant, write that explicitly (e.g.
  "Status: dormant since 2026-04-12. Re-evaluate before next sprint").

## Avoiding redundancy

This file describes a slice. The cross-agent SSOT
(`.agent/handoffs/CURRENT.md`) describes the **active** session. There
can be one of each but they overlap. Rule of thumb:

- CURRENT.md = "what the agent is doing right now"
- status/<slice>.md = "what the slice looks like as of the last
  end-of-session refresh"
