"""Unit tests for the FEA Stage-2 watch (failure-signature monitor).

The sacct/df backends are injected as callables, so the suite is hermetic — it
never shells out to SLURM or the real filesystem. Covers the two shipped checks
(job_dead, disk_full), the per-branch disk semantics (the mergerfs lesson), and
the self-clearing marker.
"""

from __future__ import annotations

from scripts.fea.watch import (
    Finding,
    WatchReport,
    check_disk,
    check_jobs,
    clear_marker,
    read_watch_list,
    scan_once,
    write_marker,
)


# --------------------------------------------------------------------------- #
# job_dead
# --------------------------------------------------------------------------- #
def test_terminal_failure_is_flagged_as_error():
    states = {"7974": "FAILED", "8098": "RUNNING", "8100": "COMPLETED"}
    findings = check_jobs(states.keys(), state_fn=lambda j: states[j])
    dead = [f for f in findings if f.code == "job_dead"]
    assert [f.subject for f in dead] == ["7974"]
    assert dead[0].severity == "error"
    assert "FAILED" in dead[0].message


def test_clean_and_unknown_states_produce_no_finding():
    # COMPLETED is success; "" is sacct-unknown (too new / purged) — both silent.
    states = {"1": "COMPLETED", "2": "", "3": "PENDING", "4": "RUNNING"}
    assert check_jobs(states.keys(), state_fn=lambda j: states[j]) == []


def test_oom_and_node_fail_are_failures():
    for bad in ("OUT_OF_MEMORY", "NODE_FAIL", "TIMEOUT", "CANCELLED"):
        findings = check_jobs(["42"], state_fn=lambda j, b=bad: b)
        assert findings and findings[0].severity == "error"


def test_blank_job_ids_skipped():
    assert check_jobs(["", "  ", None], state_fn=lambda j: "FAILED") == []


# --------------------------------------------------------------------------- #
# disk_full — the mergerfs per-branch lesson
# --------------------------------------------------------------------------- #
def test_branch_over_crit_is_error_even_if_union_is_healthy():
    # The real 7974 failure mode: kfs5 at 98% while the /mnt/data union is 41%.
    usage = {"/mnt/kfs5": 98, "/mnt/kfs1": 3, "/mnt/data": 41}
    findings = check_disk(paths=list(usage), use_fn=lambda p: usage[p])
    full = {f.subject: f for f in findings}
    assert full["/mnt/kfs5"].severity == "error"
    assert "/mnt/kfs1" not in full  # healthy branch is silent
    assert "/mnt/data" not in full  # union below warn threshold


def test_warn_band_is_warn_not_error():
    findings = check_disk(paths=["/x"], warn_pct=85, crit_pct=95, use_fn=lambda p: 88)
    assert len(findings) == 1
    assert findings[0].severity == "warn"


def test_missing_path_is_skipped():
    assert check_disk(paths=["/gone"], use_fn=lambda p: None) == []


# --------------------------------------------------------------------------- #
# scan_once composition + report
# --------------------------------------------------------------------------- #
def test_scan_once_merges_both_checks_and_report_ok():
    rep = scan_once(
        job_ids=["7974"],
        disk_paths=["/mnt/kfs5"],
        state_fn=lambda j: "FAILED",
        use_fn=lambda p: 98,
    )
    codes = sorted(f.code for f in rep.findings)
    assert codes == ["disk_full", "job_dead"]
    assert rep.ok is False
    assert len(rep.errors) == 2


def test_clean_scan_is_ok():
    rep = scan_once(
        job_ids=["8098"],
        disk_paths=["/mnt/kfs1"],
        state_fn=lambda j: "RUNNING",
        use_fn=lambda p: 3,
    )
    assert rep.findings == []
    assert rep.ok is True


# --------------------------------------------------------------------------- #
# marker self-clear + watch-list
# --------------------------------------------------------------------------- #
def test_marker_writes_then_self_clears(tmp_path):
    marker = tmp_path / "proactive-watch-findings"
    dirty = WatchReport([Finding("error", "disk_full", "/mnt/kfs5", "full")])
    assert write_marker(dirty, path=str(marker)) == str(marker)
    assert marker.exists() and "disk_full" in marker.read_text()

    # A later clean scan overwrites to nothing → marker removed (no nag).
    assert write_marker(WatchReport([]), path=str(marker)) is None
    assert not marker.exists()


def test_clear_marker_is_idempotent(tmp_path):
    marker = tmp_path / "m"
    clear_marker(path=str(marker))  # absent — no error
    marker.write_text("stale\n")
    clear_marker(path=str(marker))
    assert not marker.exists()


def test_read_watch_list_skips_comments_and_blanks(tmp_path):
    wl = tmp_path / "wl"
    wl.write_text("# header\n7974\n\n8098  host-10-0-5-90\n  # indented comment\n")
    assert read_watch_list(str(wl)) == ["7974", "8098"]


def test_read_watch_list_absent_is_empty(tmp_path):
    assert read_watch_list(str(tmp_path / "nope")) == []
