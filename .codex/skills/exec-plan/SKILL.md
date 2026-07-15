---
name: exec-plan
description: Use when a request will touch 5+ files, refactor, change domain rules, or take more than ~30 minutes. Converts the request into a contract under .agent/contracts/ before any implementation.
license: MIT
---

# Exec Plan

Large work needs a plan locked before code is written. This skill turns
a free-form request into a contract document the human approves.

## Workflow

1. Restate the request in observable terms (what changes for the user).
2. List assumptions and open questions. Mark each open question as
   blocking or non-blocking.
3. Map the in-scope surface: files, modules, configs, tests.
4. Define "Done when" — the exact behaviour or test result that ends
   the task.
5. Define "Do not change" — files, modules, behaviors out of scope.
6. Define verification: command + expected signal per step.
7. Identify risks: data, perf, security, regression surface.
8. Specify rollback / recovery path.
9. Write the contract to `.agent/contracts/<task>-<YYYYMMDD>.md` using
   `.agent/templates/contract.md` as the base.
10. Stop. Wait for human approval before any code change.

## Guardrails

- Do not start implementation in the same turn as planning.
- Do not collapse blocking questions into "I will assume X" silently.
- Keep the contract under ~200 lines. Long context = drifted scope.
- One contract per task. No multi-task contracts.

## Output

- Path to the contract written.
- The 3 blocking questions, if any.
- "Awaiting approval" — do not proceed.
