# Tool Inventory

Track MCP servers, plugins, CLIs, browser tools, local services, and external APIs used by Codex.

| Tool | Type | Tier | Purpose | Owner | Last used | Context cost | Risk |
| --- | --- | --- | --- | --- | --- | --- | --- |
| shell | core | core | local inspection and verification | team | always | low | medium |
| codex CLI | CLI | core | primary agent runtime on this server | team | 2026-05-18 | low | medium |
| harness scripts | scripts | core | standard verify, audit, eval, remote, and skill entrypoints | team | 2026-05-18 | low | low |
| harness skills | skills | on-demand | scoped workflows for change discipline, remote work, evals, tools, and governance | team | 2026-05-18 | medium | low |
| Hermes Agent runtime | agent runtime / tool ecosystem | disabled | reference source for skill, toolset, approval, and memory patterns; not installed or run | team | 2026-06-02 | high | high |

## Tier Labels

- `core`: needed in most sessions
- `project`: common for this repository
- `on-demand`: load only for specific workflows
- `disabled`: installed but not part of the default harness

## Side-Effect Classes

- `read-only-local`: reads local files or status only
- `local-write`: writes local files in the workspace
- `external-network`: calls external network services
- `credential-bearing`: requires or can expose credentials, tokens, or provider keys
- `scheduler-daemon`: runs scheduled or background work
- `messaging-notification`: sends messages, notifications, or chat replies
- `production-facing`: can affect production services, infrastructure, or customer data
- `destructive-infra`: can delete, reset, redeploy, rotate secrets, or change infrastructure

## Disabled Runtime Surfaces

Hermes Agent is a reference source only for the current harness phase. The
following Hermes surfaces are disabled unless a later approval-gated contract
enables a sidecar: gateway, cron, messaging, Home Assistant, browser,
computer-use, credentials, provider keys, direct skill mutation, and Notion
reverse sync.

## Review Rules

- Every tool needs an owner and purpose.
- Promote repeated workflows to Skills when that reduces context.
- Demote unused tools to on-demand or disabled.
