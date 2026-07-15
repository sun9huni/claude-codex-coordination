---
name: eval-harness
description: Use for AI behavior, search, recommendation, RAG, agent, or critical UX-copy changes that need eval data, failure taxonomy, and judge calibration.
license: MIT
---

# Eval Harness

Use this skill when a change affects probabilistic behavior or subjective quality.

## Workflow

1. Read `.agent/evals/eval-plan.md`.
2. Inspect real failures before creating synthetic cases.
3. Add or update cases in `.agent/evals/dataset.jsonl`.
4. Update `.agent/evals/failure-taxonomy.md`.
5. If using an LLM judge, update `.agent/evals/judge-calibration.md`.
6. Run `./scripts/eval.sh`.
7. Record criteria changes in `.agent/evals/criteria-drift.md`.

## Guardrails

- Prefer narrow pass/fail checks over broad quality scores.
- Do not trust uncalibrated LLM judges.
- Keep examples, dev cases, and final test cases separate.
- Do not automate away manual inspection of raw failures.
