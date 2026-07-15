#!/usr/bin/env python3
"""Notion sync CLI (skeleton).

Syncs per-slice status into Notion hub pages. This task provides only the
skeleton: argparse, mapping load, and an --check-env preflight. No Notion
API/network calls are made here; real sync logic lands in later tasks.

The token is read from the NOTION_TOKEN environment variable only. The cron
wrapper sources .agent/.secrets/notion.env; this script never reads that file
directly.
"""

from __future__ import annotations

import argparse
import datetime
import glob
import hashlib
import json
import os
import re
import subprocess
import sys
from pathlib import Path

import yaml


# Repo root is two levels up from this file (<repo>/scripts/notion_sync.py),
# resolved from the script location so it works from any CWD.
def _resolve_repo_root() -> Path:
    """Repo root for all .agent reads/writes. Honors NOTION_SYNC_REPO_ROOT
    (so a bash caller — handoff.sh, hooks, tests — can point this process at a
    throwaway .agent fixture); defaults to the repo two levels up from this file."""
    override = os.environ.get("NOTION_SYNC_REPO_ROOT")
    if override:
        return Path(override).resolve()
    return Path(__file__).resolve().parent.parent


REPO_ROOT = _resolve_repo_root()
NOTION_MAP_PATH = REPO_ROOT / ".agent" / "notion_map.yaml"


def load_map(path: Path = NOTION_MAP_PATH) -> dict:
    """Load the Notion mapping YAML."""
    with path.open("r", encoding="utf-8") as fh:
        return yaml.safe_load(fh)


def _parse_frontmatter(path: Path) -> dict | None:
    """Parse the YAML frontmatter (block between the first two `---` lines).

    Returns the parsed dict, or None if the file is unreadable or has no
    frontmatter.
    """
    try:
        text = path.read_text(encoding="utf-8")
    except OSError as exc:
        print(f"warning: cannot read {path}: {exc}", file=sys.stderr)
        return None

    lines = text.splitlines()
    if not lines or lines[0].strip() != "---":
        return None
    # Find the closing `---` after the opening one.
    end = None
    for i in range(1, len(lines)):
        if lines[i].strip() == "---":
            end = i
            break
    if end is None:
        return None

    block = "\n".join(lines[1:end])
    try:
        data = yaml.safe_load(block)
    except yaml.YAMLError as exc:
        # Tolerant fallback: a baton with quote/colon-rich list items can break
        # strict YAML (e.g. a single-quoted item whose embedded apostrophe closes
        # the quote early). The line-oriented regex extractor recovers the fields
        # so the slice still populates its Notion row. Keep the warning visible.
        print(f"warning: bad frontmatter YAML in {path}: {exc}", file=sys.stderr)
        recovered = _regex_extract_frontmatter(lines[1:end])
        return recovered or None
    return data if isinstance(data, dict) else None


def _classify_status(text: str) -> str:
    """Best-effort map a decision string to a Decision Status select value.

    Default "Decided". Leading/embedded markers steer the result:
    ✅ / DECIDED → Decided, HELD / defer → Deferred, OPEN → Open.
    """
    upper = text.upper()
    if "✅" in text or "DECIDED" in upper:
        return "Decided"
    if "HELD" in upper or "DEFER" in upper:
        return "Deferred"
    if "OPEN" in upper:
        return "Open"
    return "Decided"


def read_slice(slice_name: str) -> dict:
    """Parse a slice's status frontmatter + linked contract decisions.

    Returns a dict with keys: slice, conclusion, remaining_actions,
    last_updated, owner_agent, decisions. Robust to missing files / absent
    frontmatter (returns empty fields + stderr warning, never crashes).
    """
    empty = {
        "slice": slice_name,
        "conclusion": "",
        "remaining_actions": [],
        "last_updated": "",
        "owner_agent": "",
        "decisions": [],
    }

    status_path = REPO_ROOT / ".agent" / "status" / f"{slice_name}.md"
    if not status_path.exists():
        print(f"warning: status file not found: {status_path}", file=sys.stderr)
        return empty

    fm = _parse_frontmatter(status_path)
    if fm is None:
        print(f"warning: no frontmatter in {status_path}", file=sys.stderr)
        return empty

    remaining_actions = fm.get("remaining_actions") or []
    if not isinstance(remaining_actions, list):
        remaining_actions = []
    contract_pointers = fm.get("contract_pointers") or []
    if not isinstance(contract_pointers, list):
        contract_pointers = []

    conclusion = remaining_actions[0] if remaining_actions else ""

    decisions: list[dict] = []
    for pointer in contract_pointers:
        contract_path = (REPO_ROOT / pointer).resolve()
        if not contract_path.exists():
            print(f"warning: contract not found, skipping: {pointer}", file=sys.stderr)
            continue
        cfm = _parse_frontmatter(contract_path)
        if cfm is None:
            print(
                f"warning: no frontmatter in contract, skipping: {pointer}",
                file=sys.stderr,
            )
            continue
        contract_decisions = cfm.get("decisions") or []
        if not isinstance(contract_decisions, list):
            continue
        topic = cfm.get("topic") or contract_path.stem
        for i, decision in enumerate(contract_decisions):
            decision_text = str(decision)
            decisions.append(
                {
                    "slug": f"{slice_name}:{topic}:{i}",
                    "title": decision_text[:200],
                    "status": _classify_status(decision_text),
                    "contract": str(pointer),
                }
            )

    return {
        "slice": slice_name,
        "conclusion": conclusion,
        "remaining_actions": remaining_actions,
        "last_updated": str(fm.get("last_updated") or ""),
        "owner_agent": str(fm.get("owner_agent") or ""),
        "decisions": decisions,
    }


def iso_week(d: datetime.date | None = None) -> str:
    """ISO year-week like '2026-W22' from a date (default today)."""
    if d is None:
        d = datetime.date.today()
    year, week, _ = d.isocalendar()
    return f"{year}-W{week:02d}"


def classify_event(conclusion: str) -> dict:
    """Classify a slice conclusion into one of 6 event types for Notion lab-log
    rendering. Priority-ordered keyword match (case-insensitive substring);
    first match wins. Default = 작업 (work-in-progress).
    See .agent/contracts/harness-v042-notion-report-format-20260529.md.
    """
    text = conclusion.lower()
    # Priority-ordered table: (event_type, emoji, color, keywords)
    table = [
        ("차단", "⚠️", "red_bg", ["blocker", "blocked", "차단", "fail", "stuck"]),
        (
            "출시",
            "🚀",
            "green_bg",
            ["shipped", "released", "ship", "tag v", "pr #", "merged"],
        ),
        ("수정", "🐛", "orange_bg", ["fixed", "fix", "bug", "수정", "hotfix"]),
        ("결정", "✅", "purple_bg", ["decided", "결정", "agreed on", "확정"]),
        (
            "설계",
            "📝",
            "gray_bg",
            ["contract", "approved", "planning", "spec", "drafted"],
        ),
        ("작업", "🛠", "blue_bg", []),  # default (no keywords — falls through)
    ]
    for event_type, emoji, color, keywords in table:
        for kw in keywords:
            if kw.lower() in text:
                return {
                    "event_type": event_type,
                    "event_emoji": emoji,
                    "event_color": color,
                }
    # Default fallthrough (last tuple has no keywords)
    last = table[-1]
    return {"event_type": last[0], "event_emoji": last[1], "event_color": last[2]}


_CONTRACT_STATUS_TO_ADR = {
    "pending": "Proposed",
    "approved": "Accepted",
    "done": "Implemented",
}


def _extract_frontmatter_block(text: str) -> list[str] | None:
    """Return the raw frontmatter lines (between the first two ``---`` sentinels)
    or None if the file has no frontmatter."""
    lines = text.splitlines()
    if not lines or lines[0].strip() != "---":
        return None
    for i in range(1, len(lines)):
        if lines[i].strip() == "---":
            return lines[1:i]
    return None


def _regex_extract_frontmatter(block_lines: list[str]) -> dict:
    """Best-effort regex extraction of top-level scalar fields + a ``decisions:``
    list from a YAML frontmatter block that may be too colon-rich for safe_load.

    Recognized:
      - top-level scalars (``key: value`` with no leading whitespace; surrounding
        quotes stripped),
      - ANY top-level ``key:`` with an empty value followed by ``  - <item>``
        block-sequence lines → a Python list (surrounding quotes stripped,
        deeper-indented continuation lines folded into the current item).
    The line-oriented ``- `` match is content-agnostic, so it survives the embedded
    quotes/colons that break ``yaml.safe_load``. Other nested structures are ignored.
    """
    out: dict = {}
    list_key: str | None = None  # top-level key currently collecting a sequence
    items: list[str] = []
    current: list[str] = []  # continuation buffer for the in-progress item

    def _unquote(v: str) -> str:
        v = v.strip()
        if len(v) >= 2 and v[0] == v[-1] and v[0] in "\"'":
            return v[1:-1]
        return v

    def _flush_item():
        if current:
            items.append(_unquote(" ".join(s.strip() for s in current).strip()))
            current.clear()

    def _flush_list():
        nonlocal list_key, items
        _flush_item()
        if list_key is not None and items:
            out[list_key] = list(items)
        list_key = None
        items = []

    for line in block_lines:
        # Top-level key (no leading whitespace).
        if not (line.startswith(" ") or line.startswith("\t")):
            m = re.match(r"^([A-Za-z_][A-Za-z0-9_]*):\s*(.*)$", line)
            if m:
                _flush_list()
                key, value = m.group(1), m.group(2).strip()
                out[key] = _unquote(value)
                if value == "":
                    list_key = key  # candidate sequence (filled if items follow)
                continue

        # Indented lines under an open list key.
        if list_key is not None:
            m = re.match(r"^\s+-\s+(.*)$", line)
            if m:
                _flush_item()
                current.append(m.group(1))
                continue
            if line.strip() == "":
                continue
            if current:  # deeper-indented continuation of the current item
                current.append(line.strip())
                continue

    _flush_list()
    return out


def _extract_purpose(text: str) -> str:
    """Return the body of the ``## Purpose`` section (up to the next ``## ``
    heading), trimmed and clipped to 500 chars. Returns "" if absent."""
    # Skip frontmatter so a top-level "---" doesn't confuse the section regex.
    lines = text.splitlines()
    if lines and lines[0].strip() == "---":
        for i in range(1, len(lines)):
            if lines[i].strip() == "---":
                body = "\n".join(lines[i + 1 :])
                break
        else:
            body = text
    else:
        body = text
    m = re.search(
        r"^##\s+Purpose\s*\n(.*?)(?=\n##\s+|\Z)", body, re.MULTILINE | re.DOTALL
    )
    if not m:
        return ""
    return m.group(1).strip()[:500]


def contract_to_adr_rows(contract_path: str) -> list[dict]:
    """Parse a .agent/contracts/<slice>-<topic>.md and return a list of ADR-row
    dicts (one per ``decisions:`` item) for Decisions DB seeding.

    Uses :func:`_parse_frontmatter` first; falls back to a regex extractor when
    the frontmatter contains colon-rich items that break safe_load (common in
    this repo). Each row has keys: ``title``, ``status``, ``slice``, ``date``,
    ``deciders``, ``context``, ``decision``, ``consequences``,
    ``linked_contract``, ``adr_id``.
    """
    path = Path(contract_path)
    if not path.is_absolute():
        path = (REPO_ROOT / contract_path).resolve()

    try:
        text = path.read_text(encoding="utf-8")
    except OSError as exc:
        print(f"warning: cannot read contract {path}: {exc}", file=sys.stderr)
        return []

    fm: dict = {}
    fm_parsed = _parse_frontmatter(path)
    if isinstance(fm_parsed, dict):
        fm = fm_parsed

    # Always try regex extraction for the decisions list (safe_load may have
    # silently dropped it on a parse failure, or returned a non-list value).
    block = _extract_frontmatter_block(text)
    regex_fm = _regex_extract_frontmatter(block) if block else {}

    # Use safe_load values where available, else regex values, else "".
    def _field(name: str, default: str = "") -> str:
        if name in fm and fm[name] not in (None, ""):
            return str(fm[name])
        if name in regex_fm and regex_fm[name] not in (None, ""):
            return str(regex_fm[name])
        return default

    decisions = fm.get("decisions") if isinstance(fm.get("decisions"), list) else None
    if not decisions:
        decisions = regex_fm.get("decisions") or []
    if not isinstance(decisions, list):
        decisions = []

    slice_name = _field("slice")
    topic = _field("topic") or path.stem
    contract_status = _field("status").strip().lower()
    adr_status = _CONTRACT_STATUS_TO_ADR.get(contract_status, "Proposed")
    date_field = _field("date") or datetime.date.today().isoformat()
    deciders = _field("owner") or _field("approved_by")
    context = _extract_purpose(text)

    # Relative path for linked_contract — relative to REPO_ROOT (/home/ubuntu).
    try:
        linked_contract = str(path.relative_to(REPO_ROOT))
    except ValueError:
        linked_contract = str(path)

    rows: list[dict] = []
    for idx, decision in enumerate(decisions, start=1):
        decision_text = str(decision).strip()
        if not decision_text:
            continue
        # Title: first 50 chars, ellipsized cleanly when truncated.
        if len(decision_text) > 50:
            title = decision_text[:47].rstrip() + "..."
        else:
            title = decision_text
        rows.append(
            {
                "title": title,
                "status": adr_status,
                "slice": slice_name,
                "date": date_field,
                "deciders": deciders,
                "context": context,
                "decision": decision_text,
                "consequences": "See linked contract",
                "linked_contract": linked_contract,
                "adr_id": f"ADR-{slice_name}-{topic}-{idx}",
            }
        )

    return rows


_SACCT_STATE_TO_STATUS = {
    "COMPLETED": "Completed",
    "RUNNING": "Running",
    "FAILED": "Failed",
    "CANCELLED": "Cancelled",
    "PENDING": "Queued",
    "TIMEOUT": "Failed",
    "NODE_FAIL": "Failed",
    "OUT_OF_MEMORY": "Failed",
}


def _infer_slice_from_job_name(job_name: str) -> str:
    """Map a SLURM job name to a slice name via prefix heuristics."""
    name = job_name.strip().lower()
    if not name:
        return ""
    if name.startswith(("norm143_", "norm143", "mmgbsa_", "custom_")):
        return "mmgbsa"
    if name.startswith(("fragmap_", "9nfr_")):
        return "fragmap"
    if name.startswith("vav1_"):
        return "vav1"
    return ""


def _infer_phase_from_job_name(job_name: str) -> str:
    """Best-effort: extract a phase label from the SLURM job name.

    Recognizes ``ab_stage<N>`` -> ``AB Stage <N>``; ``stage<N>`` -> ``Stage <N>``.
    Returns "" when no pattern matches.
    """
    if not job_name:
        return ""
    lower = job_name.lower()
    m = re.search(r"ab[_-]?stage[_-]?(\d+)", lower)
    if m:
        return f"AB Stage {m.group(1)}"
    m = re.search(r"stage[_-]?(\d+)", lower)
    if m:
        return f"Stage {m.group(1)}"
    return ""


def _find_mmgbsa_artifact_dir(job_name: str) -> str:
    """Best-effort glob match for an mmgbsa output dir whose basename contains
    a token from job_name. Returns the most-recently-modified match, or ""."""
    if not job_name:
        return ""
    base = "/mnt/data/users/ubuntu/mmgbsa_outputs"
    if not os.path.isdir(base):
        return ""
    # Token: strip trailing numerics/datetime, leave the descriptive prefix.
    token = re.split(r"[^A-Za-z0-9_]+", job_name)[0]
    if not token:
        return ""
    candidates = sorted(
        glob.glob(os.path.join(base, f"*{token}*")),
        key=lambda p: os.path.getmtime(p) if os.path.exists(p) else 0,
        reverse=True,
    )
    return candidates[0] if candidates else ""


def _extract_mmgbsa_metrics(artifact_dir: str) -> str:
    """Read ready_for_mmpbsa_prod.tsv (row count minus 1 = passed). Returns
    ``"pass_rate=<N>"`` or "" on any failure (file absent, unreadable, empty)."""
    if not artifact_dir:
        return ""
    tsv = os.path.join(artifact_dir, "ready_for_mmpbsa_prod.tsv")
    if not os.path.isfile(tsv):
        return ""
    try:
        with open(tsv, "r", encoding="utf-8", errors="replace") as fh:
            n_lines = sum(1 for _ in fh)
    except OSError:
        return ""
    passed = max(0, n_lines - 1)
    return f"pass_rate={passed}"


def slurm_to_experiment_row(job_id: int) -> dict:
    """Query SLURM sacct for job_id, return an Experiments DB row dict.

    Returns a dict with both lowercase keys (run_id/slice/status/start/end/
    duration/exit/metrics/artifacts) used by tests/internal code, AND
    capitalized Notion-DB-column keys (Run ID / Slice / Phase / Status /
    Start / End / Duration / Exit Code / Parameters / Metrics /
    Artifact Path) for the Experiments DB row payload. Robust to missing
    jobs: returns the same shape with empty fields on any sacct / parse
    failure. v0.5 — see .agent/contracts/harness-notion-redesign-20260529.md
    (Task 13).
    """
    # Skeleton with empty defaults — populated below as fields become available.
    out: dict = {
        # Lowercase keys (used by tests + internal callers).
        "run_id": str(job_id),
        "slice": "",
        "status": "",
        "start": "",
        "end": "",
        "duration": "",
        "exit": "",
        "metrics": "",
        "artifacts": "",
        # Capitalized Notion DB column keys.
        "Run ID": str(job_id),
        "Slice": "",
        "Phase": "",
        "Status": "",
        "Start": "",
        "End": "",
        "Duration": "",
        "Exit Code": "",
        "Parameters": "",
        "Metrics": "",
        "Artifact Path": "",
    }

    try:
        proc = subprocess.run(
            [
                "sacct",
                "-j",
                str(job_id),
                "--format=JobID,State,Start,End,Elapsed,ExitCode,JobName",
                "-n",
                "-P",
            ],
            capture_output=True,
            text=True,
            timeout=30,
            check=False,
        )
    except (FileNotFoundError, subprocess.TimeoutExpired) as exc:
        print(f"warning: sacct unavailable for job {job_id}: {exc}", file=sys.stderr)
        return out

    if proc.returncode != 0:
        print(
            f"warning: sacct returned {proc.returncode} for job {job_id}: "
            f"{proc.stderr.strip()}",
            file=sys.stderr,
        )
        return out

    # Parse pipe-delimited rows; pick the row whose JobID == str(job_id) exactly
    # (skip sub-steps like 5754.batch, 5754.0).
    target = str(job_id)
    main_row: list[str] | None = None
    for line in proc.stdout.splitlines():
        line = line.strip()
        if not line:
            continue
        parts = line.split("|")
        if not parts:
            continue
        if parts[0] == target:
            main_row = parts
            break

    if main_row is None or len(main_row) < 7:
        return out

    _, state, start, end, elapsed, exit_code, job_name = main_row[:7]
    # Normalize sacct state — leading word before any "+" or " by" suffix.
    state_norm = state.strip().split()[0].split("+")[0].upper()
    status_label = _SACCT_STATE_TO_STATUS.get(state_norm, "")

    # End may be "Unknown" while a job is running — normalize to "".
    end_clean = "" if end.strip().lower() in ("unknown", "") else end.strip()

    slice_name = _infer_slice_from_job_name(job_name)
    phase = _infer_phase_from_job_name(job_name)

    artifact_dir = ""
    metrics = ""
    if slice_name == "mmgbsa":
        artifact_dir = _find_mmgbsa_artifact_dir(job_name)
        metrics = _extract_mmgbsa_metrics(artifact_dir)

    # Populate both key spellings.
    out["slice"] = slice_name
    out["status"] = status_label
    out["start"] = start.strip()
    out["end"] = end_clean
    out["duration"] = elapsed.strip()
    out["exit"] = exit_code.strip()
    out["metrics"] = metrics
    out["artifacts"] = artifact_dir

    out["Slice"] = slice_name
    out["Phase"] = phase
    out["Status"] = status_label
    out["Start"] = start.strip()
    out["End"] = end_clean
    out["Duration"] = elapsed.strip()
    out["Exit Code"] = exit_code.strip()
    out["Metrics"] = metrics
    out["Artifact Path"] = artifact_dir

    return out


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
    lowered = raw.lower()
    if "승인" in raw or "approve" in lowered or "decision" in lowered:
        return "decision", raw
    if "blocked" in lowered or "pending" in lowered or "대기" in raw:
        return "blocker", raw
    return "agent", raw


def _truncate_field(text: str, limit: int = 160) -> str:
    cleaned = " ".join(str(text or "").split())
    if len(cleaned) <= limit:
        return cleaned
    return cleaned[: limit - 1].rstrip() + "…"


def _is_done_line(text: str) -> bool:
    """A completed-work note, not a queue item: leading ✅, or a leading
    DONE/SHIPPED/CLOSED/완료 **word**. Word-boundary anchored so a genuine
    next-action is not dropped — e.g. "closedown the cluster" or the Korean
    "완료되지 않음" (= *not* done) must NOT count as done."""
    raw = str(text or "").strip()
    if raw.startswith("✅"):
        return True
    if re.match(r"^(DONE|SHIPPED|CLOSED)\b", raw, re.IGNORECASE):
        return True
    # 완료 only when it stands alone (followed by space/punctuation/end), so
    # "완료되지 않음" (다른 동사 어간이 붙은 경우) is not misread as done.
    if re.match(r"^완료(?:[\s:·.\-—)\]]|$)", raw):
        return True
    return False


def _action_queue_fields(slice_name: str, fm: dict) -> dict:
    actions = fm.get("remaining_actions") or []
    if not isinstance(actions, list):
        actions = []

    decision = ""
    agent_next = ""
    blocker = ""
    fallback = ""
    first_item = ""  # for the all-done fallback (slice must stay represented)

    for action in actions:
        kind, cleaned = _clean_action_marker(str(action))
        cleaned = _truncate_field(cleaned)
        if not first_item and cleaned:
            first_item = cleaned
        if _is_done_line(action):
            continue  # completed note, not live queue work
        if not fallback and cleaned:
            fallback = cleaned
        if kind == "decision" and not decision:
            decision = cleaned
        elif kind == "agent" and not agent_next:
            agent_next = cleaned
        elif kind == "blocker" and not blocker:
            blocker = cleaned

    if not agent_next:
        agent_next = fallback
    # Every item was a done line → still represent the slice with its first item.
    if not (decision or agent_next or blocker):
        agent_next = first_item

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


def slice_to_db_row(slice_name: str) -> dict:
    """Read .agent/status/<slice>.md frontmatter and return a Slices DB row
    dict (Name/Status/Owner/Heartbeat/Project/Next Action).
    v0.5 — see .agent/contracts/harness-notion-redesign-20260529.md (Task 8).

    Returns a SEMANTIC dict mapping Notion Slices DB column names to values.
    Translation to Notion API payload (expanded date keys, select shapes, etc.)
    happens in a later migrate wrapper (Task 23). Missing/absent fields default
    to "" except Status which defaults to "활성".
    """
    # state → Status enum mapping (Korean labels per Slices DB SELECT options).
    _STATE_TO_STATUS = {
        "active": "활성",
        "closed": "완료",
        "released": "릴리즈",
        "dormant": "휴면",
    }
    # slice name → Project enum mapping (Notion SELECT options on Slices DB).
    _HARNESS_PROJECT = "Harness / Agent Ops"
    _AIGENFOLD_PROJECT = "AIGEN-Fold"
    _SLICE_TO_PROJECT = {
        "harness": _HARNESS_PROJECT,
        "fea": _HARNESS_PROJECT,
        "fragmap": _AIGENFOLD_PROJECT,
        "mmgbsa": _AIGENFOLD_PROJECT,
        "vav1": _AIGENFOLD_PROJECT,
        "aigen-fold-core": _AIGENFOLD_PROJECT,
    }

    status_path = REPO_ROOT / ".agent" / "status" / f"{slice_name}.md"
    fm = _parse_frontmatter(status_path) if status_path.exists() else None
    if fm is None:
        fm = {}

    state = str(fm.get("state") or "").strip().lower()
    status = _STATE_TO_STATUS.get(state, "활성")

    owner_agent = str(fm.get("owner_agent") or "").strip()
    owner_session = str(fm.get("owner_session") or "").strip()
    # Released slices: owner fields may be empty — return "" (default already).

    heartbeat = str(fm.get("heartbeat") or "").strip()
    last_updated = str(fm.get("last_updated") or "").strip()

    remaining_actions = fm.get("remaining_actions") or []
    if not isinstance(remaining_actions, list):
        remaining_actions = []
    next_action = str(remaining_actions[0]) if remaining_actions else ""
    if len(next_action) > 500:
        next_action = next_action[:500]

    project = _SLICE_TO_PROJECT.get(slice_name, _AIGENFOLD_PROJECT)
    queue_fields = _action_queue_fields(slice_name, fm)
    sync_status = "Fresh" if heartbeat else "Stale"

    return {
        "Name": slice_name,
        "Status": status,
        **queue_fields,
        "Owner Agent": owner_agent,
        "Owner Session": owner_session,
        "Last Heartbeat": heartbeat,
        "Last Updated": last_updated,
        "Project": project,
        "Next Action": next_action,
        "Health": sync_status,
        "Sync Status": sync_status,
        "Last Sync Source": f".agent/status/{slice_name}.md",
        "State Body": "",
    }


# Trailing -YYYYMMDD date stamp on contract/plan filenames (e.g.
# harness-notion-redesign-20260529.md). Used to compute the "last 7d" window.
_FILENAME_DATE_RE = re.compile(r"-(\d{8})(?:\.[^.]+)?$")


def _filename_date(path: Path) -> datetime.date | None:
    """Parse a trailing ``-YYYYMMDD`` stamp from a filename into a date, falling
    back to the file mtime. Returns None if neither is available."""
    m = _FILENAME_DATE_RE.search(path.name)
    if m:
        try:
            return datetime.datetime.strptime(m.group(1), "%Y%m%d").date()
        except ValueError:
            pass
    try:
        return datetime.date.fromtimestamp(path.stat().st_mtime)
    except OSError:
        return None


def _frontmatter_status(path: Path) -> tuple[dict, str]:
    """Classify a status file's frontmatter parse health for the audit:
    "OK" (strict YAML), "Regex fallback" (strict YAML failed but the tolerant
    extractor recovered fields), "Parser warning" (neither), or "Missing".

    Unlike :func:`_parse_frontmatter` (which silently falls back to regex), this
    detects the strict-vs-fallback path on its own so the audit can SURFACE a
    non-strict baton instead of hiding it behind a successful fallback.
    """
    if not path.exists():
        return {}, "Missing"
    try:
        text = path.read_text(encoding="utf-8")
    except OSError:
        return {}, "Parser warning"
    block_lines = _extract_frontmatter_block(text)
    if block_lines is None:
        return {}, "Parser warning"
    try:
        data = yaml.safe_load("\n".join(block_lines))
        if isinstance(data, dict):
            return data, "OK"
    except yaml.YAMLError:
        pass
    recovered = _regex_extract_frontmatter(block_lines)
    if recovered:
        return recovered, "Regex fallback"
    return {}, "Parser warning"


def _slice_sync_status(slice_name: str) -> dict:
    path = REPO_ROOT / ".agent" / "status" / f"{slice_name}.md"
    fm, parse_status = _frontmatter_status(path)
    if parse_status in ("Parser warning", "Missing"):
        return {
            "slice": slice_name,
            "status": parse_status,
            "detail": f"frontmatter could not be parsed: {path.relative_to(REPO_ROOT)}",
        }
    if parse_status == "Regex fallback":
        # Fields were recovered, but the baton is not strict YAML — surface it
        # (the row still populates via the same fallback in _parse_frontmatter).
        return {
            "slice": slice_name,
            "status": "Regex fallback",
            "detail": "frontmatter recovered via regex fallback (not strict YAML); tighten the baton",
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


_ACTION_PREFIX_RE = re.compile(r"^(DECISION|AGENT|BLOCKED):")


def lint_baton(slice_name: str) -> list[str]:
    """Lint a single slice's status baton, returning human-readable issue
    strings (empty list = clean). Never raises — file/parse problems are
    reported as issues, consistent with the module's robust style.

    Checks:
      * frontmatter parse health (must be strict-YAML "OK");
      * ``remaining_actions`` must not LEAD with a done-line;
      * every non-done ``remaining_actions`` item must carry a
        ``DECISION:`` / ``AGENT:`` / ``BLOCKED:`` prefix.
    """
    path = REPO_ROOT / ".agent" / "status" / f"{slice_name}.md"
    if not path.exists():
        return ["frontmatter: status file missing"]

    issues: list[str] = []
    fm, status = _frontmatter_status(path)
    if status != "OK":
        issues.append(f"frontmatter: {status}")

    actions = fm.get("remaining_actions")
    if isinstance(actions, list):
        for idx, action in enumerate(actions):
            item = str(action or "")
            if _is_done_line(item):
                if idx == 0:
                    issues.append(
                        "remaining_actions leads with a done-line; "
                        "lead with the real next action"
                    )
                continue
            if not _ACTION_PREFIX_RE.match(item.strip()):
                issues.append(f"missing DECISION:/AGENT:/BLOCKED: prefix: {item[:50]}")
    return issues


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
            "slices_checked": len(
                [p for p in status_dir.glob("*.md") if p.stem != "README"]
            ),
            "findings": len(findings),
        },
        "findings": findings,
    }


def _active_slice_names() -> list[str]:
    """Slice names whose .agent/status/<slice>.md has ``state: active`` OR no
    ``state`` field at all. README.md is skipped. Sorted for determinism."""
    status_dir = REPO_ROOT / ".agent" / "status"
    names: list[str] = []
    for path in sorted(status_dir.glob("*.md")):
        if path.stem == "README":
            continue
        fm = _parse_frontmatter(path) or {}
        state = str(fm.get("state") or "").strip().lower()
        if state in ("", "active"):
            names.append(path.stem)
    return names


def _running_slurm_ids() -> list[int]:
    """Active (running/pending) SLURM job ids for the current user via squeue.
    Robust: returns [] if squeue is unavailable, errors, or returns nothing."""
    try:
        proc = subprocess.run(
            ["squeue", "-h", "-u", os.environ.get("USER", ""), "-o", "%i"],
            capture_output=True,
            text=True,
            timeout=30,
            check=False,
        )
    except (FileNotFoundError, subprocess.TimeoutExpired, OSError) as exc:
        print(f"warning: squeue unavailable: {exc}", file=sys.stderr)
        return []
    if proc.returncode != 0:
        return []
    ids: list[int] = []
    for line in proc.stdout.splitlines():
        token = line.strip().split(".", 1)[0]  # drop array/step suffix
        if token.isdigit():
            ids.append(int(token))
    return ids


def _history_slurm_ids(since_days: int = 30) -> list[int]:
    """Historical SLURM job ids in the last ``since_days`` via sacct, mirroring
    plan Task 14 (``sacct -S <start> -E now --format=JobID -P -n``). Robust:
    sacct unavailable/error/empty -> []. Numeric ids only (drop .batch/.extern
    steps and array suffixes that aren't plain ints), deduped in order."""
    start = (datetime.date.today() - datetime.timedelta(days=since_days)).isoformat()
    try:
        proc = subprocess.run(
            ["sacct", "-S", start, "-E", "now", "--format=JobID", "-P", "-n"],
            capture_output=True,
            text=True,
            timeout=30,
            check=False,
        )
    except (FileNotFoundError, subprocess.TimeoutExpired, OSError) as exc:
        print(f"warning: sacct unavailable: {exc}", file=sys.stderr)
        return []
    if proc.returncode != 0:
        return []
    ids: list[int] = []
    seen: set[int] = set()
    for line in proc.stdout.splitlines():
        token = line.strip().split(".", 1)[0]  # drop array/step suffix
        if token.isdigit():
            job_id = int(token)
            if job_id not in seen:
                seen.add(job_id)
                ids.append(job_id)
    return ids


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


def home_navigator_payload() -> dict:
    """Compute the 5-section Navigator payload for the Notion home page:
    {active_slices, recent_decisions, running_experiments, recent_reports, docs}.
    v0.5 — see .agent/contracts/harness-notion-redesign-20260529.md (Task 17).

    Each section is a list. Robust by construction: an unavailable ``squeue`` /
    ``sacct`` yields an empty ``running_experiments`` list rather than raising.
    Reuses :func:`slice_to_db_row`, :func:`contract_to_adr_rows`, and
    :func:`slurm_to_experiment_row` rather than re-implementing their logic.
    """
    today = datetime.date.today()
    cutoff = today - datetime.timedelta(days=7)
    contracts_dir = REPO_ROOT / ".agent" / "contracts"
    plans_dir = REPO_ROOT / ".agent" / "plans"

    # 1. Active slices — one Slices DB row per active (or stateless) slice.
    active_slices = [slice_to_db_row(name) for name in _active_slice_names()]

    # 1b. Action queues — split active-slice work into human-decision vs
    #     agent-execution (vs blockers) for the Navigator first viewport.
    action_queues = _home_action_queues(active_slices)

    # 2. Recent decisions — ADR rows from contracts dated within the last 7d.
    recent_decisions: list[dict] = []
    for path in sorted(contracts_dir.glob("*.md")):
        if path.stem.startswith("_"):  # skip _template.md
            continue
        dt = _filename_date(path)
        if dt is None or dt < cutoff:
            continue
        recent_decisions.extend(contract_to_adr_rows(str(path)))

    # 3. Running experiments — one Experiments DB row per live SLURM job.
    running_experiments = [
        slurm_to_experiment_row(job_id) for job_id in _running_slurm_ids()
    ]

    # 4. Recent reports — contract + plan paths (relative to REPO_ROOT) from
    #    the last 7d.
    recent_reports: list[dict] = []
    for base_dir in (contracts_dir, plans_dir):
        for path in sorted(base_dir.glob("*.md")):
            if path.stem.startswith("_") or path.stem == "README":
                continue
            dt = _filename_date(path)
            if dt is None or dt < cutoff:
                continue
            recent_reports.append(
                {
                    "name": path.name,
                    "path": str(path.relative_to(REPO_ROOT)),
                    "date": dt.isoformat(),
                }
            )

    # 5. Docs — fixed top-level entry points.
    docs = [
        {"name": "AGENTS.md", "path": "AGENTS.md"},
        {"name": "CLAUDE.md", "path": "CLAUDE.md"},
        {"name": "WORKFLOW.md", "path": "WORKFLOW.md"},
    ]

    return {
        "action_queues": action_queues,
        "active_slices": active_slices,
        "recent_decisions": recent_decisions,
        "running_experiments": running_experiments,
        "recent_reports": recent_reports,
        "docs": docs,
    }


_HOME_PRESERVE_RE = re.compile(r'<(?:page|database)\s+url="([^"]+)"')


def _home_preserved_urls(text: str) -> set[str]:
    """The set of <page>/<database> URLs in a home/tail body — the child pages and
    inline DB views that a ``replace_content`` MUST carry forward or it deletes them."""
    return set(_HOME_PRESERVE_RE.findall(text))


def assert_home_preserves(body: str, tail_text: str) -> list[str]:
    """Return the <page>/<database> URLs present in the tail template but MISSING
    from the rendered body (empty list = safe to replace_content). The render-home
    CLI refuses to emit a body that would drop any child page or database."""
    return sorted(u for u in _home_preserved_urls(tail_text) if u not in body)


def _git_short_rev() -> str:
    """Short HEAD rev of the repo for the freshness stamp. Defensive: any
    failure (git missing, not a repo, timeout, non-zero) falls back to "?"."""
    try:
        proc = subprocess.run(
            ["git", "rev-parse", "--short", "HEAD"],
            cwd=REPO_ROOT,
            capture_output=True,
            text=True,
            timeout=30,
            check=False,
        )
    except (FileNotFoundError, subprocess.TimeoutExpired, OSError):
        return "?"
    if proc.returncode != 0:
        return "?"
    return proc.stdout.strip() or "?"


def _sync_pending_path() -> Path:
    """Path to the notion-sync-pending marker (handoff.sh drops it; the hooks
    read it; --stamp-home-applied clears it)."""
    return REPO_ROOT / ".agent" / "handoffs" / "state" / "notion-sync-pending"


def write_home_stamp() -> int:
    """Write ``.agent/handoffs/state/home-render.stamp`` recording WHEN the home
    was last applied to Notion (rev + ISO-8601 UTC timestamp). A later Stop-hook
    reads it to detect "a baton changed since the last home apply". Idempotent:
    overwrites the file (exactly two lines) on each call."""
    state_dir = REPO_ROOT / ".agent" / "handoffs" / "state"
    state_dir.mkdir(parents=True, exist_ok=True)
    rev = _git_short_rev()
    applied = datetime.datetime.now(datetime.timezone.utc).strftime(
        "%Y-%m-%dT%H:%M:%SZ"
    )
    (state_dir / "home-render.stamp").write_text(
        f"rev: {rev}\napplied: {applied}\n", encoding="utf-8"
    )
    _sync_pending_path().unlink(missing_ok=True)
    return 0


def render_home() -> str:
    """Render the full Notion-flavored-markdown home body from the live payload
    (dynamic Mission-Control cockpit) + the verbatim static tail template, so the
    Navigator home is REGENERATED (Task-18) instead of hand-edited and never drifts.

    Cockpit = 🛰️ header + gray metrics line + three full-width stacked gray callout
    cards (🙋 Decisions first, then 🤖 Agent queue, then 🩺 sync-health strip); then
    ``---`` then the verbatim contents of ``.agent/notion_home_tail.md`` (which carries
    the inline DB views + child-page links, so a downstream ``replace_content`` keeps them).
    """
    nav = home_navigator_payload()
    audit = notion_audit_payload()
    queues = nav.get("action_queues", {})
    decisions = queues.get("human_decisions", [])
    agents = queues.get("agent_execution", [])
    blockers = queues.get("blockers", [])

    def _dedupe_live(items):
        """Drop done-lines (a slice whose remaining_actions are ALL done reaches
        here only via _action_queue_fields' all-done fallback) and cap at one
        live item per slice, keeping the first."""
        seen = set()
        out = []
        for it in items:
            if _is_done_line(it.get("text", "")):
                continue
            s = it.get("slice", "")
            if s in seen:
                continue
            seen.add(s)
            out.append(it)
        return out

    decisions = _dedupe_live(decisions)
    agents = _dedupe_live(agents)

    status_by_slice = {f["slice"]: f["status"] for f in audit.get("findings", [])}
    active = [row.get("Name", "") for row in nav.get("active_slices", [])]
    stale = [n for n in active if status_by_slice.get(n) == "Stale"]
    soft = [
        n
        for n in active
        if status_by_slice.get(n) in ("Regex fallback", "Parser warning")
    ]
    fresh = [n for n in active if n not in stale and n not in soft]
    running = len(nav.get("running_experiments", []))
    n_findings = len(audit.get("findings", []))
    n_checked = audit.get("summary", {}).get("slices_checked", len(active))

    def _short(text: str, limit: int = 90) -> str:
        # anti-AI 문체(AGENTS.md §출력 문체): em-dash는 표시 시 제거(의미 보존, baton 원본 불변).
        t = " ".join(str(text or "").replace("—", " ").split())
        return t if len(t) <= limit else t[: limit - 1].rstrip() + "…"

    def _agent_chip(text: str) -> str:
        up = str(text or "").upper()
        return "RUNNING" if ("RUNNING" in up or "IN FLIGHT" in up) else "대기"

    def _names(ns: list[str]) -> str:
        return " · ".join(ns) if ns else "없음"

    dec_lines = [
        f"\t\t\t- **{d['slice']}**: {_short(d['text'])}" for d in decisions
    ] or ["\t\t\t- 없음"]
    agt_lines = []
    for a in agents:
        run = " (running)" if _agent_chip(a["text"]) == "RUNNING" else ""
        agt_lines.append(f"\t\t\t- **{a['slice']}**{run}: {_short(a['text'])}")
    if not agt_lines:
        agt_lines = ["\t\t\t- 없음"]

    health_rows = [
        f"<tr><td>fresh</td><td>{_names(fresh)}</td></tr>",
        f"<tr><td>unclaimed</td><td>{_names(stale)}</td></tr>",
    ]
    if soft:
        health_rows.append(f"<tr><td>regex-fallback</td><td>{_names(soft)}</td></tr>")

    cockpit = "\n".join(
        [
            "**Research Lab · Mission Control**",
            (
                '<span color="gray">.agent/status 파생 · read-only · '
                f"렌더 {datetime.date.today().isoformat()} · baton {_git_short_rev()}</span>"
            ),
            (
                f'<span color="gray">active {len(fresh)} · running {running} · '
                f"unclaimed {len(stale)} · blockers {len(blockers)} · "
                f"findings {n_findings}</span>"
            ),
            "<columns>",
            "\t<column>",
            '\t\t<callout color="red_bg">',
            "\t\t\t**결정 필요**",
            *dec_lines,
            "\t\t</callout>",
            "\t</column>",
            "\t<column>",
            '\t\t<callout color="blue_bg">',
            "\t\t\t**에이전트 큐**",
            *agt_lines,
            "\t\t</callout>",
            "\t</column>",
            "</columns>",
            "**동기화 상태**",
            '<table fit-page-width="true" header-row="false">',
            *health_rows,
            "</table>",
            (
                f'<span color="gray">{n_checked} slices · '
                "재확인 `python scripts/notion_sync.py --audit`</span>"
            ),
        ]
    )

    tail = (REPO_ROOT / ".agent" / "notion_home_tail.md").read_text(encoding="utf-8")
    return cockpit + "\n---\n" + tail.rstrip("\n") + "\n"


def render_project_hub(slug: str) -> str:
    """Render a project-hub body (block style) from its template + live slice batons.

    Editorial content lives in the version-controlled template
    (``v0_5.project_hubs.<slug>.template``); the ``{{SLICES}}`` marker is filled from
    the listed slices' current batons and ``{{DATE}}`` from today, so the hub
    REGENERATES from repo state and never drifts. Apply via MCP replace_content.
    """
    cfg = (_apply_map().get("v0_5", {}).get("project_hubs", {}) or {}).get(slug)
    if not cfg:
        raise SystemExit(
            f"render-project: no v0_5.project_hubs.{slug} in notion_map.yaml"
        )
    body = (REPO_ROOT / cfg["template"]).read_text(encoding="utf-8")
    nav = home_navigator_payload()
    agt = {
        a["slice"]: a.get("text", "")
        for a in nav.get("action_queues", {}).get("agent_execution", [])
    }
    rows = {r.get("Name", ""): r for r in nav.get("active_slices", [])}

    def _short(text: str, limit: int = 88) -> str:
        t = " ".join(str(text or "").replace("—", " ").split())
        return t if len(t) <= limit else t[: limit - 1].rstrip() + "…"

    lines = []
    for s in cfg.get("slices", []):
        txt = agt.get(s) or (rows.get(s) or {}).get("Now") or ""
        lines.append(f"- **{s}** · {_short(txt)}" if txt else f"- **{s}**")
    body = body.replace("{{SLICES}}", "\n".join(lines) or "- (활성 슬라이스 없음)")
    body = body.replace("{{DATE}}", datetime.date.today().isoformat())
    return body.rstrip("\n") + "\n"


def emit_project_plan(slug: str) -> str:
    """One-shot apply plan for a project hub: page_id + rendered body + the MCP call."""
    cfg = (_apply_map().get("v0_5", {}).get("project_hubs", {}) or {}).get(slug) or {}
    pid = cfg.get("page_id", "")
    body = render_project_hub(slug)
    return "\n".join(
        [
            f"=== PROJECT HUB PLAN: {slug} ===",
            f"page_id: {pid}",
            "--- MCP CALL: notion-update-page command=replace_content "
            f"page_id={pid} (new_str = body below) ---",
            body,
            f"=== END PROJECT HUB PLAN: {slug} ===",
        ]
    )


def _apply_map() -> dict:
    """Load the Notion map from the CURRENT REPO_ROOT (not the frozen
    NOTION_MAP_PATH constant) so a monkeypatched REPO_ROOT / NOTION_SYNC_REPO_ROOT
    fixture is honored by the apply-plan tooling."""
    return load_map(REPO_ROOT / ".agent" / "notion_map.yaml") or {}


def resolve_apply_ids(slice_name: str) -> dict:
    """Resolve the Notion page ids needed to APPLY a handoff for ``slice_name``:
    the Navigator HOME page and the slice's Slices-DB row. Read from
    ``.agent/notion_map.yaml`` ``v0_5`` so the apply step needs NO MCP search.

    Returns ``{"home_page_id", "row_page_id", "errors": [..]}``; an id is ``""``
    when the map has no (non-empty) entry and a human-readable error is appended.
    Never raises — the caller decides the exit code (FAIL loud, never
    silent-search)."""
    v0_5 = _apply_map().get("v0_5") or {}
    errors: list[str] = []

    home_page_id = str(v0_5.get("home_page_id") or "").strip()
    if not home_page_id:
        errors.append(
            "v0_5:home_page_id missing from notion_map.yaml — cannot resolve the "
            "HOME page (record it, or run --render-home and apply by hand)"
        )

    row_ids = v0_5.get("slice_row_ids") or {}
    row_page_id = str(row_ids.get(slice_name) or "").strip()
    if not row_page_id:
        errors.append(
            f"v0_5:slice_row_ids[{slice_name}] missing/empty in notion_map.yaml — "
            "create the Slices-DB row and record its id"
        )

    return {
        "home_page_id": home_page_id,
        "row_page_id": row_page_id,
        "errors": errors,
    }


# Slices-DB date-typed columns. MCP `update_properties` needs the EXPANDED
# date key form (date:{col}:start [+ :is_datetime]) — a bare string silently
# fails for a date property. Source of truth for the full column set + types is
# notion_apply.SLICES_SCHEMA; duplicated minimally here to avoid a circular
# import (notion_apply imports notion_sync).
_MCP_DATE_COLS = ("Last Heartbeat", "Last Updated")
# Semantic fields slice_to_db_row() carries that are NOT Slices DB columns
# (home-navigator hints, e.g. "Next" — the column is "Next Action"). Dropped
# from the DB-row payload. Mirrors notion_apply._NON_COLUMN_FIELDS.
_MCP_NON_COLUMN_FIELDS = frozenset({"Next"})


def _row_to_mcp_properties(row: dict) -> dict:
    """Translate a :func:`slice_to_db_row` SEMANTIC dict into a Notion-MCP
    ``update_properties`` payload. Drops non-column hints (``Next``) and expands
    date columns into the MCP flat-key form (``date:{col}:start`` +
    ``date:{col}:is_datetime``); select/title/text columns pass through as plain
    strings (MCP accepts those). Empty date values are skipped (the column is
    left untouched rather than cleared). Pure / offline.

    This is the MCP sibling of :func:`notion_apply.build_row_properties` (the
    REST translator): notion_sync's emit paths feed the in-session Notion MCP,
    which uses a different property-payload shape than the REST API."""
    props: dict = {}
    for key, value in row.items():
        if key in _MCP_NON_COLUMN_FIELDS:
            continue
        if key in _MCP_DATE_COLS:
            text = "" if value is None else str(value).strip()
            if not text:
                continue  # empty date → leave the column untouched
            # A time component (":") means datetime; a bare YYYY-MM-DD is
            # date-only. PyYAML may parse an ISO timestamp into a datetime whose
            # str() uses a SPACE separator ("2026-06-12 11:46:51+00:00") — Notion
            # wants ISO "T", so normalize the date/time space back to "T".
            is_dt = ":" in text
            if is_dt and "T" not in text and " " in text:
                text = text.replace(" ", "T", 1)
            props[f"date:{key}:start"] = text
            props[f"date:{key}:is_datetime"] = 1 if is_dt else 0
            continue
        props[key] = value
    return props


def emit_apply_plan(slice_name: str) -> tuple[str, int]:
    """Build the ONE-SHOT apply plan for ``slice_name``: resolved HOME + ROW page
    ids, the preflighted HOME body, and the Slices-DB row payload — everything an
    in-session MCP agent needs to fire two calls with ZERO discovery.

    Returns ``(text, exit_code)``. exit_code != 0 if any id is unresolved (1) or
    the HOME render preflight fails (2, HOME_RENDER_UNSAFE) — the plan still prints
    what it can so the failure is actionable. No Notion calls; deterministic."""
    ids = resolve_apply_ids(slice_name)
    tail = (REPO_ROOT / ".agent" / "notion_home_tail.md").read_text(encoding="utf-8")
    body = render_home()
    missing = assert_home_preserves(body, tail)
    row = slice_to_db_row(slice_name)

    preflight = "PASS" if not missing else f"HOME_RENDER_UNSAFE: would drop {missing}"
    exit_code = 2 if missing else (1 if ids["errors"] else 0)

    lines = [
        f"=== APPLY PLAN: {slice_name} ===",
        f"preflight:    {preflight}",
        f"home_page_id: {ids['home_page_id'] or '<UNRESOLVED>'}",
        f"row_page_id:  {ids['row_page_id'] or '<UNRESOLVED>'}",
    ]
    lines.extend(f"error:        {err}" for err in ids["errors"])
    lines.append(
        "--- MCP CALL 1: notion-update-page command=replace_content "
        f"page_id={ids['home_page_id'] or '<UNRESOLVED>'} (new_str = body below) ---"
    )
    lines.append(body)
    lines.append(
        "--- MCP CALL 2: notion-update-page command=update_properties "
        f"page_id={ids['row_page_id'] or '<UNRESOLVED>'} (properties = JSON below) ---"
    )
    lines.append(json.dumps(_row_to_mcp_properties(row), indent=2, ensure_ascii=False))
    lines.append(f"=== END APPLY PLAN: {slice_name} ===")
    return "\n".join(lines), exit_code


def _emit_migration(target: str, db: str, upsert_key: str, rows: list[dict]) -> None:
    """Print one migration payload as JSON to stdout for manual MCP application.

    NO Notion API / network call — the workspace headless token is blocked, so
    the printed payload is applied in-session via Notion MCP by a human/agent.
    ``upsert_key`` names the row field that is the STABLE identifier: re-running
    a migrate produces the same key per row, so MCP application upserts (matches
    on that field) rather than inserting duplicates. ensure_ascii=False keeps
    Korean Status labels (활성 etc.) legible.
    """
    payload = {
        "target": target,
        "db": db,
        "mode": "upsert",
        "upsert_key": upsert_key,
        "count": len(rows),
        "rows": rows,
    }
    print(json.dumps(payload, indent=2, ensure_ascii=False))


def migrate_slices() -> None:
    """Backfill the active slice rows into Slices DB.
    v0.5 — see .agent/contracts/harness-notion-redesign-20260529.md (Task 9 + Task 23).

    Sources one row per active (or stateless) slice via :func:`slice_to_db_row`
    and PRINTS the payload as JSON for manual MCP application — no Notion writes.
    Idempotent: upsert key is ``Name`` (the slice name is stable per row).
    """
    rows = [slice_to_db_row(name) for name in _active_slice_names()]
    _emit_migration("slices", "Slices", "Name", rows)


def migrate_contracts() -> None:
    """Backfill all .agent/contracts/*.md decisions into Decisions DB as ADR rows.
    v0.5 — see .agent/contracts/harness-notion-redesign-20260529.md (Task 12 + Task 23).

    Iterates every ``.agent/contracts/*.md`` (skipping ``_template`` and other
    leading-underscore files) and flattens its ADR rows via
    :func:`contract_to_adr_rows`, then PRINTS the payload as JSON for manual MCP
    application — no Notion writes. Idempotent: upsert key is ``adr_id`` (stable
    ``ADR-<slice>-<topic>-<idx>`` identifier per decision).
    """
    contracts_dir = REPO_ROOT / ".agent" / "contracts"
    rows: list[dict] = []
    for path in sorted(contracts_dir.glob("*.md")):
        if path.stem.startswith("_"):  # skip _template.md
            continue
        rows.extend(contract_to_adr_rows(str(path)))
    _emit_migration("contracts", "Decisions", "adr_id", rows)


def migrate_slurm_history() -> None:
    """Backfill SLURM job history into Experiments DB.
    v0.5 — see .agent/contracts/harness-notion-redesign-20260529.md (Task 14 + Task 23).

    Sources historical job ids from the last 30 days via :func:`_history_slurm_ids`
    (``sacct``, mirroring plan Task 14) and resolves each to an Experiments row via
    :func:`slurm_to_experiment_row`, then PRINTS the payload as JSON for manual
    MCP application — no Notion writes. Robust: an unavailable/erroring sacct
    yields an empty row list rather than raising. Idempotent: upsert key is
    ``Run ID`` (the SLURM job id is stable per row).
    """
    rows = [slurm_to_experiment_row(job_id) for job_id in _history_slurm_ids()]
    _emit_migration("slurm", "Experiments", "Run ID", rows)


def migrate_home() -> None:
    """Emit the Navigator payload for the Notion home page.
    v0.5 — see .agent/contracts/harness-notion-redesign-20260529.md (Task 17 + Task 23).

    Computes the 5-section Navigator via :func:`home_navigator_payload` and
    PRINTS it as JSON for manual MCP application — no Notion writes. Idempotent:
    the Navigator is a single page keyed by ``upsert_key`` = ``"home"`` (one
    home page, re-rendered in place rather than duplicated).
    """
    payload = {
        "target": "home",
        "db": "Navigator",
        "mode": "upsert",
        "upsert_key": "home",
        "navigator": home_navigator_payload(),
    }
    print(json.dumps(payload, indent=2, ensure_ascii=False))


# SLURM-id-like tokens: optional "SLURM " prefix, then a 4-digit number 5xxx.
_SLURM_RE = re.compile(r"(?:SLURM\s*)?\b5\d{3}\b")


def handoff_log_payload(slice_name: str) -> dict:
    """Build a handoff-log payload for a slice. Token-independent, no network.

    Reuses read_slice(). Returns date, iso_week, conclusion, a stable
    change_digest (detects conclusion-text OR decision-set change), and a
    short evidence list (contract basenames + SLURM-id-like tokens from the
    conclusion). The change_digest is hex so it survives Notion's markdown
    re-render round-trip (the raw conclusion does not).
    """
    data = read_slice(slice_name)
    decisions = data.get("decisions") or []
    conclusion = data.get("conclusion") or ""

    slugs = sorted(str(d.get("slug", "")) for d in decisions)
    n = len(decisions)
    h = hashlib.sha1(
        (conclusion + "\x00" + "\n".join(slugs)).encode("utf-8")
    ).hexdigest()[:8]
    change_digest = f"{n}:{h}"

    evidence: list[str] = []
    seen: set[str] = set()
    for d in decisions:
        contract = d.get("contract")
        if not contract:
            continue
        base = Path(str(contract)).name
        if base not in seen:
            seen.add(base)
            evidence.append(base)
    for token in _SLURM_RE.findall(conclusion):
        token = token.strip()
        if token and token not in seen:
            seen.add(token)
            evidence.append(token)
    evidence = evidence[:5]

    payload = {
        "date": datetime.date.today().isoformat(),
        "iso_week": iso_week(),
        "conclusion": conclusion,
        "change_digest": change_digest,
        "evidence": evidence,
    }
    payload.update(classify_event(payload["conclusion"]))
    return payload


def gate_should_write(prev_entry_text: str, payload: dict) -> bool:
    """Pure change-gate: write iff conclusion text OR decision-set changed.

    Relies solely on the mangle-proof hex marker payload['change_digest'],
    which captures both conclusion and decision changes. Notion re-renders
    markdown on read-back (auto-links, escapes), so the raw conclusion is not
    a reliable substring of prev_entry_text — only the hex digest survives the
    round-trip. True iff change_digest is NOT a substring of prev_entry_text.
    Empty or None prev_entry_text → always True (no prior entry).
    """
    return not prev_entry_text or payload["change_digest"] not in prev_entry_text


def dry_run(slice_names: list[str], mapping: dict) -> int:
    """Render intended Notion changes per slice. No writes, no network.

    For each slice prints the hub conclusion callout text that WOULD be
    written (conclusion_marker + conclusion line + up to 3 remaining_actions)
    and the decisions that WOULD be upserted. Token-independent: with no
    NOTION_TOKEN we cannot resolve CREATE vs UPDATE, so everything is tagged
    UPSERT and a trailing note is printed.
    """
    slices_map = mapping.get("slices") or {}
    marker = mapping.get("conclusion_marker") or ""
    has_token = bool(os.environ.get("NOTION_TOKEN"))

    n_slices = 0
    m_decisions = 0

    for name in slice_names:
        n_slices += 1
        entry = slices_map.get(name) or {}
        hub_page_id = entry.get("hub_page_id")
        header_id = hub_page_id if hub_page_id else "NO MAP ENTRY"
        print(f"=== {name} ({header_id}) ===")

        data = read_slice(name)

        if not hub_page_id:
            print(
                f"warning: no map entry for slice '{name}' — skipping write section",
                file=sys.stderr,
            )
            print()
            continue

        # Hub conclusion callout (would write).
        print("CALLOUT (would write):")
        conclusion = data.get("conclusion") or ""
        print(f"  {marker} {conclusion}".rstrip())
        for action in (data.get("remaining_actions") or [])[:3]:
            print(f"  - {action}")

        # Decisions (would upsert).
        decisions = data.get("decisions") or []
        for decision in decisions:
            m_decisions += 1
            print(
                f"[UPSERT] {decision.get('slug')} | "
                f"{decision.get('status')} | {decision.get('title')}"
            )
        if not has_token:
            print(
                "(no NOTION_TOKEN — would need token to apply; "
                "CREATE/UPDATE resolved at apply time)"
            )
        print()

    print(f"DRY-RUN: {n_slices} slices, {m_decisions} decisions would upsert.")
    return 0


def check_env() -> int:
    """Preflight: verify notion-client import and NOTION_TOKEN, no API call."""
    try:
        from notion_client import Client
    except ImportError as exc:  # pragma: no cover - depends on env
        print(f"notion-client not installed: {exc}", file=sys.stderr)
        return 1

    token = os.environ.get("NOTION_TOKEN")
    if not token:
        print("NOTION_TOKEN not set — set it in .agent/.secrets/notion.env")
        return 0

    # Construct the client to confirm the SDK is usable. This makes NO
    # network/API call — the Client is lazy until a method is invoked.
    Client(auth=token)
    print("notion-client ready (no API call) — NOTION_TOKEN set, Client constructed")
    return 0


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        prog="notion_sync.py",
        description="Sync per-slice status into Notion hub pages (skeleton).",
    )
    parser.add_argument(
        "--slice", dest="slice_name", metavar="NAME", help="sync a single slice by name"
    )
    parser.add_argument(
        "--all", action="store_true", help="sync all slices in the mapping"
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="resolve and report actions without writing to Notion",
    )
    parser.add_argument(
        "--check-env",
        action="store_true",
        help="preflight: check notion-client import + NOTION_TOKEN; no API call",
    )
    parser.add_argument(
        "--dump",
        action="store_true",
        help="parse slice status + contract decisions and print as JSON; no Notion calls",
    )
    parser.add_argument(
        "--handoff-log",
        action="store_true",
        help="print handoff-log payload JSON for --slice NAME; no Notion calls",
    )
    parser.add_argument(
        "--migrate",
        dest="migrate_target",
        metavar="TARGET",
        choices=["slices", "contracts", "slurm", "home", "all"],
        help=(
            "emit backfill payload JSON (upsert-keyed) for manual MCP application; "
            "TARGET is one of slices|contracts|slurm|home|all; no Notion calls"
        ),
    )
    parser.add_argument(
        "--audit",
        action="store_true",
        help="print local Notion sync trust audit JSON; no Notion calls",
    )
    parser.add_argument(
        "--lint-baton",
        dest="lint_baton",
        nargs="?",
        const=True,
        default=None,
        metavar="NAME",
        help=(
            "lint a status baton (frontmatter health + remaining_actions "
            "hygiene); slice from this arg or --slice; issues to stderr, "
            "exit 1 if dirty"
        ),
    )
    parser.add_argument(
        "--render-home",
        action="store_true",
        help=(
            "render the full Notion-flavored-markdown home body (Mission Control "
            "cockpit + static tail) for MCP replace_content; refuses if any child "
            "page/DB would be dropped; no Notion calls"
        ),
    )
    parser.add_argument(
        "--handoff-emit",
        dest="handoff_emit",
        nargs="?",
        const=True,
        default=None,
        metavar="NAME",
        help=(
            "emit the home body + a slice's Slices-DB row payload for one-shot "
            "MCP apply (slice from this arg or --slice); no Notion calls"
        ),
    )
    parser.add_argument(
        "--emit-apply-plan",
        dest="emit_apply_plan",
        nargs="?",
        const=True,
        default=None,
        metavar="NAME",
        help=(
            "emit a ONE-SHOT apply plan for a slice: resolved HOME + ROW page ids "
            "(from notion_map.yaml v0_5) + preflighted home body + row payload + the "
            "two MCP calls; exit !=0 if an id is unresolved or preflight fails; "
            "no Notion calls"
        ),
    )
    parser.add_argument(
        "--stamp-home-applied",
        action="store_true",
        help=(
            "record when the home was last applied to Notion by writing "
            ".agent/handoffs/state/home-render.stamp (rev + UTC timestamp); "
            "no Notion calls"
        ),
    )
    parser.add_argument(
        "--emit-project-plan",
        dest="emit_project_plan",
        metavar="SLUG",
        help=(
            "emit a one-shot apply plan for a project hub (v0_5.project_hubs.<SLUG>): "
            "page_id + body rendered from its template with {{SLICES}} filled from "
            "live batons; apply via MCP replace_content; no Notion calls"
        ),
    )
    parser.add_argument(
        "--project-for-slice",
        dest="project_for_slice",
        metavar="SLICE",
        help=(
            "print the project_hub slug(s) whose 'slices' list includes SLICE "
            "(one per line); used by handoff.sh to flag project hubs for re-sync"
        ),
    )
    parser.add_argument(
        "--stamp-project-applied",
        dest="stamp_project_applied",
        metavar="SLUG",
        help=(
            "clear SLUG from .agent/handoffs/state/notion-project-pending after its "
            "hub was applied to Notion; no Notion calls"
        ),
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)

    if args.check_env:
        return check_env()

    if args.audit:
        print(json.dumps(notion_audit_payload(), indent=2, ensure_ascii=False))
        return 0

    if args.lint_baton is not None:
        # Slice from the positional value (--lint-baton NAME) or --slice NAME;
        # a bare --lint-baton yields the sentinel True and needs --slice.
        slice_name = (
            args.lint_baton if isinstance(args.lint_baton, str) else args.slice_name
        )
        if not slice_name:
            print("--lint-baton requires --slice NAME", file=sys.stderr)
            return 2
        issues = lint_baton(slice_name)
        for issue in issues:
            print(issue, file=sys.stderr)
        return 1 if issues else 0

    if args.render_home:
        tail = (REPO_ROOT / ".agent" / "notion_home_tail.md").read_text(
            encoding="utf-8"
        )
        body = render_home()
        missing = assert_home_preserves(body, tail)
        if missing:
            print(f"HOME_RENDER_UNSAFE: would drop {missing}", file=sys.stderr)
            return 2
        print(body)
        return 0

    if args.handoff_emit is not None:
        # Slice from the positional value (--handoff-emit NAME) or --slice NAME;
        # a bare --handoff-emit yields the sentinel True and needs --slice.
        slice_name = (
            args.handoff_emit if isinstance(args.handoff_emit, str) else args.slice_name
        )
        if not slice_name:
            print("--handoff-emit requires --slice NAME", file=sys.stderr)
            return 2
        tail = (REPO_ROOT / ".agent" / "notion_home_tail.md").read_text(
            encoding="utf-8"
        )
        body = render_home()
        missing = assert_home_preserves(body, tail)
        if missing:
            print(f"HOME_RENDER_UNSAFE: would drop {missing}", file=sys.stderr)
            return 2
        print("=== HOME (apply via MCP replace_content on the home page) ===")
        print(body)
        print(
            f"=== ROW: {slice_name} (apply via MCP update_properties on the slice row) ==="
        )
        print(
            json.dumps(
                _row_to_mcp_properties(slice_to_db_row(slice_name)),
                indent=2,
                ensure_ascii=False,
            )
        )
        return 0

    if args.emit_apply_plan is not None:
        # Slice from the positional value (--emit-apply-plan NAME) or --slice NAME.
        slice_name = (
            args.emit_apply_plan
            if isinstance(args.emit_apply_plan, str)
            else args.slice_name
        )
        if not slice_name:
            print("--emit-apply-plan requires --slice NAME", file=sys.stderr)
            return 2
        text, code = emit_apply_plan(slice_name)
        print(text)
        return code

    if args.emit_project_plan:
        print(emit_project_plan(args.emit_project_plan))
        return 0

    if args.project_for_slice:
        hubs = _apply_map().get("v0_5", {}).get("project_hubs", {}) or {}
        for slug, cfg in hubs.items():
            if args.project_for_slice in ((cfg or {}).get("slices") or []):
                print(slug)
        return 0

    if args.stamp_project_applied:
        marker = REPO_ROOT / ".agent" / "handoffs" / "state" / "notion-project-pending"
        if marker.exists():
            kept = [
                ln
                for ln in marker.read_text(encoding="utf-8").splitlines()
                if ln.strip() and ln.split()[0] != args.stamp_project_applied
            ]
            if kept:
                marker.write_text("\n".join(kept) + "\n", encoding="utf-8")
            else:
                marker.unlink()
        return 0

    if args.stamp_home_applied:
        return write_home_stamp()

    if args.handoff_log:
        if not args.slice_name:
            print("--handoff-log requires --slice NAME", file=sys.stderr)
            return 2
        payload = handoff_log_payload(args.slice_name)
        print(json.dumps(payload, indent=2, ensure_ascii=False))
        return 0

    if args.migrate_target:
        # Each migrate_* PRINTS its upsert-keyed payload as JSON; no Notion
        # writes (apply via in-session MCP). "all" runs each in sequence with
        # a section header so the combined output stays parseable.
        migrators = {
            "slices": migrate_slices,
            "contracts": migrate_contracts,
            "slurm": migrate_slurm_history,
            "home": migrate_home,
        }
        if args.migrate_target == "all":
            for name, fn in migrators.items():
                print(f"=== MIGRATE {name} ===")
                fn()
        else:
            migrators[args.migrate_target]()
        return 0

    if args.dump:
        if args.all:
            mapping = load_map()
            slice_names = list((mapping.get("slices") or {}).keys())
            result = {name: read_slice(name) for name in slice_names}
        elif args.slice_name:
            result = read_slice(args.slice_name)
        else:
            print("--dump requires --slice NAME or --all", file=sys.stderr)
            return 2
        print(json.dumps(result, indent=2, ensure_ascii=False))
        return 0

    if args.dry_run:
        mapping = load_map()
        if args.all:
            slice_names = list((mapping.get("slices") or {}).keys())
        elif args.slice_name:
            slice_names = [args.slice_name]
        else:
            print("--dry-run requires --slice NAME or --all", file=sys.stderr)
            return 2
        return dry_run(slice_names, mapping)

    if args.slice_name or args.all:
        print("not yet implemented (skeleton)")
        return 0

    # No actionable flag given.
    print("nothing to do — pass --check-env, --slice NAME, or --all")
    return 0


if __name__ == "__main__":
    sys.exit(main())
