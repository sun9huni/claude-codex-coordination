---
name: contract-check
description: Decide whether the in-flight work needs a contract per WORKFLOW.md §2 triggers (long-running job submission, 4+ files changed, ranking/eval change, API contract change, multi-write-scope edit, etc.). If yes, draft a contract from .agent/contracts/_template.md. Use before starting any non-trivial change.
allowed-tools: Read Edit Write Bash(git status:*) Bash(git diff:*) Bash(find:*) Bash(cat:*)
---

# /contract-check — Should this work have a contract?

`WORKFLOW.md §2` lists the contract triggers for this project. This
skill makes the check explicit instead of relying on memory.

## Step 1 — Inventory current work

- `git status --short` — file count and what is dirty.
- `cat .agent/handoffs/CURRENT.md` — declared goal and remaining
  actions.
- Recent commits on the active branch.

## Step 2 — Check triggers

Read `WORKFLOW.md §2` and evaluate each listed trigger against the
current work. For each, answer yes/no with evidence (file path, diff
line count, etc.).

If `WORKFLOW.md §2` is empty (fresh template), use these defaults:

1. **4 or more files modified** in one logical change?
2. **Long-running / expensive job** about to be submitted (training,
   HPC, batch ETL, paid API at scale)?
3. **Ranking / scoring / evaluation semantics** changed?
4. **Public API contract** changed?
5. **Two write scopes** in one task (e.g. local repo + shared
   storage, or two separate repos)?
6. **New "mode" added** to a feature with a registry of modes?

## Step 3 — Decide

- **All no** → No contract needed. Report: "No contract trigger
  matched. Proceeding is fine." and stop.
- **Any yes** → Contract required. Go to step 4.

## Step 4 — Draft the contract

Copy `.agent/contracts/_template.md` to
`.agent/contracts/<slice>-<short-name>-<YYYYMMDD>.md`. Fill in:

- **Scope** — what is in / out.
- **Triggers matched** — list from step 2.
- **Success criteria** — observable, measurable.
- **Resource budget** — files, time, GPU/CPU/$, etc.
- **Approval status** — `pending` initially.
- **Rollback plan** — how to undo if it goes wrong.

Then tell the user the contract path and pause for approval before
proceeding with the work.

## Red Flags

| Rationalization | Reality |
|---|---|
| "Only 3 files, no contract needed." | File-count is one of several triggers, not the gate. Long-running-job / API-change / ranking-change triggers fire **independently** of file count. Check all triggers in `WORKFLOW.md §2`. |
| "Similar contract exists — I'll just extend it." | Different scope, different contract. Extending an unrelated contract pollutes the audit trail. Fork a new file; reference the old one in `Pointers:` if relevant. |
| "The expensive job is small / a smoke test — contract can wait." | If a SLURM gate (or equivalent) is enabled, submission is blocked anyway. Write the contract first, even if 5 lines. |
| "I'll mark the contract approved myself after I write it." | Approval comes from the user, not from `/contract-check`. Status stays `pending` until the user says approved or edits the file directly. |
| "The change is just a coefficient tweak — not really semantic." | If a downstream metric (an evaluation score, a ranking order, a user-visible output) could change, it's semantic. Trigger fires. |
| "I'll act now and write the contract retroactively." | The contract is a *commitment*, not a *record*. Retroactive contracts have zero value — they're rationalization-as-paperwork. |

## Forbidden

- Do NOT submit jobs, change ranking, or otherwise act on the work
  before the user marks the contract `approved`.
- Do NOT skip step 4 just because a similar contract exists —
  different scope, different contract.
