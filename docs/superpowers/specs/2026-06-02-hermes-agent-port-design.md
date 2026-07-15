# Hermes Agent Pattern-Port Design

Date: 2026-06-02
Slice: harness
Status: design-approved-for-review
Source repo: https://github.com/NousResearch/hermes-agent
Source baseline: `272c2f30aa60d6d98b2c97dde6ba42a9231d4f56`

## Summary

This design ports useful Hermes Agent patterns into the existing Codex/Claude
`.agent` harness without importing Hermes as a primary runtime. Hermes is a full
agent system with its own CLI, agent loop, tools, skills, persistent state,
gateway, cron scheduler, plugins, and optional MCP catalog. The current harness
already has its own source-of-truth model: `.agent/status`, contracts,
handoffs, Notion derived views, Codex skills, Claude skills, and verification
scripts.

The safest first move is to learn from Hermes and improve our harness
governance. A sidecar pilot remains possible later, but only behind a separate
contract and with external side effects disabled.

## Goals

- Inventory Hermes patterns that are useful for this harness.
- Strengthen skill governance using Hermes skill and progressive-disclosure
  ideas.
- Strengthen tool-budget governance using Hermes toolset and side-effect
  separation ideas.
- Compare Hermes approval and subagent guardrails with the workspace approval
  gates.
- Evaluate whether a read-only searchable baton or contract index is worth a
  later prototype.
- Preserve `.agent` as the durable source of truth.

## Non-Goals

- Do not install Hermes globally.
- Do not enable Hermes gateway, cron, messaging, Home Assistant, browser,
  computer-use, or production-facing tools.
- Do not let Hermes write to `skills/`, `.codex/skills`, or `.claude/skills`.
- Do not replace Codex or Claude as the primary implementation agents.
- Do not sync Hermes memory or session state into Notion.
- Do not add credentials, provider keys, or persistent external service state.

## Baseline Observations

The source baseline was refreshed on 2026-06-02. Local inspection found:

- 548 files under `maxdepth 2`
- 86 optional `SKILL.md` files
- 91 plugin directories under `maxdepth 2`
- about 55k lines across key runtime files:
  `run_agent.py`, `cli.py`, `model_tools.py`, `hermes_state.py`,
  `tools/skill_manager_tool.py`, `tools/delegate_tool.py`,
  `tools/mcp_tool.py`, `cron/scheduler.py`, and `gateway/run.py`
- package metadata: `hermes-agent` version `0.15.1`, Python `>=3.11`,
  MIT license

These observations confirm that Hermes should be treated as a complete runtime,
not a small dependency.

## Architecture

The import plan has four components.

### 1. Hermes Pattern Inventory

This component reads Hermes source and classifies patterns into four buckets:

- skills and skill metadata
- tools, toolsets, and MCP surfaces
- approvals, dangerous-command handling, and subagent restrictions
- memory, session search, and state persistence

The inventory records each pattern as one of:

- `port`: useful for immediate harness improvement
- `reference`: useful as design guidance only
- `defer`: useful but too large for this phase
- `reject`: conflicts with our harness ownership or approval model

The output should be a durable harness note or contract attachment so Claude and
Codex do not repeat the same repo investigation.

### 2. Skill Governance Bridge

This component maps Hermes skill concepts onto the current harness skill model.
It does not import Hermes skills automatically.

Expected improvements:

- add or propose validation for skill metadata and prerequisites
- compare Hermes progressive disclosure against current `SKILL.md` structure
- identify optional Hermes skills that could become governed team skills
- keep `skills/`, `.codex/skills`, and `.claude/skills` mirror ownership under
  existing `skills-sync` and skill-lint checks

Hermes `skill_manage` is explicitly excluded from this phase because it allows
agent-driven skill mutation. In this workspace, skill changes must remain
registry-backed, reviewable, and verifiable.

### 3. Tool Surface And Approval Bridge

This component maps Hermes toolsets to our tool-budget taxonomy. Every tool or
toolset should be classified by side-effect class:

- read-only local
- local write
- external network
- credential-bearing
- scheduler or daemon
- messaging or notification
- production-facing
- destructive or infrastructure-facing

Expected improvements:

- propose a side-effect class section for `.agent/tools/inventory.md`
- propose `tool-audit.sh` checks or fixtures for new high-risk tools
- compare Hermes dangerous-command approval with root `AGENTS.md` approval gates
- identify policy gaps without copying Hermes approval code directly

The root workspace approval gates remain authoritative.

### 4. Optional Search Or Sidecar Pilot

This component is not an immediate implementation. It defines the conditions
under which a later pilot may be allowed.

A read-only searchable baton prototype may be considered if it indexes only:

- `.agent/status/*.md`
- `.agent/contracts/*.md`
- `.agent/plans/*.md`
- `.agent/handoffs/CURRENT.md`

A Hermes sidecar may be considered only with:

- `HERMES_HOME` under `.agent/hermes` or another explicit harness-owned path
- no gateway daemon
- no cron scheduler
- no messaging platforms
- no production secrets
- no direct skill mutation
- no Notion reverse sync

Any sidecar pilot requires a separate contract before execution.

## Data Flow

1. Refresh or clone Hermes at a pinned commit.
2. Run read-only inventory over the selected source files.
3. Classify patterns by component and disposition.
4. Map accepted patterns to current harness surfaces:
   - skills to `skills-sync`, skill-lint, and registry docs
   - tools to `tool-audit`, inventory, and context-budget docs
   - approvals to `AGENTS.md` gates and tool policy
   - memory/search to status, contracts, and handoff index
5. Produce scoped implementation candidates.
6. Verify only the touched harness surfaces.

## Error Handling

- If the Hermes source is unavailable, stop the inventory and record
  `source unavailable`.
- If the remote HEAD changes, pin the new commit and rerun the read-only
  inventory before implementation.
- If a Hermes feature conflicts with the root `AGENTS.md` approval gates, reject
  the Hermes feature for this phase.
- If a proposed skill import would create mirror drift, do not import it.
- If a proposed sidecar requires credentials, messaging, gateway, cron, or
  production-facing tools, split it into a separate approval-gated contract.
- If Notion synchronization is requested from Hermes state, reject it. Notion is
  a derived view of `.agent`, not a reverse-sync target.

## Verification

Minimum verification for pattern-port changes:

- `./scripts/skills-sync.sh --dry-run`
- `bash tests/run-skill-lint.sh`
- `./scripts/tool-audit.sh`
- `./scripts/verify.sh`
- `git diff --check`

Additional verification by change type:

- skill validation changes: add or update a drift or metadata fixture
- tool-audit changes: add or update a side-effect class fixture
- search prototype: use read-only fixtures over `.agent/status` and contracts
- sidecar pilot: run a dedicated contract verification that proves gateway,
  cron, messaging, credentials, and direct skill mutation are disabled

## Milestones

### Milestone 0: Contract And Baseline

Create `.agent/contracts/harness-hermes-agent-port-20260602.md`.

Acceptance criteria:

- contract states that the first phase is pattern-port only
- source baseline commit is recorded
- existing assessment is linked:
  `.agent/scratch/harness-hermes-agent-assessment-20260601.md`
- full runtime merge is listed as a non-goal

### Milestone 1: Pattern Inventory

Create the Hermes pattern inventory.

Acceptance criteria:

- skills, tools, approvals, subagents, and memory/search are covered
- each item has `port`, `reference`, `defer`, or `reject`
- rejected runtime features include gateway, cron, messaging, direct skill
  mutation, and Notion reverse sync

### Milestone 2: Governance Improvements

Implement or document the smallest useful harness improvements.

Acceptance criteria:

- skill governance candidates are tied to existing skill registry and sync
  checks
- tool-budget candidates are tied to existing inventory and audit scripts
- approval comparison preserves root `AGENTS.md` as the authority
- no Hermes runtime dependency is introduced

### Milestone 3: Optional Pilot Decision

Decide whether a follow-up sidecar or search prototype is justified.

Acceptance criteria:

- if no pilot is justified, close the contract with the pattern-port results
- if a pilot is justified, create a new contract with side-effect gates and
  verification commands before installing or running Hermes as a sidecar

## Deliverables

- design spec: `docs/superpowers/specs/2026-06-02-hermes-agent-port-design.md`
- implementation contract:
  `.agent/contracts/harness-hermes-agent-port-20260602.md`
- pattern inventory:
  `.agent/tools/hermes-agent-pattern-inventory-20260602.md`
- updated harness status and regenerated handoff index after work

## Implementation Planning Decisions

- The first implementation plan should use one contract:
  `.agent/contracts/harness-hermes-agent-port-20260602.md`.
- The pattern inventory should live in `.agent/tools/` because it is a durable
  tool-governance reference, not temporary scratch output.
- Skill-governance and tool-budget changes should remain in the same contract
  only while they are documentation or small validation changes. If either side
  grows into a broad refactor, split it into a follow-up contract.
- The search prototype is out of scope for this phase. It may be proposed only
  after the pattern inventory shows a concrete handoff/search failure that a
  read-only index would solve.
