# Harness Usage Guide

Day-to-day reference for using the claude-codex-coordination harness.
For *why* each piece exists, see [docs/design.md](docs/design.md). For
*how to adapt* to your project, see
[docs/customization.md](docs/customization.md).

---

## 1. Starting a session

Two things happen automatically:

1. **`SessionStart` hook fires** and does two things in one pass:
   - **stderr warnings** if state is stale — `CURRENT.md` older than
     24h, any `.agent/status/<slice>.md` older than 7d, or
     `project_*` memory leak (see
     [docs/concepts/memory-policy.md](docs/concepts/memory-policy.md)).
   - **stdout JSON `additionalContext` injection** — the live
     workspace bootstrap (CURRENT.md frontmatter + detected skills +
     enabled gates + memory policy + 3-step ritual) is pushed into
     the session context. The bootstrap reflects your actual
     deployment, not template defaults — enabling optional hooks
     lights up extra lines automatically.
2. **The 3-step ritual** from `CLAUDE.md` (or `AGENTS.md` for Codex)
   loads into context.

What you do:

```
1. Read the .agent/handoffs/CURRENT.md index (derived — which session
   owns which slice).
2. Identify your slice and read its .agent/status/<slice>.md baton
   (owner_session / heartbeat / remaining_actions), or run
   ./scripts/status.sh <slice> if the file looks stale.
3. Drill down to .agent/projects/<slice>-harness.md only if needed.
   If the slice is owned by another live session (fresh heartbeat,
   different owner_session), follow takeover-prompt.md first.
```

If the work area is not obvious, start with **`/route "<one-liner>"`**.

---

## 2. Slash commands

The template ships **11 slash skills** in three categories.

### Process (cross-agent coordination)

`/handoff`, `/slice-status`, `/contract-check`, `/route` — see
their detailed sections below.

### Expertise (opinionated code work)

`/code-review`, `/refactor-simplify`, `/test-gen`, `/debug` — each
carries Karpathy 4-principle guardrails (Think Before Coding /
Simplicity First / Surgical Changes / Goal-Driven) and a Red
Flags rationalization table.

- `/code-review [<file-path> | <commit>..<commit> | PR#]` — 5
  lenses (correctness / design / simplicity / surgicality /
  testability). Default verdict `REQUEST_CHANGES`; APPROVE
  requires active checking.
- `/refactor-simplify <path>` — find what to **delete / inline /
  rename**. Net-line negative required. Test gate at Step 0
  refuses behavior-changing refactor on uncovered code.
- `/test-gen <file::function | diff>` — pytest scaffold. Step 3
  proposes a behavior list (3-7 cases), Step 4 pauses for user
  confirm, then writes. Honest invariant assertions when expected
  output isn't known.
- `/debug <symptom>` — hypothesis-first failure diagnosis. Six
  lenses (recent change / boundary / wrong assumption /
  concurrency / wrong env / test artifact). Proposes ONE
  distinguishing diagnostic command, never a fix in the same turn.

### Workflow (spec → plan → execute chain)

Three-skill pipeline. Each skill **refuses** to advance if the
upstream artifact is still `Status: pending`.

- `/brainstorm "<topic>"` — Socratic spec gate. Drafts a contract
  at `.agent/contracts/<slug>.md`. HARD-GATE: no source edits
  during brainstorm.
- `/write-plan <contract-path>` — decomposes approved contract
  into 2-5 minute tasks at `.agent/plans/<slug>.md`. Each task
  has a mandatory verification command.
- `/execute-plan <plan-path>` — subagent task loop. Per task:
  delegate → `/code-review` the diff → commit. One commit per
  task. Hard stops on approval-gate triggers and scope creep.

### `/handoff [one-line note]`
**When**: end of session, context < 20%, switching agents, before a
long-running job, before any approval gate.
**Does**: fills your slice's `.agent/status/<slice>.md` baton, runs
`./scripts/handoff.sh claude <slice>` (claims + refreshes that slice's
frontmatter), then `./scripts/status.sh index` to regenerate
`CURRENT.md`.
**Required fields** (Stop hook validates): `owner_session`,
`owner_agent`, `version`, `last_updated` (today, ISO date),
`heartbeat`, `remaining_actions` (1-3 concrete next steps), plus the
markdown body fields like `goal`, `current status`, `files touched`,
`verification run`, `approval required`.

### `/slice-status <slice>`
**When**: entering or resuming a slice; want one consolidated view.
**Does**: combines static `.agent/status/<slice>.md` + live scan +
project-repo `git status`/log, flags contradictions and stale signals.

### `/contract-check`
**When**: starting any non-trivial change in your project.
**Does**: walks `WORKFLOW.md §2` triggers against your current diff and
declared goal. If any trigger fires, drafts a contract from
`.agent/contracts/_template.md` and pauses for approval.

### `/route "<free-form description>"`
**When**: not sure which slice the work belongs to.
**Does**: matches the description against the `WORKFLOW.md §1` routing
table. Refuses to invent slices — if no match, asks you to clarify or
add a row.

---

## 3. Subagents (Agent tool)

Define task-specialized subagents under `.claude/agents/<name>.md`.
Invoke via `Agent(subagent_type="<name>", prompt="...")`. Why this is
better than the generic agent: narrower tool surface, lower context
cost, faster turnaround, deny lists prevent accidental writes/submits.

This template ships with **example agents** under
`examples/research-deployment/.claude/agents/` (a SLURM status
inspector, a zero-compute diagnostician, a stage-gate checker).
Copy what fits, then write your own. See
[docs/customization.md](docs/customization.md) for how.

---

## 4. Auto-blocked Bash commands (PreToolUse hooks)

Out of the box, these fail with exit 2 (stderr explains why):

| Pattern | Hook | Bypass |
|---|---|---|
| `rm -rf /<shared-storage>` | `pre-bash-destructive-gate.sh` | Get explicit user approval. |
| `rm -rf .agent/.claude/.codex/.git` | same | Same. |
| `git push --force` / `-f` | same | User approval, then run directly. |
| `git reset --hard origin/...` / `upstream/...` | same | Same. |
| `git branch -D` | same | Same. |
| `sbatch ...` *(if optional SLURM gate enabled)* | `pre-bash-slurm-gate.sh` | Create a contract under `.agent/contracts/` (modified within 7d). |
| `psql ... DROP TABLE / TRUNCATE / ALTER TABLE` *(if optional DB gate enabled)* | `pre-bash-db-gate.sh` | User approval per `AGENTS.md` gates. |

**Heredoc bodies are stripped before matching**, so commit messages
containing these keywords are safe.

Adapt the destructive-gate's shared-storage path patterns for your
environment by editing
[.claude/hooks/pre-bash-destructive-gate.sh](.claude/hooks/pre-bash-destructive-gate.sh).

---

## 5. Per-slice batons + derived index

Each `.agent/status/<slice>.md` is the **authoritative per-slice
baton**: it names the live owner of the slice and holds that slice's
next actions. `.agent/handoffs/CURRENT.md` is a **DERIVED** lab-wide
index regenerated by `scripts/status.sh index` — it shows which
session owns which slice and is **never hand-edited**. A session
writes only its own slice's status file.

### Per-slice baton frontmatter
The schema authority is
[.agent/status/README.md](.agent/status/README.md). The block:
```yaml
---
owner_session: 3f2b9c7a-1d4e-4a8b-9c0f-7e6d5a4b3c21  # UUID; set by handoff.sh
owner_label: dev-a             # optional human label, may be empty
owner_agent: claude            # tool axis: claude | codex | cursor
version: 7                     # integer, bumped each handoff write
last_updated: 2026-05-27       # ISO date
heartbeat: 2026-05-27T14:32:05Z  # ISO timestamp of last write
remaining_actions:             # list, max ~3
  - "next concrete action"
contract_pointers:             # relevant contract paths
  - ".agent/contracts/slice-1-topic.md"
---
```

### Two ways to update
1. Call `/handoff` and let the skill guide the baton field-by-field.
2. Edit your `status/<slice>.md` body directly, then run
   `./scripts/handoff.sh <agent> <slice>` (claims + refreshes the
   frontmatter) followed by `./scripts/status.sh index` (regenerates
   the derived `CURRENT.md`). Stop hook validates on session end.

A slice is simply a `.agent/status/<slice>.md` file — no central
registry to maintain. `scripts/status.sh` discovers slices by scanning
that directory; create one with `./scripts/init-slice.sh <slice>`. The
Stop hook validates `owner_agent` against its `VALID_AGENTS` set
([.claude/hooks/stop-handoff-check.sh](.claude/hooks/stop-handoff-check.sh)).

---

## 6. Memory policy

Auto-memory (`~/.claude/projects/<workspace>/memory/`) is for:

- `user_profile.md` — sustained user role/context.
- `feedback_*.md` — "do this / don't do that" with reasoning.
- `reference_*.md` — pointers to external systems (Linear projects,
  Grafana dashboards, etc.).

**Do not** save:

- `project_*` — project state lives in `.agent/`.
- Code patterns, file paths (read the codebase).
- Ephemeral debugging or per-task context.

The SessionStart hook detects `project_*` memory regressions and
prints a warning.

---

## 7. Common recipes

### Resume work after a break
```
1. Open Claude Code / Codex — SessionStart hook auto-runs.
2. Read the CURRENT.md index, then your status/<slice>.md baton.
3. /slice-status <slice> for the live view.
4. Take the first remaining_action.
```

### Start a non-trivial change
```
1. /route "<description>"
2. /slice-status <slice>
3. /contract-check
4. (After approval) implement.
5. /handoff before stopping.
```

### Hand off to another agent
```
1. /handoff "specific note for next session" — or manually update your
   status/<slice>.md, then ./scripts/handoff.sh <agent> <slice> and
   ./scripts/status.sh index.
2. The Stop hook validates the baton frontmatter on session end.
3. Next agent (any of Claude/Codex/Cursor) reads the CURRENT.md index,
   then the status/<slice>.md baton.
```

### Take over from someone else's session
```
1. Read the CURRENT.md index, then your status/<slice>.md baton.
2. Follow .agent/handoffs/takeover-prompt.md (the full 7-step
   variant — 3-step ritual + cross-checks).
3. State the goal in your own words and confirm with the user.
```

---

## 8. Troubleshooting

| Symptom | Cause / Fix |
|---|---|
| Slash command not in autocomplete | Restart Claude Code; it scans `.claude/skills/` at startup. |
| Hook blocks a legitimate command | Tighten the regex in the hook script. Heredoc bodies are already excluded. |
| Stop hook says "frontmatter validation: missing X" | Add the missing field to your slice's `.agent/status/<slice>.md` (schema: `.agent/status/README.md`). Do NOT edit the derived CURRENT.md; there is no schema_version field. |
| `Agent(subagent_type=foo)` fails | Confirm `.claude/agents/foo.md` exists; restart Claude Code. |
| SLURM gate keeps blocking | `find .agent/contracts -name '*.md' ! -name '_template.md' -mtime -7` returned empty. Create a contract. |
| Codex sees yaml frontmatter | Expected — Codex ignores it and reads the body (backward compatible). |
| Memory keeps growing project_* | Delete the file; the SessionStart hook will warn if it returns. |

---

## 9. Extending

- New slash command: `.claude/skills/<name>/SKILL.md` with `name:`,
  `description:`, `argument-hint:`, optional `allowed-tools:`. Body
  becomes the prompt Claude receives.
- New subagent: `.claude/agents/<name>.md` with `name:`,
  `description:`, optional `model:`, `tools:`,
  `permissions: {allow, deny}`.
- New hook: `.claude/hooks/<name>.sh` + register in
  `.claude/settings.json` under the right event
  (`SessionStart` / `PreToolUse` / `PostToolUse` / `Stop`). Hook reads
  JSON on stdin; exit 0 = allow, exit 2 = block, stderr fed back.
- New slice: add a row to `WORKFLOW.md §1`, then create
  `.agent/status/<slice>.md` and `.agent/projects/<slice>-harness.md`
  (helper: `./scripts/init-slice.sh <slice-name>`). No registry to
  edit — `scripts/status.sh` discovers the slice from its status file.

For deeper rationale see [docs/design.md](docs/design.md).
