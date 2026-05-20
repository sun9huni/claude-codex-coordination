# Changelog

All notable changes follow [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [0.3.0] - 2026-05-20

Three new capability layers added on top of the v0.2.x coordination
foundation. All v0.2.x behavior preserved; this is purely additive.

### Added — Expertise skills (4)
Opinionated, Karpathy-aligned skills with Red Flags rationalization
tables and "When NOT to" sections. Independent of the workflow chain.

- `/code-review` — reviews a diff through 5 lenses (correctness /
  design / simplicity / surgicality / testability) + Karpathy
  guardrails. Default verdict REQUEST_CHANGES; APPROVE requires
  active checking. Refuses to review > 500-line diffs.
- `/refactor-simplify` — proactively scans for what to DELETE /
  INLINE / RENAME. Net-line negative required. Test gate at Step
  0 refuses behavior-changing refactor on uncovered code.
- `/test-gen` — pytest scaffold generator. Step 3 lists behaviors
  (3-7 cases); Step 4 pauses for user confirm; Step 5 writes file
  with parametrize / pytest.raises / honest invariant assertions.
  No-silent-write rule.
- `/debug` — hypothesis-first failure diagnosis. Six lenses;
  proposes ONE distinguishing diagnostic command, never a fix in
  the same turn. allowed-tools excludes Edit/Write.

### Added — Workflow chain (3 skills, obra/superpowers adaptation)

Three skills enforce upstream artifacts before downstream can run.
Plugs into existing `.agent/contracts/`; introduces `.agent/plans/`.

- `/brainstorm "<topic>"` — Socratic spec gate. 5 high-leverage
  questions (success criterion / out-of-scope / constraints /
  rollback / approval gates) → contract draft. HARD-GATE: no
  source edits during brainstorm.
- `/write-plan <contract-path>` — refuses to plan against a
  pending contract. Decomposes approved spec into 2-5 minute
  tasks with mandatory verification field. Phases:
  setup / schema / core / glue / tests / docs.
- `/execute-plan <plan-path>` — subagent task loop. Per task:
  delegate to subagent → `/code-review` the diff → spec-conformance
  check → one commit. Hard stops on approval-gate triggers, scope
  creep, consecutive review failures.

### Added — `.agent/plans/` directory

New directory with README documenting the contract → plan →
execute lifecycle and per-task structure (status / prereqs /
files / change-shape / verification / estimate / rollback).

### Added — Productive PostToolUse hook (optional)

First productive (vs defensive) hook: `optional/post-edit-format.sh`.
Reformats touched files via `ruff format` (.py), `prettier --write`
(.js/ts/json/md/yaml), or `shfmt -w` (.sh). Auto-detects which
formatters are installed; missing formatter or missing jq → silent
skip. Always exits 0 — productivity layer never blocks.

### Changed — SessionStart hook

`session-start-decay-check.sh` extended with a second job:
- **stderr** (unchanged): warnings on stale CURRENT.md / status /
  memory leak.
- **stdout JSON** (new): `hookSpecificOutput.additionalContext`
  payload injecting workspace bootstrap directly into session
  context at turn 0. Auto-detects which skills, gates, and
  productive hooks are actually present and adapts the bootstrap
  text accordingly.

Effect: no reliance on CLAUDE.md being re-read at session start.
The active context reflects the live deployment (not template
defaults) within the first turn.

### Skill inventory

Now 11 skills in 3 categories:
- **Process** (4): `/handoff`, `/slice-status`, `/contract-check`, `/route`
- **Expertise** (4): `/code-review`, `/refactor-simplify`, `/test-gen`, `/debug`
- **Workflow** (3): `/brainstorm`, `/write-plan`, `/execute-plan`

## [0.2.1] - 2026-05-20

### Fixed
- `scripts/handoff.sh` used `flock` unconditionally, which is
  util-linux only. macOS CI broke with "flock: command not found".
  Added a portable fallback: `flock` when available, otherwise an
  atomic `mkdir OWNER.lock.d` mutex with trap-based cleanup. The
  Linux path is unchanged; macOS / BSD now works.

## [0.2.0] - 2026-05-20

External audit found 3 P1 and 4 P2 issues against v0.1.0. This
release addresses all 7.

### Security / correctness (P1)
- **Hook fail-closed when jq missing**. Previously the Bash-input
  parsing returned an empty string when `jq` was off PATH, the
  `tool_name == "Bash"` test failed, and the hook exited 0 (allow).
  All three Bash hooks now check `command -v jq` and exit 2 with a
  clear stderr message if missing.
- **Atomic + versioned handoff with flock**. `scripts/handoff.sh`
  acquires `.agent/handoffs/OWNER.lock` (exclusive, 30s timeout)
  for the duration of the run. CURRENT.md frontmatter gains a
  `version` field that is bumped via `.tmp + mv -f` (atomic). Two
  concurrent handoffs now serialize cleanly instead of racing.
- **Per-run snapshot directories**. State files used to overwrite
  fixed paths in `.agent/handoffs/state/`. Now each handoff writes
  to `state/sessions/<UTC-timestamp>-<agent>/` and re-points
  `state/latest` symlink. Previous snapshots are preserved (kept
  to the most recent 20).
- **Stop hook detects "agent forgot to /handoff"**. Compares
  `CURRENT.md.version` against `state/latest/meta.txt:current_version`.

### Portability (P2)
- **Portable file mtime**. Both `SessionStart` and `Stop` hooks
  replace GNU-only `stat -c %Y` with a `file_mtime()` fallback
  chain: `stat -c %Y` → `stat -f %m` (BSD/macOS) → `python3 -c
  "os.path.getmtime(...)"`.
- **Stdlib-only yaml validation**. Previous Stop hook silently
  skipped schema validation when PyYAML was not installed. Now
  PyYAML is tried first; on `ImportError`, a stdlib mini-parser
  (regex + key/list line handling) still catches missing required
  fields, invalid agent names, action-count violations, and stale
  dates.

### Native surface (P2)
- **`PreCompact` hook** (`.claude/hooks/pre-compact-inject.sh`)
  prints the current `.agent/handoffs/CURRENT.md` content to stdout
  before context compaction so the summarized post-compact context
  retains workspace state-of-truth instead of paraphrasing it away.
- **`statusLine`** (`.claude/statusline.sh`) renders model,
  active_slice, owner_agent, version, CURRENT.md age, and context
  window % on every assistant message and after `/compact`.

### Quality (P2)
- **CI workflow** at `.github/workflows/test.yml` running on
  `ubuntu-latest` and `macos-latest`:
  - `bash -n` on every `*.sh`
  - JSON validation
  - Hook tests via `tests/run-hook-tests.sh` with golden fixtures
    under `tests/fixtures/*.json`
  - Smoke test for `handoff.sh` (snapshot + symlink + version bump
    sequence) and `init-slice.sh` (status + harness scaffolded)
- **`tests/run-hook-tests.sh`** — 13 golden fixture tests covering
  destructive / slurm / db / decay / stop hooks across allow/block
  + false-positive scenarios (rm and DROP TABLE keywords inside
  heredoc commit messages).

### Fixed
- `optional/pre-bash-slurm-gate.sh` `ROOT` was computed two
  directories up but the script lives in `.claude/hooks/optional/`,
  needing three. SLURM gate now correctly resolves contracts
  directory.
- Destructive gate `rm` regex previously required `[rRfF]+` which
  matched `rm -f` (single-file delete). Now requires both `r/R`
  AND `f/F` in the flag string.

### Docs
- `multi-agent-coexistence.md` concurrency section rewritten to
  reflect what the new lock + version field guarantee vs the
  remaining agent-level limit.
- `handoff.md` documents `version` field as script-managed.

## [0.1.0] - 2026-05-20

Initial release. Extracted and generalized from a production research
workspace where Claude Code, Codex, and Cursor coexisted across multiple
projects.

### Added
- Three coordinated entry documents: `CLAUDE.md`, `AGENTS.md`,
  `WORKFLOW.md` — all sharing the same 3-step session-start ritual.
- `HARNESS_USAGE.md` — day-to-day reference.
- `.agent/handoffs/CURRENT.md` template with yaml frontmatter
  (schema_version 1) + `handoff.md` protocol + `takeover-prompt.md`
  for cross-agent takeover.
- `.claude/hooks/` core hooks:
  - `session-start-decay-check.sh` — stale handoff / status warning
  - `pre-bash-destructive-gate.sh` — block rm -rf on shared/harness
    dirs, force pushes, hard resets, force branch deletes
  - `stop-handoff-check.sh` — validate CURRENT.md yaml frontmatter +
    warn if not updated recently
- `.claude/hooks/optional/`:
  - `pre-bash-slurm-gate.sh` — block sbatch without active contract
  - `pre-bash-db-gate.sh` — block psql DDL
- `.claude/skills/` four slash commands:
  - `/handoff` — schema-guided CURRENT.md update + handoff.sh
  - `/slice-status` — consolidated slice view (static + live + git)
  - `/contract-check` — WORKFLOW §2 trigger check + contract draft
  - `/route` — map work signal to slice + harness file
- `.agent/contracts/_template.md` — generic contract template
- `scripts/handoff.sh` — git state snapshot + placeholder check
- `scripts/init-slice.sh` — scaffold a new slice (status + harness +
  routing-table reminder)
- `docs/design.md` — 8-phase architecture rationale
- `docs/customization.md` — how to adapt to your project
- `docs/concepts/` — deeper dives
- `examples/research-deployment/` — filled-in example deployment
