---
name: brainstorm
description: Upstream spec gate. Explore user intent, requirements, and constraints through Socratic questioning BEFORE any implementation begins. Produces a contract draft at .agent/contracts/<slice>-<topic>-<YYYYMMDD>.md. Use when starting any feature, change, or experiment whose success criterion is not already obvious — and ALWAYS before writing code that would trip WORKFLOW.md §2 contract triggers.
argument-hint: "<free-form topic or goal>"
allowed-tools: Read Grep Edit Write Bash(git status:*) Bash(ls:*) Bash(find:*) Bash(cat:*) Bash(grep:*)
---

# /brainstorm — Spec gate

The work is a hypothesis: *"this change will accomplish X."* If you
cannot state X in a single observable sentence, you do not yet have
a spec — you have a hunch. This skill turns the hunch into a spec.

## HARD-GATE rule

After /brainstorm runs, you DO NOT write production code in the
same turn. The output is a contract draft. The next step is
either:
- user approves the draft → /write-plan to decompose it, OR
- user revises the draft → another /brainstorm round.

If you find yourself reaching for the Edit tool on a `src/` file
during /brainstorm, stop. That's a different skill.

## Step 1 — Restate the goal

In your own words, one sentence: "You want to ___ so that ___."
If you can't fill the second blank, you don't know why — ask.

## Step 2 — Five high-leverage questions

Ask these one at a time, waiting for each answer before the next.
Skip a question only if the user has already answered it
explicitly.

1. **Success criterion.** "How will we know this is done? Name a
   command or observation that distinguishes done from
   not-done."
2. **Out of scope.** "What is intentionally NOT being done in
   this change, even though it sounds related?"
3. **Constraints.** "Any non-negotiable resource, time, dependency,
   or compatibility constraints? (e.g. has to ship before X, must
   keep API compat, < N GPU-hours, no new external deps.)"
4. **Rollback.** "If this ships and we discover a problem, how do
   we undo it?"
5. **Approval gates.** "Does this trigger any approval gate?
   (SLURM submission, DB schema, ranking semantics, 4+ files,
   shared-storage writes, public API change.) If yes, that's
   what this contract is for."

Stop at 3 questions if you have all three of:
(a) one-sentence success criterion, (b) one-sentence rollback,
(c) explicit "yes/no" on whether contract triggers apply.

## Step 3 — Draft the contract

Use `.agent/contracts/_template.md` as a base. Save to:

```
.agent/contracts/<slice>-<short-topic>-<YYYYMMDD>.md
```

Where `<slice>` is one of WORKFLOW.md §1 slice names; `<short-topic>`
is 2-4 hyphenated lowercase words.

Fill in:
- **Status**: `pending`
- **Scope** / **Out of scope** (from Q1/Q2)
- **Triggers matched** (from Q5)
- **Success criteria** (concrete + verification command, from Q1)
- **Resource budget** (from Q3)
- **Approval**: `requested: <today>`, `approved by: pending`
- **Rollback plan** (from Q4)

Leave blank fields that the answers genuinely did not cover.
DO NOT fabricate.

## Step 4 — Show the draft, wait for "approved"

Print the contract path and a 5-line summary:

```
Spec drafted: .agent/contracts/<slug>.md
  Success: <one-line>
  Out of scope: <one-line>
  Triggers: <list or "none">
  Budget: <one-line>
  Rollback: <one-line>

Next step: review the contract. When approved, run /write-plan with this path.
```

Do NOT proceed to /write-plan automatically — the user must
explicitly mark the contract approved (by editing the status line
or saying "approved").

## Red Flags

| Rationalization | Reality |
|---|---|
| "I just want to try X first, we'll spec it after." | Try-first means the spec exists post-hoc, biased to what was easy. Spec now or accept that this is exploratory (in `.agent/scratch/`, not in a project repo). |
| "It's small, no contract needed." | If the change touches files in a slice's project repo and is non-trivial, run /contract-check; let it decide. |
| "The user said 'just do it'." | Even with permission, take 60 seconds to write the success criterion. That criterion is what you'll be measured against. |
| "We can rollback by git revert." | Sometimes. For SLURM submissions, /mnt/data writes, DB changes, "git revert" is not enough. Spell out the recovery. |
| "Out of scope is everything else." | Useless. Name the 2-3 adjacent things that someone might assume are in scope but aren't. |
| "I don't know the constraints yet." | That IS the constraint: this is exploratory, not production. Mark the contract `scope: exploratory` and limit changes to `.agent/scratch/`. |

## Karpathy alignment

- **Think Before Coding**: this skill IS the think step. Spec
  before implementation is non-negotiable.
- **Goal-Driven**: the success criterion in step 2.1 is the
  literal goal. Implementation later is judged by it.
- **Simplicity First**: when the user describes scope, push back
  on anything that smells like "and also...". Adjacent features
  → adjacent contracts.

## When to skip /brainstorm

- The change is a typo, comment fix, dependency bump within a
  patch version, or running a verification command. These don't
  need contracts.
- The work is exploratory in `.agent/scratch/` or `/tmp/` and the
  user explicitly says it's throwaway.
- The change matches an existing approved contract with the same
  scope — extend that contract instead of forking a new one.

## Forbidden

- Do NOT edit any file under a project repo's source tree during
  /brainstorm.
- Do NOT advance to /write-plan in the same turn — the user must
  approve first.
- Do NOT skip the questions just because you "know what the user
  wants" — the spec is what the user actually approves, not what
  you guessed.
- Do NOT bury the spec inside an existing contract that has
  different scope — fork a new file.
