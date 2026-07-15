"""Task 10 — assert ``draft_baton`` emits a valid, verdict-bearing draft.

The fixture ``fixtures/sample_baton.md`` is a clean control baton (parses
under the house frontmatter parser). We copy it into ``tmp_path`` so the
``.fea-draft`` lands beside a throwaway copy, never beside the committed
fixture. After drafting we assert the draft parses, the version is bumped
by one, the first remaining_actions item is the FEA ``DECISION:`` line, and
the committed fixture is byte-for-byte unchanged.
"""

from __future__ import annotations

import shutil
from pathlib import Path

from scripts.fea.capture import draft_baton
from scripts.fea.results_card import ResultsCard
from scripts.notion_sync import _parse_frontmatter

FIXTURE = Path(__file__).resolve().parent / "fixtures" / "sample_baton.md"
FIXTURE_VERSION = 7


def _make_card(slice_name: str) -> ResultsCard:
    return ResultsCard(
        job_dir="/tmp/fea_sample_job",
        verdict="KILL",
        slice_name=slice_name,
        gate_rows=[
            {
                "metric": "vav1_rigid_body_offset",
                "raw_rho": -0.3046,
                "oof_rho": -0.1174,
                "perm_p": 0.7313,
                "verdict": "KILL",
            }
        ],
        failure_manifest={"counts": {"success": 125, "silent_fail": 20}},
    )


def test_draft_baton_valid_and_verdict_bearing(tmp_path):
    before_bytes = FIXTURE.read_bytes()

    tmp_copy = tmp_path / "sample_baton.md"
    shutil.copyfile(FIXTURE, tmp_copy)

    card = _make_card("sample-slice")
    returned = draft_baton(card, baton_path=str(tmp_copy))

    draft_path = Path(f"{tmp_copy}.fea-draft")
    assert draft_path.exists()
    assert draft_path.read_text(encoding="utf-8") == returned

    fm = _parse_frontmatter(draft_path)
    assert fm is not None
    assert int(fm["version"]) == FIXTURE_VERSION + 1

    actions = fm["remaining_actions"]
    assert isinstance(actions, list) and actions
    first = actions[0]
    assert first.startswith("DECISION:")
    assert "KILL" in first

    # The committed fixture must be untouched by the draft.
    assert FIXTURE.read_bytes() == before_bytes
