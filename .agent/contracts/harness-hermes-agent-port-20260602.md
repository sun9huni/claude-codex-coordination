---
status: done
slice: harness
topic: hermes-agent-pattern-port
date: 2026-06-02
owner: codex
approved_by: user approved design spec on 2026-06-02
design_spec: docs/superpowers/specs/2026-06-02-hermes-agent-port-design.md
source_repo: https://github.com/NousResearch/hermes-agent
source_baseline: 272c2f30aa60d6d98b2c97dde6ba42a9231d4f56
follow_on_to:
  - .agent/scratch/harness-hermes-agent-assessment-20260601.md
decisions:
  - First phase is pattern-port only. Hermes is not installed globally and does not become a primary runtime.
  - Pattern inventory lives in .agent/tools/hermes-agent-pattern-inventory-20260602.md as a durable tool-governance reference.
  - Gateway, cron, messaging, direct skill mutation, credentials, production-facing tools, and Notion reverse sync are rejected for this phase.
  - Skill-governance and tool-budget improvements stay small and documentation/validation-focused in this contract.
  - Search prototype and isolated sidecar are later-contract options, not part of this implementation.
---

# Harness Hermes Agent Pattern-Port Contract

## Purpose

Import the useful governance patterns from NousResearch Hermes Agent into the
Codex/Claude `.agent` harness without importing Hermes as a runtime dependency.
The value is better tool-budget, skill-governance, and approval discipline while
preserving `.agent` as the workspace source of truth.

## Current State

- Hermes assessment exists at
  `.agent/scratch/harness-hermes-agent-assessment-20260601.md`.
- Approved design spec exists at
  `docs/superpowers/specs/2026-06-02-hermes-agent-port-design.md`.
- Hermes source baseline for planning is
  `272c2f30aa60d6d98b2c97dde6ba42a9231d4f56`.
- `scripts/tool-audit.sh` checks only that `.agent/tools/inventory.md` exists
  and reports incomplete-entry markers.
- `.agent/tools/inventory.md` does not yet define side-effect classes.
- `.agent/skills/registry.md` tracks approved skills but does not yet carry a
  Hermes comparison or import checklist.

## Constraints

- Allowed change scope:
  - `.agent/tools/hermes-agent-pattern-inventory-20260602.md`
  - `.agent/tools/inventory.md`
  - `.agent/skills/hermes-skill-governance-20260602.md`
  - `scripts/tool-audit.sh`
  - focused tests or smoke checks required by the plan
  - `.agent/status/harness.md` and regenerated `.agent/handoffs/CURRENT.md`
- Forbidden change scope:
  - no global Hermes install
  - no `HERMES_HOME` creation
  - no gateway, cron, messaging, or Home Assistant enablement
  - no direct writes from Hermes to `skills/`, `.codex/skills`, or
    `.claude/skills`
  - no credentials or provider keys
  - no Notion reverse sync
  - no replacement of Codex or Claude agent loops

## Done When

- Pattern inventory is written and covers skills, tools/toolsets,
  approvals/subagents, and memory/search.
- Tool inventory contains a side-effect taxonomy and maps Hermes as a rejected
  or deferred runtime surface.
- Skill-governance note explains how Hermes skills may be evaluated without
  auto-import or direct skill mutation.
- `tool-audit.sh` verifies that tool inventory has the required taxonomy and
  flags missing side-effect documentation.
- Required verification commands pass or their failures are documented:
  `./scripts/skills-sync.sh --dry-run`, `bash tests/run-skill-lint.sh`,
  `./scripts/tool-audit.sh`, `./scripts/verify.sh`, and `git diff --check`.
- Harness status and handoff index point to the new inventory and final result.

## Non-Goals

- Running Hermes.
- Installing Hermes dependencies.
- Creating a search index.
- Creating a sidecar pilot.
- Importing optional Hermes skills.
- Extending Notion automation.

## Risks

- Tool taxonomy may become decorative if `tool-audit.sh` does not enforce the
  required sections.
- Optional Hermes skill names may tempt direct import. This contract requires
  checklist-based evaluation only.
- Runtime side effects can leak into scope if gateway, cron, messaging, or
  credentials are treated as normal tools. They are rejected for this phase.

## Rollback

Revert the documentation and script changes from this contract. Since Hermes is
not installed or run, rollback does not need service shutdown, credential
rotation, or state cleanup.

## Progress Log

- 2026-06-02: contract created from approved design spec.
- 2026-06-02: pattern-port implementation completed; Hermes remains
  reference-only. Verification passed for `skills-sync --dry-run`, skill-lint,
  `tool-audit.sh`, `verify.sh`, and scoped diff-check over Hermes/harness files.
  Global `git diff --check` is blocked by unrelated dirty
  `.agent/status/mmgbsa.md` trailing whitespace owned by another slice.
