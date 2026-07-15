#!/usr/bin/env python3
"""baton-deps.py — resolve cross-slice dependency edges declared in batons.

A slice baton may declare it is waiting on another slice to COMMIT a file, via
an optional ``depends_on`` frontmatter list:

    depends_on:
      - "aigen-fold-core:file=FKSFold-Boltz_Advancement/workflow/scripts/run_mmpbsa.py"

Each item is ``<upstream-slice-stem>:file=<workspace-relative-path>``. The edge
is SATISFIED when that path is tracked AND clean (not modified) in its OWNING
git repo — which is the real meaning of "aigen-fold-core committed run_mmpbsa.py
from its dirty-tree WIP". Until then the downstream slice is BLOCKED.

Only the ``file=`` condition is supported — it is the only cross-slice
dependency that has ever actually occurred in this workspace (a 4-condition
grammar for a population of one was deliberately rejected in design review).

Multi-repo aware: the workspace nests separate git repos (e.g.
``FKSFold-Boltz_Advancement/`` is its own repo, NOT a submodule of
``/home/ubuntu``). A naive ``git -C $ROOT ls-files`` can never see those files,
so each path is resolved against its OWNING toplevel
(``git -C <dir> rev-parse --show-toplevel``).

Read-only, best-effort, never exits non-zero. Prints one finding per line in the
same ``[slice] TAG: ...`` shape baton-drift.sh uses, so the existing
session-start / pre-compact surfaces carry it for free. Standard library only.
"""

from __future__ import annotations

import os
import subprocess

ROOT = os.environ.get("BATON_DEPS_ROOT") or os.path.dirname(
    os.path.dirname(os.path.abspath(__file__))
)
STATUS_DIR = os.path.join(os.environ.get("AGENT_ROOT") or f"{ROOT}/.agent", "status")


def _frontmatter_depends_on(path: str) -> list[str]:
    """Extract the ``depends_on`` string items from a baton's YAML frontmatter.

    Manual parse (no PyYAML dependency, since this runs under the system python3
    too): read the ``---`` … ``---`` block, find the ``depends_on:`` key, and
    collect its ``- item`` lines until the next top-level key.
    """
    try:
        with open(path, encoding="utf-8") as fh:
            lines = fh.read().splitlines()
    except OSError:
        return []
    if not lines or lines[0].strip() != "---":
        return []
    end = next((i for i in range(1, len(lines)) if lines[i].strip() == "---"), None)
    if end is None:
        return []

    items: list[str] = []
    in_block = False
    for ln in lines[1:end]:
        if not in_block:
            if ln.strip() == "depends_on:" or ln.startswith("depends_on:"):
                in_block = True
            continue
        # A new top-level key (no leading space, ends the list).
        if ln and not ln[0].isspace():
            break
        stripped = ln.strip()
        if stripped.startswith("- "):
            val = stripped[2:].strip().strip("\"'")
            if val:
                items.append(val)
    return items


def _git(repo: str, *args: str) -> subprocess.CompletedProcess:
    return subprocess.run(
        ["git", "-C", repo, *args],
        capture_output=True,
        text=True,
        timeout=8,
    )


def _owning_toplevel(abs_path: str) -> str | None:
    """The git toplevel that owns ``abs_path`` (handles nested repos)."""
    start = abs_path if os.path.isdir(abs_path) else os.path.dirname(abs_path)
    if not os.path.isdir(start):
        return None
    try:
        out = _git(start, "rev-parse", "--show-toplevel")
    except (OSError, subprocess.SubprocessError):
        return None
    top = out.stdout.strip()
    return top or None


def resolve_edge(upstream: str, rel_path: str) -> dict:
    """Resolve one ``file=`` edge against its owning repo.

    Returns {satisfied, tracked, clean, repo, reason}. ``satisfied`` is True iff
    the path is tracked AND clean in its owning git repo.
    """
    abs_path = os.path.join(ROOT, rel_path)
    top = _owning_toplevel(abs_path)
    if top is None:
        return {
            "satisfied": False,
            "tracked": False,
            "clean": False,
            "repo": "?",
            "reason": "no owning git repo on disk",
        }
    repo_name = os.path.basename(top)
    repo_rel = os.path.relpath(abs_path, top)
    try:
        tracked = _git(top, "ls-files", "--error-unmatch", repo_rel).returncode == 0
        clean = not _git(top, "status", "--porcelain", "--", repo_rel).stdout.strip()
    except (OSError, subprocess.SubprocessError):
        return {
            "satisfied": False,
            "tracked": False,
            "clean": False,
            "repo": repo_name,
            "reason": "git query failed",
        }
    return {
        "satisfied": tracked and clean,
        "tracked": tracked,
        "clean": clean,
        "repo": repo_name,
        "reason": "",
    }


def scan(status_dir: str = STATUS_DIR) -> list[str]:
    """One finding line per cross-slice edge across all batons."""
    findings: list[str] = []
    try:
        names = sorted(os.listdir(status_dir))
    except OSError:
        return findings
    for name in names:
        if not name.endswith(".md") or name == "README.md":
            continue
        slice_name = name[:-3]
        path = os.path.join(status_dir, name)
        for item in _frontmatter_depends_on(path):
            upstream, sep, cond = item.partition(":")
            if not sep or not cond.startswith("file="):
                findings.append(
                    f"[{slice_name}] DEP-WARN: unparseable depends_on item "
                    f"'{item}' (expected '<upstream>:file=<repo-relative-path>')"
                )
                continue
            rel_path = cond[len("file=") :]
            r = resolve_edge(upstream, rel_path)
            if r["satisfied"]:
                findings.append(
                    f"[{slice_name}] DEP-READY: {upstream} dependency "
                    f"'{rel_path}' is committed+clean in {r['repo']} — "
                    f"{slice_name} can proceed; drop the depends_on edge."
                )
            else:
                detail = r["reason"] or (
                    f"tracked={'y' if r['tracked'] else 'n'}, "
                    f"clean={'y' if r['clean'] else 'n'} in {r['repo']}"
                )
                findings.append(
                    f"[{slice_name}] DEP-BLOCKED: waiting on {upstream} to commit "
                    f"'{rel_path}' ({detail})."
                )
    return findings


def main() -> int:
    for line in scan():
        print(line)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
