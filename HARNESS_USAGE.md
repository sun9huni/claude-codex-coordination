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
1. Read .agent/handoffs/CURRENT.md — yaml frontmatter (owner_agent,
   active_slice, remaining_actions). If owner_agent ≠ you, follow
   takeover-prompt.md.
2. Read .agent/status/<active_slice>.md or run a live scan.
3. Drill down to .agent/projects/<slice>-harness.md only if needed.
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
**Does**: fills required `CURRENT.md` fields and runs
`./scripts/handoff.sh claude`.
**Required fields** (Stop hook validates): `owner_agent`,
`last_updated` (today, ISO date), `active_slice`,
`remaining_actions` (1-3 concrete next steps), plus the markdown body
fields like `goal`, `current status`, `files touched`,
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

## 5. CURRENT.md management

`.agent/handoffs/CURRENT.md` is **cross-agent SSOT**. Yaml frontmatter
is machine-validated; the Markdown body is human-readable.

### Required frontmatter (schema_version 1)
```yaml
---
owner_agent: claude            # claude | codex | cursor | human
last_updated: 2026-05-20       # ISO date, must be ≤ 7 days old
active_slice: <your-slice>     # must match one of your defined slices
remaining_actions:             # list, length 1-3
  - "next concrete action"
schema_version: 1
---
```

### Optional fields
`session_title`, `files_touched_count`, `verification_run`,
`verification_result`, `failure_log`, `prior_slice_archive`,
`approval_required`, `contract_pointers`.

### Two ways to update
1. Call `/handoff` and let the skill guide field-by-field.
2. Edit directly. Stop hook validates on session end.

The valid slice set lives in
[.claude/hooks/stop-handoff-check.sh](.claude/hooks/stop-handoff-check.sh)
(`valid_slices` variable). Add your slice names there when you set up.

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
2. Read .agent/handoffs/CURRENT.md (frontmatter tells you slice).
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
1. /handoff "specific note for next session"
2. The Stop hook validates frontmatter on session end.
3. Next agent (any of Claude/Codex/Cursor) reads CURRENT.md.
```

### Take over from someone else's session
```
1. Read .agent/handoffs/CURRENT.md.
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
| Stop hook says "frontmatter validation: missing X" | Add the field, or pass schema_version: 1 and the required keys. |
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
- New slice: add a row to `WORKFLOW.md §1`, create
  `.agent/status/<slice>.md` and
  `.agent/projects/<slice>-harness.md`, add the slice name to
  `valid_slices` in `stop-handoff-check.sh`. Helper:
  `./scripts/init-slice.sh <slice-name>`.

For deeper rationale see [docs/design.md](docs/design.md).
