---
name: review-skeptical
description: Use to review a diff or PR with a bug-hunting mindset. Prioritizes behavioral regressions, missing tests, boundary errors, security issues, and scope leakage. Not for style nitpicks.
license: MIT
---

# Skeptical Review

Review the diff as if it will break in production. The default
assumption is that the change introduces a regression somewhere.

## Workflow

1. Read the contract (`.agent/contracts/<task>.md`) if one exists. Note
   "Done when" and "Do not change".
2. Read `git diff` against the merge base. Note every file touched.
3. For each touched file ask:
   - What behavior changed?
   - What input or state could now produce a wrong output?
   - What boundary conditions are untested?
   - What error path is silently swallowed?
   - What concurrent or async edge case is new?
4. For tests:
   - Does any new test actually exercise the new code path?
   - Are any deleted tests load-bearing?
   - Are mocks hiding integration risk?
5. For scope:
   - Any file touched that is not justified by "Done when"?
   - Any unrelated refactor or reformat?
   - Any new abstraction with a single caller?
6. For security:
   - Auth, authz, input validation, secrets, deserialization, SSRF.
7. Report findings as: file:line — severity — concrete fix or test
   suggestion.

## Guardrails

- Do not approve based on "looks clean". Cite evidence per file.
- Style and naming are non-blocking unless they hide a bug.
- Do not propose unrelated improvements.
- If "Done when" is not verifiable from the diff, that itself is a
  blocking finding.

## Output

- Blocking findings (must fix before merge)
- Non-blocking findings (worth noting)
- Missing verification (commands or tests the author should run)
- Scope leakage (files outside "Done when")
