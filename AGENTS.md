# Workspace Guide (Codex / Cursor / Claude)

> This document is the **shared rule set** for any agent operating in
> this workspace. Claude reads it via `CLAUDE.md`. Codex/Cursor read
> it directly. Replace `<project-name>` placeholders as you adapt.

## Purpose

This workspace is operated by one or more autonomous coding agents
(Codex, Claude, Cursor) plus a human. Humans define intent,
constraints, and acceptance criteria. Agents inspect the workspace,
implement scoped changes, verify, and report.

## Precedence

1. A project-specific `AGENTS.md` deeper in the tree, if present,
   overrides this one for its subtree.
2. This root `AGENTS.md` is the default rule set.
3. `CLAUDE.md` adds Claude-specific guidance but defers to this file
   on shared rules.
4. `WORKFLOW.md` is a router (where to look), not authoritative.

## Agent Handoff Protocol

Chat sessions are not durable. Working state lives in the workspace,
not the chat.

- At session start: read `.agent/handoffs/CURRENT.md` before acting.
  It is the single source of truth for "what is happening now".
- When taking over from another agent: open
  `.agent/handoffs/takeover-prompt.md` and execute its steps.
- Before context runs out, before switching agents, or before pausing
  for approval: run `./scripts/handoff.sh <next-agent>` and update
  `CURRENT.md` per `.agent/handoffs/handoff.md`.
- See `.agent/handoffs/README.md` for the full protocol.

## Quick Router

For day-to-day work, start at `WORKFLOW.md` — one-screen decision tree.
It routes to the right `.agent/projects/*.md` harness, lists contract
triggers, and names approval gates. Read this file when the router
points back here for the underlying rules.

## Working Rules

- Read the relevant `AGENTS.md` (this file, or a nested one) before
  planning or editing.
- For non-trivial edits, also read `.agent/status/<slice>.md` for the
  slice you are touching, and the matching
  `.agent/projects/<slice>-harness.md` if deep workflow context is
  needed.
- For complex work, create or update a plan/contract under
  `.agent/contracts/`.
- Prefer existing project patterns over new abstractions.
- Keep changes scoped to the user request and the affected slice.
- Do not modify secrets, production config, or destructive
  infrastructure paths unless explicitly approved.
- Do not treat unrelated subdirectories as part of the same change
  unless the user asks for cross-project work.

## Approval Gates

Stop and ask before:

- Database schema changes
- Deployment or release changes
- Destructive file operations (e.g. `rm -rf` on shared storage)
- Secret or credential rotation
- External side effects on production services
- Submitting long-running jobs (HPC, training, CI runs that consume
  budget)

The `.claude/hooks/pre-bash-destructive-gate.sh` PreToolUse hook
enforces several of these automatically. Optional hooks in
`.claude/hooks/optional/` cover SLURM submission and DB DDL — copy
to `.claude/hooks/` and register in `settings.json` to enable.

## Required Verification

Run the most specific project verification command when one exists.
If no project-specific command exists, define one in
`scripts/verify.sh` and add it here.

Task-specific verification:

- Web UI changes: `scripts/browser-check.sh` (you provide)
- AI behavior / RAG / agent / ranking changes: `scripts/eval.sh`
  (you provide)
- Tool, MCP, or skill changes: review `.claude/skills/`,
  `.claude/agents/`, and any project-level mirror.
- Remote SSH work: define `scripts/remote-verify.sh` for your
  environment first.

## Completion Rules

Do not claim completion unless:

- Implementation is done.
- Changed scope is limited to the request.
- Required verification ran, or the reason it could not run is stated
  in `CURRENT.md.verification_result`.
- Task-specific QA ran when applicable.
- Remaining failures or risks are explained in
  `CURRENT.md.remaining_actions` or `approval_required`.
