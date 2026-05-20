# Multi-agent coexistence

Three coding agents (Claude, Codex, Cursor) plus a human can share
the same workspace. This document is the model for how that works
and what its limits are.

## The model

```
              shared workspace
                       │
        ┌──────────────┼──────────────┐
        │              │              │
     Claude         Codex          Cursor          (one at a time)
        │              │              │
        ▼              ▼              ▼
        ╔══════════════════════════════╗
        ║   .agent/handoffs/CURRENT.md ║   <-- single SSOT
        ╚══════════════════════════════╝
                       │
                       ▼
                  next session
```

Each agent reads `CURRENT.md` at session start. The agent that just
ended a session wrote it. No agent talks to the others directly —
they communicate through the file system.

## Why this works

- **File system is durable**; chat sessions are not.
- **All three agents read Markdown** — pick a format they all
  handle and they coordinate without changing their internals.
- **The yaml frontmatter is opt-in**: Claude validates it, Codex /
  Cursor ignore it and read the markdown body. Backward compatible.

## What each agent has

| Capability | Claude | Codex | Cursor |
|---|---|---|---|
| Reads `CURRENT.md` | ✓ | ✓ | ✓ |
| Reads `CLAUDE.md` automatically | ✓ | — | — |
| Reads `AGENTS.md` automatically | ✓ (via CLAUDE.md) | ✓ | ✓ |
| Has hooks (PreToolUse, etc.) | ✓ | partial | — |
| Has slash skills | ✓ | partial | — |
| Has custom subagents | ✓ | partial | — |
| Has auto-memory | ✓ | partial | session history |
| Worktree isolation | ✓ | ✓ | — |

This template's `.claude/` is Claude-native. Equivalent Codex setup
goes under `.codex/`. Cursor uses its own conventions.

## What the model does NOT provide

### Concurrency
**Handoff-level**: `scripts/handoff.sh` uses `flock` on
`.agent/handoffs/OWNER.lock` (exclusive, 30s timeout) and bumps the
`version` field in CURRENT.md frontmatter atomically (.tmp + mv).
Two concurrent handoffs serialize correctly.

**Agent-level**: while an agent is editing `CURRENT.md` directly
(via the Edit tool, between handoffs), no lock is held. If two
agents edit at the same time, the later write wins silently. The
practical mitigation is to keep "one active agent at a time" as a
human convention; the Stop hook's `version monotonicity` check
detects "agent forgot to call /handoff" but not "two agents
overlapped".

If you need true concurrent agents, add an `OWNER.lock` heartbeat
(periodically `touch`) plus a check at session-start that refuses
to take over while another agent's heartbeat is fresh. That is not
in this template because the practical pattern is sequential.
Worktree-based parallelism within one agent's session is supported
by Claude's built-in `EnterWorktree`.

### Cross-agent state in agent-private memory
What lives in Claude's auto-memory, Codex's session DB, or Cursor's
history is invisible to the other agents. The mitigation is the
[memory policy](memory-policy.md): keep project state out of
private stores, in `.agent/` only.

### Atomic state updates
A poorly-written hook or interrupted session can leave `CURRENT.md`
half-edited. There is no transactional guarantee. Recovery: git
history (since the workspace is a git tree) and the
`.agent/handoffs/state/diff.patch` snapshot from the previous
handoff.

## Practical patterns

### Pair of agents on the same project, different specialties
Example: Claude for high-level reasoning + planning, Codex for
mechanical refactors and codegen.

- Active session = either Claude or Codex.
- End-of-session: `./scripts/handoff.sh codex` (or `claude`) and
  fill `CURRENT.md`.
- Next session: incoming agent reads `CURRENT.md`, follows
  takeover protocol if it was the other agent.

### Human stewardship
Human is the human in this model. Approval gates fire to humans;
contracts await human `approved` marking. `owner_agent: human`
means "no agent should auto-take this without human handing it off".

### Worktree-based parallelism (one-agent)
For independent write scopes within one agent's session, use
`EnterWorktree` (Claude). Each worker gets its own checkout; merges
happen in the main checkout. See `AGENTS.md` Worktree Discipline.

## When this model fails

- High-frequency multi-agent collaboration (every few minutes).
  The file-handoff cost dominates.
- Long-running agents that don't naturally checkpoint.
- Workspaces where the agents fundamentally disagree on file
  formats (rare in practice).

In those cases, build a real cross-agent runtime. This template is
*coordination by convention*, not *coordination by runtime*.
