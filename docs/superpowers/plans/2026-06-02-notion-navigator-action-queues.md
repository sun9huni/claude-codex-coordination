# Notion Navigator Action Queues Implementation Plan

> ✅ **COMPLETED 2026-06-02** (claude takeover from codex). All 7 tasks done.
> Tasks 1-2 by codex (`bda63c9`/`50694ea`/`3b7c0de`); Tasks 3-5 by claude
> (`d96a305` audit / `354ad57` home payload / `30abe23` runbook); Task 6 Notion
> MCP applied + verified (user approved "전체 적용"); Task 7 closed
> (`91830cb`/`e3de8c5`). Contract `harness-notion-ux-action-queues-20260602`
> status=done. See its Progress Log for the MCP detail + deferred follow-ups.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the Notion Navigator and Slices DB into an action-oriented operating view that separates human decisions from agent execution work and shows sync trust.

**Architecture:** Keep `.agent/status/<slice>.md` as the source of truth and compute a short derived Notion view model in `scripts/notion_sync.py`. Add local tests for queue extraction, sync health, home payload shape, and CLI audit output before any live Notion MCP writes. Apply Notion schema and home updates only after approval.

**Tech Stack:** Python 3, PyYAML, pytest, existing `scripts/notion_sync.py`, Notion MCP manual application, existing `.agent` harness scripts.

---

## File Structure

- Modify: `scripts/notion_sync.py`
  - Add a slice queue view model, sync trust model, `--audit` CLI, and action-queue home payload fields.
- Modify: `tests/test_notion_migration.py`
  - Add no-network tests for queue fields, health statuses, home action queues, and audit payloads.
- Modify: `tests/test_notion_sync_read.py`
  - Add a parser-warning fixture only if the implementation exposes parser diagnostics through the read layer.
- Modify: `docs/notion-sync-runbook.md`
  - Document the action-queue Notion UX, approval gate, and audit workflow.
- Modify: `.agent/contracts/harness-notion-ux-action-queues-20260602.md`
  - Update progress after implementation and verification.
- Modify: `.agent/status/harness.md`
  - Record final result and next action.
- Regenerate: `.agent/handoffs/CURRENT.md`
  - Run `./scripts/status.sh index` after the harness status update.

Do not modify unrelated slice status files. Do not apply Notion schema changes until the user approves the MCP write step.

## Task 1: Add Local Tests For Slice Queue Fields

**Files:**
- Modify: `tests/test_notion_migration.py`

- [ ] **Step 1: Add a tmp status helper**

Append this helper near the top of `tests/test_notion_migration.py`, after the module import:

```python
def _write_status(tmp_path, slice_name, frontmatter, body="body\n"):
    status_dir = tmp_path / ".agent" / "status"
    status_dir.mkdir(parents=True, exist_ok=True)
    lines = ["---"]
    for key, value in frontmatter.items():
        if isinstance(value, list):
            lines.append(f"{key}:")
            for item in value:
                lines.append(f"  - {item!r}")
        else:
            lines.append(f"{key}: {value!r}")
    lines.extend(["---", body])
    (status_dir / f"{slice_name}.md").write_text("\n".join(lines), encoding="utf-8")
```

- [ ] **Step 2: Add the failing queue-field test**

Append this test to `tests/test_notion_migration.py`:

```python
def test_slice_to_db_row_adds_action_queue_fields(tmp_path, monkeypatch):
    monkeypatch.setattr(notion_sync, "REPO_ROOT", tmp_path)
    _write_status(
        tmp_path,
        "harness",
        {
            "state": "active",
            "owner_agent": "codex",
            "owner_session": "session-1",
            "last_updated": "2026-06-02",
            "heartbeat": "2026-06-02T15:30:00Z",
            "remaining_actions": [
                "DECISION: approve Notion schema fields",
                "AGENT: implement --audit sync trust layer",
                "BLOCKED: MCP write approval pending",
            ],
        },
    )

    row = notion_sync.slice_to_db_row("harness")

    assert row["Name"] == "harness"
    assert row["Headline"] == "approve Notion schema fields"
    assert row["Decision Needed"] == "approve Notion schema fields"
    assert row["Agent Next"] == "implement --audit sync trust layer"
    assert row["Blocker"] == "MCP write approval pending"
    assert row["Now"] == "approve Notion schema fields"
    assert row["Next"] == "implement --audit sync trust layer"
    assert row["Health"] == "Fresh"
    assert row["Sync Status"] == "Fresh"
    assert row["Last Sync Source"] == ".agent/status/harness.md"
```

- [ ] **Step 3: Run the test and confirm it fails**

Run:

```bash
python -m pytest tests/test_notion_migration.py::test_slice_to_db_row_adds_action_queue_fields -q
```

Expected: `FAIL` with a `KeyError` for `Headline` or another new queue field.

- [ ] **Step 4: Commit the failing test**

Run:

```bash
git add tests/test_notion_migration.py
git commit -m "test: specify Notion slice action queue fields"
```

Expected: commit succeeds with the failing test only.

## Task 2: Implement Slice Queue Extraction

**Files:**
- Modify: `scripts/notion_sync.py`

- [ ] **Step 1: Add queue extraction helpers**

Add this code above `slice_to_db_row()`:

```python
def _clean_action_marker(text: str) -> tuple[str, str]:
    """Return (kind, cleaned_text) for a baton action string."""
    raw = str(text or "").strip()
    patterns = [
        ("decision", r"^(?:DECISION|USER|HUMAN|내가 결정할 것)\s*[:：-]\s*"),
        ("agent", r"^(?:AGENT|CODEX|CLAUDE|에이전트가 실행할 것)\s*[:：-]\s*"),
        ("blocker", r"^(?:BLOCKED|BLOCKER|차단|블로커)\s*[:：-]\s*"),
    ]
    for kind, pattern in patterns:
        cleaned = re.sub(pattern, "", raw, flags=re.IGNORECASE).strip()
        if cleaned != raw:
            return kind, cleaned
    upper = raw.upper()
    if "승인" in raw or "approve" in upper or "decision" in upper:
        return "decision", raw
    if "blocked" in upper or "pending" in upper or "대기" in raw:
        return "blocker", raw
    return "agent", raw


def _truncate_field(text: str, limit: int = 160) -> str:
    cleaned = " ".join(str(text or "").split())
    if len(cleaned) <= limit:
        return cleaned
    return cleaned[: limit - 1].rstrip() + "…"


def _action_queue_fields(slice_name: str, fm: dict) -> dict:
    actions = fm.get("remaining_actions") or []
    if not isinstance(actions, list):
        actions = []

    decision = ""
    agent_next = ""
    blocker = ""
    fallback = ""

    for action in actions:
        kind, cleaned = _clean_action_marker(str(action))
        cleaned = _truncate_field(cleaned)
        if not fallback and cleaned:
            fallback = cleaned
        if kind == "decision" and not decision:
            decision = cleaned
        elif kind == "agent" and not agent_next:
            agent_next = cleaned
        elif kind == "blocker" and not blocker:
            blocker = cleaned

    if not decision:
        decision = ""
    if not agent_next:
        agent_next = fallback

    now = decision or agent_next or blocker
    next_value = agent_next if agent_next != now else ""
    headline = now or slice_name

    return {
        "Headline": headline,
        "Now": now,
        "Next": next_value,
        "Decision Needed": decision,
        "Agent Next": agent_next,
        "Blocker": blocker,
    }
```

- [ ] **Step 2: Extend `slice_to_db_row()` return fields**

In `slice_to_db_row()`, after the existing `project = _SLICE_TO_PROJECT.get(slice_name, _FKSFOLD_PROJECT)` line, add:

```python
    queue_fields = _action_queue_fields(slice_name, fm)
    sync_status = "Fresh" if heartbeat else "Stale"
```

Then update the returned dict so it includes:

```python
        **queue_fields,
        "Health": sync_status,
        "Sync Status": sync_status,
        "Last Sync Source": f".agent/status/{slice_name}.md",
```

- [ ] **Step 3: Run the queue-field test**

Run:

```bash
python -m pytest tests/test_notion_migration.py::test_slice_to_db_row_adds_action_queue_fields -q
```

Expected: `1 passed`.

- [ ] **Step 4: Run existing Notion migration tests**

Run:

```bash
python -m pytest tests/test_notion_migration.py -q
```

Expected: all tests pass. If `test_slurm_to_experiment_row_for_5754` depends on unavailable `sacct`, document the environment failure and run the targeted slice/home tests instead.

- [ ] **Step 5: Commit**

Run:

```bash
git add scripts/notion_sync.py tests/test_notion_migration.py
git commit -m "feat: derive Notion action queue fields"
```

Expected: commit succeeds with the test and implementation.

## Task 3: Add Sync Trust Audit

**Files:**
- Modify: `scripts/notion_sync.py`
- Modify: `tests/test_notion_migration.py`

- [ ] **Step 1: Add the failing audit test**

Append this test to `tests/test_notion_migration.py`:

```python
def test_notion_audit_payload_flags_stale_and_parser_warning(tmp_path, monkeypatch):
    monkeypatch.setattr(notion_sync, "REPO_ROOT", tmp_path)
    _write_status(
        tmp_path,
        "fresh",
        {
            "state": "active",
            "heartbeat": "2026-06-02T15:30:00Z",
            "remaining_actions": ["AGENT: continue work"],
        },
    )
    _write_status(
        tmp_path,
        "stale",
        {
            "state": "active",
            "heartbeat": "",
            "remaining_actions": ["AGENT: refresh status"],
        },
    )
    status_dir = tmp_path / ".agent" / "status"
    (status_dir / "bad.md").write_text(
        "---\nremaining_actions:\n  - ok\n  bad\n---\nbody\n",
        encoding="utf-8",
    )

    payload = notion_sync.notion_audit_payload()

    findings = payload["findings"]
    assert payload["summary"]["slices_checked"] == 3
    assert any(f["slice"] == "stale" and f["status"] == "Stale" for f in findings)
    assert any(f["slice"] == "bad" and f["status"] == "Parser warning" for f in findings)
```

- [ ] **Step 2: Run the audit test and confirm it fails**

Run:

```bash
python -m pytest tests/test_notion_migration.py::test_notion_audit_payload_flags_stale_and_parser_warning -q
```

Expected: `FAIL` with `AttributeError: module 'notion_sync' has no attribute 'notion_audit_payload'`.

- [ ] **Step 3: Implement parser diagnostics and audit payload**

Add these helpers above `_active_slice_names()`:

```python
def _frontmatter_status(path: Path) -> tuple[dict, str]:
    if not path.exists():
        return {}, "Missing"
    parsed = _parse_frontmatter(path)
    if parsed is None:
        return {}, "Parser warning"
    return parsed, "OK"


def _slice_sync_status(slice_name: str) -> dict:
    path = REPO_ROOT / ".agent" / "status" / f"{slice_name}.md"
    fm, parse_status = _frontmatter_status(path)
    if parse_status != "OK":
        return {
            "slice": slice_name,
            "status": parse_status,
            "detail": f"frontmatter could not be parsed: {path.relative_to(REPO_ROOT)}",
        }
    heartbeat = str(fm.get("heartbeat") or "").strip()
    state = str(fm.get("state") or "active").strip().lower()
    if not heartbeat and state != "released":
        return {
            "slice": slice_name,
            "status": "Stale",
            "detail": "active slice has no heartbeat",
        }
    return {
        "slice": slice_name,
        "status": "Fresh",
        "detail": "status frontmatter parsed and heartbeat present",
    }


def notion_audit_payload() -> dict:
    status_dir = REPO_ROOT / ".agent" / "status"
    findings = []
    for path in sorted(status_dir.glob("*.md")):
        if path.stem == "README":
            continue
        finding = _slice_sync_status(path.stem)
        if finding["status"] != "Fresh":
            findings.append(finding)
    return {
        "target": "audit",
        "source": ".agent/status",
        "summary": {
            "slices_checked": len([p for p in status_dir.glob("*.md") if p.stem != "README"]),
            "findings": len(findings),
        },
        "findings": findings,
    }
```

- [ ] **Step 4: Add `--audit` CLI support**

In `parse_args()`, add:

```python
    parser.add_argument(
        "--audit",
        action="store_true",
        help="print local Notion sync trust audit JSON; no Notion calls",
    )
```

In `main()`, after the `args.check_env` block, add:

```python
    if args.audit:
        print(json.dumps(notion_audit_payload(), indent=2, ensure_ascii=False))
        return 0
```

- [ ] **Step 5: Run the audit tests**

Run:

```bash
python -m pytest tests/test_notion_migration.py::test_notion_audit_payload_flags_stale_and_parser_warning -q
python scripts/notion_sync.py --audit
```

Expected: pytest passes. The CLI prints JSON with `target` equal to `audit` and no Notion network call.

- [ ] **Step 6: Commit**

Run:

```bash
git add scripts/notion_sync.py tests/test_notion_migration.py
git commit -m "feat: add Notion sync trust audit"
```

Expected: commit succeeds.

## Task 4: Add Home Action Queue Payload

**Files:**
- Modify: `scripts/notion_sync.py`
- Modify: `tests/test_notion_migration.py`

- [ ] **Step 1: Add the failing home queue test**

Append this test to `tests/test_notion_migration.py`:

```python
def test_home_navigator_payload_includes_action_queues(tmp_path, monkeypatch):
    monkeypatch.setattr(notion_sync, "REPO_ROOT", tmp_path)
    _write_status(
        tmp_path,
        "harness",
        {
            "state": "active",
            "heartbeat": "2026-06-02T15:30:00Z",
            "remaining_actions": [
                "DECISION: approve schema update",
                "AGENT: render Navigator action queue",
            ],
        },
    )
    (tmp_path / ".agent" / "contracts").mkdir(parents=True)
    (tmp_path / ".agent" / "plans").mkdir(parents=True)

    payload = notion_sync.home_navigator_payload()

    assert "action_queues" in payload
    assert payload["action_queues"]["human_decisions"] == [
        {"slice": "harness", "text": "approve schema update"}
    ]
    assert payload["action_queues"]["agent_execution"] == [
        {"slice": "harness", "text": "render Navigator action queue"}
    ]
```

- [ ] **Step 2: Run the test and confirm it fails**

Run:

```bash
python -m pytest tests/test_notion_migration.py::test_home_navigator_payload_includes_action_queues -q
```

Expected: `FAIL` because `action_queues` is missing.

- [ ] **Step 3: Implement action queue collection**

Add this helper above `home_navigator_payload()`:

```python
def _home_action_queues(active_rows: list[dict]) -> dict:
    human_decisions = []
    agent_execution = []
    blockers = []
    for row in active_rows:
        name = row.get("Name", "")
        decision = row.get("Decision Needed", "")
        agent_next = row.get("Agent Next", "")
        blocker = row.get("Blocker", "")
        if decision:
            human_decisions.append({"slice": name, "text": decision})
        if agent_next:
            agent_execution.append({"slice": name, "text": agent_next})
        if blocker:
            blockers.append({"slice": name, "text": blocker})
    return {
        "human_decisions": human_decisions,
        "agent_execution": agent_execution,
        "blockers": blockers,
    }
```

In `home_navigator_payload()`, after the existing `active_slices = [slice_to_db_row(name) for name in _active_slice_names()]` line, add:

```python
    action_queues = _home_action_queues(active_slices)
```

Then include:

```python
        "action_queues": action_queues,
```

The returned key set test must be updated from exact equality to expected subset membership:

```python
    assert expected_keys <= set(payload.keys())
```

- [ ] **Step 4: Run home payload tests**

Run:

```bash
python -m pytest tests/test_notion_migration.py::test_home_navigator_payload_structure tests/test_notion_migration.py::test_home_navigator_payload_includes_action_queues -q
```

Expected: both tests pass.

- [ ] **Step 5: Commit**

Run:

```bash
git add scripts/notion_sync.py tests/test_notion_migration.py
git commit -m "feat: add Navigator action queue payload"
```

Expected: commit succeeds.

## Task 5: Update Runbook And Local Migration Output

**Files:**
- Modify: `docs/notion-sync-runbook.md`
- Modify: `scripts/notion_sync.py` if migration comments or help text need adjustment

- [ ] **Step 1: Add runbook section**

Add this section to `docs/notion-sync-runbook.md` near the v0.5 Navigator instructions. Insert the text between the `BEGIN` and `END` markers; do not include the markers themselves:

```text
BEGIN
## Navigator Action Queues

The Navigator first viewport is action-oriented:

- `내가 결정할 것` lists human approvals, choices, release calls, and priority decisions.
- `에이전트가 실행할 것` lists Codex/Claude-ready work that does not require another human decision.
- Slices DB Project Rows show `Health`, `Sync Status`, `Decision Needed`, `Agent Next`, `Now`, `Next`, `Blocker`, and `Last Heartbeat`.

`.agent/status/<slice>.md` remains the source of truth. Notion is a derived view.
Do not edit Notion with the expectation that `.agent` will be updated.

Before applying any MCP-backed Notion update, run:

~~~bash
python scripts/notion_sync.py --audit
python scripts/notion_sync.py --migrate slices
python scripts/notion_sync.py --migrate home
~~~

If `--audit` reports `Parser warning`, `State mismatch`, `Stale`, or
`Notion row missing`, show the findings to the user before applying Notion
writes. Schema changes to the Slices DB require explicit approval under the
root `AGENTS.md` approval gates.
END
```

- [ ] **Step 2: Run local payload commands**

Run:

```bash
python scripts/notion_sync.py --audit
python scripts/notion_sync.py --migrate slices
python scripts/notion_sync.py --migrate home
```

Expected: all commands exit `0`; outputs are JSON. Warnings are acceptable only if they name known malformed frontmatter and are documented in the contract progress log.

- [ ] **Step 3: Commit**

Run:

```bash
git add docs/notion-sync-runbook.md scripts/notion_sync.py
git commit -m "docs: document Notion action queue sync"
```

Expected: commit succeeds. If `scripts/notion_sync.py` was not changed in this task, omit it from `git add`.

## Task 6: Approval-Gated Notion MCP Application

**Files:**
- Modify after approval: Notion Slices DB schema and Navigator Home through MCP
- Modify after MCP check: `.agent/contracts/harness-notion-ux-action-queues-20260602.md`

- [ ] **Step 1: Stop and request approval**

Ask the user:

```text
Notion schema/home updates require approval. I have local payloads for Slices and Home. May I add the new Slices DB properties and update the Navigator Home through Notion MCP?
```

Expected: user explicitly approves before this task continues.

- [ ] **Step 2: Add Slices DB properties through MCP**

Use Notion MCP to add these properties to the Slices DB data source:

```text
Headline: RICH_TEXT
Now: RICH_TEXT
Decision Needed: RICH_TEXT
Agent Next: RICH_TEXT
Blocker: RICH_TEXT
Health: SELECT('Fresh':green, 'Stale':yellow, 'Parser warning':red, 'State mismatch':red, 'MCP skipped':gray)
Sync Status: SELECT('Fresh':green, 'Stale':yellow, 'Parser warning':red, 'State mismatch':red, 'MCP skipped':gray)
Last Sync Source: RICH_TEXT
```

Expected: MCP returns the updated schema. Record the data source ID in the contract progress log.

- [ ] **Step 3: Apply slice rows through MCP**

Run:

```bash
python scripts/notion_sync.py --migrate slices
```

Apply the emitted rows to Slices DB by upserting on `Name`.

Expected: existing rows update instead of duplicating. Representative rows show `Decision Needed`, `Agent Next`, `Health`, and `Sync Status`.

- [ ] **Step 4: Apply Navigator Home through MCP**

Run:

```bash
python scripts/notion_sync.py --migrate home
```

Update the Navigator Home first viewport so it starts with:

```text
내가 결정할 것
에이전트가 실행할 것
Sync health summary
Active Slices preview
```

Expected: the home page no longer front-loads setup instructions before the action queues.

- [ ] **Step 5: Fetch and verify live Notion**

Use Notion MCP fetch for:

```text
Navigator Home
Slices DB data source
harness row
one stale or mismatched row if audit reports one
```

Expected: fetched content shows action queues and trust fields. If a row is stale or parser-limited, the live view exposes that status.

- [ ] **Step 6: Commit contract progress**

Update `.agent/contracts/harness-notion-ux-action-queues-20260602.md` progress log with the MCP result and commit:

```bash
git add .agent/contracts/harness-notion-ux-action-queues-20260602.md
git commit -m "docs: record Notion action queue MCP application"
```

Expected: commit succeeds.

## Task 7: Final Verification And Handoff

**Files:**
- Modify: `.agent/contracts/harness-notion-ux-action-queues-20260602.md`
- Modify: `.agent/status/harness.md`
- Regenerate: `.agent/handoffs/CURRENT.md`

- [ ] **Step 1: Run required verification**

Run:

```bash
python -m pytest tests/test_notion_migration.py tests/test_notion_sync_read.py
python scripts/notion_sync.py --audit
python scripts/notion_sync.py --migrate slices
python scripts/notion_sync.py --migrate home
./scripts/tool-audit.sh
./scripts/verify.sh
git diff --check -- scripts/notion_sync.py tests/test_notion_migration.py tests/test_notion_sync_read.py docs/notion-sync-runbook.md .agent/contracts/harness-notion-ux-action-queues-20260602.md .agent/status/harness.md
```

Expected: all commands pass. If global `git diff --check` fails on unrelated dirty files, run the scoped diff-check above and document the unrelated path.

- [ ] **Step 2: Mark contract done**

In `.agent/contracts/harness-notion-ux-action-queues-20260602.md`, change:

```yaml
status: pending
```

to:

```yaml
status: done
```

Append a progress log entry:

```markdown
- 2026-06-02: implementation completed. Verification passed for pytest,
  local audit, migration payloads, tool audit, verify script, and scoped
  diff-check. Notion MCP live result: applied through MCP; fetched Navigator
  Home and representative Slices rows confirmed action queues and sync trust
  fields.
```

If the user does not approve live MCP writes, use this exact progress entry
instead and keep `status: pending`:

```markdown
- 2026-06-02: local implementation completed. Verification passed for pytest,
  local audit, migration payloads, tool audit, verify script, and scoped
  diff-check. Notion MCP live result: skipped because the user did not approve
  schema or home-page writes.
```

- [ ] **Step 3: Update harness status**

Update `.agent/status/harness.md` frontmatter `remaining_actions` to include:

```yaml
remaining_actions:
  - "✅ Notion Navigator action queues completed: Home separates human decision and agent execution queues; Slices DB exposes Project Rows and sync trust fields."
  - "NEXT: monitor --audit output during future handoffs; fix any slice-specific parser/stale findings in that slice's own baton."
```

Add the contract pointer:

```yaml
  - .agent/contracts/harness-notion-ux-action-queues-20260602.md
```

- [ ] **Step 4: Regenerate handoff index**

Run:

```bash
./scripts/status.sh index
```

Expected: `.agent/handoffs/CURRENT.md` regenerates from status files.

- [ ] **Step 5: Commit final status**

Run:

```bash
git add .agent/contracts/harness-notion-ux-action-queues-20260602.md .agent/status/harness.md .agent/handoffs/CURRENT.md
git commit -m "docs: close Notion action queue contract"
```

Expected: commit succeeds.

## Self-Review

- Spec coverage: action queues are covered by Tasks 1, 2, and 4; sync trust is covered by Task 3; runbook and source-of-truth language are covered by Task 5; approval-gated MCP application is covered by Task 6; handoff and Claude/Codex continuity are covered by Task 7.
- Placeholder scan: this plan has no unresolved marker text or unspecified "add tests" steps.
- Type consistency: queue field names are consistent across tests, implementation snippets, schema, migration payloads, and verification.
