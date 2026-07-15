# Change Discipline Checklist

Use this checklist before non-trivial coding, refactoring, or review work.

## 1. Surface Assumptions

- State assumptions that affect behavior, data, security, or user experience.
- If the request has multiple plausible meanings, list the interpretations.
- Ask for clarification when choosing silently would create meaningful risk.
- Push back when the requested path is more complex than the needed outcome.

## 2. Prefer The Smallest Adequate Solution

- Do not add features that were not requested.
- Do not introduce configuration, extensibility, or framework code for a single use case.
- Do not add defensive handling for impossible states unless the system already models them.
- If the implementation is getting large, pause and identify the smaller version.

## 3. Keep Changes Surgical

- Touch only files required by the task.
- Match the existing style, even when a different style would be preferable in isolation.
- Do not reformat, rename, rewrite comments, or refactor adjacent code as a side effect.
- Remove unused code created by this change.
- Report pre-existing dead code instead of deleting it unless asked.

## 4. Make Goals Verifiable

- Convert vague tasks into observable success criteria.
- For bugs, reproduce first with a failing test or concrete manual check.
- For features, define successful and failing cases before implementation.
- For refactors, verify behavior before and after.
- Every implementation step should have a check that can pass or fail.

## Completion Signal

The change is disciplined when every diff line maps to the request, the plan, or a verification failure.
