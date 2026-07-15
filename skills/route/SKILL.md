---
name: route
description: Use when mapping a free-form workspace request to the right slice, status file, and harness document using WORKFLOW.md §1.
license: MIT
---

# Route

Map a work signal to exactly one workspace slice. The live routing table
is `WORKFLOW.md §1`; read it at invocation time and prefer it over this
summary.

## Workflow

1. Read `.agent/handoffs/CURRENT.md` and `WORKFLOW.md §1`.
2. Match the user's request to one slice only:
   - `fragmap` — FragMap, 9NFR, pharmacophore, target occupancy.
   - `mmgbsa` — MMGBSA, SLURM, F105, normtest143, DDG merge, backup import.
   - `vav1` — VAV1 ranking, `vav1_ensemble_rank.py`, `*ranking*.yaml`.
   - `fksfold-core` — `src/boltz`, steering internals, Boltz/steering config,
     workflow script.
   - `arl` — ARL, paper discovery, LangGraph, coscientist.
   - `harness` — Notion sync, ADR/Decisions/Experiments DB, runbook,
     skill/hook, Navigator, `notion_sync.py`.
3. If multiple slices plausibly match, ask the user to choose.
4. If no row matches, do not invent a slice; ask for clarification or a
   routing-table update.
5. Output the slice, status file, harness/deep-dive file, and one caveat.

## Guardrails

- Process words like baton, handoff, or status are shared across slices; they
  are not enough to route to `harness` by themselves.
- Do not hand-edit `.agent/handoffs/CURRENT.md`; it is generated.
- Do not fuzzy-match slice names.
- If this skill's summary differs from `WORKFLOW.md §1`, use `WORKFLOW.md`
  and report that this skill needs a refresh.
