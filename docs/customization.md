# Customizing for your project

After cloning the template, do these in order. Each step is 5-15
minutes; the full customization is under an hour.

## 1. Decide your slices (≈ 10 min)

A **slice** is one workstream within the workspace. Slices have
distinct vocabularies, success criteria, and (usually) separate
project repos. Examples:

- A research workspace: `data-pipeline`, `model-training`,
  `inference-service`, `evals`.
- A SaaS workspace: `backend`, `frontend`, `infra`, `analytics`.
- A consultancy workspace: one slice per active client.

Write down 2-6 slices. Fewer is fine; more than 6 starts to need
sub-slices.

## 2. Fill in `WORKFLOW.md` §1 routing table (≈ 10 min)

One row per slice. The columns:

- **Work signal**: keywords that appear in the user's request when
  this slice is involved. Be concrete (filenames, feature names).
- **Status file**: `.agent/status/<slice>.md`.
- **Harness file**: `.agent/projects/<slice>-harness.md`.
- **Critical reminder**: one-line caveat the agent must keep in mind.

Example:

```markdown
| backend bug, API, auth, migration | `.agent/status/backend.md` | `.agent/projects/backend-harness.md` | RUN migrations in a dedicated PR, never bundled |
| ML training run, eval, dataset    | `.agent/status/ml.md`      | `.agent/projects/ml-harness.md`      | Eval before merging any prompt change          |
```

## 3. Scaffold per-slice files (≈ 5 min)

For each slice:

```bash
./scripts/init-slice.sh <slice-name>
```

This creates the status + harness file with sensible templates. Edit
them with real content as the slice develops; the first iteration
can be minimal.

## 4. Update `stop-handoff-check.sh` (≈ 1 min)

Edit `.claude/hooks/stop-handoff-check.sh`, find `VALID_SLICES`, add
your slice names:

```python
VALID_SLICES = {"backend", "ml", "infra"}
```

Without this, the Stop hook warns that `active_slice` is unknown.

## 5. Customize the destructive-gate hook (≈ 2 min)

Edit `.claude/hooks/pre-bash-destructive-gate.sh`. The
`SHARED_PATHS_REGEX` variable matches the prefix of paths whose
deletion would be hard to recover from. Defaults are
`/mnt/|/shared/|/data/|/srv/`. Add yours:

```bash
SHARED_PATHS_REGEX='(/mnt/|/shared/|/data/|/srv/|/your/data/lake/)'
```

## 6. Enable optional hooks if relevant (≈ 5 min)

- HPC / SLURM users:
  ```bash
  cp .claude/hooks/optional/pre-bash-slurm-gate.sh .claude/hooks/
  ```
  Then add it to `.claude/settings.json` under
  `hooks.PreToolUse[*].hooks[]`.
- PostgreSQL users: same pattern with `pre-bash-db-gate.sh`. For
  other DBs, copy the script and adjust `DB_BINARY_REGEX` and
  `DDL_REGEX`.

## 7. Define your contract triggers (≈ 5 min)

Edit `WORKFLOW.md §2` with the change types that should require a
written contract before proceeding. The defaults work for most
projects:

- 4+ files in one change
- Long-running / expensive operations
- Ranking / scoring / eval semantics changes
- Public API contract changes
- Touching two write scopes in one task

Add anything specific to your domain.

## 8. Seed `CURRENT.md` (≈ 2 min)

Open `.agent/handoffs/CURRENT.md`. Replace the placeholder
`remaining_actions` with your real first session's goal. Set
`active_slice` to whichever slice you'll start on. Set
`last_updated` to today.

## 9. Add custom subagents as needed (incremental)

When you notice you keep doing the same narrow read-only task,
write a subagent for it. See
[examples/research-deployment/.claude/agents/](../examples/research-deployment/.claude/agents/)
for patterns:

- Read-only inspector (status of external systems)
- Zero-compute diagnostician (read input + config, propose
  hypotheses without running anything expensive)
- Gate checker (PASS / FAIL / WARN on a list of prereqs)

## 10. Configure auto-memory (one-time)

Tell future Claude sessions the memory rules. In your first session
with the harness, say: "save a feedback memory: project state lives
in .agent/, never in auto-memory. SessionStart hook detects
project_* regression."

This way the agent applies the rule even in earlier turns of future
sessions.

## 11. (Optional) Wire MCP servers

If your workflows touch filesystems across multiple project repos,
GitHub PRs, Postgres, Slack, etc., consider adding an `.mcp.json`.
See [docs/concepts/mcp-servers.md](concepts/mcp-servers.md) for
which servers pair well with this harness, recommended scopes, and
the failure modes to plan for. **Skip MCP if none of the listed
patterns fit your work** — it adds startup latency and auth surface
for no return.

## When NOT to use parts of this template

- **Single-agent workspaces**: you don't need cross-agent SSOT. Keep
  CLAUDE.md and `.claude/`; drop `.agent/handoffs/` and the takeover
  protocol.
- **Truly trivial projects**: a 100-line script in a repo doesn't
  need slices. Drop `WORKFLOW.md` and slice-status; keep handoff +
  hooks if you'll have long sessions.
- **No HPC / no DB**: do not enable the optional hooks.
- **Don't like the 3-step ritual**: it's the SAME 3 steps in
  CLAUDE.md, WORKFLOW.md, and takeover-prompt.md. Edit all three
  to your preferred ritual — but edit them *together* to keep them
  aligned.

## Maintenance

- Run `./scripts/handoff.sh <agent>` at end of every session.
- Refresh `.agent/status/<slice>.md` whenever a slice meaningfully
  changes state. SessionStart warns at 7d.
- Move stale `CURRENT.md` snapshots to
  `.agent/handoffs/archive/YYYY-MM-DD-HHMM-<agent>-<topic>/` when
  starting a new chapter.
- Periodically purge `.claude/settings.local.json` of hyper-specific
  entries (Phase 1 pattern). The general allowlists in this template
  are a sustainable starting point.
