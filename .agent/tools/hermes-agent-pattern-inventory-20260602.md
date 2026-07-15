# Hermes Agent Pattern Inventory

Date: 2026-06-02
Slice: harness
Source repo: https://github.com/NousResearch/hermes-agent
Source baseline: `272c2f30aa60d6d98b2c97dde6ba42a9231d4f56`
Contract: `.agent/contracts/harness-hermes-agent-port-20260602.md`

## Disposition Labels

- `port`: implement a small harness change in this contract
- `reference`: keep as design guidance only
- `defer`: useful, but needs a later contract
- `reject`: conflicts with current harness ownership, approval gates, or tool budget

## Skills And Skill Metadata

| Hermes surface | Disposition | Harness mapping | Rationale |
| --- | --- | --- | --- |
| `tools/skills_tool.py` progressive disclosure | reference | `SKILL.md` authoring and skill-lint guidance | Good model for keeping skill bodies discoverable without loading every reference eagerly. |
| `tools/skill_manager_tool.py` direct skill mutation | reject | no direct writes to `skills/`, `.codex/skills`, or `.claude/skills` | Our skill changes must remain registry-backed, reviewable, and mirror-verified. |
| `optional-skills/` catalog | defer | future governed skill candidates | Useful source of ideas, but auto-import would bypass team governance. |
| pinned or protected skills | reference | future skill registry metadata | Useful policy concept; not needed for this first contract. |

## Tools, Toolsets, And MCP Surfaces

| Hermes surface | Disposition | Harness mapping | Rationale |
| --- | --- | --- | --- |
| `tools/registry.py` central registry | reference | `.agent/tools/inventory.md` and `tool-audit.sh` | Good model for explicit ownership and availability, but code copy is unnecessary. |
| `toolsets.py` named toolsets | port | side-effect classes in `.agent/tools/inventory.md` | Helps classify context cost and risk for new tools. |
| `tools/mcp_tool.py` optional MCP integration | defer | future MCP-specific contract | Large surface that can carry credentials and external effects. |
| broad core toolset with browser, computer-use, messaging, cron, and code execution | reject | no default enablement | Too much blast radius for the current harness. |

## Approvals And Subagents

| Hermes surface | Disposition | Harness mapping | Rationale |
| --- | --- | --- | --- |
| `tools/approval.py` dangerous-command patterns | reference | root `AGENTS.md` approval gates and tool policy | Useful comparison source, but root approval gates remain authoritative. |
| subagent blocked-tool list in `tools/delegate_tool.py` | reference | Codex subagent rules and delegation skills | Good design reference for preventing recursive or high-risk delegation. |
| subagent auto-deny dangerous commands | reference | future delegation-manager checklist | Useful concept; no immediate code change. |
| cron approval mode | reject | no cron sidecar in this phase | Non-interactive approvals are not needed and increase risk. |

## Memory, Session Search, And State

| Hermes surface | Disposition | Harness mapping | Rationale |
| --- | --- | --- | --- |
| `hermes_state.py` SQLite and FTS5 session search | defer | future read-only `.agent` baton index | Potentially useful, but implementation would be a separate search prototype. |
| `~/.hermes` state root | reject | `.agent/` remains source of truth | A second durable state root would create handoff drift. |
| session compression and splitting | reference | future handoff-history design | Useful concept if handoff logs grow large. |

## Rejected Runtime Surfaces

The following Hermes runtime surfaces are out of scope for this contract:

- global Hermes install
- `HERMES_HOME` creation
- gateway daemon
- cron scheduler
- messaging or notification delivery
- Home Assistant integration
- browser or computer-use enablement
- credentials or provider key persistence
- direct skill mutation
- Notion reverse sync
- Codex or Claude runtime replacement

## Immediate Port Items

1. Add side-effect taxonomy to `.agent/tools/inventory.md`.
2. Teach `scripts/tool-audit.sh` to check for that taxonomy.
3. Add a Hermes skill-governance checklist in `.agent/skills/`.

## Later Contract Candidates

- read-only searchable baton index over `.agent/status`, contracts, plans, and `CURRENT.md`
- isolated Hermes sidecar with gateway, cron, messaging, credentials, and direct skill mutation disabled
- optional Hermes skill review batch using the governed skill checklist
