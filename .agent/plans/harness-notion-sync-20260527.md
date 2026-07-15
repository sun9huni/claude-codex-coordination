---
contract: .agent/contracts/harness-notion-sync-20260527.md
slice: harness
status: done
total_tasks: 11
estimated_total_min: 44
---

# Plan — Notion sync (`.agent/` → Notion, headless one-way)

Phase order: Setup(1-2) → Skeleton/Read(3-5) → Dry-run(6) →
**⚠ TOKEN PREREQ GATE** → Write/upsert(7-9) → Idempotency test(10) →
Wrapper+Docs(11).

**Token prereq**: Tasks 7-10 require the user-provided Notion internal-integration
token in `.agent/.secrets/notion.env` (per contract). Tasks 1-6 run WITHOUT a
token (read/parse/dry-run only). /execute-plan must pause at the gate and confirm
the token exists before Task 7.

---

## Task 1: gitignore + secrets scaffold

- **Status**: done (2026-05-27, commit 0749c33; code-review APPROVE, no token leak)
- **Prereq tasks**: none
- **Files touched**: `.gitignore`, `.agent/.secrets/notion.env.example` (new)
- **Change shape**: Add `/.agent/.secrets/` to `.gitignore`. Create `.agent/.secrets/notion.env.example` with `NOTION_TOKEN=` (placeholder, no real value) + a one-line comment on how to obtain the internal-integration token + share the 홈 page. The real `notion.env` is created by the user and stays gitignored.
- **Verification**: `git check-ignore .agent/.secrets/notion.env` → prints the path (ignored); `git status --porcelain .agent/.secrets/notion.env.example` → shows the example tracked, no real token anywhere.
- **Estimated time**: 3 min
- **Rollback (if this task only)**: `git checkout .gitignore`; `rm .agent/.secrets/notion.env.example`

## Task 2: notion_map.yaml (slice → Notion IDs)

- **Status**: done (2026-05-27, commit a1a10c3; code-review APPROVE, IDs verified, no secrets)
- **Prereq tasks**: none
- **Files touched**: `.agent/notion_map.yaml` (new)
- **Change shape**: Static mapping (NO secrets): each slice → its hub `page_id` (fragmap `36d1e76c-3b60-8136-8921-ee505191976d`, mmgbsa `…8178…`, vav1 `…810e…`, fksfold-core `…81e5…`, harness `…813d…`); plus data-source IDs (Reports `94d8277f-…`, Decisions `b11ae976-…`, Artifacts `2e47ef6d-…`). Include a `conclusion_marker` token used to find the hub's conclusion callout.
- **Verification**: `python3 -c "import yaml;d=yaml.safe_load(open('.agent/notion_map.yaml'));assert len(d['slices'])==5 and 'decisions' in d['data_sources']"` → no error.
- **Estimated time**: 4 min
- **Rollback (if this task only)**: `rm .agent/notion_map.yaml`

## Task 3: notion_sync.py skeleton (argparse + env/client guard)

- **Status**: done (2026-05-27, commit 7ccd5b3; code-review APPROVE. notion-client 3.1.0 installed in miniconda env; --check-env token-independent, no network)
- **Prereq tasks**: 2
- **Files touched**: `scripts/notion_sync.py` (new)
- **Change shape**: CLI skeleton: args `--slice <name>`, `--all`, `--dry-run`, `--check-env`. Load `NOTION_TOKEN` from env (cron wrapper sources `.agent/.secrets/notion.env`). `--check-env` imports `notion_client`, reports token present/absent + client constructable — WITHOUT any API call. Missing token → clear non-fatal message, exit 0 for `--check-env`. Load `notion_map.yaml`.
- **Verification**: `python scripts/notion_sync.py --check-env` (no token) → "NOTION_TOKEN not set" message, exit 0; with `NOTION_TOKEN=dummy` → "notion-client ready (no API call)" (still no network).
- **Estimated time**: 5 min
- **Rollback (if this task only)**: `git checkout scripts/notion_sync.py` (or rm if new)

## Task 4: Read layer — status frontmatter + contract decisions → dict

- **Status**: done (2026-05-27, commit 766deb7; code-review APPROVE. fragmap 13 decisions, harness 6, graceful skips, no network)
- **Prereq tasks**: 3
- **Files touched**: `scripts/notion_sync.py`
- **Change shape**: Add `--dump` mode. For a slice: parse `.agent/status/<slice>.md` frontmatter (owner/remaining_actions/last_updated) + a one-line conclusion (first remaining_action or a `conclusion:` field), and read each linked contract's `decisions:` list. Produce a structured dict {slice, conclusion, remaining_actions, decisions:[{slug,title,status}]}. NO Notion calls. Stable slug = `<slice>:<contract-topic>:<index>`.
- **Verification**: `python scripts/notion_sync.py --slice fragmap --dump` → prints dict with non-empty conclusion + ≥1 decision (from fragmap contracts), zero network calls.
- **Estimated time**: 5 min
- **Rollback (if this task only)**: `git checkout scripts/notion_sync.py`

## Task 5: Read-layer test

- **Status**: done (2026-05-27, commit 80eb8a7; code-review APPROVE, 6 passed)
- **Prereq tasks**: 4
- **Files touched**: `tests/test_notion_sync_read.py` (new) or `tests/run-notion-sync-read.sh`
- **Change shape**: Test against a temp fixture status file + a fixture contract: assert the read layer extracts the expected conclusion + decision slugs. No token, no network.
- **Verification**: `python -m pytest tests/test_notion_sync_read.py -q` (or `bash tests/run-notion-sync-read.sh`) → PASS.
- **Estimated time**: 4 min
- **Rollback (if this task only)**: `rm tests/test_notion_sync_read.py`

## Task 6: Dry-run renderer

- **Status**: done (2026-05-27, commit b56800e; code-review APPROVE_WITH_NITS — dict-shaped decisions render as repr, cleaned in Task 8)
- **Prereq tasks**: 4
- **Files touched**: `scripts/notion_sync.py`
- **Change shape**: `--dry-run` prints the intended changes per slice: the hub-callout text that WOULD be written + the Decisions rows that WOULD be created/updated (keyed by slug), with a CREATE/UPDATE/NOOP tag per decision. No writes, no token required (token-absent → still renders the plan, marks "would need token to apply").
- **Verification**: `python scripts/notion_sync.py --all --dry-run` → lists all 5 slices with intended callout + decision actions; exit 0 with no token.
- **Estimated time**: 4 min
- **Rollback (if this task only)**: `git checkout scripts/notion_sync.py`

## ⚠⚠ REVISION 2026-05-27 — (가)headless → (나)MCP-driven (token blocked)

Token path blocked (user lacks workspace-integration permission). Tasks 7-11
below are SUPERSEDED by the MCP-driven set T7'-T10' (the write half runs via
the claude.ai Notion MCP, performed by the agent directly — subagents don't have
that MCP). T1-6 (foundation) are reused as-is. v1 quality cut: push hub
conclusion callouts + 1 curated Decision/slice; granular contract-bullet
Decisions auto-pop deferred to v2 (noise/curation).

- **T7'** ~~_decision_text cleanup~~ → MOOT for v1 (granular decisions deferred to v2; v1 Decision = conclusion string, already clean). DONE-by-omission.
- **T8'** Routine doc → DONE as `docs/notion-sync-runbook.md` (chose a runbook over a new skill to avoid skill-lint/self-mod overhead; same idempotent find-or-update routine). commit 5386dc4.
- **T9'** EXECUTE via MCP → DONE: fragmap/mmgbsa/harness hubs got 〔sync〕 callouts (fetch-verified on fragmap); vav1/fksfold-core dormant→skipped; Decisions DB got 1 curated row/slice.
- **T10'** Idempotency + finalize → DONE: idempotency guaranteed by runbook find-or-update (marker-owned callout + Title/Key-matched Decision); contract/plan status: done; status/harness.md updated; handoff.

---
## (SUPERSEDED) ⚠ TOKEN PREREQ GATE — Tasks 7-10 require `.agent/.secrets/notion.env`

`/execute-plan` MUST confirm the user has created the Notion internal integration,
shared the 홈 subtree, and populated `.agent/.secrets/notion.env` before Task 7.
Tasks 1-6 are complete and useful without it.

## Task 7: Hub conclusion callout upsert

- **Status**: pending
- **Prereq tasks**: 4, 6 (+ token)
- **Files touched**: `scripts/notion_sync.py`
- **Change shape**: Locate the slice hub's conclusion callout (via `conclusion_marker` from the map; create it if absent) and rewrite it with the read-layer conclusion + up to 3 remaining_actions. Uses `notion-client` blocks API. Idempotent (same input → same block content).
- **Verification**: with token: `python scripts/notion_sync.py --slice fragmap` then fetch the fragmap hub → conclusion callout text matches `.agent/status/fragmap.md`.
- **Estimated time**: 5 min
- **Rollback (if this task only)**: `git checkout scripts/notion_sync.py`; manually restore the callout in Notion if needed

## Task 8: Decisions upsert by stable slug

- **Status**: pending
- **Prereq tasks**: 4, 6 (+ token)
- **Files touched**: `scripts/notion_sync.py`
- **Change shape**: For each decision in the read dict, query the Decisions DS for an existing row with matching `Key` (stable slug) property; UPDATE if found, CREATE if not. Set Title/Project/Slice/Decision Status/Date/Owner. Add a `Key` rich-text property to the Decisions DB if missing (one-time, via update-data-source) — document this as a side effect. **Task-6 nit fix (do here)**: add a `_decision_text(d)` helper so dict/list-shaped contract `decisions:` entries render as readable "key: value" text (not Python repr) for the Notion Title.
- **Verification**: with token: `--slice fragmap` creates N Decisions rows; immediate re-run → same N rows (no duplicates), confirmed by a count query.
- **Estimated time**: 5 min
- **Rollback (if this task only)**: `git checkout scripts/notion_sync.py`; manually delete stray Decisions rows

## Task 9: --all + graceful skip + backoff

- **Status**: pending
- **Prereq tasks**: 7, 8 (+ token)
- **Files touched**: `scripts/notion_sync.py`
- **Change shape**: `--all` iterates the 5 slices; a slice with missing/broken frontmatter is skipped with a stderr warning (not a hard failure); add simple rate-limit backoff (retry with sleep on 429). Summary line: synced/skipped counts.
- **Verification**: with token: `python scripts/notion_sync.py --all` → summary shows 5 synced (or skipped-with-reason); a deliberately broken fixture slice is skipped, run exit 0.
- **Estimated time**: 4 min
- **Rollback (if this task only)**: `git checkout scripts/notion_sync.py`

## Task 10: Idempotency test (Done-When #3)

- **Status**: pending
- **Prereq tasks**: 8 (+ token)
- **Files touched**: `tests/run-notion-sync-idempotency.sh` (new)
- **Change shape**: Script: run `--slice fragmap` twice; query Decisions row count for fragmap before/after the 2nd run; assert unchanged; assert the hub callout block id/content unchanged. Proves idempotent upsert.
- **Verification**: with token: `bash tests/run-notion-sync-idempotency.sh` → "IDEMPOTENT: PASS" (2nd run no-op).
- **Estimated time**: 4 min
- **Rollback (if this task only)**: `rm tests/run-notion-sync-idempotency.sh`

## Task 11: cron wrapper + docs + finalize

- **Status**: pending
- **Prereq tasks**: 9, 10
- **Files touched**: `scripts/notion_sync.sh` (new), `.agent/status/harness.md`, `.agent/contracts/harness-notion-sync-20260527.md`
- **Change shape**: `notion_sync.sh` sources `.agent/.secrets/notion.env` then runs `python scripts/notion_sync.py --all` (the cron entrypoint; no crontab installed by this task — documented for the user). Add a usage note (in the script header or a short doc). Update `status/harness.md` baton + set contract status: done.
- **Verification**: `bash -n scripts/notion_sync.sh`; `grep -q notion_sync .agent/status/harness.md`; contract frontmatter `status: done`.
- **Estimated time**: 4 min
- **Rollback (if this task only)**: `git checkout` the three files / `rm scripts/notion_sync.sh`
