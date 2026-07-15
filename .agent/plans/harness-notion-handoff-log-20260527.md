---
contract: .agent/contracts/harness-notion-handoff-log-20260527.md
slice: harness
status: done
total_tasks: 7
estimated_total_min: 31
---

# Plan — Notion handoff log (per-slice weekly lab-notebook, change-gated)

Phase order: Core(1) → Test(2) → Docs/routine(3) → Skill glue(4) →
Execute live(5) → Idempotency check(6) → Finalize(7).

Builds on notion-sync v1 (`scripts/notion_sync.py`, `.agent/notion_map.yaml`,
`docs/notion-sync-runbook.md`, claude.ai Notion MCP). Write half is MCP-driven
(agent-executed); the script supplies a read-only payload + a pure gate function.

---

## Task 1: notion_sync.py `--handoff-log` payload + change-gate function

- **Status**: done (2026-05-27, commit 4ded374; code-review APPROVE. 2026-W22, digest 13:bc1938e9, gate verified, no network)
- **Prereq tasks**: none (extends existing read layer)
- **Files touched**: `scripts/notion_sync.py`
- **Change shape**: Add (a) `iso_week(date)` helper → `YYYY-Www` via `datetime.date.isocalendar()`; (b) `handoff_log_payload(slice) -> dict` reusing `read_slice`: `{date: today, iso_week, conclusion, decision_digest, evidence}` where `decision_digest` = count+short hash of decision slugs (detects decision-set change) and `evidence` = contract_pointer basenames + any SLURM-id tokens (`\b5\d{3}\b` / `SLURM \d+`) found in the conclusion; (c) pure `gate_should_write(prev_entry_text, payload) -> bool` → True iff the payload's conclusion OR decision_digest is absent-from / differs-from `prev_entry_text`. Wire a `--handoff-log --slice X` CLI mode that prints the payload JSON. NO Notion/network calls.
- **Verification**: `/home/ubuntu/miniconda3/bin/python scripts/notion_sync.py --handoff-log --slice fragmap` → JSON with `iso_week` like `2026-W22`, non-empty `conclusion`, `decision_digest`, `evidence`; zero network.
- **Estimated time**: 5 min
- **Rollback (if this task only)**: `git checkout scripts/notion_sync.py`

## Task 2: Gate + payload test

- **Status**: done (2026-05-27, commit 7d9c7d5; code-review APPROVE, 7 passed)
- **Prereq tasks**: 1
- **Files touched**: `tests/test_notion_handoff_log.py` (new)
- **Change shape**: pytest. (a) `iso_week` returns `YYYY-Www` for a known date. (b) `gate_should_write`: identical conclusion+digest in prev_entry → False (SKIP); changed conclusion → True; changed decision_digest only → True; empty prev → True. (c) `handoff_log_payload` against a tmp fixture (monkeypatch REPO_ROOT) → expected keys + evidence extraction (SLURM id picked up).
- **Verification**: `/home/ubuntu/miniconda3/bin/python -m pytest tests/test_notion_handoff_log.py -q` → all pass.
- **Estimated time**: 4 min
- **Rollback (if this task only)**: `rm tests/test_notion_handoff_log.py`

## Task 3: Runbook — weekly-digest entry routine + gate

- **Status**: done (2026-05-27, commits 8e2a9bb + ec6a5e3; code-review APPROVE. updated to mangle-proof chg-digest gate after T6 finding)
- **Prereq tasks**: 1
- **Files touched**: `docs/notion-sync-runbook.md`
- **Change shape**: Add a "## Handoff lab-log (weekly digest)" section: for slice X — (1) overwrite the hub `〔sync〕` callout (existing v1 routine); (2) `notion-search` Reports for Title `X <YYYY-Www> Weekly Digest`; create if absent (Report Type=Weekly Digest, Project, Slice=X, Date=ISO-week Monday); (3) read the row's latest dated bullet, run `gate_should_write`; if WRITE → `update_content` today's bullet (`<MM-DD> — <conclusion> (<evidence>)`) or insert it; if SKIP → only the callout was refreshed. Document the embedded `· dd:<n>` digest suffix used by the gate, and the NON-BLOCKING rule.
- **Verification**: `grep -q 'Handoff lab-log' docs/notion-sync-runbook.md && grep -q 'Weekly Digest' docs/notion-sync-runbook.md`.
- **Estimated time**: 4 min
- **Rollback (if this task only)**: `git checkout docs/notion-sync-runbook.md`

## Task 4: Wire lab-log step into the /handoff skill

- **Status**: done (2026-05-27, commit d1f7165; code-review APPROVE, skill-lint 14/14. allowed-tools widening blocked by classifier (non-essential, prompts at runtime instead) — body Step 5 landed)
- **Prereq tasks**: 3
- **Files touched**: `.claude/skills/handoff/SKILL.md`
- **Change shape**: Add a final "## Step 5 — Notion lab-log (best-effort)" step: after writing the slice status + `handoff.sh`, the agent runs the runbook's handoff lab-log routine for the active slice via the Notion MCP. Explicit: **non-blocking** — if the MCP is unavailable or errors, emit a one-line warning and finish the handoff anyway (never raise/block). Note scope: Claude only (Codex mirror separate). (Self-modification of agent config — user-authorized.)
- **Verification**: `grep -q 'Notion lab-log' .claude/skills/handoff/SKILL.md && grep -qi 'non-blocking\|best-effort' .claude/skills/handoff/SKILL.md`; `bash tests/run-skill-lint.sh` → 14/14 (or 14+) PASS.
- **Estimated time**: 4 min
- **Rollback (if this task only)**: `git checkout .claude/skills/handoff/SKILL.md`

## Task 5: EXECUTE live — harness slice weekly digest (create + entry)

- **Status**: done (2026-05-27; live MCP. Created "harness 2026-W22 Weekly Digest" Report row (Project=Harness/Agent Ops, Slice=harness, Date=2026-05-25) + 05-27 bullet with conclusion + evidence + chg:13:6e755196; fetch-verified)
- **Prereq tasks**: 1, 3
- **Files touched**: none (Notion writes via MCP; agent-executed)
- **Change shape**: Run the handoff lab-log routine for the `harness` slice: `--handoff-log --slice harness` → create the `harness <YYYY-Www> Weekly Digest` Report row (Project=Harness/Agent Ops, Slice=harness) + today's dated entry (conclusion + evidence); confirm the hub callout is current.
- **Verification**: `notion-fetch` the new weekly row → Title matches, Report Type=Weekly Digest, body has today's `MM-DD —` entry with the harness conclusion.
- **Estimated time**: 5 min
- **Rollback (if this task only)**: manually trash the created weekly Report row in Notion

## Task 6: Idempotency + gate check (live)

- **Status**: done (2026-05-27; PROVEN. gate(read-back bullet, harness payload) → False (idempotent SKIP); stale-digest → True (WRITE). Surfaced + fixed the read-back-mangling bug → mangle-proof chg-digest gate, commit 5ed5c36)
- **Prereq tasks**: 5
- **Files touched**: none (verification)
- **Change shape**: Re-run the harness lab-log with NO conclusion change → assert the weekly row is unchanged (today's entry not duplicated, no new bullet); then (optional) simulate a changed conclusion → assert a new/updated bullet. Confirms the gate + idempotency Done-When #3/#4.
- **Verification**: `notion-fetch` weekly row before/after the no-change re-run → identical entry count; (changed case) one updated/added bullet.
- **Estimated time**: 4 min
- **Rollback (if this task only)**: n/a (verification)

## Task 7: Finalize

- **Status**: done (2026-05-27; contract+plan done, harness baton updated, handoff+index)
- **Prereq tasks**: 2, 4, 6
- **Files touched**: `.agent/status/harness.md`, `.agent/contracts/harness-notion-handoff-log-20260527.md`, `.agent/plans/harness-notion-handoff-log-20260527.md`
- **Change shape**: Set contract + plan `status: done` + Notes. Update harness baton (lab-log live; per-handoff change-gated weekly digest). Run `handoff.sh claude harness` + `status.sh index`.
- **Verification**: contract+plan frontmatter `status: done`; `grep -q 'lab-log\|handoff-log' .agent/status/harness.md`; `bash tests/run-notion-handoff-log` style tests still pass.
- **Estimated time**: 5 min
- **Rollback (if this task only)**: `git checkout` the three files
