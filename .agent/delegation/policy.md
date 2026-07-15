# Delegation Policy

Use this when delegating generation, review, or refactoring to another model, tool, or worker.

## Roles

- `Architect`: decomposes requirements, writes the spec, verifies final result.
- `Developer`: generates or modifies code within a bounded scope.
- `Reviewer`: checks the result against the spec and verification evidence.

## Allowed Delegation

- boilerplate generation
- repetitive refactors
- large test generation
- first-pass code review
- migration draft

## Not Delegated

- final architecture decision
- production approval
- security-sensitive policy choice
- schema or migration approval
- final merge decision

## Required Contract

- scope:
- input context:
- allowed files:
- forbidden files:
- max iterations:
- pass criteria:
- stop criteria:

## Stop Criteria

- scope drift
- repeated verification failure
- max iterations reached
- uncertainty about requirements
- security or data risk
