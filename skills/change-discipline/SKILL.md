---
name: change-discipline
description: Use before writing, reviewing, or refactoring code to surface assumptions, keep changes minimal, avoid unrelated edits, and define verifiable success criteria.
license: MIT
---

# Change Discipline

Apply this skill for non-trivial implementation, debugging, refactoring, and code review.

## Workflow

1. Restate the goal in observable terms.
2. List assumptions, ambiguity, and meaningful tradeoffs.
3. Choose the smallest adequate implementation.
4. Define what files or modules are in scope.
5. Pair each implementation step with a verification check.
6. After editing, review the diff for unrelated changes.

## Guardrails

- Do not silently choose between materially different interpretations.
- Do not add speculative features, extension points, or abstractions.
- Do not refactor adjacent code unless the task requires it.
- Do not remove pre-existing dead code unless explicitly asked.
- Do clean up unused imports, variables, and functions introduced by your own change.

## Output

For planning work, add assumptions, scope, and step-by-step verification to the task contract.

For implementation work, report:

- what changed
- what stayed intentionally untouched
- what verification ran
- any remaining ambiguity or risk
