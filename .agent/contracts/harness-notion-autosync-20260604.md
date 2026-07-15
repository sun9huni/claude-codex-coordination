---
status: done
slice: harness
topic: notion-autosync
date: 2026-06-04
owner: claude
approved_by: user ("승인") 2026-06-04
design_spec:
implementation_plan: .agent/plans/harness-notion-autosync-20260604.md
decisions:
  - "Architecture = A (MCP-only auto-catch-up) THIS contract; B (headless NOTION_TOKEN writer for DB-row properties) is explicitly a SEPARATE follow-up contract. Hard ceiling acknowledged: Notion writes are MCP-only and the styled home cockpit (callouts/columns/embedded DBs = enhanced-markdown) can NEVER go headless — only the in-session agent can render it. So 'max automation' = make the manual MCP apply un-skippable + auto-recovered by the next MCP-capable session, NOT a no-agent write."
  - "Pending marker: handoff.sh drops/updates `.agent/handoffs/state/notion-sync-pending` (one line per slice that handed off since the last sync: `<slice> <rev> <iso>`), under the untracked state dir (like home-render.stamp). handoff.sh ALSO prints the exact apply recipe at the end so a session running the bare script cannot miss it."
  - "Auto-catch-up = SessionStart aggressiveness 'surface + auto-apply' (user choice): session-start-decay-check.sh injects a self-contained `⚠️ NOTION SYNC PENDING: <slices>` directive (with the exact apply commands); the next MCP-capable (Claude) session applies it as part of its ritual (--handoff-emit → MCP replace_content + row update → --stamp-home-applied) and reports one line. A non-MCP session (Codex) leaves the marker for the next Claude session (cross-session recovery)."
  - "Consolidated emit: `notion_sync.py --handoff-emit <slice>` prints BOTH the rendered home body AND that slice's Slices-DB row payload in one structured block, so the apply is a deterministic mechanical step (no per-substep judgement)."
  - "Resolution: `--stamp-home-applied` clears the pending marker (the stamp IS the 'sync complete' signal). The Stop hook escalates `[notion-sync-pending]` when the marker is non-empty (complements the [home-stale] mtime backstop shipped in home-trust). All hooks stay NON-blocking (exit 0)."
---

# Harness — Notion Auto-Sync (handoff → Notion, MCP-only auto-catch-up)

## Purpose

A handoff currently advances the local baton (`handoff.sh`) but the Notion
reflection is a separate, manual, easily-skipped step (`/handoff` Step 5, MCP).
When skipped — a bare `handoff.sh` run, a Codex session without MCP, or a
forgotten Step 5 — Notion drifts silently (the fragmap case: the home + the
fragmap row sat on 2026-06-01/02 state while the baton advanced to v32). The
home-trust `[home-stale]` warning made this VISIBLE; this contract makes it
**self-correcting**: a handoff leaves an un-missable, slice-named pending marker,
and the next MCP-capable session AUTO-APPLIES the sync as part of its start
ritual. The Notion write stays agent-mediated (MCP-only is a hard ceiling,
especially for the styled home cockpit) — but skipping it no longer causes
lasting drift.

## Current State

- `scripts/handoff.sh`: writes the per-slice baton frontmatter + a git snapshot;
  prints "next steps for the incoming agent". Zero Notion/MCP references — it
  structurally cannot and does not touch Notion.
- `scripts/notion_sync.py`: `--render-home` (prints home body, preflight),
  `--migrate slices` (prints row payloads), `--stamp-home-applied` (writes
  `.agent/handoffs/state/home-render.stamp`), `--lint-baton`. NO headless API
  writer exists — every function only PRINTS payloads for an in-session MCP
  apply (line ~1244: "NO Notion API / network call — headless token blocked").
  A latent `NOTION_TOKEN` scaffold (`.agent/.secrets/notion.env.example`) exists
  but is unused (that is the deferred B path).
- `.claude/hooks/session-start-decay-check.sh`: SessionStart hook (warns on stale
  state). `.claude/hooks/stop-handoff-check.sh`: Stop hook (non-blocking; already
  emits `[home-stale]` when a baton's mtime is newer than home-render.stamp, and
  `[baton-lint]`). Both have an `AGENT_ROOT` test seam.
- `/handoff` + `.codex/skills/handoff-writer` Step 5: 7 manual MCP sub-steps,
  "best-effort, non-blocking" — the skip surface this contract closes.

## Assumptions And Questions

- assumptions: SessionStart hook output is surfaced to the agent as context (so a
  directive injected there is acted on); a Claude session has the Notion MCP, a
  Codex/headless session may not; the pending marker lives in the untracked state
  dir (not committed), like home-render.stamp; the agent following the start
  ritual will apply a clearly-injected pending directive.
- open questions (resolve at plan time): marker as one multi-line file vs a
  per-slice dir (default: one file, handoff.sh holds the flock so appends are
  safe); whether to also add a one-line pointer to the CLAUDE.md start ritual
  (default: NO — keep the hook injection self-contained; revisit if unreliable).
- tradeoffs: the marker+hook make skipping loud and auto-recovered, but the
  literal MCP apply is still agent-mediated (cannot be removed under MCP-only);
  auto-apply at SessionStart does an agent-mediated Notion write without an
  explicit per-session user ask — accepted (user chose "surface + auto-apply";
  it is a preflight-guarded derived-view refresh).

## Constraints

- allowed change scope: `scripts/handoff.sh` (write the pending marker + print
  the recipe); `scripts/notion_sync.py` (`--handoff-emit <slice>` consolidated
  emitter; `--stamp-home-applied` also clears the marker); a marker helper if
  needed; `.claude/hooks/session-start-decay-check.sh` (inject the pending
  directive) + `.claude/hooks/stop-handoff-check.sh` (escalate `[notion-sync-
  pending]`); `tests/test_notion_migration.py` + `tests/run-stop-hook-tests.sh`
  (+ a session-start hook test harness if needed); `docs/notion-sync-runbook.md`;
  `.claude/skills/handoff/SKILL.md` + `.codex/skills/handoff-writer/SKILL.md`;
  this contract + harness baton.
- forbidden change scope: building the headless `NOTION_TOKEN` API writer (that
  is the deferred B contract); any real network/secret use; making the styled
  home cockpit headless (impossible); a BLOCKING hook (all stay exit 0); editing
  other slices' batons; trashing/moving any DB or child page; redesigning the
  tail; auto-heartbeat (#2) / git dashboard (#3).
- external constraints: Notion writes via in-session MCP only; `.agent/` is the
  source of truth; Korean-first; Notion-flavored markdown per the spec; a session
  writes only its own slice's baton (the marker names slices but the sync only
  reads their committed batons to refresh the derived Notion views).

## Non-Goals

- The headless `NOTION_TOKEN` writer / true no-agent Notion writes (deferred B).
- Headless rendering of the styled home cockpit (architecturally impossible).
- Forcing a non-MCP (Codex) session to sync — it leaves the marker for the next
  Claude session (cross-session recovery is the design, not a bug).
- #2 mechanical-liveness auto-heartbeat; #3 git fallback dashboard.
- Re-deriving the action-queue/audit logic or redesigning Projects/Docs/tail.

## Done When

- **Marker on handoff**: `./scripts/handoff.sh claude <slice>` writes/updates
  `.agent/handoffs/state/notion-sync-pending` with a `<slice> <rev> <iso>` line
  AND prints a clear "NOTION SYNC PENDING — apply: …" recipe at the end. Verified
  with an `AGENT_ROOT` fixture (marker file appears; recipe on stdout).
- **Consolidated emit**: `python scripts/notion_sync.py --handoff-emit <slice>`
  prints, in one structured block, the rendered home body (same as `--render-home`,
  preflight-guarded) AND that slice's Slices-DB row payload (same as the row in
  `--migrate slices`). Exit 0; exit 2 if the home preflight would drop a child.
  Verified by a test.
- **Auto-catch-up surfaced**: `session-start-decay-check.sh`, when the marker is
  non-empty, prints a self-contained `⚠️ NOTION SYNC PENDING: <slices>` directive
  naming the slices + the exact apply commands. Verified by a hook test
  (`AGENT_ROOT` fixture with a marker → directive present; no marker → silent).
- **Escalation + resolution**: `stop-handoff-check.sh` prints a non-blocking
  `[notion-sync-pending]` line when the marker is non-empty; `--stamp-home-applied`
  removes/empties the marker (resolution). Verified by hook + CLI tests
  (pending → Stop warns; after `--stamp-home-applied` → marker gone, Stop silent).
- **Docs**: runbook documents the marker + `--handoff-emit` + the auto-catch-up
  loop; both handoff skills' Step 5 reference `--handoff-emit` and note the
  marker is dropped automatically + cleared by `--stamp-home-applied`.
- **Loop demo (the fragmap scenario, replayed on a fixture)**: simulate a slice
  handoff (marker written) → run the SessionStart hook (directive surfaced) →
  `--handoff-emit <slice>` (both payloads) → `--stamp-home-applied` (marker
  cleared) → Stop hook silent. All non-blocking, exit 0.
- Verification: `python -m pytest tests/test_notion_migration.py
  tests/test_notion_sync_read.py`, `bash tests/run-stop-hook-tests.sh`, the
  SessionStart hook test, `--handoff-emit`/`--stamp-home-applied` exit codes,
  `./scripts/tool-audit.sh`, `./scripts/verify.sh`, `bash tests/run-skill-lint.sh`,
  scoped `git diff --check`. (No live MCP apply is REQUIRED to close this contract;
  the next real session's auto-catch-up exercises it end-to-end.)

## Implementation Steps

1. inspect handoff.sh tail, notion_sync.py main/--render-home/--stamp, both hooks,
   the home-render.stamp format; confirm the `AGENT_ROOT`/`REPO_ROOT` seams
   verify: read-only notes
2. notion_sync.py: marker helpers (write/append-dedup, read, clear) + make
   `--stamp-home-applied` clear the marker (red→green)
   verify: pytest — write marker for 2 slices, stamp clears it
3. notion_sync.py: `--handoff-emit <slice>` (home body + row payload, preflight)
   verify: pytest + CLI exit 0; emits both sections; exit 2 on preflight drop
4. handoff.sh: write/append the pending marker + print the recipe
   verify: AGENT_ROOT fixture run → marker line present + recipe on stdout
5. session-start-decay-check.sh: inject the `⚠️ NOTION SYNC PENDING` directive
   verify: hook test — marker present → directive; absent → silent
6. stop-handoff-check.sh: non-blocking `[notion-sync-pending]` escalation
   verify: extend run-stop-hook-tests.sh — pending → warns; cleared → silent
7. docs: runbook + both handoff skills (marker, --handoff-emit, auto-catch-up)
   verify: grep + skill-lint
8. loop demo on a fixture (handoff → SessionStart → emit → stamp → Stop silent)
   verify: a small scripted walk-through, all exit 0
9. verification + contract close + handoff
   verify: full suite green; baton bumped; CURRENT.md regen

## Change Discipline

- simplest adequate approach: reuse `--render-home` + `slice_to_db_row` +
  `home-render.stamp` + the existing hooks + the state dir; the only new artifacts
  are one marker file, `--handoff-emit`, a marker-clear on `--stamp-home-applied`,
  and two hook blocks. No headless writer, no secret, no network, no daemon.
- new abstractions introduced: a `notion-sync-pending` marker + its read/write/
  clear helpers; `--handoff-emit`; two hook sections. Nothing else.
- unrelated code touched: none (no logic change to queues/audit/render output).
- request-to-diff trace: user "최대한 자동화하면 좋을 것 같아" + chosen "C (A 먼저)"
  + "서명 후 자동 적용" → A = handoff drops a pending marker; the next MCP session
  auto-applies the sync; resolution clears the marker. B deferred.

## Verification

- `./scripts/verify.sh`
- task-specific: `python -m pytest tests/test_notion_migration.py
  tests/test_notion_sync_read.py`; `bash tests/run-stop-hook-tests.sh`; the
  SessionStart hook test; `python scripts/notion_sync.py --handoff-emit <slice>`;
  `./scripts/tool-audit.sh`; `bash tests/run-skill-lint.sh`
- manual check: the loop demo on an `AGENT_ROOT` fixture (handoff → SessionStart
  directive → emit → stamp → Stop silent), all exit 0.

## Risks

- regression risk: handoff.sh is core — a bug could break every handoff.
  Mitigated by: the marker write + recipe print are append-only at the END of
  handoff.sh (after the baton write/snapshot), guarded so a failure cannot fail
  the handoff; covered by an AGENT_ROOT fixture test.
- false-signal risk: the pending marker or SessionStart directive fires when
  nothing is actually stale. Mitigated by clearing on `--stamp-home-applied` +
  hook tests asserting silence when cleared; all hooks stay exit 0.
- over-eager auto-apply risk: a SessionStart auto-apply writes Notion without a
  per-session ask. Mitigated: it is a preflight-guarded derived-view refresh, the
  user chose this aggressiveness, and it only fires when a marker is genuinely
  pending; the agent reports the one-line result.

## Rollback

- revert strategy: `git revert` the handoff.sh / notion_sync.py / hook / doc /
  skill changes; `rm .agent/handoffs/state/notion-sync-pending`. The marker + the
  hook lines are advisory and non-blocking, so even a buggy build cannot break a
  session or a handoff.
- containment strategy: zero compute / no SLURM / no /mnt/data / no secret / no
  network; no live Notion write is required to close the contract; all hooks stay
  exit 0.

## Progress Log

- 2026-06-04: drafted via /brainstorm. Q-architecture = C (build A now, defer B
  to a separate contract). Q-aggressiveness = "surface + auto-apply" (SessionStart
  injects a self-contained directive; the next MCP session auto-applies + reports
  one line). Hard ceiling acknowledged: MCP-only writes; the styled home cockpit
  cannot go headless. Approval: pending.
- 2026-06-04 (DONE — /write-plan → /execute-plan, 9 tasks, user approved plan):
  **Status → done.** Commits `0767077`(T1 RED) `3187344`(T2 NOTION_SYNC_REPO_ROOT
  override + clear-marker-on-stamp) `1b3f26d`(T3 --handoff-emit) `cebc0b5`(T4
  handoff.sh drops notion-sync-pending marker + recipe, fully `|| true`-guarded)
  `1960f50`(T5 SessionStart injects ⚠️ NOTION SYNC PENDING) `fd429a1`(T6 Stop
  [notion-sync-pending]) `d7c91ed`(T7 docs) `7f61fff`(T8 E2E loop test). The loop:
  handoff.sh drops `.agent/handoffs/state/notion-sync-pending` → the next
  MCP-capable session sees the SessionStart directive + auto-applies via
  `--handoff-emit <slice>` (home body + row payload, one MCP replace_content +
  update_properties) → `--stamp-home-applied` clears the marker; the Stop hook
  escalates `[notion-sync-pending]` while unresolved. A non-MCP (Codex) session
  leaves the marker for the next Claude session (cross-session catch-up). Verified
  pytest 30 / run-notion-autosync-tests.sh + run-session-start-tests.sh +
  run-stop-hook-tests.sh PASS / --handoff-emit exit 0 / tool-audit / verify.sh /
  skill-lint 14 / scoped diff-check CLEAN. NOTE: closing this contract's own
  handoff (T9) dropped a REAL harness marker (`notion-sync-pending: harness`) —
  the mechanism working live. The T9 live Notion apply was DEFERRED (not required
  to close, per Done When): a CONCURRENT session was actively committing on the
  harness slice (contract harness-experiment-autopilot-20260604, commits
  96aec40/7d44bb0/bb2112e at 15:59–16:01, touching only scripts/fea/* — no
  overlap with this contract's files, no baton clobber). Applying Notion mid-race
  would conflict with that session's view; the marker is left for the auto-catch-up
  (the next clean MCP session resolves it — the exact dogfood this contract built).
  **B (headless NOTION_TOKEN DB-row writer) remains the available next follow-up.**
