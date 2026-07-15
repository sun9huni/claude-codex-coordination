# Skill-Tuning Discipline (Path A)

When you revise a skill or prompt document — any `.claude/skills/*/SKILL.md`,
`skills/*/SKILL.md`, or prompt template — apply these three rules. They are
distilled from Microsoft **SkillOpt** (text-space skill optimization), adopted
as a *manual* discipline. We do **not** run SkillOpt's automated training loop
(see "Why manual" below).

## The three rules

1. **Held-out gate.** Before editing, set aside a few example cases you will
   NOT look at while writing the change. After editing, check the skill against
   them. Accept the edit only if it *strictly improves* (or at least does not
   regress) on the held-out set — not just on the cases that motivated it.
   Editing to fix the cases in front of you overfits the skill to them.
2. **Rejection buffer.** When an edit regresses, record it (one line: what you
   tried, what it broke). Do not silently retry the same direction next session.
   Negative results are state worth keeping.
3. **Bounded edit.** Prefer small add/delete/replace edits over full rewrites.
   A skill that drifts one bounded edit at a time stays reviewable; a wholesale
   rewrite loses the institutional memory encoded in the prior wording.

## When to apply
Any non-trivial revision to a skill's instructions, routing tables, red-flag
lists, or prompt templates. Trivial typo/format fixes are exempt.

## Why manual (not the SkillOpt loop)
The automated SkillOpt loop needs a repeatable, side-effect-free task batch with
a programmatic scorer. Almost all our skills are one-shot, stateful, and
side-effecting (`/handoff`, `/execute-plan`, …) — no scorer, no rollback. The
one clean candidate, `/route`, was diagnosed zero-compute and **killed**: a
3-line hand-fix saturated its accuracy ceiling (67.9%→96.4%), leaving the
learning loop with negligible marginal value. Lesson: **hand-fix and diagnose
first; a learning loop is only worth it once a clean scorer + real headroom both
exist.** Full diagnosis: `.agent/scratch/skillopt_route_prereg/PREREG.md`.

## If a SkillOpt env is ever wanted
Pick a skill that is (a) repeatable, (b) side-effect-free, (c) auto-scorable with
gold labels, AND (d) has measured headroom a hand-fix can't close. Pre-register
the GO/KILL gates *before* building (as `/route` did). `/route` is not it.
