"""Tests for scripts/baton-deps.py — cross-slice dependency edge resolution.

Exercised end-to-end through the CLI (the script's filename has a hyphen, so it
is not importable as a module). Builds a throwaway workspace with a NESTED git
repo so the multi-repo resolution path is covered — the exact case the design
review flagged (FKSFold-Boltz_Advancement is its own repo, invisible to a
`git -C /home/ubuntu ls-files`).
"""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "baton-deps.py"


def _git(repo: Path, *args: str) -> None:
    subprocess.run(
        ["git", "-c", "user.email=t@t", "-c", "user.name=t", "-C", str(repo), *args],
        check=True,
        capture_output=True,
        text=True,
    )


def _baton(status_dir: Path, slice_name: str, depends_on: list[str]) -> None:
    body = ["---", "owner_agent: claude", "version: 1"]
    if depends_on:
        body.append("depends_on:")
        body.extend(f'  - "{d}"' for d in depends_on)
    body += ["contract_pointers:", "  - .agent/contracts/x.md", "---", "# body", ""]
    (status_dir / f"{slice_name}.md").write_text("\n".join(body), encoding="utf-8")


def _run(root: Path) -> str:
    res = subprocess.run(
        [sys.executable, str(SCRIPT)],
        env={
            "BATON_DEPS_ROOT": str(root),
            "AGENT_ROOT": str(root / ".agent"),
            "PATH": "/usr/local/bin:/usr/bin:/bin",
        },
        capture_output=True,
        text=True,
    )
    assert res.returncode == 0, res.stderr
    return res.stdout


def _workspace(tmp_path: Path) -> tuple[Path, Path]:
    """A workspace ROOT with a nested git repo and an .agent/status/ tree."""
    root = tmp_path / "ws"
    status = root / ".agent" / "status"
    status.mkdir(parents=True)

    repo = root / "nested_repo"
    repo.mkdir()
    _git(repo, "init", "-q")
    (repo / "committed.txt").write_text("done\n")
    _git(repo, "add", "committed.txt")
    _git(repo, "commit", "-q", "-m", "init")
    # tracked but now modified (dirty) — the "WIP not committed yet" state
    (repo / "dirty.txt").write_text("v1\n")
    _git(repo, "add", "dirty.txt")
    _git(repo, "commit", "-q", "-m", "add dirty")
    (repo / "dirty.txt").write_text("v2 uncommitted\n")
    # untracked
    (repo / "untracked.txt").write_text("new\n")
    return root, status


def test_committed_clean_edge_is_ready(tmp_path):
    root, status = _workspace(tmp_path)
    _baton(status, "downstream", ["up:file=nested_repo/committed.txt"])
    out = _run(root)
    assert "[downstream] DEP-READY: up" in out
    assert "committed.txt" in out


def test_dirty_tracked_edge_is_blocked(tmp_path):
    root, status = _workspace(tmp_path)
    _baton(status, "downstream", ["up:file=nested_repo/dirty.txt"])
    out = _run(root)
    assert "[downstream] DEP-BLOCKED: waiting on up" in out
    assert "clean=n" in out


def test_untracked_edge_is_blocked(tmp_path):
    root, status = _workspace(tmp_path)
    _baton(status, "downstream", ["up:file=nested_repo/untracked.txt"])
    out = _run(root)
    assert "[downstream] DEP-BLOCKED" in out
    assert "tracked=n" in out


def test_malformed_edge_warns(tmp_path):
    root, status = _workspace(tmp_path)
    _baton(status, "downstream", ["up:state=closed"])  # unsupported condition
    out = _run(root)
    assert "[downstream] DEP-WARN" in out


def test_no_depends_on_is_silent(tmp_path):
    root, status = _workspace(tmp_path)
    _baton(status, "downstream", [])
    _baton(status, "other", [])
    out = _run(root)
    assert out.strip() == ""


def test_readme_is_skipped(tmp_path):
    root, status = _workspace(tmp_path)
    (status / "README.md").write_text('depends_on:\n  - "x:file=y"\n')
    out = _run(root)
    assert "README" not in out
