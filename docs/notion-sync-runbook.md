# Notion sync runbook (`.agent/` → Notion, MCP-driven) — v0.5

**Contract**: `.agent/contracts/harness-notion-redesign-20260529.md` ·
**Plan**: `.agent/plans/harness-notion-redesign-20260529.md` ·
**Read engine**: `scripts/notion_sync.py` · **Map**: `.agent/notion_map.yaml`

> **Scope**: This is a **workspace-only** redesign (`/home/ubuntu`). There is no
> upstream port — the template repo `sun9huni/claude-codex-coordination` does
> not carry `notion_sync.py`, `notion_map.yaml`, or this runbook. v0.5 lands as
> workspace commits only; no upstream PR.

> **Status honesty (read this first)**: At the time of writing, Phase A
> (Foundation: DBs created/restructured) and Phase B (Backfill: rows seeded)
> are **shipped**. Phase C is **partial** — the migration engine and `--migrate`
> CLI (Task 23) and `home_navigator_payload()` (Task 17) ARE shipped, but the
> **rendered Navigator home page (Task 18)** and the **`/handoff` Step 5 v0.5
> auto-update (Task 19)** are **NOT yet shipped**. Wherever this runbook
> describes "automatic on `/handoff`" or "the home page shows…", it is
> describing the **intended v0.5 flow**; the live wiring lands in Tasks 18/19.
> Such spots are flagged inline with **(pending Task 18)** / **(pending Task 19)**.

---

## Why MCP-driven (not headless) — load-bearing constraint

The headless-token path is **blocked**: creating a Notion internal integration
requires workspace-owner/admin permission this account lacks. The **claude.ai
Notion MCP** already has write access to the workspace, so every *write* (DB
creation, row upsert, page rewrite, migration) runs as an **in-session MCP call
performed by Claude/Codex**. `scripts/notion_sync.py` is the deterministic
*read/compute* half: it parses `.agent/` state and **PRINTS** upsert-keyed JSON
payloads — it never opens a network connection to Notion. A human or agent then
applies that JSON via the in-session Notion MCP. **This constraint is permanent
until an owner provides a token** (the `--check-env` + `.agent/.secrets/`
scaffold remains as a future bonus path only).

---

## Section 1 — IA overview: three proven patterns + a Navigator home

v0.4.0–v0.4.2 spread state across **five** disconnected surfaces (per-hub
`〔sync〕` callouts + Weekly Digest rows + Reports DB + Decisions DB + Artifacts
DB). The user's diagnosis (2026-05-29): *"어디 볼지 감 안 온다"* — no single
entry point. v0.5 consolidates into **three databases modeled on industry
patterns**, fronted by a **Navigator home page**:

| Pattern (industry source) | v0.5 database | One row = | Replaces |
|---|---|---|---|
| **Engineering Wiki › Projects** | **Slices DB** | one workspace slice | the 5 per-hub `〔sync〕` callouts |
| **ADR (Architecture Decision Record)** | **Decisions DB** (restructured) | one decision (one `decisions:` item) | the 5 curated Decision rows |
| **W&B Experiments** | **Experiments DB** (replaces Artifacts DB) | one SLURM job / phase / release | the near-empty Artifacts DB |

The **Navigator home** stitches these together with five linked views so a cold
session re-orients in 1–2 clicks (down from ~5). The old surfaces stay
**read-only / lightly preserved** during migration; the three DBs are the new
SSOT.

**Korean-label policy (preserved from v0.4.2).** Status values and event labels
are **Korean**; identifiers (DB names, ADR IDs, Run IDs, property keys) stay
**English**. Status mapping: `active→활성`, `closed→완료`, `released→릴리즈`,
`dormant→휴면`. Event lexicon (six types, see Section 7): **출시 / 작업 / 설계 /
결정 / 차단 / 수정**.

**MCP-only writes.** Every section below assumes writes go through the
in-session Notion MCP. The script only emits payloads.

---

## Section 2 — Slices DB (Engineering Wiki › Projects pattern)

**Real IDs** (from `.agent/notion_map.yaml` `v0_5:`):
- Slices DB: `3435079f-07ca-4d3c-85c8-f51f0efb0936`
- Slices data source: `01c936b7-2afd-4425-92f7-d94148cab227`
- Seeded row IDs (per slice): `fragmap 36f1e76c-…-90ce-…`, `mmgbsa …-90a5-…`,
  `vav1 …-8b93-…`, `fksfold-core …-85a4-…`, `harness …-af5f-…`,
  `arl …-9d49-…` (full UUIDs in `notion_map.yaml` `v0_5:slice_row_ids`).

**Properties** (created in Task 5): `Name` (title), `Status`
(select: 활성 / 완료 / 릴리즈 / 휴면), `Owner Agent` (select:
claude/codex/cursor/human), `Owner Session` (text, UUID), `Last Heartbeat`
(datetime), `Last Updated` (date), `Project` (select:
`Harness / Agent Ops` or `AIGEN-Fold`), `Next Action` (text),
`State Body` (text), `Linked Decisions` (relation → Decisions DB),
`Linked Experiments` (relation → Experiments DB).

**Row source — `slice_to_db_row(slice_name)`** (in `scripts/notion_sync.py`).
Reads `.agent/status/<slice>.md` frontmatter and returns a **semantic** dict
(Notion column name → value). Concrete mappings, exactly as the code does them:

- `state:` → `Status`: `active→활성`, `closed→완료`, `released→릴리즈`,
  `dormant→휴면`. **Missing/blank `state:` defaults to `활성`** (consistent with
  v0.4.1's default-active rule).
- `slice name` → `Project`: `harness → Harness / Agent Ops`; everything else →
  `AIGEN-Fold`.
- `owner_agent` / `owner_session` / `heartbeat` / `last_updated` → the matching
  columns (empty string if absent — released slices may have empty owners).
- `remaining_actions[0]` → `Next Action` (clipped to 500 chars).

The dict is **semantic only**; translation to the Notion API row payload
(date-key expansion, select shapes) happens in the migrate wrapper (Section 6).

**Auto-update from frontmatter (INTENDED — pending Task 19).** The v0.5 design
has `/handoff` Step 5 recompute `slice_to_db_row(<active slice>)` and
`notion-update-page` the slice's row in place (upsert key = `Name`), refreshing
Status / Last Heartbeat / Last Updated / Next Action. **This auto-update is not
wired into the live `/handoff` yet — it lands in Task 19.** Until then, refresh
a row manually via `--migrate slices` (Section 6).

**Hub reparenting (shipped, Task 10).** The five existing slice hub pages were
`notion-move-pages`'d under their Slices DB row's child-page area. Notion page
URLs are **ID-based**, so the moves preserved every hub URL — external links
still resolve. The hub bodies themselves keep the v0.4.2 `〔sync〕` toggle
format (see Section 7).

---

## Section 3 — Decisions DB as ADR registry (ADR pattern)

**Real IDs**: Decisions data source `b11ae976-472b-46dd-98d9-b42ebe2e8b7b`
(unchanged — Task 6 added ADR properties **in place** on the existing DB).

**Properties added (Task 6)**: `ADR ID` (Notion `unique_id`, prefix **`ADR`**),
`Status` (select: **Proposed / Accepted / Rejected / Implemented / Superseded**),
`Date`, `Slice` (relation → Slices DB), `Deciders` (text/people),
`Linked Contract` (URL), `Supersedes` / `Superseded By` (self-relation pair).
The legacy `Decision Status` enum is retained for backward-compat with the 5
pre-existing curated rows.

**ADR body schema** (Markdown in the page body): `# ADR-NNNN: <title>` then
`## Context` / `## Decision` / `## Consequences` / `## Links`.

**Row source — `contract_to_adr_rows(contract_path)`.** Parses a contract's
frontmatter (safe_load, with a colon-tolerant regex fallback for the repo's
colon-rich `decisions:` items) and emits **one ADR row per `decisions:` item**.
Each row dict: `title` (first 50 chars, ellipsized), `status`, `slice`, `date`,
`deciders` (from `owner` / `approved_by`), `context` (auto-extracted from the
contract's `## Purpose`), `decision` (full text), `consequences`
(`"See linked contract"`), `linked_contract` (repo-relative path), and a stable
`adr_id` of the form **`ADR-<slice>-<topic>-<idx>`**.

**Status transition rules (load-bearing).** The ADR `Status` is derived from the
**contract's `status:` frontmatter** via `_CONTRACT_STATUS_TO_ADR`:

| Contract `status:` | ADR `Status` |
|---|---|
| `pending`  | **Proposed** |
| `approved` | **Accepted** |
| `done`     | **Implemented** |

(Any other / unknown contract status falls back to **Proposed**.) `Rejected` and
`Superseded` are set **manually** by a human reviewer — the code never auto-assigns
them. The **intended** flow (pending Task 19) is that a `/handoff` triggered by a
contract status transition re-runs `contract_to_adr_rows()` and upserts those ADRs
so they advance Proposed → Accepted → Implemented automatically. **Today, advance
ADRs by re-running `--migrate contracts` (Section 6); the contract→ADR auto-trigger
on `/handoff` is not yet wired (Task 19).**

---

## Section 4 — Experiments DB (W&B pattern) + SLURM ingestion

**Real IDs**: Experiments DB `949a3553-1e44-41a7-a8d3-d673ae2f0efe`,
Experiments data source `b1a7f410-364b-4af3-8939-5624ca351605`. Created fresh
(Task 7) next to the legacy Artifacts DB, which is left **read-only**.

**Properties**: `Run ID` (title), `Slice` (relation), `Phase` (text),
`Status` (select: **Queued / Running / Completed / Failed / Cancelled**),
`Start` / `End` (datetime), `Duration` (formula End−Start), `Exit Code` (text),
`Parameters` (text/JSON), `Metrics` (text), `Artifact Path` (URL/text),
`Linked Decision` (relation → Decisions DB).

**Two distinct SLURM sources — do not conflate:**

1. **`sacct` — historical (backfill).** `--migrate slurm` calls
   `_history_slurm_ids()`, which runs
   `sacct -S <today-30d> -E now --format=JobID -P -n` (the **last 30 days**),
   dedupes numeric ids (dropping `.batch`/`.extern` sub-steps and array
   suffixes), then resolves each via `slurm_to_experiment_row(job_id)`. This is
   the **history backfill** path (mirrors plan Task 14).
2. **`squeue` — live (home page).** `_running_slurm_ids()` runs
   `squeue -h -u $USER -o %i` for **currently running/pending** jobs. This feeds
   the Navigator home's `running_experiments` section **only** — it is **not**
   used by the history migration.

**`slurm_to_experiment_row(job_id)`** runs
`sacct -j <id> --format=JobID,State,Start,End,Elapsed,ExitCode,JobName -n -P`,
selects the exact-id main row (skips `.batch`/`.0` steps), and returns a dict
with both lowercase keys (`run_id/slice/status/start/end/duration/exit/metrics/
artifacts`) and capitalized Notion-column keys (`Run ID / Slice / Phase /
Status / Start / End / Duration / Exit Code / Metrics / Artifact Path`).
sacct `State` → `Status` via `_SACCT_STATE_TO_STATUS`
(COMPLETED→Completed, RUNNING→Running, FAILED/TIMEOUT/NODE_FAIL/OOM→Failed,
CANCELLED→Cancelled, PENDING→Queued). Slice/phase are inferred from the job
name (`norm143_*/mmgbsa_*/custom_*→mmgbsa`, `fragmap_*/9nfr_*→fragmap`,
`vav1_*→vav1`; `ab_stage<N>→AB Stage <N>`). For mmgbsa jobs only, metrics are
read from the output dir's `ready_for_mmpbsa_prod.tsv` as `pass_rate=<N>`. The
function is **robust to a missing/erroring sacct** — it returns the same dict
shape with empty fields rather than raising.

**Non-SLURM phase events** (e.g. fragmap Phase 1..10) are not jobs; they were
seeded one-per-fragmap-contract (Task 15) with `Run ID` = contract slug,
`Phase` = contract topic.

**Auto-update on completion (INTENDED).** The design is a poll/manual-trigger
sacct snapshot that upserts a job's row (Status/End/Duration/Exit/Metrics) on
completion (upsert key = `Run ID`). There is **no daemon and no real-time
monitor** (explicit Non-Goal). Today this is driven by re-running
`--migrate slurm`.

---

## Section 5 — Navigator home maintenance

> **SHIPPED (Task 18, 2026-06-04, contract harness-notion-home-renderer).** The
> Navigator home is now RENDERED from the live payload by
> `python scripts/notion_sync.py --render-home` (Mission-Control cockpit + verbatim
> static tail) and applied via one MCP `replace_content` — no more hand-editing /
> drift. See "Rendering the home" below.

**Intended home page** (Notion home `28d1e76c-3b60-8069-a83b-eab69a131a99`),
five linked-view sections:

- 🔄 **지금 진행 중** — Slices DB linked view filtered `Status = 활성`.
- 🧭 **최근 결정** — Decisions DB linked view, last 7d, `Status ∈ {Accepted, Implemented}`.
- 📊 **진행 중 실험** — Experiments DB linked view filtered `Status = Running`.
- 📝 **최근 리포트** — Reports DB linked view, last 7d.
- 📚 **Docs & Standards** — links to `AGENTS.md`, `CLAUDE.md`, `WORKFLOW.md`,
  this runbook, `CLAUDE_HARNESS_USAGE.md`.

**Payload — `home_navigator_payload()`** returns a dict with exactly five list
keys: `active_slices` (one `slice_to_db_row` per active/stateless slice),
`recent_decisions` (ADR rows from contracts dated within the last 7d),
`running_experiments` (one `slurm_to_experiment_row` per **live** `squeue` id),
`recent_reports` (contract + plan paths from the last 7d), and `docs` (fixed
entry points). The "last 7d" window is computed from the trailing
`-YYYYMMDD` filename stamp (falling back to mtime). It is robust by
construction: an unavailable `squeue`/`sacct` yields an empty
`running_experiments` rather than raising.

**Rendering the home (Task 18 — SHIPPED):**

```bash
python scripts/notion_sync.py --render-home   # prints the full home body; no Notion call
```

`--render-home` emits the entire Notion-flavored-markdown home body: the dynamic
Mission-Control cockpit (🛰️ banner + metrics, then a 🕐 freshness-stamp line under
the metrics (`🕐 렌더 <date> · baton @ <git-short-rev> · stale N`), then **three
full-width stacked gray callouts in decision-first order** — 🙋 Decisions (top;
`✅ 결정 대기 없음` when empty) → 🤖 Agent queue (done-lines dropped, ≤1 line/slice)
→ 🩺 sync-health strip — all from `home_navigator_payload()` +
`notion_audit_payload()`), then `---`, then the
**verbatim static tail** from `.agent/notion_home_tail.md` (the 🔄 Slices board,
🗄️ Archives toggle DBs, 🚀 Projects / 🗂️ More child pages, 📚 Docs).

Apply by handing the printed body to one MCP **`replace_content`** on the home
page (`28d1e76c-3b60-8069-a83b-eab69a131a99`). A **preservation preflight**
(`assert_home_preserves`) runs first: if the rendered body would drop any child
`<page>`/`<database>` URL the tail carries, `--render-home` prints
`HOME_RENDER_UNSAFE` and exits 2 — so `replace_content` can never delete a child
page or inline DB. The dynamic content is regenerated each run (zero drift); the
static tail template only needs updating if Projects/More/Docs themselves change.
After the `replace_content` apply, run
`python scripts/notion_sync.py --stamp-home-applied` to record the apply (writes
`.agent/handoffs/state/home-render.stamp` with the rev + UTC time) so the Stop
hook can warn `[home-stale]` when a baton later changes.
`--migrate home` still emits the JSON payload (for inspection); `--render-home` is
the markdown renderer that supersedes the old hand-editing.

### Baton-lint + freshness reminders (Task — home-trust)

```bash
python scripts/notion_sync.py --lint-baton <slice>   # validate a baton at write time
```

`--lint-baton <slice>` checks the baton's frontmatter parse health and its
`remaining_actions` hygiene — the list must NOT lead with a `✅`-done line, and
every non-done item must carry a `DECISION:` / `AGENT:` / `BLOCKED:` prefix (the
rules from `.agent/status/README.md`). It prints any issues to stderr and exits 1
when dirty; exits 0 silently when clean. The Stop hook
(`.claude/hooks/stop-handoff-check.sh`, non-blocking) surfaces two advisory
warnings: `[baton-lint]` fires when the active/claimed slice's baton is dirty, and
`[home-stale]` fires when a `status/*.md` changed since the last
`--stamp-home-applied` (or the home was never stamped). Both only remind — the MCP
write path is manual, so nothing is blocked or auto-applied.

### Notion auto-sync (handoff → marker → auto-catch-up)

핸드오프부터 Notion 적용까지의 catch-up 루프 (순서대로):

1. **`handoff.sh`** 가 슬라이스를 핸드오프할 때마다
   `.agent/handoffs/state/notion-sync-pending` 마커에 슬라이스명을 한 줄씩
   추가하고, 적용용 3-step 레시피를 stderr로 출력한다.
2. **`./scripts/notion_sync.py --emit-apply-plan <slice>`** 가 권장 one-shot 이미터다 —
   `notion_map.yaml` `v0_5` 에서 HOME + ROW page_id 를 RESOLVE 해 (MCP 검색 불필요)
   preflight 결과(`PASS` / `HOME_RENDER_UNSAFE`) + home body + row payload + 두 MCP 콜을
   한 블록으로 찍는다. id 미해결·preflight 실패 시 exit≠0 (FAIL loud). 구버전
   **`--handoff-emit <slice>`** 는 id 해석 없이 home+row 만 찍는다 (`=== HOME … ===` /
   `=== ROW: <slice> … ===`); 신규 적용은 `--emit-apply-plan` 을 우선 쓴다.
3. **SessionStart 훅** (`session-start-decay-check.sh`) 은 마커가 비어있지 않으면
   `⚠️ NOTION SYNC PENDING: <slices>` 지시문을 주입해, 다음 MCP-capable (Claude)
   세션이 시작 리추얼의 일부로 sync 를 자동 적용하게 한다.
4. **Stop 훅** (`stop-handoff-check.sh`) 은 마커가 비어있지 않으면 non-blocking
   `[notion-sync-pending]` 리마인더를 출력한다 (차단하지 않음).
5. **`--stamp-home-applied`** 가 마커를 CLEAR 한다 — stamp 가 "sync 완료" 신호다.

**MCP-only 천장 (load-bearing) + headless ROW writer (무인 직전).** 스타일링된 HOME
cockpit 은 여전히 MCP 전용이다 (rich markdown→blocks 는 MCP 로만 적용; 천장 불변). 단
DB-ROW 프로퍼티용 headless writer 는 이제 **존재한다**: `scripts/notion_apply.py`
(contract `harness-notion-headless-apply-20260609`). `--dry-run` (기본) 은 REST
property payload 를 OFFLINE 으로 빌드·검증한다 (토큰·네트워크 불필요; CI 검증면).
`--apply` 는 `NOTION_TOKEN` 으로 `PATCH /v1/pages/{row_id}` 한다 — **단 토큰이
provision 될 때까지 라이브 경로는 UNVERIFIED** (워크스페이스 권한이 막음; 토큰 provision +
cron 트리거는 OUT of scope). 즉 ROW 동기화는 "무인 직전" 까지 와 있고 토큰 1개만 풀리면
무인이 된다. `NOTION_SYNC_REPO_ROOT` 환경변수는 repo root 를 오버라이드해 훅/테스트가
fixture 를 가리키게 한다.

### Navigator Action Queues

The Navigator first viewport is action-oriented:

- `내가 결정할 것` lists human approvals, choices, release calls, and priority decisions.
- `에이전트가 실행할 것` lists Codex/Claude-ready work that does not require another human decision.
- Slices DB Project Rows show `Health`, `Sync Status`, `Decision Needed`, `Agent Next`, `Now`, `Next`, `Blocker`, and `Last Heartbeat`.

`.agent/status/<slice>.md` remains the source of truth. Notion is a derived view.
Do not edit Notion with the expectation that `.agent` will be updated.

The payload is emitted by `--migrate home` under `navigator.action_queues`
(`home_navigator_payload()` adds `human_decisions` / `agent_execution` /
`blockers`, each item `{slice, text}`). Before applying any MCP-backed Notion
update, run:

```bash
python scripts/notion_sync.py --audit
python scripts/notion_sync.py --migrate slices
python scripts/notion_sync.py --migrate home
```

If `--audit` reports `Parser warning`, `Regex fallback`, `Stale`, or
`Missing`, show the findings to the user before applying Notion writes.
(`Regex fallback` = the baton's frontmatter is not strict YAML but the row was
recovered via the tolerant extractor — the row still populates, but the baton
should be tightened; `Parser warning` = unrecoverable.) Schema changes to the
Slices DB require explicit approval under the root `AGENTS.md` approval gates.

### Cockpit vs Archives — what belongs on the home

The home is an **operating cockpit, not a mirror of everything**. A section is
only worth a live home view if it is *reliably maintained*, which is
**(stable upsert key) × (push frequency)**:

- **Slices DB = the live cockpit.** Fixed rows, stable key `Name`, pushed every
  `/handoff` (Step 5.2). The action queues + 진행 중 슬라이스 view derive from it.
  This is the home's first viewport.
- **Decisions (ADR) / Experiments / Reports = on-demand archives, OFF the home.**
  They are append-only logs with no stable agent-writable key (ADR `ADR ID` is
  auto-increment) and a manual push that is routinely skipped — so a live
  "최근 7일" home view goes stale. Keep them in the `🗄️ Archives` toggle (or the
  Databases page) and backfill on demand with `--migrate {contracts,slurm}` when
  you actually need them current. Do NOT re-add them as live home views, and do
  NOT make them a per-handoff push burden. A periodic "이번 주 결정" summary, if
  wanted, belongs in the Weekly Digest (text), not a live DB view.

---

## Section 6 — Backfill & migration procedures (`--migrate` CLI)

The CLI mode (Task 23): `--migrate {slices,contracts,slurm,home,all}`. **Every
`--migrate` invocation PRINTS upsert-keyed JSON to stdout and makes ZERO Notion /
network calls** — the headless token is blocked by workspace permissions (see
top), so a **human or agent applies the printed payload via the in-session
Notion MCP**. This separation is load-bearing.

```bash
# Slices DB rows (one per active/stateless slice). upsert_key = "Name".
python /home/ubuntu/scripts/notion_sync.py --migrate slices

# All contract decisions → ADR rows. upsert_key = "adr_id".
python /home/ubuntu/scripts/notion_sync.py --migrate contracts

# Last-30d SLURM history → Experiments rows (sacct, NOT squeue). upsert_key = "Run ID".
python /home/ubuntu/scripts/notion_sync.py --migrate slurm

# Navigator home payload (5 sections). upsert_key = "home".
python /home/ubuntu/scripts/notion_sync.py --migrate home

# All four in sequence, each under a "=== MIGRATE <name> ===" header.
python /home/ubuntu/scripts/notion_sync.py --migrate all
```

**Envelope shape** (`_emit_migration`): `{target, db, mode:"upsert", upsert_key,
count, rows}`. The `upsert_key` names the **stable identifier field** per target
(`Name` / `adr_id` / `Run ID` / `home`); re-running a migrate produces the same
key per row, so MCP application **matches-and-updates** rather than inserting
duplicates. **Idempotency = stable upsert key, applied as a find-or-update by the
MCP operator.** `ensure_ascii=False` keeps Korean Status labels (활성 etc.)
legible in the JSON.

**Other read helpers (no Notion calls):** `--dump --all` / `--dump --slice NAME`
(slice status + contract decisions as JSON), `--handoff-log --slice NAME`
(v0.4.2 lab-log payload), `--check-env` (notion-client + token preflight; never
calls the API).

**Backfill done in Phase B** (record): 6 Slices rows seeded; 100+ ADR rows from
16 contracts (5 curated rows preserved); 240 SLURM jobs + 12 fragmap-phase rows
into Experiments. A pre-migration Notion backup lives in
`.agent/scratch/notion_backup_20260529/`. **Re-running any migrate is safe** —
the upsert key prevents duplicates.

---

## Section 7 — Slice-hub child-page format (preserved from v0.4.2)

The per-slice **lab-log** that `/handoff` writes is **preserved** in v0.5 — it
just now lives on each slice's hub page, which is a **child page of that slice's
Slices DB row** (Section 2 reparenting). Two artifacts per active slice: the hub
`〔sync〕` **toggle** and a `<slice> <ISO-week> Weekly Digest` Reports row with
one **event-typed callout** per research-meaningful day.

> **(pending Task 19)** The *live* `/handoff` Step 5 still runs the v0.4.2 logic
> below. The v0.5 additions (Slices-row + ADR + Experiments updates) wrap around
> this preserved core but are **not yet wired** — see Task 19.

### 7.1 Get the payload (no Notion calls)

```bash
/home/ubuntu/miniconda3/bin/python scripts/notion_sync.py --handoff-log --slice X
```

Yields `{date, iso_week, conclusion, change_digest, evidence, event_type,
event_emoji, event_color}` (the last three from `classify_event`).

### 7.2 Slice hub `〔sync〕` block — TOGGLE template

Notion-flavored markdown, TAB-indented:

```
<details color="<slice_color>_bg">
<summary>🔄 **동기화** · <date> · 자동 생성 (`.agent/status/<slice>.md`)</summary>
	**상태**       <event emoji> <conclusion-snippet> (<key evidence>)
	**진행 중**    — (또는 in-flight 한 줄 요약)
	**다음**       <first remaining_action>
	**갱신**       <ISO heartbeat>
</details>
```

`<slice_color>` per slice: fragmap=blue, mmgbsa=red, vav1=green,
fksfold-core=purple, harness=brown. **Find-or-update**: replace an existing
`🔄 **동기화**` toggle; else `insert_content {position:start}`.

### 7.3 Weekly Digest row — EVENT-TYPED CALLOUT per entry

Find or create the Reports row `<slice> <ISO-week> Weekly Digest` (Report
Type = **Weekly Digest**, Project, Slice, Date = Monday of ISO-week). Body =
event-typed callouts, most-recent first:

```
<callout icon="<event_emoji>" color="<event_color>">
**<event_type_label> · <MM-DD>** — <one-line title>
<identifier line: PR # · tag v... · SHA · etc.>
<body line(s): adds, evidence, impact>
**다음**: <next action, optional>
</callout>
```

The `Report Type` enum in Reports DB is rich (Weekly Digest / Meeting Brief /
Research Update / Experiment Closeout / E2E Verification / Operational Update),
so the home's 📝 최근 리포트 view can filter cleanly (Task 16 verified — no
restructuring was needed).

### 7.4 Event classification (`classify_event`) — 한글 lexicon (preserved)

| 순위 | 한글 라벨 | 이모지 | 색 (Notion bg) | 키워드 (case-insensitive substring) |
|---|---|---|---|---|
| 1 | 차단 | ⚠️ | red_bg | blocker, blocked, 차단, FAIL, stuck |
| 2 | 출시 | 🚀 | green_bg | shipped, released, ship, "tag v", "PR #", merged |
| 3 | 수정 | 🐛 | orange_bg | fixed, fix, bug, 수정, hotfix |
| 4 | 결정 | ✅ | purple_bg | decided, 결정, "agreed on", 확정 |
| 5 | 설계 | 📝 | gray_bg | contract, approved, planning, spec, drafted |
| 6 | 작업 (default) | 🛠 | blue_bg | (no keywords — falls through) |

**Priority**: 차단 > 출시 > 수정 > 결정 > 설계 > 작업; first match wins.
LLM-based classification remains a **Non-Goal** (keyword heuristic only).

### 7.5 Gate & non-blocking (preserved)

`gate_should_write(prev_entry_text, payload)` writes iff
`payload["change_digest"]` is **not** a substring of the prior entry text — so
only research-meaningful days (conclusion or decision-set changed) get a new
callout. If the Notion MCP is unavailable or any step errors, emit a one-line
stderr warning and **STOP the lab-log without raising** — `/handoff` must
complete regardless.

---

## Section 8 — `chg` marker handling (where it lives now)

In v0.4.2 the change-gate digest was rendered as a visible gray inline span at
the foot of each Weekly Digest callout (`<span color="gray">chg:<digest></span>`),
because that was the only place known to survive Notion's markdown read-back.

**v0.5 target:** move the digest **off the visible body** into a **hidden page
property `last_change_digest`** on the Weekly Digest row. This fully hides it
from the rendered callout while preserving the gate behavior — `gate_should_write`
checks the digest string, so reading it back from a property is equivalent to
reading it from the span, *provided* the Notion API exposes hidden properties on
fetch.

**Compatibility caveat (load-bearing).** Whether Notion's fetch reliably returns
a hidden property value must be verified on a throwaway test page before relying
on it. **Fallback:** if hidden-property read-back proves unreliable, keep the
v0.4.2 gray-span placement. Either way the digest format (`<n>:<8hex>` from
`handoff_log_payload`) and the substring gate semantics are **unchanged** —
**fully removing the `chg` marker is a Non-Goal** (the gate depends on it).

---

## Appendix — legacy v1/v0.4.x IDs (preserved during migration)

- Slice hub pages (URLs preserved post-reparent): fragmap
  `36d1e76c-3b60-8136-8921-ee505191976d`, mmgbsa
  `36d1e76c-3b60-8178-aa35-e69e2be57dc4`, vav1
  `36d1e76c-3b60-810e-8aa5-e9e4706c8b8a`, fksfold-core
  `36d1e76c-3b60-81e5-94a3-fddefcca6e40`, harness
  `36d1e76c-3b60-813d-ab19-cc9b41e69d4a`.
- Legacy data sources: Reports `94d8277f-…`, Decisions
  `b11ae976-…` (now the ADR registry), Artifacts `2e47ef6d-…`
  (read-only, superseded by Experiments DB).
- Reverse sync (Notion → `.agent/`) is a permanent **non-goal** — Notion is the
  derived view; `.agent/` is the source of truth.
