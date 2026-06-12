# Design rationale

Why each piece of this harness exists. Useful before customizing —
once you know what each thing solves, deciding what to keep, change,
or drop becomes easy.

## The problem this solves

A single workspace shared by Claude, Codex, Cursor, and a human
hits seven failure modes that compound:

1. **Aspirational governance via prose.** Rules ("approve before X",
   "don't push to main") live in docs. Nothing enforces them. Each
   agent reads, interprets, applies — and drifts.
2. **Coordination layer is unversioned.** Workspaces typically are
   not git trees. State files like `CURRENT.md` overwrite history
   silently. Lose one, lose context.
3. **Eight state surfaces, zero SSOT.** Per-agent memory, per-slice
   status, per-task contract, archive, handoff, scratch, plan,
   chat. Three agents pick three different subsets.
4. **Private context leak.** Claude's auto-memory and Codex's
   sessions hold facts the other agent cannot see, biasing decisions
   silently.
5. **Multiple session-start rituals.** CLAUDE.md says one order,
   AGENTS.md another, takeover-prompt.md a third. Behavior depends
   on which file the agent anchored on first.
6. **Claude's native primitives unused.** Hooks, slash skills,
   custom subagents — all available, none integrated.
7. **Settings bloat.** Permission files accumulate hyper-specific
   entries that never re-match.

The harness moves each of these from "ambient drift" to "explicit
mechanism":

| Failure | Mechanism |
|---|---|
| Prose-only governance | PreToolUse / Stop hooks |
| Unversioned coord | workspace `git init` + this template tracks the coord layer |
| 8 surfaces | one SSOT (`CURRENT.md`) with yaml schema; status/contract have explicit lifecycles |
| Private leak | memory policy + SessionStart hook detects regression |
| Mixed rituals | 3-step ritual stated identically in CLAUDE.md / WORKFLOW.md / takeover-prompt.md |
| Unused primitives | `.claude/hooks/`, `.claude/skills/`, `.claude/agents/` wired in |
| Settings bloat | Phase 1 cleanup pattern + `settings.local.json` for project-scoped overrides |

## The 8 phases

The reference deployment was built in 8 incremental phases (in
`examples/research-deployment/`). Each phase is one git commit so it
can be reverted independently.

### Phase 0 — git init + .gitignore + baseline
The coordination layer must be versioned. Without history, lose
`CURRENT.md` once and the workspace state is gone. `.gitignore`
excludes project repos (each has its own `.git`), large binaries,
and runtime caches.

### Phase 1 — Settings cleanup
`.claude/settings.json` accumulates broken permission entries over
time (heredoc captures, malformed escapes). Periodic cleanup +
generalization (`Bash(conda run:*)` instead of 50-line heredocs) is
needed.

### Phase 2 — CLAUDE.md as single Claude entry
One 3-step ritual. No "read these 6 files in some order". Defers
shared rules to AGENTS.md.

### Phase 3 — Memory cleanup
`project_*` memory files violate the auto-memory guide ("do not save
project state"). Move that content to `.agent/`. Auto-memory is
user/feedback/reference only.

### Phase 4 — Enforcement hooks
PreToolUse hooks block dangerous Bash. SessionStart warns about
stale state. Stop validates handoff schema. The first actual
enforcement layer in the workspace; everything before was prose.

Critical lesson: hooks must anchor patterns to look like real
commands AND strip heredoc bodies, or they trip on commit messages
that mention the dangerous keywords.

### Phase 5 — Slash skills
`/handoff`, `/slice-status`, `/contract-check`, `/route`. These
encode the workflow patterns as Claude-native primitives instead of
prose instructions the agent has to remember.

### Phase 6 — Custom subagents
Restricted-tool delegations. A SLURM inspector with `sbatch` denied,
a zero-compute diagnostician with `python:*` denied, etc. Narrower
tool surface = less context, fewer accidents.

### Phase 7 — CURRENT.md yaml schema
Frontmatter with `owner_agent`, `last_updated`, `active_slice`,
`remaining_actions`. Stop hook validates. Codex continues to read
the markdown body — backward compatible. (Superseded in v0.4: the
schema moved to per-slice `.agent/status/<slice>.md` batons — the
slice is the filename, so `active_slice` is gone — and CURRENT.md
became a derived index over them.)

### Phase 8 — Ritual unification
WORKFLOW.md and takeover-prompt.md aligned to the same 3 steps that
CLAUDE.md uses. takeover-prompt.md adds 4 takeover-specific steps as
a clearly-marked extension.

## v0.3.0 additions (post-initial release)

The first eight phases built the **coordination layer** (one SSOT,
enforced gates, schema-validated handoffs). v0.3.0 adds three more
layers on top:

### Expertise skills (opinionated code work)

Four skills replace ad-hoc requests like "review this" or "find a
bug" with structured, Karpathy-aligned workflows. Each ships with
a Red Flags rationalization table (the common excuses that get
blocked) plus an explicit "When NOT to" section.

- `/code-review` — five lenses + Karpathy guardrails + default
  REQUEST_CHANGES verdict.
- `/refactor-simplify` — net-line negative discipline; the bias
  is delete / inline / rename, never add.
- `/test-gen` — behavior list first, user confirms, then pytest
  scaffold writes. No-silent-write rule.
- `/debug` — hypothesis-first; never applies a fix in the same
  turn as diagnosis.

These are independent of the workflow chain — you can /debug a
failure without going through /brainstorm.

### Workflow chain (spec → plan → execute)

Adapted from obra/superpowers. Three skills enforce upstream
artifacts before downstream skills can run:

```
/brainstorm        →  .agent/contracts/<slug>.md   (Status: pending → approved)
   |
/write-plan        →  .agent/plans/<slug>.md       (Status: pending → approved)
   |
/execute-plan      →  per-task subagent loop with /code-review gate
                      one commit per task
                      contract status: done at the end
```

Each downstream skill refuses to run if the upstream artifact is
still pending. The chain plugs into existing `.agent/contracts/` —
no new directory invented.

### Productive PostToolUse layer

The first PostToolUse hook that is productive (vs the defensive
PreToolUse gates). Optional `post-edit-format.sh` reformats
touched files via `ruff format` / `prettier --write` / `shfmt -w`
based on extension. Productive hooks never block; they exit 0
regardless. The defensive gates remain the security boundary.

### SessionStart additionalContext injection

The SessionStart hook now emits a JSON payload (Claude Code's
`hookSpecificOutput.additionalContext` channel) that injects the
live workspace bootstrap directly into the session context. The
hook auto-detects which skills, gates, and productive layers are
actually present and adapts the bootstrap text accordingly — so
the cloning user sees an accurate snapshot of *their* deployment,
not the template defaults.

Net effect: turn 0 of every session already knows what's active,
without relying on CLAUDE.md being re-read.

## What this harness does not solve

- It only partially synchronizes **concurrent agent execution**.
  Since v0.4, concurrent sessions are safe as long as they work on
  DIFFERENT slices: each session writes only its own
  `.agent/status/<slice>.md` baton, `handoff.sh` serializes through
  `OWNER.lock`, and `CURRENT.md` is a derived index regenerated
  atomically. Two agents claiming the SAME slice is still a
  coordination problem — the heartbeat/lease warns, it does not
  prevent.
- It does not measure governance compliance. The KPI doc in the
  reference deployment is aspirational — *what to measure*, not
  *how to collect it*. Building that telemetry is a separate
  project.
- It is not opinionated about your project. The slices, contracts,
  and routing are blank — you fill them in.

## See also

- [customization.md](customization.md) — adapting to your project
- [concepts/](concepts/) — deeper dives on each piece
- [examples/research-deployment/](../examples/research-deployment/) —
  one filled-in deployment
