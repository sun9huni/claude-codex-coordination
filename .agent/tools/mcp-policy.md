# MCP And Tool Policy

## Default Policy

- Add MCP servers only when they materially reduce manual work or improve verification.
- Prefer project-scoped configuration over global configuration.
- Prefer on-demand Skills for rarely used tool workflows.
- Do not expose secrets through tool descriptions, examples, or logs.

## Approval Required

Ask before adding tools that can:

- modify production data
- send external messages
- spend money
- access private customer data
- change infrastructure
- persist credentials

## Audit Cadence

- Run `./scripts/tool-audit.sh` after adding tools.
- Review `.agent/tools/inventory.md` monthly.
- Remove or disable tools with no clear owner.
