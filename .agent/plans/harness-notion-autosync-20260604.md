---
contract: .agent/contracts/harness-notion-autosync-20260604.md
slice: harness
status: done
total_tasks: 9
estimated_total_min: 46
---

# Plan: Harness Notion Auto-Sync (MCP-only auto-catch-up)

A handoff drops a `notion-sync-pending` marker; the next MCP-capable session
auto-applies the sync (SessionStart surfaces a self-contained directive);
`--stamp-home-applied` clears the marker; the Stop hook escalates if unresolved.
The Notion write stays agent-mediated (MCP-only ceiling) — but a skipped Step 5
no longer causes lasting drift. B (headless writer) is a separate contract.

Marker = `.agent/handoffs/state/notion-sync-pending` (untracked, like
home-render.stamp), lines `<slice> <rev> <iso>`. Ownership: handoff.sh WRITES it
in bash (honors `$AGENT_DIR`/AGENT_ROOT); the hooks READ it in bash (honor
`$AGENT_DIR`); `notion_sync.py --stamp-home-applied` CLEARS it (honors REPO_ROOT
+ a new `NOTION_SYNC_REPO_ROOT` override so bash fixtures can point it at a tmp tree).

Grounding (verified this session):
- `scripts/notion_sync.py`: `REPO_ROOT = Path(__file__).resolve().parent.parent`
  (L30, no override); `write_home_stamp()` (T7, writes home-render.stamp);
  `render_home()`, `slice_to_db_row()`, `assert_home_preserves()`; `parse_args`
  (~L1460) / `main` (~L1476, early-return dispatch blocks).
- `scripts/handoff.sh`: slice branch `if [ -n "$SLICE" ]` (L328) writes the baton
  and prints `[handoff] wrote: $slice_file` (~L429), all under the flock; uses
  `AGENT_DIR="${AGENT_ROOT:-$ROOT/.agent}"`.
- `.claude/hooks/session-start-decay-check.sh`: `AGENT_DIR` seam; Job 2 builds the
  `bootstrap` heredoc (L208-242) emitted as `additionalContext` JSON (L245-254).
- `.claude/hooks/stop-handoff-check.sh`: non-blocking; `AGENT_DIR`; ends `exit 0`;
  already emits `[home-stale]`/`[baton-lint]`. `tests/run-stop-hook-tests.sh` exists.
- home-render.stamp + state dir already present + untracked.

## Task 1: RED test — marker clear-on-stamp + NOTION_SYNC_REPO_ROOT override

- **Status**: done
- **Prereq tasks**: none
- **Files touched**: `tests/test_notion_migration.py`
- **Change shape**: add `test_stamp_clears_sync_pending_marker(tmp_path, monkeypatch)`
  (monkeypatch `REPO_ROOT`→tmp; create `.agent/handoffs/state/notion-sync-pending`
  with two lines; call `notion_sync.main(["--stamp-home-applied"])`; assert exit 0
  AND the marker file no longer exists / is empty). Add
  `test_repo_root_env_override(monkeypatch)` asserting that setting
  `NOTION_SYNC_REPO_ROOT` makes `notion_sync._resolve_repo_root()` (or the
  documented override accessor) return that path. (Use whatever minimal accessor
  T2 will add — the test pins the contract.)
- **Verification**: `python -m pytest tests/test_notion_migration.py -k "sync_pending or repo_root_env" -q`
  → fails (no marker-clear / no override yet).
- **Estimated time**: 5 min
- **Rollback (if this task only)**: remove the added tests.

## Task 2: GREEN — NOTION_SYNC_REPO_ROOT override + clear marker on stamp

- **Status**: done
- **Prereq tasks**: 1
- **Files touched**: `scripts/notion_sync.py`
- **Change shape**: (a) make `REPO_ROOT` honor an env override:
  `REPO_ROOT = Path(os.environ["NOTION_SYNC_REPO_ROOT"]).resolve() if
  os.environ.get("NOTION_SYNC_REPO_ROOT") else Path(__file__).resolve().parent.parent`
  (keep a tiny helper or inline; `os` is already imported). (b) add a module
  constant `_SYNC_PENDING = lambda`-free helper `_sync_pending_path() -> Path`
  returning `REPO_ROOT/".agent"/"handoffs"/"state"/"notion-sync-pending"`. (c) in
  `write_home_stamp()`, after writing the stamp, delete the marker if present
  (`p.unlink(missing_ok=True)`), so `--stamp-home-applied` resolves the pending state.
- **Verification**: `python -m pytest tests/test_notion_migration.py -k "sync_pending or repo_root_env" -q`
  → passes; `NOTION_SYNC_REPO_ROOT=/tmp/x python scripts/notion_sync.py --stamp-home-applied; ls /tmp/x/.agent/handoffs/state/` → stamp present.
- **Estimated time**: 5 min
- **Rollback (if this task only)**: `git checkout scripts/notion_sync.py`

## Task 3: `--handoff-emit <slice>` (consolidated emitter, red→green)

- **Status**: done
- **Prereq tasks**: 2
- **Files touched**: `scripts/notion_sync.py`, `tests/test_notion_migration.py`
- **Change shape**: add `--handoff-emit` (nargs="?" like `--lint-baton`, slice from
  the arg or `--slice`). In `main()` (after the `--render-home` block): render the
  home body, run `assert_home_preserves`; if a child would drop, print
  `HOME_RENDER_UNSAFE` to stderr + return 2; else print a structured block — a
  `=== HOME (replace_content) ===` header + the home body, then
  `=== ROW: <slice> (update_properties) ===` + `json.dumps(slice_to_db_row(slice))`
  — and return 0. Add `test_handoff_emit_has_home_and_row(tmp_path, monkeypatch)`
  (monkeypatch REPO_ROOT + copy the real tail; assert output contains `🛰️`, the
  `=== ROW:` header, and `"Name": "<slice>"`).
- **Verification**: `python -m pytest tests/test_notion_migration.py -k handoff_emit -q`
  → passes; `python scripts/notion_sync.py --handoff-emit harness | grep -cE '🛰️|=== ROW:|"Name"'` → ≥3; `echo $?` of the run → 0.
- **Estimated time**: 6 min
- **Rollback (if this task only)**: `git checkout scripts/notion_sync.py tests/test_notion_migration.py`

## Task 4: handoff.sh — write the pending marker + print the recipe

- **Status**: done
- **Prereq tasks**: none
- **Files touched**: `scripts/handoff.sh`
- **Change shape**: in the slice branch (after `[handoff] wrote: $slice_file`,
  ~L429, still under the flock), append a guarded block: compute
  `rev=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo '?')` and
  `iso=$(date -u +%Y-%m-%dT%H:%M:%SZ)`; write to
  `marker="$AGENT_DIR/handoffs/state/notion-sync-pending"` — dedup the slice's
  prior line (`grep -v "^$SLICE " "$marker" 2>/dev/null > "$marker.tmp"`,
  `mv "$marker.tmp" "$marker"`) then append `"$SLICE $rev $iso"`. Then print a
  recipe to stdout: `[handoff] NOTION SYNC PENDING (MCP-only — not scriptable):` +
  `  python scripts/notion_sync.py --handoff-emit $SLICE` + `  → apply HOME via MCP
  replace_content + the ROW via update_properties` + `  python scripts/notion_sync.py
  --stamp-home-applied   # clears this marker`. Guard the whole block with
  `|| true`/`mkdir -p` so it can NEVER fail the handoff.
- **Verification**: `AGENT_ROOT=$(mktemp -d)/.agent` fixture with a `status/foo.md`;
  `mkdir -p "$AGENT_ROOT/status" "$AGENT_ROOT/handoffs"`; run
  `AGENT_ROOT=... ./scripts/handoff.sh claude foo 2>&1 | tee /tmp/h.out`; assert
  `grep -q '^foo ' "$AGENT_ROOT/handoffs/state/notion-sync-pending"` AND
  `grep -q 'NOTION SYNC PENDING' /tmp/h.out`. (Reported inline; T8 makes it a
  persistent E2E test.)
- **Estimated time**: 6 min
- **Rollback (if this task only)**: `git checkout scripts/handoff.sh`

## Task 5: session-start hook — inject the pending directive (red→green)

- **Status**: done
- **Prereq tasks**: none
- **Files touched**: `.claude/hooks/session-start-decay-check.sh`, `tests/run-session-start-tests.sh` (new)
- **Change shape**: in Job 2, before building the `bootstrap` heredoc, read
  `marker="$AGENT_DIR/handoffs/state/notion-sync-pending"`; if it exists and is
  non-empty, set `pending_slices=$(awk '{print $1}' "$marker" | sort -u | paste -sd' ')`
  and build a `pending_block` string:
  `⚠️ NOTION SYNC PENDING: <slices> — a prior handoff did not refresh Notion.
  As part of session start, run: python scripts/notion_sync.py --handoff-emit <slice>
  → apply HOME via MCP replace_content + the ROW via update_properties →
  python scripts/notion_sync.py --stamp-home-applied (clears the marker).` Inject
  `${pending_block}` into the `bootstrap` heredoc (a new section, only when
  non-empty). New `tests/run-session-start-tests.sh`: AGENT_ROOT fixture with a
  marker → assert the hook's STDOUT contains `NOTION SYNC PENDING`; no marker →
  assert it does not. Print PASS/FAIL.
- **Verification**: `bash tests/run-session-start-tests.sh` → `PASS`.
- **Estimated time**: 6 min
- **Rollback (if this task only)**: `git checkout .claude/hooks/session-start-decay-check.sh; rm tests/run-session-start-tests.sh`

## Task 6: stop hook — `[notion-sync-pending]` escalation

- **Status**: done
- **Prereq tasks**: none
- **Files touched**: `.claude/hooks/stop-handoff-check.sh`, `tests/run-stop-hook-tests.sh`
- **Change shape**: add a non-blocking section (near the `[home-stale]` block,
  before `exit 0`): if `"$AGENT_DIR/handoffs/state/notion-sync-pending"` exists and
  is non-empty, print `[notion-sync-pending] <slices> — run notion_sync.py
  --handoff-emit → MCP apply → --stamp-home-applied to sync Notion.` (slices via
  `awk '{print $1}' | sort -u`). Stays `exit 0`. Extend `tests/run-stop-hook-tests.sh`:
  a fixture with a non-empty marker → assert `[notion-sync-pending]` present; an
  empty/absent marker → assert absent.
- **Verification**: `bash tests/run-stop-hook-tests.sh` → `PASS` (existing cases +
  the two new ones).
- **Estimated time**: 5 min
- **Rollback (if this task only)**: `git checkout .claude/hooks/stop-handoff-check.sh tests/run-stop-hook-tests.sh`

## Task 7: Docs — runbook + both handoff skills

- **Status**: done
- **Prereq tasks**: 3, 4, 5, 6
- **Files touched**: `docs/notion-sync-runbook.md`, `.claude/skills/handoff/SKILL.md`, `.codex/skills/handoff-writer/SKILL.md`
- **Change shape**: runbook — new subsection documenting the auto-sync loop: the
  `notion-sync-pending` marker (dropped by handoff.sh), `--handoff-emit`, the
  SessionStart auto-catch-up directive + the `[notion-sync-pending]` Stop warning,
  and that `--stamp-home-applied` clears the marker; note the MCP-only ceiling +
  that B (headless writer) is a future contract. Both handoff skills' Step 5:
  mention the marker is dropped automatically, `--handoff-emit` is the one-shot
  emitter, and `--stamp-home-applied` clears it; the next MCP session auto-applies
  a pending sync.
- **Verification**: `grep -c -E 'handoff-emit|notion-sync-pending' docs/notion-sync-runbook.md .claude/skills/handoff/SKILL.md .codex/skills/handoff-writer/SKILL.md` → ≥1 each; `bash tests/run-skill-lint.sh` → PASS.
- **Estimated time**: 5 min
- **Rollback (if this task only)**: `git checkout docs/notion-sync-runbook.md .claude/skills/handoff/SKILL.md .codex/skills/handoff-writer/SKILL.md`

## Task 8: E2E loop test (handoff → SessionStart → emit → stamp → Stop)

- **Status**: done
- **Prereq tasks**: 2, 4, 5, 6
- **Files touched**: `tests/run-notion-autosync-tests.sh` (new)
- **Change shape**: a bash test on an `AGENT_ROOT` fixture (with a `status/<slice>.md`):
  (1) run `handoff.sh claude <slice>` → assert the marker line + `NOTION SYNC PENDING`
  recipe; (2) run the SessionStart hook → assert stdout has the pending directive;
  (3) run the Stop hook → assert `[notion-sync-pending]`; (4) run
  `NOTION_SYNC_REPO_ROOT=<fixture-root> notion_sync.py --stamp-home-applied` → assert
  the marker is gone; (5) re-run the Stop + SessionStart hooks → assert NO pending
  line/directive. Print PASS/FAIL. (Pure local; no Notion/MCP — the literal MCP
  apply is the only step not exercised, by design.)
- **Verification**: `bash tests/run-notion-autosync-tests.sh` → `PASS`.
- **Estimated time**: 6 min
- **Rollback (if this task only)**: `rm tests/run-notion-autosync-tests.sh`

## Task 9: Verification + contract close + handoff

- **Status**: done
- **Prereq tasks**: 7, 8
- **Files touched**: `.agent/contracts/harness-notion-autosync-20260604.md`, `.agent/status/harness.md`, `.agent/handoffs/CURRENT.md`
- **Change shape**: run the full suite; set contract `status: done` + Progress Log;
  update harness baton (auto-sync shipped; note the marker + `--handoff-emit` +
  auto-catch-up + that B is the next available follow-up); `./scripts/handoff.sh
  claude harness`; `./scripts/status.sh index`; commit. (Then this session's own
  next SessionStart will itself exercise the auto-catch-up.)
- **Verification**: `python -m pytest tests/test_notion_migration.py
  tests/test_notion_sync_read.py -q` green; `bash tests/run-notion-autosync-tests.sh`,
  `bash tests/run-session-start-tests.sh`, `bash tests/run-stop-hook-tests.sh` PASS;
  `python scripts/notion_sync.py --handoff-emit harness` exit 0; `./scripts/tool-audit.sh`;
  `./scripts/verify.sh`; `bash tests/run-skill-lint.sh`; scoped `git diff --check`;
  `head -8 .agent/status/harness.md` shows bumped version.
- **Estimated time**: 5 min
- **Rollback (if this task only)**: `git revert` the close commit; contract back to approved.
