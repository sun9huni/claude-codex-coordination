---
name: ui-qa
description: Use after any UI / frontend / dashboard change. Drives Chrome-based manual QA — golden path, edge cases, regressions, accessibility, responsive — and records the result.
license: MIT
---

# UI QA

Code change correctness ≠ feature correctness. UI changes must be
exercised in a browser before the task is reported as done.

## Workflow

1. Read the contract. Identify the golden path and 1–3 edge cases.
2. Start the dev server (or open the deployed URL). For remote work,
   open the SSH tunnel first per `.agent/remote/runbook.md`.
3. Walk through `.agent/qa/browser-checklist.md`:
   - Golden path completes end-to-end.
   - Edge cases produce the documented behavior.
   - Network failures, empty states, long content, slow responses.
   - Keyboard navigation and focus visible.
   - Color contrast and aria labels on new interactive elements.
   - Mobile width (≤375px), tablet (~768px), desktop.
4. Capture evidence:
   - Screenshots into `.agent/qa/runs/<YYYYMMDD-HHMM>/`.
   - Console errors and network 4xx/5xx noted.
5. Compare against the previous build for unintended regression on
   adjacent screens (not just the one changed).
6. Report PASS / PARTIAL / FAIL with a per-check matrix.

## Guardrails

- Do not declare PASS without actually running the dev server.
- If you cannot run the UI (env missing, ssh tunnel down), state so
  explicitly and mark verification "not run".
- Do not fix bugs you find mid-QA. Log them and continue the matrix.
- Do not skip accessibility checks because "the design didn't mention
  it".

## Output

- PASS / PARTIAL / FAIL
- Check matrix (per item: ok / fail / not-run, with note)
- Screenshot directory path
- Bugs found, with reproduction steps
- Adjacent regressions found (if any)
