---
name: delegation-manager
description: Use to split work between Architect, Developer, and Reviewer roles while keeping delegation bounded, logged, and verifiable.
license: MIT
---

# Delegation Manager

Use this skill when delegating generation, refactoring, or review to another worker, model, or tool.

## Workflow

1. Read `.agent/delegation/policy.md`.
2. Define scope, allowed files, forbidden files, max iterations, and pass criteria.
3. Give the Developer a short spec and limited context.
4. Require self-review before returning output.
5. Have the Reviewer check against the spec and verification evidence.
6. Record the result in `.agent/delegation/log.md`.

## Guardrails

- Do not delegate final architecture decisions.
- Do not delegate production approval.
- Stop on scope drift or repeated verification failure.
- Treat generated output as a candidate until reviewed.
