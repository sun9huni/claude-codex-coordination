---
name: route
description: Map a free-form work signal to the right slice + harness file using WORKFLOW.md §1. Use at session start when the work area isn't obvious from the CURRENT.md index, or whenever the user's request mentions a topic but not a slice name.
argument-hint: "<free-form description of the work>"
allowed-tools: Read
---

# /route — Workspace router

Match `$ARGUMENTS` against `WORKFLOW.md §1` and pick exactly one slice.

## Routing table (from WORKFLOW.md §1)

| Signal in `$ARGUMENTS` | Slice | Harness | Reminder |
|---|---|---|---|
| SILCS-Lite map build (GCMC/GrandLig/probe/channel/GFE), FragMap scoring/overlay, 9NFR pharmacophore | `fragmap` | `.agent/projects/aigen-fold-fragmap-9nfr-harness.md` | map-build & scoring only; placement/steering execution & validation (held-out, AB) route to aigen-fold-core (this slice produces maps); 6-step ladder, do not skip |
| MMGBSA, SLURM, F105, normtest143, DDG merge, backup import | `mmgbsa` | `.agent/projects/aigen-fold-mmgbsa-slurm-harness.md` | Stage 1–4 separate reports, SLURM after approval |
| VAV1 ranking, `vav1_ensemble_rank.py`, `*ranking*.yaml` | `vav1` | `.agent/projects/vav1-ranking-harness.md` | shared = active; keep baseline + production modes |
| `src/boltz`, steering internals/execution, generation/placement validation (held-out, AB, DockQ), boltz/steering config, workflow script | `aigen-fold-core` | `.agent/projects/aigen-fold-boltz-core-harness.md` | Do not mix boundary slices; FragMap 'map/scoring' routes to fragmap (this slice consumes maps); bare `configs` is not a signal |
| ARL, paper discovery, LangGraph, coscientist | `arl` | `.agent/projects/arl-threads-coscientist-harness.md` | `make check` only; `make ci-full` / `test-integration` are human-only (bare `experiments` is not a signal) |
| harness, Notion sync, ADR/Decisions/Experiments DB, runbook, skill/hook, Navigator, `notion_sync.py` | `harness` | `.agent/status/README.md` (baton schema) + `CLAUDE.md` | process words (baton/handoff/status) are **shared across all slices → not routing keywords**; ask the user if ambiguous. Never hand-edit `CURRENT.md` |
| "Where is this file" / local vs shared / CLI/config merge | (file-map) | `.agent/projects/aigen-fold-actual-file-map-20260518.md` | local is dirty; shared has active version |
| "What happened last week" / new Cursor plan detection | (activity) | `.agent/projects/recent-cursor-activity-20260518.md` | Stale after 1 week; rescan |

## Workflow

1. Read `WORKFLOW.md` § 1 to confirm the routing table is unchanged
   from the table above. If it is, the routing table here is the
   wrong copy — use the one in WORKFLOW.md and tell the user.
2. Scan `$ARGUMENTS` for the signal phrases.
3. If multiple slices plausibly match, list them and ask the user to
   pick. Do not guess silently.
4. If none match, do NOT invent a slice. Tell the user to add a
   routing row or to clarify the work.

## Output

Single block:
```
slice:   <name>
harness: <path>
remind:  <one-line caveat>
status:  <.agent/status/<slice>.md if exists, else "no static status">
```

Then suggest reading `.agent/status/<slice>.md` next.

## Red Flags

| Rationalization | Reality |
|---|---|
| "FragMap is mentioned — going with `fragmap`." | One keyword isn't routing; it's pattern-matching. Verify the work signal actually fits §1's intent column, not just shares a word. |
| "Multiple slices match — I'll pick the most active one." | Don't guess. List the candidates and ask the user. Routing silently picks the *wrong* slice silently. |
| "No row matches — I'll invent a new slice." | Forbidden. New slices need a `WORKFLOW.md §1` row + `VALID_SLICES` entry + status + harness files. Tell the user to add them (or run the project's slice-init helper), not to guess one. |
| "User typed a slice name directly — I'll just use it." | Verify it's in §1. A misspelling or stale alias should be caught here, not 5 turns later when the Stop hook rejects `active_slice`. |
| "Empty `$ARGUMENTS` — I'll infer from the open files / cwd." | Ask the user explicitly. Inference from incidental context is exactly the silent-routing failure mode. |
| "The routing table in this skill body looks current." | Read `WORKFLOW.md §1` at invocation time. If it differs from the snapshot here, this skill is out of date — flag it, then route from the live file. |

## Forbidden

- Do NOT invent a slice when no row matches. Tell the user to add a routing row first.
- Do NOT fuzzy-match slice names. The §1 table is authoritative.
- Do NOT embed a copy of the routing table in this skill — read `WORKFLOW.md §1` at invocation time.
- Do NOT proceed to load `.agent/projects/<slice>-harness.md` content automatically; just point at the file path.
