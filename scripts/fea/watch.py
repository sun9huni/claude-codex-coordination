"""FEA Stage-2 watch — proactive failure-signature monitor over live runs.

Read-only, advisory, and it NEVER actuates: no ``scancel``, ``sbatch`` or
resubmit. It mirrors the preflight family's ``Issue``/``Report`` shape so
``fea watch`` slots into the existing CLI next to ``fea preflight``.

The two cheapest, highest-leverage checks ship first — they target the user's
actual recurring pain (jobs die silently and get noticed late; a disk fills
mid-run):

    job_dead  — a watched SLURM job id reached a terminal FAILURE state
                (FAILED / TIMEOUT / OUT_OF_MEMORY / NODE_FAIL / ...). Uses the
                same ``sacct -j <id> -X -n -o State`` query that
                ``baton-drift.sh:50-58`` already trusts.
    disk_full — a storage branch is at/over a use-% threshold. It checks the
                mergerfs BRANCHES (``/mnt/kfs*``) individually, NOT the
                ``/mnt/data`` union, because mergerfs routing once filled
                ``kfs5`` to 99% while the union still reported tens of TB free
                — that silent fill killed job 7974.

Liveness note: a login-node file mtime is unreliable (mergerfs serves a stale
stat), so the death check trusts ``sacct`` and never a file timestamp — this is
the ``feedback_slurm_liveness_check`` lesson baked in.

Standard library only. The ``sacct`` and ``df`` backends are injected as
callables so the unit tests never shell out.
"""

from __future__ import annotations

import glob
import os
import subprocess
from dataclasses import dataclass
from pathlib import Path

# A terminal SLURM state that is NOT a clean completion. Mirrors the set
# baton-drift.sh flags as scheduler-drift (minus COMPLETED, which is success).
TERMINAL_FAILURE_STATES = frozenset(
    {
        "FAILED",
        "TIMEOUT",
        "OUT_OF_MEMORY",
        "NODE_FAIL",
        "CANCELLED",
        "BOOT_FAIL",
        "DEADLINE",
        "PREEMPTED",
        "OOM",
    }
)

# Default storage branches to disk-check: the mergerfs back-end mounts, probed
# one by one (the union mount hides a full branch). Resolved against what is
# actually mounted at call time, so this degrades cleanly off the cluster.
_DISK_GLOBS = ("/mnt/kfs*",)
_DISK_EXTRA = ("/home/ubuntu",)

# The surfaced findings marker. Overwrite-semantics (not append): each
# `--write-marker` run rewrites it to exactly the current findings, so a
# resolved condition self-clears on the next scan — no separate stamp step,
# no nag-until-acknowledged accumulation.
MARKER = ".agent/handoffs/state/proactive-watch-findings"

# Optional watch-list the launcher/agent drops job ids into (one per line;
# blank lines and `#` comments ignored). Read when no ids are passed explicitly.
WATCH_LIST = ".agent/handoffs/state/fea-watched-jobs"


@dataclass
class Finding:
    severity: str  # "error" | "warn"
    code: str  # "job_dead" | "disk_full"
    subject: str  # the job id / mount path the finding is about
    message: str  # human-readable, includes a recipe


@dataclass
class WatchReport:
    findings: list[Finding]

    @property
    def ok(self) -> bool:
        """True iff no error-severity finding is present."""
        return not any(f.severity == "error" for f in self.findings)

    @property
    def errors(self) -> list[Finding]:
        return [f for f in self.findings if f.severity == "error"]


# --------------------------------------------------------------------------- #
# Backends (shell-outs). Injected in tests so the suite stays hermetic.
# --------------------------------------------------------------------------- #
def sacct_state(job_id: str) -> str:
    """Terminal/active SLURM state for a job id, or "" if unknown.

    Mirrors baton-drift.sh:50-58 — ``-X`` collapses the array/step rows to the
    top-level job, ``-n`` drops the header, and a trailing ``+`` (a truncated
    state like ``CANCELLED+``) is stripped.
    """
    try:
        out = subprocess.run(
            ["sacct", "-j", str(job_id), "-X", "-n", "-o", "State"],
            capture_output=True,
            text=True,
            timeout=8,
        ).stdout
    except (OSError, subprocess.SubprocessError):
        return ""
    first = out.strip().splitlines()[0] if out.strip() else ""
    return first.strip().rstrip("+").upper()


def df_use_pct(path: str) -> int | None:
    """Use-% (0-100) for the filesystem holding ``path``; None if unavailable.

    Parses ``df -P`` so the capacity column is always field 5 regardless of how
    long the device name is (``-P`` forbids the line-wrap that bare ``df`` does).
    """
    if not os.path.exists(path):
        return None
    try:
        out = subprocess.run(
            ["df", "-P", path],
            capture_output=True,
            text=True,
            timeout=8,
        ).stdout
    except (OSError, subprocess.SubprocessError):
        return None
    lines = out.strip().splitlines()
    if len(lines) < 2:
        return None
    fields = lines[-1].split()
    if len(fields) < 5:
        return None
    cap = fields[4].rstrip("%")
    try:
        return int(cap)
    except ValueError:
        return None


# --------------------------------------------------------------------------- #
# Checks
# --------------------------------------------------------------------------- #
def check_jobs(job_ids, state_fn=sacct_state) -> list[Finding]:
    """Flag any watched job id whose SLURM state is a terminal FAILURE.

    Clean states (COMPLETED / RUNNING / PENDING / ...) and unknown ids (sacct
    returns "" — too new, or purged from the accounting db) produce no finding.
    """
    findings: list[Finding] = []
    for jid in job_ids or []:
        if not jid:
            continue
        jid = str(jid).strip()
        if not jid:
            continue
        state = state_fn(jid)
        if state in TERMINAL_FAILURE_STATES:
            findings.append(
                Finding(
                    "error",
                    "job_dead",
                    jid,
                    f"job {jid} is {state} — inspect its log + run dir; "
                    f"if OOM/NODE_FAIL, re-stage and resubmit (no auto-resubmit).",
                )
            )
    return findings


def default_disk_paths() -> list[str]:
    """Mounted mergerfs branches + local home — the per-branch disk targets."""
    paths: list[str] = []
    for pattern in _DISK_GLOBS:
        paths.extend(sorted(p for p in glob.glob(pattern) if os.path.ismount(p)))
    paths.extend(p for p in _DISK_EXTRA if os.path.exists(p))
    return paths


def check_disk(
    paths=None, warn_pct: int = 85, crit_pct: int = 95, use_fn=df_use_pct
) -> list[Finding]:
    """Flag storage branches at/over the use-% thresholds.

    ``>= crit_pct`` is an error (a run will fail soon / has likely failed);
    ``>= warn_pct`` is a warning. Probes each branch individually so a full
    back-end behind a healthy-looking union mount is still caught.
    """
    if paths is None:
        paths = default_disk_paths()
    findings: list[Finding] = []
    for path in paths:
        pct = use_fn(path)
        if pct is None:
            continue
        if pct >= crit_pct:
            findings.append(
                Finding(
                    "error",
                    "disk_full",
                    path,
                    f"{path} is {pct}% full (>= {crit_pct}%) — writes will fail; "
                    f"point new output at an empty branch before launching.",
                )
            )
        elif pct >= warn_pct:
            findings.append(
                Finding(
                    "warn",
                    "disk_full",
                    path,
                    f"{path} is {pct}% full (>= {warn_pct}%) — "
                    f"check headroom before a large run.",
                )
            )
    return findings


def scan_once(
    job_ids=None,
    disk_paths=None,
    warn_pct: int = 85,
    crit_pct: int = 95,
    state_fn=sacct_state,
    use_fn=df_use_pct,
) -> WatchReport:
    """One advisory snapshot: terminal-failure jobs + over-threshold disks."""
    findings: list[Finding] = []
    findings.extend(check_jobs(job_ids, state_fn=state_fn))
    findings.extend(
        check_disk(disk_paths, warn_pct=warn_pct, crit_pct=crit_pct, use_fn=use_fn)
    )
    return WatchReport(findings)


# --------------------------------------------------------------------------- #
# Marker + watch-list IO
# --------------------------------------------------------------------------- #
def read_watch_list(path: str = WATCH_LIST) -> list[str]:
    """Read job ids from the watch-list marker (one per line; '#'/blank skipped)."""
    p = Path(path)
    if not p.exists():
        return []
    ids: list[str] = []
    for line in p.read_text(encoding="utf-8").splitlines():
        token = line.strip().split()[0] if line.strip() else ""
        if token and not token.startswith("#"):
            ids.append(token)
    return ids


def write_marker(report: WatchReport, path: str = MARKER) -> str | None:
    """Overwrite the findings marker with the current findings.

    Zero findings removes the marker, so a resolved condition self-clears on the
    next scan — there is no separate stamp/ack step to forget. Returns the path
    written, or None if the marker was removed/absent.
    """
    p = Path(path)
    if not report.findings:
        if p.exists():
            p.unlink()
        return None
    p.parent.mkdir(parents=True, exist_ok=True)
    lines = [
        f"{f.severity}\t{f.code}\t{f.subject}\t{f.message}" for f in report.findings
    ]
    p.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return str(p)


def clear_marker(path: str = MARKER) -> None:
    """Manual reset of the findings marker."""
    p = Path(path)
    if p.exists():
        p.unlink()
