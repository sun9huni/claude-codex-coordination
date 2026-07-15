---
name: repo-bootstrap
description: Use when starting a new repo or when an existing repo lacks AGENTS.md / .agent / scripts skeleton. Produces a minimal harness so Codex and Claude can operate consistently.
license: MIT
---

# Repo Bootstrap

Bring a repo up to the shared harness baseline. Do not overwrite an
existing AGENTS.md or scripts; create only what is missing.

## Workflow

1. Read the repo root. Note: language, package manager, existing test
   command, branch model, secret locations.
2. If `AGENTS.md` is missing, create it from `.agent/templates/AGENTS.md.example`
   (in this server's root harness). Keep it short — map, gates, verify command.
3. Create only missing directories:
   - `docs/{product,architecture,adr,runbooks,qa}/` with index README per dir.
   - `.agent/{contracts,checklists,handoffs,knowledge/raw,knowledge/wiki,templates}/`.
   - `scripts/` with `verify.sh`, `handoff.sh` at minimum.
4. Add `.github/workflows/verify.yml` only if the repo has CI access and
   the team agrees to enforce it.
5. Add `CLAUDE.md` that points to `AGENTS.md` so Claude shares the harness.
6. Do not move or rename any existing file.

## Guardrails

- Never delete or overwrite existing content. If a file exists, skip it.
- Do not invent verify commands. If you cannot detect the right
  command, leave a TODO and ask.
- Do not commit secrets or env files.

## Output

Report:

- files created (paths)
- files intentionally skipped (already present)
- verify command detected, or marked TODO
- next action for the human (review AGENTS.md, wire CI, etc.)
