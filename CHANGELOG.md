# Changelog

All notable changes follow [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [0.1.0] - 2026-05-20

Initial release. Extracted and generalized from a production research
workspace where Claude Code, Codex, and Cursor coexisted across multiple
projects.

### Added
- Three coordinated entry documents: `CLAUDE.md`, `AGENTS.md`,
  `WORKFLOW.md` — all sharing the same 3-step session-start ritual.
- `HARNESS_USAGE.md` — day-to-day reference.
- `.agent/handoffs/CURRENT.md` template with yaml frontmatter
  (schema_version 1) + `handoff.md` protocol + `takeover-prompt.md`
  for cross-agent takeover.
- `.claude/hooks/` core hooks:
  - `session-start-decay-check.sh` — stale handoff / status warning
  - `pre-bash-destructive-gate.sh` — block rm -rf on shared/harness
    dirs, force pushes, hard resets, force branch deletes
  - `stop-handoff-check.sh` — validate CURRENT.md yaml frontmatter +
    warn if not updated recently
- `.claude/hooks/optional/`:
  - `pre-bash-slurm-gate.sh` — block sbatch without active contract
  - `pre-bash-db-gate.sh` — block psql DDL
- `.claude/skills/` four slash commands:
  - `/handoff` — schema-guided CURRENT.md update + handoff.sh
  - `/slice-status` — consolidated slice view (static + live + git)
  - `/contract-check` — WORKFLOW §2 trigger check + contract draft
  - `/route` — map work signal to slice + harness file
- `.agent/contracts/_template.md` — generic contract template
- `scripts/handoff.sh` — git state snapshot + placeholder check
- `scripts/init-slice.sh` — scaffold a new slice (status + harness +
  routing-table reminder)
- `docs/design.md` — 8-phase architecture rationale
- `docs/customization.md` — how to adapt to your project
- `docs/concepts/` — deeper dives
- `examples/research-deployment/` — filled-in example deployment
