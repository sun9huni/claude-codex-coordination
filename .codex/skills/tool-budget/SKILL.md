---
name: tool-budget
description: Use when adding, removing, auditing, or optimizing MCP servers, plugins, CLIs, browser tools, and other external tools used by Codex.
license: MIT
---

# Tool Budget

Use this skill when tool context, MCP schemas, or plugin sprawl could affect Codex performance.

## Workflow

1. Read `.agent/tools/mcp-policy.md`.
2. Update `.agent/tools/inventory.md`.
3. Classify each tool as `core`, `project`, `on-demand`, or `disabled`.
4. Update `.agent/tools/context-budget.md`.
5. Run `./scripts/tool-audit.sh`.
6. Record findings in `.agent/tools/audit-log.md`.

## Guardrails

- Do not add a tool without an owner and purpose.
- Do not expose secrets through tool docs or examples.
- Prefer on-demand Skills for rarely used tools.
- Remove or disable unused tools.
