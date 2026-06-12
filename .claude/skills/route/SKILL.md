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

## Red Flags

| Rationalization | Reality |
|---|---|
| "One keyword matched — going with that slice." | One keyword isn't routing; it's pattern-matching. Verify the work signal actually fits §1's intent, not just shares a word. |
| "Multiple slices match — I'll pick the most active one." | Don't guess. List the candidates and ask the user. Routing silently picks the *wrong* slice silently. |
| "No row matches — I'll invent a new slice." | Forbidden. New slices need a `WORKFLOW.md §1` row + status + harness files. Tell the user to add them (or run `./scripts/init-slice.sh`), not to guess one. |
| "User typed a slice name directly — I'll just use it." | Verify it's in §1. A misspelling or stale alias should be caught here, not 5 turns later when there's no `.agent/status/<slice>.md` baton to claim. |
| "Empty `$ARGUMENTS` — I'll infer from the open files / cwd." | Ask the user explicitly. Inference from incidental context is exactly the silent-routing failure mode. |
| "I'll embed a copy of the routing table in this skill body." | The table lives in `WORKFLOW.md §1` — read it at invocation time. An embedded copy goes stale silently. |

## Forbidden

- Do NOT invent a slice when no row matches. Tell the user to add a routing row first.
- Do NOT fuzzy-match slice names. The §1 table is authoritative.
- Do NOT embed a copy of the routing table in this skill — read it at invocation time.
- Do NOT proceed to load `.agent/projects/<slice>-harness.md` content automatically; just point at the file path.
