# Changelog

All notable changes follow [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [0.5.0] - 2026-06-11

Hardening release: 31 adversarially-verified fixes from a full audit of
the scripts, hooks, skills, and CI against current Claude Code spec and
production-skill conventions. Three themes: (1) **BSD/macOS portability**
— several GNU-only constructs silently no-opped on stock macOS (the
snapshot prune never pruned; `realpath --relative-to` errored into
`$(...)`); (2) **gate-bypass hardening** — the heredoc strip threw away
real commands after the first `<<`, so a heredoc prefix could smuggle
`rm -rf` / DDL / `sbatch` past every gate, and common non-obfuscated
forms (`rm -r -f`, `git -C … push --force`, lowercase `drop table`)
slipped through; (3) **spec alignment** — `$CLAUDE_PROJECT_DIR` hook
paths, per-hook timeouts, and a `SessionEnd` cleanup hook. Behavior is
backward-compatible; only internals and defaults changed.

### Added
- `.claude/hooks/session-end-cleanup.sh` (wired in `settings.json` under
  `SessionEnd`) — deletes this session's start marker; markers leaked by
  crashed sessions are swept by a new >7d prune in the SessionStart hook,
  and the markers dir is now gitignored.
- `tests/run-baton-drift-tests.sh` — 5 assertions covering heartbeat-age
  drift, `--stale-days`, README exclusion, and silent-on-empty behavior
  (baton-drift.sh previously had zero test coverage). Wired into CI.
- CI "GNU-ism tripwire" step — greps `scripts/` and `.claude/hooks/` for
  `find -printf`, `realpath --relative-to`, `mapfile`, un-fallbacked
  `stat -c`/`date -d`, and ungated `declare -A`, so BSD-breaking
  constructs fail CI instead of silently no-opping on macOS.
- 16 new hook-test fixtures; `tests/run-hook-tests.sh` grows 13→30 cases
  (post-heredoc commands — including same-line `<<X; cmd` tails and the
  `<<\EOF` delimiter form, split/quoted rm flags, env-var prefixes,
  `git -C`, lowercase DDL, SessionEnd, sbatch in/after heredoc). The
  same-line and backslash-delimiter cases are mutation-verified: they
  fail under the previous strip.
- `AGENTS.md` §"Slice ownership & leases" — the owner_session/heartbeat
  lease model, 30-min freshness window, and `--release` lifecycle were
  previously documented nowhere Codex/Cursor would read them.

### Changed
- `scripts/handoff.sh`: snapshot rotation now sorts session-dir names
  lexicographically (chronological by construction) instead of GNU
  `find -printf` — on macOS the old prune silently kept every snapshot
  forever. The mkdir-fallback lock self-heals stale locks (dead holder
  PID or >120s age) instead of deadlocking until manual cleanup;
  reclaim is serialized through a `.reap` mutex with staleness
  re-verified while holding it (0 races in a 240-acquisition stress on
  macOS bash 3.2; a naive check-then-rmdir let two waiters tear down a
  live lock), and every loop iteration consumes the 30s budget so a
  failing reclaim cannot busy-spin. `realpath --relative-to` replaced
  with a pure-shell prefix strip. Non-numeric `version:` values no
  longer abort the handoff. `--release` inserts `owner_agent: human`
  when the field is absent so released batons always pass the Stop-hook
  schema. No-slice mode detects the frontmatter-less derived-index
  CURRENT.md and skips the version bump with a notice instead of
  claiming a phantom bump.
- `scripts/status.sh`: derived-table cells escape `|` (free-text actions
  can no longer split the Markdown table); the no-pyyaml flow-list parser
  is quote-aware (matching the pyyaml path on `"do A, then B"`); the awk
  discovery scan reads flow-form `remaining_actions`; deprecated
  `datetime.utcnow()` replaced with timezone-aware now (Python 3.13).
- All three Bash gates strip heredoc/here-string **bodies** while keeping
  the commands that follow them — including commands on the SAME line as
  the `<<` operator (which the shell executes) — and recognize the
  `<<\EOF` delimiter form so its body cannot false-positive (fail-closed
  to raw-command scan if python3 is absent). The destructive gate also
  strips quotes around flags, anchors through env-var prefixes and
  `git -C/-c` options, and matches split `rm` flags; the DB gate matches
  DDL case-insensitively; the SLURM gate no longer counts
  `.agent/contracts/README.md` as an active contract.
- `.claude/settings.json`: hook + statusLine commands are
  `$CLAUDE_PROJECT_DIR`-based (CWD-independent) and every hook has an
  explicit `timeout`.
- `.claude/hooks/session-start-decay-check.sh`: empty-skills deployment
  no longer trips `set -u` on bash 3.2.
- `tests/run-skill-lint.sh`: frontmatter values are everything after the
  *first* colon — the old `-F': *'` split mangled descriptions containing
  colons and mis-measured their length.
- CI: the handoff smoke test is hermetic (AGENT_ROOT fixture with a
  legacy frontmattered CURRENT.md) so the version-bump behavior it pins
  stays testable after the template is adapted.
- Docs synced to the per-slice baton model where they still taught the
  old one: `docs/concepts/handoff-protocol.md` rewritten (batons
  authoritative, CURRENT.md derived, no `active_slice` /
  `schema_version`); `/handoff` SKILL.md prescribes the per-slice
  schema + `--release`; `.claude/hooks/README.md` documents the
  body-strip rule, the per-slice Stop-hook validation, and the
  SessionEnd hook; README quick start seeds batons via `init-slice.sh`;
  AGENTS.md / CLAUDE.md no longer claim a live SessionStart collision
  warning (it only fires under the `ENTERING_SLICE` test seam — the
  check is manual for every agent); `docs/concepts/enforcement-hooks.md`
  teaches the body-strip heredoc rule (the old `${cmd%%<<*}` advice was
  the bypass) and the `$CLAUDE_PROJECT_DIR` registration form.

## [0.4.2] - 2026-06-11

Auto-freshness on the per-slice baton model. The derived `CURRENT.md`
index previously only refreshed when someone ran `scripts/status.sh
index` by hand; a session that updated batons but skipped that step left
the index — and any view derived from it — silently frozen. This release
regenerates the index automatically at the points where staleness bites,
and surfaces baton↔reality drift so the next agent fixes the baton
instead of trusting a frozen snapshot. Additive and backward-compatible:
the manual `status.sh index` still works unchanged.

### Added
- `scripts/baton-drift.sh` — read-only, best-effort detector of drift
  between a per-slice baton and live reality. Reports (B) heartbeat age
  (`heartbeat` ≥ N days old, default 2; `--stale-days N` to override) on
  any POSIX bash, and (A) scheduler drift (a baton asserting a job is
  RUNNING that `sacct` reports terminal) only where `sacct` is on PATH
  and bash ≥ 4. Honors the `AGENT_ROOT` test seam. Never exits non-zero,
  so it can never fail a caller.

### Changed
- `scripts/handoff.sh` regenerates the derived `CURRENT.md` index and
  surfaces `baton-drift.sh` findings on **both** the claim and
  `--release` paths (new `refresh_derived_views` helper, called while the
  `OWNER.lock` is still held — `status.sh` takes no lock, so no deadlock).
- `.claude/hooks/session-start-decay-check.sh` gains a "Job 0" that
  regenerates the index and reports baton drift before the session reads
  state. Skipped under the `AGENT_ROOT` test seam so it never mutates the
  real repo during tests.
- `.claude/hooks/pre-compact-inject.sh` regenerates the index before
  snapshotting it into the compacted context, and appends any baton drift
  to the snapshot.
- Docs: `docs/concepts/enforcement-hooks.md` documents the `PreCompact`
  hook + the freshness flow; `.agent/handoffs/handoff.md` notes that
  `handoff.sh` now runs the index regen for you.

## [0.4.1] - 2026-05-29

Lifecycle hotfix on top of the v0.4.0 per-slice baton model. Adds a
terminal `released` state, an end-of-session safety net for sessions
that forget to `/handoff`, and an auto-commit convenience for
contract/plan artifacts. All v0.4.0 behavior preserved.

### Added
- `state` field in per-slice baton frontmatter
  (`active | closed | released`; default `active`). Distinguishes
  active work from intentionally archived (`closed`) or completed-and-
  handed-back (`released`) slices.
- `handoff.sh --release <slice>` verb — terminal handoff that clears
  `owner_session` / `owner_label` / `heartbeat` and sets
  `state: released`, preserving `remaining_actions`,
  `contract_pointers`, and body verbatim. Use when a slice's work is
  done and ownership should return to the pool.
- Auto-commit on handoff: untracked
  `.agent/contracts/<slice>-*.md` and `.agent/plans/<slice>-*.md`
  files matching the slice are auto-committed when the working tree
  is otherwise clean. Pass `--no-auto-commit` to opt out.
- Per-session marker written by the SessionStart hook (Job 1c) at
  `$AGENT_DIR/handoffs/state/session-markers/<session_id>.start`.
  The Stop hook compares per-slice baton `heartbeat` epochs against
  this marker to detect sessions that ended without running
  `handoff.sh` for a slice they owned.
- `tests/run-harness-lifecycle.sh` — 4-assertion regression test
  (state default, `--release` semantics, auto-commit, missed-handoff
  detection), hermetic via a sandbox repo + `AGENT_ROOT`. Wired into
  the CI matrix.

### Changed
- `.claude/hooks/stop-handoff-check.sh` now warns when a session ends
  without running `handoff.sh` for a slice it owns (per-slice baton
  `heartbeat` older than the session marker epoch).
- Stop hook validates the `state` field against the closed enum
  `{active, closed, released}`; unknown values are a schema error.
- `scripts/status.sh index` renders a `state` column with distinct
  rendering for `🔒 closed` and `📦 released`, so released slices
  are visually distinguishable from active claims.

## [0.4.0] - 2026-05-27

Per-slice handoff model — concurrent-safe coordination for multiple
agent sessions sharing one `.agent/` tree. Previously a single
hand-edited `CURRENT.md` was the cross-agent SSOT; two sessions
working different slices would clobber each other's `remaining_actions`
on handoff. The authoritative baton is now per-slice, and `CURRENT.md`
becomes a derived index. The plain no-slice `handoff.sh <agent>` mode
is preserved for backward compatibility.

### Added
- `scripts/status.sh` — read-only slice status with a derived-index
  mode. `status.sh index` regenerates `.agent/handoffs/CURRENT.md`
  from the per-slice `status/*.md` frontmatter (one table row per
  slice + a per-slice `remaining_actions` section, with a hard
  anti-leak guarantee that a slice's actions appear only under that
  slice). Atomic write (`.tmp` + `mv`); zero status files is a hard
  error that does not clobber an existing `CURRENT.md`. No-arg lists
  discovered slices; `<slice>` summarizes one. No hardcoded slice
  names — slices are discovered from `status/*.md`.
- Per-slice baton frontmatter in `.agent/status/<slice>.md`:
  `owner_session` (UUID), `owner_label`, `owner_agent`, `version`,
  `last_updated`, `heartbeat`, `remaining_actions`, `contract_pointers`.
  Schema documented in `.agent/status/README.md`.
- `tests/run-harness-concurrency.sh` — 5-assertion concurrency
  regression test (lost-update, index regen, claim warning, no
  cross-slice leak, per-slice Stop validation), hermetic via a sandbox
  repo + `AGENT_ROOT`. Wired into the CI matrix.
- `AGENT_ROOT` env seam across `handoff.sh`, `status.sh`, and both
  hooks — points all `.agent` reads/writes at an alternate tree
  (used by the concurrency test for isolation; default = the repo's
  own `.agent`).

### Changed
- `scripts/handoff.sh` gained a per-slice mode: `handoff.sh <agent>
  <slice>` claims and refreshes ONLY `status/<slice>.md` (owner fields
  + heartbeat + version bump), preserving its `remaining_actions` /
  `contract_pointers` / body verbatim, and leaves `CURRENT.md` alone.
  The no-slice mode (git-snapshot writer) is unchanged.
- `.claude/hooks/session-start-decay-check.sh` — adds a live-claim
  check: when entering a slice (`ENTERING_SLICE`) whose heartbeat is
  fresh (<30 min) under a different `owner_session`, it warns about the
  contested slice. Bootstrap now sources active state from the
  per-slice frontmatter instead of a single `active_slice` scalar.
- `.claude/hooks/stop-handoff-check.sh` — validates the per-slice
  `status/<slice>.md` frontmatter (required fields, `owner_agent` ∈
  the valid set, ISO `last_updated`, unfilled `<...>` placeholder
  scan) instead of `CURRENT.md`'s `active_slice` scalar; tolerates a
  derived `CURRENT.md` with no top-level `version`.
- Ritual docs (`CLAUDE.md`, `WORKFLOW.md`,
  `.agent/handoffs/{handoff,takeover-prompt,README}.md`,
  `.agent/status/README.md`, `HARNESS_USAGE.md`) rewritten to the
  per-slice baton model: `status/<slice>.md` is authoritative,
  `CURRENT.md` is the derived index (never hand-edited), handoff is
  `handoff.sh <agent> <slice>` + `status.sh index`.

## [0.3.1] - 2026-05-21

### Added
- `tests/run-skill-lint.sh` — quality lint for every SKILL.md
  (frontmatter shape, description length 60-400, Red Flags section,
  Forbidden section, Red Flags table ≥ 3 rows). Wired into CI on
  the ubuntu+macos matrix.
- `scripts/new-skill.sh` — scaffolds a lint-passing SKILL.md
  skeleton per category (`process | expertise | workflow`). CI
  smoke-tests all three categories on each push.

### Changed
- `.claude/hooks/post-edit-format.sh` moved from `optional/` to the
  default hooks directory and registered in `settings.json`
  PostToolUse. Safe by default: every formatter (ruff / prettier /
  shfmt) is detected at hook invocation; absent formatters → silent
  no-op. To disable entirely, remove the hook entry from
  `settings.json`.
- `code-review` and `refactor-simplify` skill descriptions trimmed
  to fit the new ≤400-char lint bound.
- `route` and `slice-status` skills gained a `## Forbidden` section
  (B3 lint rule).
- `refactor-simplify` skill gained a `## Red Flags` table (7
  entries) — B2/B4 lint rules.

### Fixed
- `session-start-decay-check.sh` SessionStart bootstrap heredoc no
  longer contains an apostrophe; macOS bash 3.2 mis-parsed
  `project's` inside `$(cat <<EOF ...)`. Linux was unaffected.

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
