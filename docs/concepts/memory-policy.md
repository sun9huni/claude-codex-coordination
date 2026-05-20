# Memory policy

Claude Code's auto-memory at
`~/.claude/projects/<workspace-slug>/memory/` is per-Claude state.
Codex and Cursor have their own analogues. Either way, **what one
agent remembers, the others cannot see**.

This is the private context leak. Left unmanaged it biases the
agent's behavior silently and breaks cross-agent coordination.

## The rule

Auto-memory holds only:

- **`user_profile.md`** — sustained role/context about the user.
  Doesn't change session-to-session.
- **`feedback_*.md`** — "do this / don't do that" rules with
  reasoning. Reusable across sessions.
- **`reference_*.md`** — pointers to external systems (Linear
  projects, Grafana dashboards, runbook locations).

Auto-memory **does not** hold:

- `project_*.md` — project state belongs in `.agent/`.
- Code patterns, file paths, conventions — the codebase is the
  source of truth, read it.
- Ephemeral session state — chat context covers it.

## Why this matters

Claude's own auto-memory guide tells you not to save project state,
yet every workspace I've seen accumulates `project_*` files within
a few weeks. The pull is real: it feels efficient to write down
"VAV1 phase 2 done" rather than read `.agent/status/vav1.md`. But
that creates two sources of truth that drift apart, and Codex /
Cursor / human can't see the auto-memory copy.

## Enforcement

The `session-start-decay-check.sh` hook walks
`~/.claude/projects/*/memory/` and warns if any `project_*.md`
exists. The warning lists the path so you can move the content to
`.agent/status/<slice>.md` or `.agent/handoffs/CURRENT.md` and
delete the memory file.

## What about Codex memory? Cursor history?

This template does not currently extend the SessionStart hook to
inspect Codex / Cursor private state. The reasoning is symmetric:
project state should not live in any agent's private state, so:

- Claude: enforce via SessionStart hook (this template).
- Codex: configure your `.codex/rules/` similarly; the hook
  approach does not generalize to Codex out of the box.
- Cursor: there isn't a hook system that reaches private state at
  this writing.

The mitigation is **discipline + the auto-memory guide**. The
template publishes the rule explicitly so all three agents see it
when reading `CLAUDE.md` / `AGENTS.md`.

## How to record information that *feels* like project state

Ask: "if I had this written down, would I want Codex to see it too?"

- **Yes** → write it to `.agent/`:
  - The work plan / state → `.agent/handoffs/CURRENT.md`.
  - A slice's current snapshot → `.agent/status/<slice>.md`.
  - A workflow design → `.agent/projects/<slice>-harness.md`.
  - A decision + scope + approval → `.agent/contracts/...`.

- **No, this is about how the user prefers to work** → auto-memory
  `feedback_*.md`.

- **No, this is about me as a user** → auto-memory `user_profile.md`.

- **It's a pointer to an external system** → auto-memory
  `reference_*.md`.

When in doubt, write to `.agent/`. Migrating from `.agent/` to
auto-memory later is easy (read + summarize). Migrating the other
direction is awkward because the user can't see your auto-memory.
