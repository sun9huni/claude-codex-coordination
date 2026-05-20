---
name: route
description: Map a free-form work signal to the right slice + harness file using WORKFLOW.md §1. Use at session start when the work area isn't obvious from CURRENT.md, or whenever the user's request mentions a topic but not a slice name.
argument-hint: "<free-form description of the work>"
allowed-tools: Read
---

# /route — Workspace router

Match `$ARGUMENTS` against the routing table in `WORKFLOW.md §1`.

## Workflow

1. **Read `WORKFLOW.md`** in full at invocation time so you use the
   live routing table, not a snapshot.
2. Scan `$ARGUMENTS` for the work-signal phrases in column 1.
3. **One match** → output the block format below and suggest reading
   `.agent/status/<slice>.md` next.
4. **Multiple plausible matches** → list them and ask the user to
   pick. Do NOT guess silently.
5. **No match** → do NOT invent a slice. Tell the user either to
   (a) clarify the work, or (b) add a row to `WORKFLOW.md §1` for the
   new domain.
6. **Empty routing table** → tell the user this is a fresh template
   and they need to fill in §1 before this skill is useful.

## Output

```
slice:   <name>
harness: <path to .agent/projects/<slice>-harness.md>
status:  <path to .agent/status/<slice>.md, or "no static status yet">
remind:  <one-line caveat from §1 column "critical reminder">
```

Then a one-line suggestion: "Read `.agent/status/<slice>.md` next, or
run `/slice-status <slice>` for the consolidated view."
