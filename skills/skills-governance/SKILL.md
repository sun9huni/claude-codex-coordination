---
name: skills-governance
description: Use when adding, syncing, reviewing, deprecating, or sharing team Codex Skills.
license: MIT
---

# Skills Governance

Use this skill to keep team Skills useful, small, and synchronized.

## Workflow

1. Read `.agent/skills/sync-policy.md`.
2. Update `.agent/skills/registry.md`.
3. Update `.agent/skills/selection.md`.
4. Run `./scripts/skills-sync.sh --dry-run`.
5. Mark unused or duplicate Skills as deprecated.

## Tuning an existing skill
When revising a skill's instructions/routing/prompts (not adding/removing a
skill), follow `.agent/skills/skill-tuning-discipline.md` (Path A): held-out
gate, rejection buffer, bounded edit. Hand-fix and diagnose before reaching for
any automated learning loop.

## Guardrails

- Keep team Skills in repository `skills/`.
- Do not assume user-local Skills exist.
- Keep descriptions precise so implicit invocation is reliable.
- Prefer references and scripts over long always-loaded instructions.
