# Claude Entry Point

This file is Claude Code's entry to this workspace. Codex/Cursor read
`AGENTS.md` directly; Claude uses this file plus the native primitives
in `.claude/`. All three agents share one SSOT: `.agent/handoffs/CURRENT.md`.

> Replace `<project-name>` placeholders below once you adapt this
> template. See [HARNESS_USAGE.md](HARNESS_USAGE.md) and
> [docs/customization.md](docs/customization.md).

## Session-start ritual (do these three steps in order, every session)

1. **Read `.agent/handoffs/CURRENT.md`** — the cross-agent SSOT. Trust
   this, not chat history. If `owner_agent` ≠ `claude`, also read
   `.agent/handoffs/takeover-prompt.md` and execute its steps before
   acting.
2. **Identify the active slice**. If `CURRENT.md.active_slice` names
   a slice, use it. Otherwise consult `WORKFLOW.md §1` routing
   table. Once the slice is fixed, read `.agent/status/<slice>.md`.
   If that file is older than 7 days, prefer the live scan in the
   harness (e.g. `./scripts/status.sh <slice>`).
3. **Drill down only if the task needs more context** —
   `.agent/projects/<slice>-harness.md` for deep workflow detail. Do
   NOT pre-read all of them; pull on demand.

Working rules, approval gates, and verification commands live in
`AGENTS.md` — do not duplicate them here.

## Claude-native primitives

| Need | Primitive | Location |
|---|---|---|
| Repeated workflow (slash command) | skill | `.claude/skills/<name>/SKILL.md` |
| Task delegation with restricted tools | subagent | `.claude/agents/<name>.md` |
| Hard approval gate (block dangerous Bash) | PreToolUse hook | `.claude/hooks/*.sh` + `settings.json` |
| Decay / stale state warning | SessionStart hook | `.claude/hooks/session-start-decay-check.sh` |
| Handoff reminder + schema validation | Stop hook | `.claude/hooks/stop-handoff-check.sh` |

If your workspace also has a top-level `skills/` directory (Codex's
convention), Claude does NOT read it for slash commands — Claude's
slash commands live under `.claude/skills/`.

## Memory policy

Claude Code's auto-memory at
`~/.claude/projects/<workspace>/memory/` holds **user profile,
feedback, and external references only**. Project state lives in
`.agent/` exclusively — never duplicate it into auto-memory. If you
find yourself about to save a `project_*.md` to memory, write to
`.agent/status/<slice>.md` or `.agent/handoffs/CURRENT.md` instead.

## End-of-session

When stopping, switching agents, or near context limit:
1. Update `.agent/handoffs/CURRENT.md` (frontmatter + body, no
   `<placeholder>` fields). Use `/handoff` to be guided.
2. Run `./scripts/handoff.sh claude` — snapshots git state under
   `.agent/handoffs/state/`.
3. The Stop hook will warn if step 1 was skipped or the frontmatter
   schema is invalid.

For full handoff field requirements see
[.agent/handoffs/handoff.md](.agent/handoffs/handoff.md).

## Precedence

If this file and `AGENTS.md` disagree, **`AGENTS.md` wins for shared
rules**. This file's authority is limited to:
- Claude-native primitive locations (`.claude/skills/`, `.claude/agents/`,
  `.claude/hooks/`).
- Memory policy (Claude-specific).
- The 3-step session ritual above (which `AGENTS.md` references but
  does not duplicate).

For everything else — working rules, approval gates, verification
commands, completion criteria — see [AGENTS.md](AGENTS.md).
