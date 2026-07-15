# Knowledge Provenance

Track where compiled knowledge came from and how confident the relationship is.

| Knowledge item | Source | Type | Confidence | Last checked | Notes |
| --- | --- | --- | --- | --- | --- |
| Codex harness design | `.agent/knowledge/raw/sources/codex-harness-design.md` | source-backed | high | 2026-05-18 | Copied from uploaded harness package. |
| Codex harness usage guide | `.agent/knowledge/raw/sources/codex-harness-usage-guide.md` | source-backed | high | 2026-05-18 | Copied from uploaded harness package. |

## Type Labels

- `source-backed`: directly supported by raw source material.
- `extracted`: deterministically extracted from code, schema, or structured files.
- `inferred`: synthesized by Codex or another AI tool.
- `ambiguous`: plausible but not confirmed.

## Maintenance Rules

- Do not delete provenance rows when facts change. Mark them stale and add a replacement row.
- Prefer source-backed or extracted facts for architectural decisions.
- Treat inferred links as navigation aids, not final truth.
