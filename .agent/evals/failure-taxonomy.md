# Failure Taxonomy

Track specific failures. Avoid generic labels like "bad answer" or "low quality".

| Failure mode | Description | Example case | Severity | Detection | Owner |
| --- | --- | --- | --- | --- | --- |
| missing-escalation | System should escalate to a human but does not. | `example-001` | high | eval case | team |

## Rules

- Add a new row when a failure cannot be classified.
- Keep failure modes narrow enough to debug.
- Link failure modes to tests, eval cases, or QA checks.
