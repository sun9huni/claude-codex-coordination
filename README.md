# claude-codex-coordination

A standardized, cloneable harness for projects where **Claude Code**,
**Codex**, and/or **Cursor** share the same working directory.

This is not a Claude Code plugin — it is a *file layout + policy +
enforcement* convention that any of those agents can pick up by reading
its entry document. It works because the coordination layer lives in
files (CURRENT.md, status, contracts) rather than chat history.

## What you get

- **One session-start ritual** shared by all three agents (CLAUDE.md /
  AGENTS.md / WORKFLOW.md / takeover-prompt.md cannot drift apart).
- **Schema-validated handoff state** in per-slice `.agent/status/<slice>.md`
  batons (yaml frontmatter the next agent can parse without trusting
  chat) plus a derived `.agent/handoffs/CURRENT.md` index over them.
- **Enforcement hooks** (`PreToolUse`, `SessionStart`, `Stop`) that
  turn prose policies into actual blocks — force pushes, hard resets,
  rm -rf on shared storage, etc.
- **Native primitives wired in**: `.claude/skills/` ships **11 slash
  skills** (4 process + 4 expertise + 3 workflow-chain),
  `.claude/agents/` for restricted-tool subagents, `.claude/hooks/`
  for enforcement *and* productivity (optional `post-edit-format.sh`).
- **SessionStart additionalContext injection**: bootstrap state +
  detected inventory pushed into context at turn 0; no reliance on
  CLAUDE.md being re-read.
- **Spec → Plan → Execute chain** (`/brainstorm`, `/write-plan`,
  `/execute-plan`): obra/superpowers-style workflow discipline
  plugged into the existing `.agent/contracts/` lifecycle.
- **Slice + routing system** so multi-workstream projects don't blur
  boundaries between work areas.
- **Memory policy** that prevents the auto-memory private-context leak
  (project state belongs in `.agent/`, not in any one agent's memory).

## What this is not

- Not a Claude Code marketplace plugin. No install step.
- Not a magic generator. You will spend ~30 minutes filling in the
  slices, contracts, and routing table for your project.
- Not opinionated about your tech stack — this is process scaffolding.

## Quick start

```bash
# 1. Clone into your project (or an empty workspace dir)
git clone https://github.com/sun9huni/claude-codex-coordination.git my-project
cd my-project
rm -rf .git
git init

# 2. Fill in the placeholders
#    - CLAUDE.md / AGENTS.md / WORKFLOW.md: replace <project-name> and
#      describe your slices in the routing table
#    - ./scripts/init-slice.sh <slice>: scaffolds one
#      .agent/status/<slice>.md baton + harness file per slice; fill
#      in each baton's goal and first remaining_actions
#    - .agent/projects/<slice>-harness.md: deep workflow detail per slice

# 3. (Optional) enable the optional hooks for your stack
#    cp .claude/hooks/optional/pre-bash-slurm-gate.sh .claude/hooks/   # if HPC
#    cp .claude/hooks/optional/pre-bash-db-gate.sh   .claude/hooks/    # if DB
#    Then add them to .claude/settings.json hooks block.

# 4. (Optional) port the example agents
#    See examples/research-deployment/.claude/agents/

# 5. First handoff to create a baseline (claims the slice baton and
#    regenerates the derived CURRENT.md index)
./scripts/handoff.sh claude <slice>   # or codex / cursor

# 6. Commit
git add -A && git commit -m "harness: initial setup from claude-codex-coordination"
```

Then open the workspace in Claude Code (or Codex / Cursor) — the
session-start hook fires, the agent reads `CURRENT.md`, and you are
ready to work.

## Architecture in one paragraph

The workspace root holds three entry documents (`CLAUDE.md`, `AGENTS.md`,
`WORKFLOW.md`) that point at one source of truth: the per-slice
`.agent/status/<slice>.md` batons, indexed by the derived
`.agent/handoffs/CURRENT.md`. Each baton's Markdown body is
human-readable; its yaml frontmatter is machine-validated. `.claude/`
contains Claude's native primitives — hooks that block dangerous Bash,
skills that are real slash commands, subagents that delegate with a
narrow tool surface. `.agent/` is the cross-agent state: handoffs,
slice status, contracts, project harness files. When the session ends,
`./scripts/handoff.sh <next-agent> <slice>` refreshes the baton and the
index (no-slice mode additionally snapshots git state into
`.agent/handoffs/state/`) so the next agent — human, Claude, Codex, or
Cursor — resumes from files, not chat history.

See [docs/design.md](docs/design.md) for the longer story.

## Documentation

- [HARNESS_USAGE.md](HARNESS_USAGE.md) — day-to-day reference
- [docs/design.md](docs/design.md) — why each piece exists
- [docs/customization.md](docs/customization.md) — adapting to your project
- [docs/concepts/](docs/concepts/) — deeper dives on slices, handoffs,
  hooks, memory, multi-agent coexistence
- [examples/research-deployment/](examples/research-deployment/) — a
  filled-in example for an HPC/research project

## License

MIT — see [LICENSE](LICENSE).

## Status

`v0.1.0` — initial release. The conventions have been used in
production by one research workspace (8 phases of design captured in
[docs/design.md](docs/design.md)). Expect rough edges; please open
issues or PRs.
