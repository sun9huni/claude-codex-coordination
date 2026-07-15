---
name: handoff
description: Update the active slice's .agent/status/<slice>.md frontmatter and run scripts/handoff.sh <agent> <slice> to snapshot session state. Use at end of session, near context limit (< 20%), before switching agents (Claude → Codex/Cursor), before a long-running job that must outlive the chat, or before any approval gate.
argument-hint: "[optional one-line note to include in session-note.md]"
allowed-tools: Read Edit Write Bash(./scripts/handoff.sh:*) Bash(./scripts/status.sh:*) Bash(cat:*) Bash(stat:*)
---

# /handoff — Session handoff

The next agent (Codex / Cursor / next-Claude-session) cannot see this
chat. State must live in files. This skill produces the durable record.

Handoff is **per-slice**: a session owns one slice and writes only that
slice's `.agent/status/<slice>.md`. `CURRENT.md` is no longer
hand-edited — it is a DERIVED lab-wide index regenerated from the slice
files (see Step 4).

## Step 1 — Identify the active slice and read its state

Determine the slice this session worked on (`fragmap`, `mmgbsa`,
`vav1`, `aigen-fold-core`, `arl`, `harness` — the one named in
`CURRENT.md` or routed to this session). Read its `.agent/status/<slice>.md` to see what is
already filled in. Read `.agent/status/README.md` for the canonical
frontmatter schema.

## Step 2 — Update that slice's `.agent/status/<slice>.md` frontmatter

Edit the slice file's YAML frontmatter so every field is present and
concrete (no `<placeholder>`). `handoff.sh` (Step 3) sets
`owner_session`, `version`, and `heartbeat` for you — but fill the rest:

- **owner_agent** — set to `claude`.
- **owner_label** — optional human label (e.g. `claude-A`), or leave empty.
- **last_updated** — today's ISO date (resolve any relative date).
- **remaining_actions** — exactly 1–3 ordered next steps, concrete
  enough that the next agent can act without asking. These live here
  now, not in `CURRENT.md`.
- **contract_pointers** — list the relevant contract paths under
  `.agent/contracts/`, or leave empty if none.

Keep the file body (status prose) current and under ~25 lines: what is
done, what is mid-flight, the live-truth artifact to verify against, and
any pending approval gate (SLURM, DB, MGD2) — or note "none".

If the user supplied `$ARGUMENTS`, append it to
`.agent/handoffs/state/session-note.md` (create the file if missing).

## Step 3 — Run handoff.sh in per-slice mode

```bash
./scripts/handoff.sh claude <slice>
```

Per-slice mode claims/refreshes ONLY `.agent/status/<slice>.md` —
bumps its `version`, stamps `heartbeat` + `owner_session`, and writes a
git snapshot under `.agent/handoffs/state/`. It preserves the
`remaining_actions` / `contract_pointers` / `state` / body you wrote in
Step 2 and leaves `CURRENT.md` untouched.

After the frontmatter write, `handoff.sh` will **auto-commit** any
untracked slice contracts/plans (paths matching
`.agent/{contracts,plans}/<slice>-*.md`) — but only when the working
tree is otherwise clean (no tracked modifications, no other untracked
files). Pass `--no-auto-commit` to opt out. If the tree is dirty, the
auto-commit is skipped with a one-line stderr notice; commit deliberately
yourself.

For terminal slice closure (work is finished and the slice should be
parked), use the release verb instead:

```bash
./scripts/handoff.sh --release <slice>
```

This clears `owner_session` / `owner_label` / `heartbeat`, sets
`state: released`, and bumps `version`. It is idempotent on an
already-released slice. Do NOT use `--release` mid-session — only when
the slice is genuinely done.

## Step 4 — Regenerate the index and verify

`CURRENT.md` is the DERIVED lab-wide index — never hand-edit it.
Regenerate it from the slice files:

```bash
./scripts/status.sh index
```

Then confirm:
- `head -8 .agent/status/<slice>.md` shows today's `last_updated`, a
  bumped `version`, and `owner_agent: claude`.
- `cat .agent/handoffs/state/meta.txt` shows `next_agent: claude`.
- No stderr warnings from `handoff.sh` or `status.sh index`.

Report a one-line summary to the user: `handoff written for <slice>,
next: <first remaining action>`.

## Step 5 — Notion sync (best-effort, non-blocking, v0.5)

If the Notion MCP is available this session (Claude only — Codex parity
lives in `.codex/skills/handoff-writer/SKILL.md`), reflect the active
slice into Notion's three-DB IA per `docs/notion-sync-runbook.md`.
**Writes are MCP-only** (the headless token is blocked by workspace
permissions): `notion_sync.py` only *computes/PRINTS* upsert-keyed
payloads — you APPLY them with the in-session Notion MCP
(`notion-update-page` / `notion-create-pages`). Never imply an automatic
network write. The seven sub-steps below wrap the preserved v0.4.2
lab-log (points 5–6) with the v0.5 DB updates (points 2–4):

1. **Get the payloads** (no Notion calls):
   ```bash
   ./scripts/notion_sync.py --handoff-log --slice <slice>   # v0.4.2 lab-log payload
   ./scripts/notion_sync.py --migrate slices                # Slices DB rows
   ```
   `--handoff-log` yields `{date, iso_week, conclusion, change_digest,
   evidence, event_type, event_emoji, event_color}` (last 3 from
   `classify_event`). For the v0.5 DB updates use `slice_to_db_row(<slice>)`
   (via `--migrate slices`), and — only on the transitions in point 3 —
   `contract_to_adr_rows(<contract_path>)` (via `--migrate contracts`).
   `home_navigator_payload()` (Task 17) supplies the home/Navigator fields.
   **Refresh the rendered home page (Task 18, SHIPPED):** run
   `./scripts/notion_sync.py --render-home` and apply the printed body via one MCP
   `notion-update-page replace_content` on the home page (it self-aborts with
   `HOME_RENDER_UNSAFE` if any child page/DB would drop). Then run
   `./scripts/notion_sync.py --stamp-home-applied` to record the apply — the Stop
   hook uses the stamp to warn `[home-stale]` if a baton later changes, and it lints
   the active baton as `[baton-lint]` (both non-blocking). Do this whenever a slice's
   state changed materially this session so the home stays accurate.
   `handoff.sh` automatically drops a `.agent/handoffs/state/notion-sync-pending`
   marker. `./scripts/notion_sync.py --emit-apply-plan <slice>` is the preferred
   one-shot — it RESOLVES the HOME + ROW page_ids from `notion_map.yaml` `v0_5`
   (no MCP search), embeds the preflight verdict, and exits ≠0 if an id is
   unresolved or `HOME_RENDER_UNSAFE`; `--handoff-emit <slice>` is the older
   id-less emitter. The next MCP session auto-applies a pending sync (the
   `⚠️ NOTION SYNC PENDING` SessionStart directive); `--stamp-home-applied`
   clears the marker. (Headless ROW-only sync: `scripts/notion_apply.py`,
   token-gated + `--dry-run`; HOME stays MCP.)

2. **Slices DB row** — find the active slice's row by
   `notion_map.yaml` `v0_5:slice_row_ids[<slice>]` and `notion-update-page`
   it with `slice_to_db_row(<slice>)`. This maps `state:` → Status
   (활성 / 완료 / 릴리즈 / 휴면) and refreshes Owner / Last Heartbeat /
   Last Updated / Next Action — **and you MUST also push the 8 cockpit
   fields the payload carries: Headline / Now / Decision Needed / Agent Next /
   Blocker / Health / Sync Status / Last Sync Source. These drive the
   Navigator action queues; if you push only the core liveness fields,
   Health/Decision/Agent re-blank on the next handoff.** (upsert key =
   `Name`). Uses `v0_5:slices_db_id` / `v0_5:slices_db_data_source_id` from
   the map — reference by these keys, never paste raw UUIDs.

3. **ADR rows (conditional)** — ONLY if this `/handoff` was triggered by a
   contract `status:` transition (`pending→approved` or `approved→done`),
   run `contract_to_adr_rows(<contract_path>)` and create/update the ADR
   rows in the Decisions data source (`v0_5:decisions_data_source_id`), one
   row per `decisions:` item (upsert key = `adr_id`). Status maps Proposed /
   Accepted / Implemented. If no such transition occurred, SKIP this step.

4. **Experiments scan (optional)** — if new mmgbsa SLURM jobs completed
   since the last handoff, run `--migrate slurm` and upsert the affected
   Experiments DB rows (`v0_5:experiments_db_id`, upsert key = `Run ID`).
   Skip if nothing new completed. No daemon / no live monitor.

5. **Slice hub `〔sync〕` block** (preserved v0.4.2) — on the slice's hub
   child page, replace the `<details>` TOGGLE colored to match the slice.
   Summary: `🔄 **동기화** · <date> · 자동 생성 ...`; body = 4-row table
   (상태 / 진행 중 / 다음 / 갱신). Find-or-update by matching `🔄 **동기화**`.

6. **Weekly Digest row** (preserved v0.4.2) — find/create `<slice>
   <iso_week> Weekly Digest` (Reports DB, Report Type=Weekly Digest,
   Slice=<slice>, Date=Monday of ISO-week). **Change-gated**: only insert
   a new EVENT-TYPED CALLOUT when `change_digest` is NOT a substring of the
   most-recent callout body (the chg-digest gate); else idempotently
   `update_content` today's callout. Insert most-recent first, using
   `event_emoji` as icon and `event_color` as color:
   ```
   <callout icon="<event_emoji>" color="<event_color>">
   **<event_type> · <MM-DD>** — <one-line title>
   <identifier line>
   <body line(s)>
   **다음**: <next action>
   <span color="gray">chg:<change_digest></span>
   </callout>
   ```

7. **NON-BLOCKING** (preserved) — best-effort, Claude-only. If the Notion
   MCP is unavailable or ANY sub-step errors, emit a one-line stderr
   warning and STOP the sync. Do NOT raise — `/handoff` MUST complete
   regardless. The durable record is the slice file + `handoff.sh` snapshot
   from Steps 1-4; Notion is the derived human view.

**한글 우선 정책 / Korean-first**: narrative + labels in 한글 (출시 / 작업 /
설계 / 결정 / 차단 / 수정, 상태 / 다음 / 진행 중 / 갱신, 추가 / 부가 / 변경;
Status 활성 / 완료 / 릴리즈 / 휴면). English identifiers preserved verbatim
(file paths like `status/<slice>.md`, CLI flags like `--release`, ADR /
Run IDs, commit SHAs, version identifiers `v0.5`, test names like
`skill-lint`, etc.).

## Red Flags

| Rationalization | Reality |
|---|---|
| "See chat above for context." | Chat is not durable. Inline the facts the next agent needs into the slice file. |
| "I'll fill in placeholders later." | Now. Leave no `<...>` in the slice frontmatter or body. |
| "owner_agent: claude is the default — skip it." | Explicit owner prevents claim-check / takeover-prompt.md ambiguity. Always set. |
| "version stays the same, I didn't really change anything." | `handoff.sh <slice>` bumps `version` for you; if you ran any tool calls this session, state changed. The Stop hook compares version vs last snapshot — a stale version is its own warning. |
| "I'll just update `CURRENT.md` by hand like before." | `CURRENT.md` is a DERIVED index now. Write the slice file; regenerate with `./scripts/status.sh index`. |
| "remaining_actions: I'll update if needed." | These live in the slice frontmatter now (1–3, ordered). The next agent acts on this list — fill it. |
| "Approval gate: n/a for now." | If a gate is pending (SLURM, DB, MGD2), name it in the slice body now. |

## Forbidden

- Do NOT hand-edit `.agent/handoffs/CURRENT.md` — it is the derived
  index, regenerated by `./scripts/status.sh index`.
- Do NOT write "see chat above" — inline the relevant facts into the
  slice file.
- Do NOT leave `<...>` placeholders in `.agent/status/<slice>.md`.
- Do NOT write a slice file other than the one this session owns.
- Do NOT commit handoff state files to project repos — they belong in
  the workspace coordination layer only.
