# Judge Calibration

Use this when an LLM or heuristic judge is part of evaluation.

## Calibration Set

- source:
- sample size:
- human label owner:
- train/dev/test split:

## Results

| Date | Judge | Dataset | Precision | Recall | Notes |
| --- | --- | --- | --- | --- | --- |
| 2026-05-18 | none configured | none | n/a | n/a | Initial harness install only. |

## Rules

- Do not trust an LLM judge without human-labeled samples.
- Report precision and recall, not only accuracy.
- Keep few-shot examples separate from the final test set.
- Recalibrate after prompt, model, rubric, or data distribution changes.
