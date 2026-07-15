# Harness KPIs

What we measure to know whether the harness is getting better. Numbers
are not collected automatically — review monthly by reading recent
handoffs, contracts, and PRs.

## Workflow quality

- Average re-request count per task
- Verification-failure → fix loops per task
- Share of tasks needing human intervention mid-implementation
- Repeated review comments per author (signal: rule candidate)
- Diff lines not connected to the request (signal: scope leak)
- New abstractions that were actually reused within 30 days

## Planning discipline

- Failure rate of tasks started without a contract
- Tasks where the contract was edited mid-implementation (signal:
  spec was wrong) — count and severity

## Test and verify discipline

- New features shipped with a new test
- UI changes shipped after a Chrome QA run
- Regressions found post-merge that a smoke or eval case would have
  caught

## Eval and review

- Real failures added to `.agent/evals/dataset.jsonl` per month
- Judge calibration precision / recall vs human label

## Tool and skill hygiene

- Unused / on-demand share of tool inventory
- Drift between `skills/` and `.codex/skills/` (target: 0)
- Skills with no `last-reviewed` within 90 days

## Delegation

- Delegated tasks passing review on first try
- Delegated tasks hitting `max-iterations` cap (signal: contract was
  too vague)

## Continuous improvement

- Patterns promoted from session retros into rule / skill / eval
- Rules retired because they became default behavior
