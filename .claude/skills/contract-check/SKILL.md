---
name: contract-check
description: Decide whether the current in-flight work requires a contract per WORKFLOW.md §2 (SLURM submission, ranking change, 4+ files modified, FragMap scoring mode, local vs shared concurrent edits). If yes, draft a contract from _template.md. Use before starting any non-trivial FKSFold-Boltz change.
allowed-tools: Read Edit Write Bash(git status:*) Bash(git diff:*) Bash(find:*) Bash(cat:*)
---

# /contract-check — Should this work have a contract?

WORKFLOW.md §2 lists the contract triggers. This skill makes that
check explicit instead of relying on memory.

## Step 1 — Inventory current work

- `git -C FKSFold-Boltz_Advancement status --short` — file count and
  what is dirty.
- `cat .agent/status/<slice>.md` — the active slice's declared goal and
  `remaining_actions` frontmatter (CURRENT.md is the derived lab-wide index).
- Recent commits on the project's active branch.

## Step 2 — Check triggers

The work needs a contract if ANY of these is true. For each, answer
yes/no with evidence:

1. **Diffusion / steering / score scaling semantics changed?**
   Evidence = files under `src/boltz_extension/steering/` or
   `configs/.../scoring*.yaml` in the diff.
2. **Ranking semantics / order / weights changed?**
   Evidence = `vav1_ensemble_rank.py`, `*ranking*.yaml`, or
   `production_rank` references.
3. **SLURM workflow script edited or new submission planned?**
   Evidence = `workflow/slurm_*.sh` dirty or about to `sbatch`.
4. **Benchmark or acceptance metric changed?**
   Evidence = `configs/.../benchmark*` or `acceptance_*` updates.
5. **4 or more files modified in this work scope?**
   Evidence = `git status --short` count ≥ 4.
6. **Local repo and shared workspace edited together?**
   Evidence = both `/home/ubuntu/FKSFold-Boltz_Advancement/` and
   `/mnt/data/users/ubuntu/workspace/FKSFold-Boltz_Advancement_shared/`
   touched.
7. **FragMap scoring mode added?**
   Evidence = new entry in FragMap scoring registry.

## Step 3 — Decide

- **All no** → No contract needed. Tell the user: "No contract trigger
  matched. Proceeding is fine."
- **Any yes** → Contract required. Go to step 4.

## Step 4 — Draft the contract

Copy `.agent/contracts/_template.md` to
`.agent/contracts/<slice>-<short-name>-<YYYYMMDD>.md`. Fill in:
- Scope (what is in / out).
- Triggers matched (list from step 2).
- Success criteria (observable).
- Resource budget (GPU-hours, files, time).
- Approval status — initially `pending`.
- Rollback plan.

Then tell the user the draft path and pause for approval before
proceeding with the work.

## Red Flags

| Rationalization | Reality |
|---|---|
| "Only 3 files, no contract needed." | File-count is one of seven triggers, not the gate. SLURM / ranking / scoring / shared-storage triggers fire **independently** of file count. Check all seven. |
| "Similar contract exists — I'll just extend it." | Different scope, different contract. Extending an unrelated contract pollutes the audit trail. Fork a new file; reference the old one in `Pointers:` if relevant. |
| "SLURM job is small / a smoke test — contract can wait." | The PreToolUse slurm-gate hook will block `sbatch` anyway. Write the contract first, even if 5 lines. |
| "I'll mark the contract approved myself after I write it." | Approval comes from the user, not from `/contract-check`. Status stays `pending` until the user says approved or edits the file directly. |
| "The scoring change is just a coefficient tweak — not really semantic." | If a downstream metric (F1, RMSD, ranking order) could change for any compound, it's semantic. Trigger fires. |
| "I'll act now and write the contract retroactively." | The contract is a *commitment*, not a *record*. Retroactive contracts have zero value — they're rationalization-as-paperwork. Don't bother; act under the slurm-gate's automatic block or pause for explicit user approval. |

## Forbidden

- Do NOT submit SLURM jobs, change ranking, or otherwise act on the
  work before the user marks the contract `approved`.
- Do NOT skip step 4 just because a similar contract exists — different
  scope, different contract.
