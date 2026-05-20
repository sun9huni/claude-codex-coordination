# Changelog

All notable changes follow [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

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
