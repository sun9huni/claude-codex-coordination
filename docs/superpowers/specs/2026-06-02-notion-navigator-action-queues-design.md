# Notion Navigator Action Queues Design

Date: 2026-06-02
Slice: harness
Status: design-ready-for-user-review

## Summary

This design improves the current Notion connection system from a derived
record of `.agent` state into a user-friendly operating view. The root problem
is not only stale or incomplete sync. The current Notion surface does not make
it obvious what the human should decide next, what Codex or Claude should run
next, or whether a slice row can be trusted.

The selected direction is a two-layer interface:

- Navigator Home first viewport: Action Queue, with separate columns for
  `내가 결정할 것` and `에이전트가 실행할 것`.
- Slices DB main view: Project Rows, with each project/slice showing decision
  work, agent execution work, progress state, and sync trust in one row.

Notion remains a derived view. `.agent/status/<slice>.md`,
`.agent/contracts/`, `.agent/plans/`, and `.agent/handoffs/CURRENT.md` remain
the source of truth. Reverse sync from Notion to `.agent` is a non-goal.

## Goals

- Make the first Notion screen answer: "What should I decide next?"
- Separate human decision work from agent execution work.
- Make project and slice progress scannable without reading long baton text.
- Show whether each Notion row is fresh, stale, mismatched, or parser-limited.
- Preserve `.agent` as the authoritative state layer.
- Leave a durable design record for Claude Code and Codex handoff.

## Non-Goals

- Do not make Notion the source of truth.
- Do not add Notion-to-`.agent` reverse sync.
- Do not introduce a daemon, cron job, or headless token write path.
- Do not replace existing `.agent/status` baton semantics.
- Do not redesign unrelated project databases beyond the harness Notion
  derived view.

## Current Findings

The audit found that MCP-backed Notion access is alive, but the user-facing
experience is not yet good enough:

- Navigator Home still reads partly like setup/runbook text instead of a daily
  cockpit.
- Slices DB has limited fields: `Next Action` is too overloaded and often
  contains long baton prose.
- Slice row bodies are thin or link-only, while slice hub pages and weekly
  digests may contain different "latest" stories.
- Some rows are stale relative to `.agent/status`.
- Status frontmatter parsing is fragile; malformed YAML can produce blank or
  misleading migration payloads.
- Existing scripts compute payloads, but there is no explicit user-facing audit
  that says "this Notion view is trustworthy right now."

## Information Architecture

Navigator Home should be the daily starting surface.

First viewport:

- `내가 결정할 것`: approvals, choices, priority calls, release decisions, or
  blocked items where human judgment is required.
- `에이전트가 실행할 것`: Codex/Claude-ready next actions that do not require
  another human choice.
- Compact health indicators: stale slice count, blocked count, parser warning
  count, recently completed count.

Below first viewport:

- Active Slices preview.
- Recent Decisions.
- Running Experiments.
- Recent Reports.
- Docs.

Slices DB should be the main full-board surface.

Primary view:

- Rows grouped or sorted by `Project`.
- Visible properties: `Project`, `Slice`, `Health`, `Sync Status`,
  `내 결정`, `Agent 실행`, `Now`, `Next`, `Blocker`, `Last Heartbeat`.
- Filters for active, stale, blocked, released, and recently changed slices.

## Components

### 1. Action Queue Extractor

Reads each `.agent/status/<slice>.md` baton and produces short user-facing
queue fields.

Preferred fields:

- `Decision Needed`
- `Agent Next`
- `Now`
- `Next`
- `Blocker`
- `Headline`

The extractor should not rely only on `remaining_actions[0]`. Long baton prose
can remain in `.agent/status`, but the Notion model should prefer short fields
or deterministic summaries.

### 2. Sync Trust Layer

Computes whether each slice row can be trusted.

Example statuses:

- `Fresh`
- `Stale`
- `Parser warning`
- `State mismatch`
- `Notion row missing`
- `MCP skipped`

The trust layer compares local `.agent/status`, `CURRENT.md`, generated sync
payloads, and, when MCP is available, live Notion rows.

### 3. Navigator Home Renderer

Generates or updates the Navigator Home as an action-oriented page.

The renderer should remove stale setup wording from the first viewport and
replace it with action queues and health indicators. Deeper setup/runbook
details can remain linked from docs, not front-loaded on the home page.

### 4. Slices DB View Model

Extends the Slices DB derived row model with short status and trust fields.

Candidate properties:

- `Headline`
- `Now`
- `Decision Needed`
- `Agent Next`
- `Blocker`
- `Health`
- `Sync Status`
- `Last Sync Source`

If schema changes require approval, implementation must stop at the approval
gate before modifying Notion DB properties.

## Data Flow

1. `.agent/status/<slice>.md` remains the per-slice source of truth.
2. `scripts/notion_sync.py` reads slice status frontmatter and body.
3. The action queue extractor computes short human/agent fields.
4. The sync trust layer computes row health and mismatch warnings.
5. `--migrate slices/home` emits MCP-apply-ready payloads.
6. In-session Notion MCP applies updates when available.
7. Notion shows the derived action queues and full project board.

Reverse sync from Notion back into `.agent` is not part of this design.

## Error Handling

The system should not fail silently.

- Frontmatter parse failures produce `Parser warning` and audit output.
- `CURRENT.md` versus slice status mismatches produce `State mismatch` or
  `Heartbeat mismatch`.
- Missing Notion rows produce `Notion row missing`.
- MCP unavailability skips writes but still leaves local audit output.
- Long or missing queue fields fall back to a bounded summary, not an empty row.
- Schema-change needs stop at the root `AGENTS.md` approval gate.

## Verification

Minimum verification for the implementation plan:

- `scripts/notion_sync.py --audit`
- `scripts/notion_sync.py --migrate slices/home`
- `./scripts/tool-audit.sh`
- `./scripts/verify.sh`

When MCP is available, add a live check:

- Fetch Navigator Home and confirm first viewport has decision and agent queues.
- Fetch representative Slices rows and confirm `Health`, `Sync Status`,
  `Decision Needed`, and `Agent Next` are populated as expected.
- Confirm stale or mismatched slices are visible rather than hidden.

## Acceptance Criteria

- The Notion home first viewport centers on `내가 결정할 것` and
  `에이전트가 실행할 것`.
- The Slices DB has a Project Rows style view suitable for full-board scanning.
- Long `remaining_actions[0]` text is no longer the primary Notion UX.
- Sync health and source-of-truth status are visible.
- Parser or stale-sync problems are reported in audit output.
- No reverse sync, daemon, cron, token-based headless writes, or production
  side effects are introduced.

## Design Decisions

- The first implementation should compute short queue fields from existing
  baton data before adding new required frontmatter fields. This preserves
  compatibility with current slice status files.
- Notion DB schema changes should be approval-gated and batched. The
  implementation plan should first prove the computed payload shape locally,
  then request approval before adding properties to the Slices DB.
- `Health` and `Sync Status` should be select/status-style properties if the
  Notion schema is updated. They are meant for filtering and scanning, not long
  prose.

## Handoff Notes

This design is part of the `harness` slice. It should be paired with a new
contract: `.agent/contracts/harness-notion-ux-action-queues-20260602.md`,
before implementation. Claude Code and Codex should treat this document as the
approved design candidate, not as an implementation record.
