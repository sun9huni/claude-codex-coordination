---
status: done
slice: harness
topic: notion-headless-apply
date: 2026-06-09
owner: claude
approved_by: user ("무인자동화 직전 레벨까지 진행 / harness 슬라이스 인계받아 작업해") 2026-06-09 — scope = Full 무인 직전 (recommended option; HOME stays MCP)
design_spec:
implementation_plan: none — implemented directly (additive tooling; see Progress Log)
decisions:
  - "AUTH BOUNDARY is the hard line. Build everything up to — but NOT including — the unattended network write. The headless NOTION_TOKEN is blocked by workspace permissions; provisioning it + any cron/daemon trigger is OUT (separate ops/secrets decision). This contract delivers '무인 직전' (just-before-unattended), not unattended."
  - "SPLIT BY SURFACE. The styled HOME cockpit stays MCP-applied (honors harness-notion-home-renderer + autosync ceiling: rich markdown->blocks is MCP-only) but becomes ZERO-DISCOVERY — ids resolved from the map, body+row+preflight emitted as one bundle. The Slices DB ROW becomes truly headless-READY via a gated REST writer (the baton's pre-scoped 'B = headless NOTION_TOKEN DB-row writer')."
  - "ADDITIVE + OFFLINE-TESTABLE only. New flags / new script / new config keys; everything dry-run validated with NO network. The live REST path is unverifiable until a token exists and is labeled UNVERIFIED — it reuses the proven slice_to_db_row payload so the field set is not re-derived."
---

# Harness — Notion apply automation up to the auth boundary ("무인 직전")

## Purpose

The Navigator HOME keeps going stale a session behind because the last mile —
the MCP `replace_content` / `update_properties` write — is manual by necessity
(the Notion MCP needs interactive auth; the headless token is blocked) AND
under-tooled: the HOME page-id is not recorded anywhere, so an applying session
must MCP-search for it and hand-assemble two calls. On 2026-06-09 a `/handoff`
deferred the apply for exactly this reason and the HOME froze at 2026-06-08 /
`ffe4bbb` until the next session re-applied by hand.

This closes the friction so the ONLY remaining manual act is the auth-gated write
itself: HOME becomes a single fully-resolved, preflighted bundle (one paste, no
search); the ROW gets a real headless REST writer that runs unattended the moment
a token is provisioned. It does NOT make the styled HOME headless (deliberately
deferred — see Non-Goals) and does NOT change what the cockpit says.

## Current State

- `scripts/notion_sync.py --handoff-emit <slice>` prints the HOME body + the ROW
  payload, but the agent must (a) MCP-search the HOME page-id — it is NOT in
  `.agent/notion_map.yaml` (the home-renderer contract listed `v0_5:home_page_id`
  as optional scope and never added it), and (b) hand-fire two MCP calls.
  `v0_5:slice_row_ids` is missing `m-relativity` entirely and `fea` is `""`.
- HOME page-id (confirmed this session by fetch): `28d1e76c-3b60-8069-a83b-eab69a131a99`.
  m-relativity row-id: `37a1e76c-3b60-8127-aeee-d1bb8acfd30d`.
- Writes are MCP-only (interactive auth). `handoff.sh` drops
  `.agent/handoffs/state/notion-sync-pending`; the next MCP session auto-applies;
  `--stamp-home-applied` clears it + records `home-render.stamp`. Self-healing,
  but with a one-session lag if the applying session defers.
- The footer interpolates `n_findings` after the literal word "stale"
  (`notion_sync.py:1236` → `stale {n_findings}`) so "stale 4" misreads as a
  stale-SLICE count; the real unclaimed count is the separate "🟡 3". The 4 are
  audit findings (arl/fea/vav1 no-heartbeat + fragmap regex-fallback).
- There is NO headless write path of any kind. `assert_home_preserves` +
  `HOME_RENDER_UNSAFE` already guard the HOME body against dropping a child page/DB.

## Assumptions And Questions

- assumptions: the Slices DB row property schema is stable (the 8 cockpit fields +
  Status/Owner/heartbeat already pushed by `slice_to_db_row`); the Notion REST
  "update page properties" endpoint accepts the same logical field set the MCP
  `update_properties` uses; map ids are stable unless a page is recreated.
- open questions (for approval, not blockers): (Q-A) include the gated REST ROW
  writer now [recommended — it IS "직전"], or stop at emit-apply-plan + ids + label
  and leave the writer for a later contract? (Q-B) leave the styled HOME headless
  path deferred [recommended] or also scope a REST md->blocks HOME writer (large,
  reverses a prior decision)?
- tradeoffs: the REST writer cannot be live-tested until a token exists, so it
  ships dry-run-validated only (offline payload build + schema-name check). Reusing
  `slice_to_db_row` keeps the field set proven; only the transport is new+unverified.

## Constraints

- allowed change scope: `scripts/notion_sync.py` (resolve HOME+ROW page-ids from the
  map; `--emit-apply-plan <slice>`; footer label fix); a new `scripts/notion_apply.py`
  (NOTION_TOKEN-gated REST ROW writer + `--dry-run`); `.agent/notion_map.yaml`
  (`v0_5:home_page_id` + backfill `slice_row_ids` incl m-relativity, fea where a row
  exists); `tests/test_notion_migration.py` / `tests/test_notion_sync_read.py`;
  `docs/notion-sync-runbook.md`; `.claude/skills/handoff/SKILL.md` +
  `.codex/skills/handoff-writer/SKILL.md` (Step 5 one-shot reference); this contract
  + `.agent/status/harness.md`.
- forbidden change scope: provisioning/unblocking the headless `NOTION_TOKEN`;
  any cron/daemon/scheduled trigger; LIVE REST writes (until a token is provisioned
  — dry-run only in this contract); making the styled HOME cockpit headless (stays
  MCP per harness-notion-home-renderer + autosync); changing `render_home` / audit /
  action-queue LOGIC (format + label only); editing any other slice's baton or
  Notion content; re-freezing any data; secrets anywhere but `.agent/.secrets/`.
- external constraints: `.agent/` is the source of truth; Notion writes via
  in-session MCP only until a token exists; Korean-first labels; Notion-flavored
  markdown per the enhanced-markdown spec.

## Non-Goals

- Full unattended automation — that needs the blocked token + a trigger (OUT).
- A headless styled-HOME (REST md->blocks) writer — deliberately deferred; the
  cockpit stays MCP. (Revisit as its own contract only if the user wants it.)
- Changing what the cockpit / queues / health say, or the render layout.
- The actual live REST row PATCH (only the gated, dry-run-validated writer ships).

## Done When

- `.agent/notion_map.yaml` carries `v0_5:home_page_id: 28d1e76c-3b60-8069-a83b-eab69a131a99`
  and `slice_row_ids` for every ACTIVE slice incl `m-relativity`
  (`37a1e76c-3b60-8127-aeee-d1bb8acfd30d`); a test asserts every active slice in
  `status.sh` `SLICES` has a non-empty row-id (or is explicitly waived).
- `python scripts/notion_sync.py --emit-apply-plan <slice>` prints ONE
  fully-resolved bundle with NO MCP search needed: (a) HOME target `page_id` +
  rendered body + preflight verdict (PASS, or `HOME_RENDER_UNSAFE` + exit ≠0),
  (b) ROW target `page_id` + `slice_to_db_row` properties JSON, (c) the exact two
  MCP calls to fire. Exits non-zero if any id is unresolved or preflight fails.
- `python scripts/notion_apply.py --dry-run --slice <slice>` builds the REST
  property-update payload for that slice's ROW OFFLINE (token NOT required for
  dry-run), validates property names against the Slices schema, prints the payload,
  exits 0, and makes NO network call. With `NOTION_TOKEN` + `--apply` it would PATCH
  the row via REST (path documented + gated; NOT exercised in CI / NOT a Done gate).
- The footer reads `findings N` (or `issues N`), not `stale N`; the metrics line is
  unchanged; a test pins the wording.
- Offline tests (no network): emit-apply-plan resolves ids + embeds the preflight;
  notion_apply `--dry-run` constructs + schema-validates the row payload and asserts
  no network use; `--render-home` / `--handoff-emit` / `--audit` still green.
- Verification: `python -m pytest tests/test_notion_migration.py
  tests/test_notion_sync_read.py`; `--emit-apply-plan m-relativity` exit 0 with
  resolved ids; `notion_apply.py --dry-run --slice m-relativity` exit 0 + no
  network; `./scripts/tool-audit.sh`; `./scripts/verify.sh`;
  `bash tests/run-skill-lint.sh`; scoped `git diff --check`.

## Implementation Steps

1. inspect current `--handoff-emit` / `slice_to_db_row` / map loader; confirm the
   id set + REST property-update endpoint shape
   verify: notes only; no code yet
2. backfill `notion_map.yaml` (`home_page_id` + `slice_row_ids` incl m-relativity) +
   RED test: every active slice has a non-empty row-id
   verify: pytest RED→GREEN
3. `notion_sync.py`: id-resolution helper (HOME + ROW from map, FAIL loud on miss) +
   `--emit-apply-plan <slice>` bundling body+preflight+row-props+ids+call-snippets
   verify: `--emit-apply-plan m-relativity` exit 0, ids present, no Notion call
4. footer label fix `stale`→`findings` + test
   verify: pytest asserts footer wording, metrics line unchanged
5. `scripts/notion_apply.py`: REST ROW PATCH, NOTION_TOKEN-gated, `--dry-run`
   offline payload build + schema-name validation (reuses `slice_to_db_row`)
   verify: `--dry-run` exit 0; test asserts zero network in dry-run
6. docs: runbook §headless-apply (AUTH BOUNDARY explicit) + /handoff Step 5 one-shot
   (`--emit-apply-plan`); both handoff skills
   verify: grep + `run-skill-lint.sh`
7. verification + contract close + claim harness baton + handoff
   verify: full suite green; baton bumped; CURRENT.md regen

## Change Discipline

- simplest adequate approach: reuse `slice_to_db_row` + `render_home` +
  `assert_home_preserves` verbatim; `--emit-apply-plan` is composition + id lookup;
  `notion_apply.py` is one REST call behind a token gate. No new data sources, no
  daemon, no change to queue/audit logic.
- new abstractions introduced: an id-resolution helper, one CLI flag, one small
  script. No classes/config beyond map keys.
- unrelated code touched: none (format/label + additive paths only).
- request-to-diff trace: user "무인자동화 직전 레벨까지 진행 / harness 인계받아 작업" →
  remove every manual step except the auth-gated write; build the headless ROW
  writer to the gated+dry-run point.

## Verification

- `./scripts/verify.sh`
- task-specific: `python -m pytest tests/test_notion_migration.py tests/test_notion_sync_read.py`;
  `python scripts/notion_sync.py --emit-apply-plan m-relativity`;
  `python scripts/notion_apply.py --dry-run --slice m-relativity`;
  `./scripts/tool-audit.sh`; `bash tests/run-skill-lint.sh`
- manual check: with a (future) token, `notion_apply.py --apply --slice m-relativity`
  PATCHes the row; until then, dry-run + the emitted MCP bundle are the surface.

## Risks

- regression risk: low — additive flags/script + a one-word label change; existing
  `--render-home`/`--handoff-emit`/`--audit` untouched in logic, pinned by tests.
- integration risk: the REST writer is UNVERIFIED live until a token exists → ships
  dry-run-only, reuses the proven `slice_to_db_row` field set, live path labeled
  UNVERIFIED in docs.
- hidden dependency risk: map ids drift if a Notion page is recreated →
  `--emit-apply-plan` must FAIL loudly on an unresolved id (never silently fall back
  to search); a test pins id format/presence.

## Rollback

- revert strategy: every change is additive (new flags/script/config keys, inert
  until invoked) + one label string — `git revert` the commit(s).
- containment strategy: zero compute / no SLURM / no /mnt/data; no live Notion write
  performed by this contract's tooling (HOME stays manual-MCP; ROW writer is
  token-gated + dry-run); the existing `HOME_RENDER_UNSAFE` guard still protects the
  HOME body.

## Progress Log

- 2026-06-09: contract drafted via /brainstorm (harness slice adopted from session
  96b788a7, heartbeat stale 2026-06-08). Scope = "무인 직전" up to the auth boundary:
  (1) record `home_page_id` + `slice_row_ids[m-relativity]` in the map; (2)
  `--emit-apply-plan` zero-discovery one-shot; (3) gated REST ROW writer
  `notion_apply.py` (dry-run validated); (4) footer `stale`→`findings` fix. Honors
  the autosync ceiling (styled HOME stays MCP). Open scope calls Q-A/Q-B in
  Assumptions. Approval: pending.
- 2026-06-10 (DONE — implemented directly, additive; user go-ahead "continue" after
  the scope picker errored; Q-A = include REST writer [Full 무인 직전], Q-B = HOME
  stays MCP): **Status → done.** Shipped: (1) `notion_map.yaml` `v0_5:home_page_id`
  (28d1e76c…) + `slice_row_ids[m-relativity]` (37a1e76c…); (2) `notion_sync.py`
  `resolve_apply_ids()` + `emit_apply_plan()` + `--emit-apply-plan <slice>` (resolves
  ids from map, embeds preflight, FAIL-loud exit≠0 on unresolved id / HOME_RENDER_UNSAFE);
  (3) footer `stale {n}`→`findings {n}` ([notion_sync.py] + test line 342 updated);
  (4) new `scripts/notion_apply.py` — REST ROW PATCH, NOTION_TOKEN-gated, `--dry-run`
  builds+validates payload offline (reuses `slice_to_db_row`; `_NON_COLUMN_FIELDS`
  skips computed "Next"); (5) runbook §headless-apply rewritten (writer now EXISTS,
  was "not built") + `.claude/skills/handoff` Step 5 → `--emit-apply-plan`. Verified:
  pytest 38/38 (8 new), `--emit-apply-plan m-relativity` exit 0, `notion_apply --dry-run`
  exit 0 (network-tripwire test), tool-audit, verify.sh, skill-lint 15/0
  (also FIXED pre-existing publish-notion lint fail F3/B2/B4 from e72c998),
  scoped diff-check clean. AMENDMENTS vs draft scope: (a) Codex handoff-writer parity
  edit REVERTED — it is tangled in a PRE-EXISTING `skills/handoff-writer` source↔mirror
  drift (differ at HEAD, source was already M); dropped to keep this diff clean.
  (b) Auto-flow DIRECTIVE rewire (SessionStart hook line 239 / Stop hook 382 /
  handoff.sh 454 still emit `--handoff-emit`) left as a FOLLOW-UP (hooks were out of
  the stated scope + need run-session-start/stop-hook test updates). FOLLOW-UPS in the
  harness baton. The actual last-session blocker (unrecorded HOME page-id) is closed;
  full unattended ROW sync needs only a provisioned NOTION_TOKEN (ops, OUT).
