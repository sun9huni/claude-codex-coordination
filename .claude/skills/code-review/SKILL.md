---
name: code-review
description: Review the current change set (uncommitted diff by default, or a specific file / PR / commit-range) through five lenses — correctness, design, simplicity, surgicality, testability — plus Karpathy's four behavioral guardrails. Produces a prioritized, opinionated review with concrete suggested edits, not vague "consider X" hedging. Use before /handoff for any non-trivial change, before opening a PR, or when reviewing someone else's branch.
argument-hint: "[file-path | <commit>..<commit> | PR# | (empty = uncommitted diff)]"
allowed-tools: Read Grep Bash(git status:*) Bash(git diff:*) Bash(git log:*) Bash(git show:*) Bash(gh pr view:*) Bash(gh pr diff:*) Bash(grep:*) Bash(find:*) Bash(wc:*)
---

# /code-review — Opinionated change-set review

A change is a hypothesis: *"this edit accomplishes X without breaking
anything."* Your job is to test that hypothesis hard. Default to
**request-changes**; only approve when you have actively looked for
issues and found none worth blocking on.

## Step 1 — Identify scope

Resolve `$ARGUMENTS`:
- empty → uncommitted diff in the project repo you are in. Use
  `git -C <project-repo> diff` (working tree vs HEAD) and `git diff --cached`.
- a file path → `git -C <repo> log -p -5 -- <path>` to see recent edits.
- `<sha1>..<sha2>` → `git diff <sha1>..<sha2>`.
- `PR#<n>` → `gh pr view <n> --json files,title,body` + `gh pr diff <n>`.

If the diff is > 500 lines, ask the user to narrow scope. Don't try
to review the whole thing at once — reviews of that size degrade fast.

## Step 2 — Read in this order

1. Commit message / PR description (states the intent).
2. The diff itself.
3. The *unchanged* surroundings of each hunk — context, callers,
   tests that exercise the touched code.
4. The relevant `.agent/projects/<slice>-harness.md` if the change is
   in a known slice.

Do not skip step 3. Reviewing a hunk without its context produces
opinions that are confidently wrong.

## Step 3 — Apply five lenses

For each hunk, walk these in order. Stop at the first one that
returns *block* and report it; otherwise continue.

| Lens | The question |
|---|---|
| **Correctness** | Does this do what the commit message claims? Off-by-one? Null/empty edge cases? Error paths? Race conditions on shared state? |
| **Design** | Is the abstraction at the right level? Does the name reflect intent? Is anything tightly coupled to something that should be swappable? |
| **Simplicity** | Could fewer lines achieve the same outcome? Is there premature abstraction (interface for one impl, factory for one type, config for one value)? Three similar lines beats one half-finished generalization. |
| **Surgicality** | Does the diff touch anything unrelated to the stated goal? "While I'm here" cleanups don't belong in a feature PR. |
| **Testability** | Can this code be tested without infrastructure heroics? Are tests included? Do existing tests still cover the changed lines? |

For each finding cite `path:line` and propose a **concrete edit**,
not a question. "Consider extracting" is hedging; "extract lines
N-M into `foo()` because both call sites copy this block" is review.

## Step 4 — Karpathy guardrails (apply across the whole change)

These are the four principles every change must clear. Cite the
specific one when calling out a violation.

1. **Think Before Coding.** Was the intent clear from commit message
   or contract? If not, the change should not be approved until the
   goal is documented.
2. **Simplicity First.** Is anything over-engineered for hypothetical
   future needs? Flag every "we might want to..." abstraction.
3. **Surgical Changes.** Is the scope tight? Renames, reformats, and
   incidental refactors belong in separate commits.
4. **Goal-Driven.** Is the success criterion verifiable? "Faster" is
   not. "Reduces p99 latency from 800ms to <400ms on benchmark X" is.

## Step 5 — Red Flags table

Before approving, mentally walk this table. If you are about to
write any of the left-hand phrases, the right-hand objection wins.

| Rationalization (don't accept) | Reality (state this instead) |
|---|---|
| "It's just a small refactor on top of the fix." | Two commits or two PRs. Reviewers can't undo half of one PR. |
| "We'll add tests later." | Tests now or the test plan in the PR body, with an open ticket. |
| "The existing pattern does it this way." | Either the pattern is right (cite it) or the pattern is wrong (fix it elsewhere first). "It matches" is not justification. |
| "It works in my local env." | Verification command + output, or the reason it could not run. |
| "The user wanted it this way." | Quote the user; if the message is ambiguous, the reviewer should not bridge the gap silently. |
| "It's only used in one place." | Then inline it. One-call-site abstractions are noise. |
| "Future-proofing." | YAGNI. Build the thing that solves today's problem; abstract on the second concrete need. |

## Step 6 — Output

```
## /code-review summary
- Scope: <files/lines/PR>
- Verdict: REQUEST_CHANGES | APPROVE_WITH_NITS | APPROVE
- Lenses triggered: <list>
- Karpathy violations: <list, or "none">

## Critical (must address before merge)
- [path:line] <issue> — <concrete fix>
- ...

## Important (should address)
- ...

## Nits (optional)
- ...

## Notes
- <anything that helps the author, not a blocker>
```

Keep it under 60 lines unless the change really demands it.

## Forbidden

- Do NOT approve without naming what you actually checked. "LGTM"
  with no findings is a signal you skimmed.
- Do NOT block on style if a formatter would fix it (the
  `post-edit-format.sh` hook is already running on `.py`).
- Do NOT propose alternate designs in a critical/important section.
  Either it ships as-is with caveats, or it's blocked with a single
  specific change request — not a redesign.
- Do NOT bikeshed naming if names are merely meh. Flag only names
  that actively mislead.
