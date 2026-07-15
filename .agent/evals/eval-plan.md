# Eval Plan

Use this plan for AI behavior, search, ranking, recommendation, RAG, agent, or critical copy changes.

## Goal

- behavior under evaluation:
- user-visible risk:
- owner:

## Data Sources

- production traces:
- bug reports:
- review findings:
- support tickets:
- synthetic edge cases:

## Dataset Split

- examples:
- dev:
- test:

## Metrics

Prefer narrow pass/fail checks tied to real failure modes.

- primary metric:
- secondary metric:
- guardrail metric:

## Judge Policy

- judge type: human / deterministic / LLM
- calibration sample:
- expected precision:
- expected recall:
- last calibrated:

## Reporting

Every report should include:

- cases run
- pass/fail by failure mode
- newly discovered failure modes
- examples inspected manually
- criteria drift notes
