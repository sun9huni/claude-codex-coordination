# Hermes Skill Governance Checklist

Date: 2026-06-02
Contract: `.agent/contracts/harness-hermes-agent-port-20260602.md`
Source baseline: `272c2f30aa60d6d98b2c97dde6ba42a9231d4f56`

## Purpose

Evaluate Hermes optional skills as candidates for this workspace without
auto-importing them or allowing agent-driven skill mutation.

## Required Decision

Each Hermes skill candidate must be classified as one of:

- `reject`: conflicts with policy or has unclear value
- `reference`: useful to read, not installed
- `adapt`: may be rewritten as a governed team skill
- `defer`: needs a separate contract

## Acceptance Checklist

A Hermes skill may become a governed team skill only when all checks pass:

1. The trigger maps to a real repeated workflow in this workspace.
2. The skill has a single clear owner.
3. The skill does not require credentials or external side effects by default.
4. The skill does not write directly to `skills/`, `.codex/skills`, or
   `.claude/skills`.
5. The skill can be expressed as a local `SKILL.md` following current
   skill-lint requirements.
6. The skill appears in `.agent/skills/registry.md` before use.
7. `./scripts/skills-sync.sh --dry-run` reports no mirror drift.
8. `bash tests/run-skill-lint.sh` passes.

## Rejected Import Modes

- bulk copying `optional-skills/`
- enabling Hermes `skill_manage`
- using Hermes to mutate team skills
- importing skills that require gateway, cron, messaging, credentials, or
  production-facing tools as default behavior

## Review Workflow

1. Read the Hermes skill source.
2. Classify it with the required decision labels.
3. If `adapt`, write a local skill from scratch using current workspace
   conventions.
4. Register the skill in `.agent/skills/registry.md`.
5. Mirror with `./scripts/skills-sync.sh --dry-run`.
6. Run `bash tests/run-skill-lint.sh`.
7. Record the decision in the relevant contract or status baton.
