# Knowledge Index

Use this index as the first stop before reading raw sources.

## Core Concepts

- Hada archive upgrades: `hada-upgrades.md`

## Architecture Flows

- Codex harness flow: read `AGENTS.md`, use `.agent/` checklists or contracts, implement scoped changes, then run `scripts/verify.sh` plus task-specific gates.

## Decisions

- Use `/home/ubuntu/AGENTS.md` as the server-wide fallback guide.
- Let project-specific `AGENTS.md` files override the server-wide fallback.
- Install harness skills both in `/home/ubuntu/skills/` and `~/.codex/skills/`.

## Source-Backed Facts

- Harness source docs are stored under `.agent/knowledge/raw/sources/`.
- The uploaded starter provides `.agent/`, `scripts/`, `skills/`, and usage guidance.

## Inferred Connections

- The current server is a multi-project workspace, so root guidance should stay generic and avoid project-specific assumptions.

## Stale Or Missing Areas

- No project-specific verification commands have been normalized into the root harness yet.
