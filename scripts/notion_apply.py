#!/usr/bin/env python3
"""notion_apply.py — headless REST writer for the Slices-DB ROW (the "무인 직전"
last mile, contract harness-notion-headless-apply-20260609).

WHAT THIS IS / IS NOT
  - This writes the slice's Slices-DB ROW *properties* via the Notion REST API
    (PATCH /v1/pages/{id}) using only the NOTION_TOKEN environment variable — the
    one surface that does NOT need interactive MCP auth.
  - The styled HOME cockpit is NOT written here: rich Notion-flavored-markdown ->
    blocks stays MCP-only (autosync + home-renderer ceiling). Use
    `notion_sync.py --emit-apply-plan <slice>` for the HOME one-shot.

AUTH BOUNDARY (honest):
  - `--dry-run` (default): builds + validates the REST payload OFFLINE. No token,
    no network. This is the CI-tested surface.
  - `--apply`: performs the live PATCH. Requires NOTION_TOKEN. *** The live path is
    UNVERIFIED until a token is provisioned (workspace perms currently block it) ***
    — it reuses notion_sync.slice_to_db_row so the field SET is proven; only the
    transport is new. Provisioning the token + any cron trigger is OUT of scope.

Usage:
  python3 scripts/notion_apply.py --slice NAME [--dry-run|--apply]
  (default is --dry-run; --apply needs NOTION_TOKEN and is gated/unverified.)
"""

import argparse
import importlib.util
import json
import os
import sys
import urllib.error
import urllib.request
from pathlib import Path

# Import the sibling notion_sync module by path (scripts/ is not a package) so we
# REUSE slice_to_db_row (the proven field set) + resolve_apply_ids (map-resolved
# row id) instead of re-deriving them.
_NS_PATH = Path(__file__).resolve().parent / "notion_sync.py"
_spec = importlib.util.spec_from_file_location("notion_sync", _NS_PATH)
notion_sync = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(notion_sync)

NOTION_API_VERSION = "2022-06-28"

# Slices-DB column name -> Notion property TYPE. The keys MUST cover every key
# slice_to_db_row() emits; an emitted key absent here is flagged as schema drift.
SLICES_SCHEMA: dict[str, str] = {
    "Name": "title",
    "Status": "select",
    "Headline": "rich_text",
    "Now": "rich_text",
    "Decision Needed": "rich_text",
    "Agent Next": "rich_text",
    "Blocker": "rich_text",
    "Owner Agent": "rich_text",
    "Owner Session": "rich_text",
    "Last Heartbeat": "date",
    "Last Updated": "date",
    "Project": "select",
    "Next Action": "rich_text",
    "Health": "select",
    "Sync Status": "select",
    "Last Sync Source": "rich_text",
    "State Body": "rich_text",
}

# Semantic fields slice_to_db_row() emits that are intentionally NOT Notion
# columns (computed/internal). Skipped silently — NOT schema drift. "Next" is the
# agent_next-when-different-from-now hint; the cockpit has 8 fields, none named
# "Next" (the column is "Next Action").
_NON_COLUMN_FIELDS = {"Next"}


def _prop_value(prop_type: str, value):
    """Render one semantic value into its Notion REST property shape. Empty
    strings become the Notion 'cleared' shape (null / [] ) for that type."""
    text = "" if value is None else str(value)
    if prop_type == "title":
        return {"title": [{"text": {"content": text}}] if text else []}
    if prop_type == "rich_text":
        return {"rich_text": [{"text": {"content": text}}] if text else []}
    if prop_type == "select":
        return {"select": {"name": text} if text else None}
    if prop_type == "date":
        # Notion parses a bare date ("YYYY-MM-DD") as date-only and a full ISO
        # timestamp as a datetime — pass the stored string straight through.
        return {"date": {"start": text} if text else None}
    raise ValueError(f"unknown property type: {prop_type}")


def build_row_properties(row: dict) -> tuple[dict, list[str]]:
    """Translate a slice_to_db_row() semantic dict into a Notion REST
    ``properties`` object. Returns (properties, drift) where ``drift`` lists any
    row keys with no SLICES_SCHEMA entry (schema drift — surfaced, not silently
    dropped). Pure / offline."""
    props: dict = {}
    drift: list[str] = []
    for key, value in row.items():
        if key in _NON_COLUMN_FIELDS:
            continue  # known computed field, not a Notion column
        prop_type = SLICES_SCHEMA.get(key)
        if prop_type is None:
            drift.append(key)  # genuine schema drift — surfaced, not sent
            continue
        props[key] = _prop_value(prop_type, value)
    return props, drift


def patch_row(page_id: str, properties: dict, token: str) -> int:
    """Live REST PATCH of a page's properties. *** UNVERIFIED until a real
    NOTION_TOKEN exists (workspace perms block it). *** stdlib-only (urllib)."""
    url = f"https://api.notion.com/v1/pages/{page_id}"
    body = json.dumps({"properties": properties}).encode("utf-8")
    req = urllib.request.Request(
        url,
        data=body,
        method="PATCH",
        headers={
            "Authorization": f"Bearer {token}",
            "Notion-Version": NOTION_API_VERSION,
            "Content-Type": "application/json",
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            print(f"PATCH {page_id} -> HTTP {resp.status}")
            return 0 if 200 <= resp.status < 300 else 1
    except urllib.error.HTTPError as exc:
        print(
            f"PATCH {page_id} FAILED: HTTP {exc.code} {exc.read()!r}", file=sys.stderr
        )
        return 1
    except urllib.error.URLError as exc:
        print(f"PATCH {page_id} FAILED: {exc}", file=sys.stderr)
        return 1


def run(slice_name: str, apply: bool) -> int:
    """Build the ROW payload (offline). On --apply, resolve the row id from the
    map and PATCH it (token-gated). Dry-run prints the payload and exits 0."""
    row = notion_sync.slice_to_db_row(slice_name)
    properties, drift = build_row_properties(row)

    for key in drift:
        print(
            f"warning: row field {key!r} has no SLICES_SCHEMA entry (schema drift) "
            "— not sent",
            file=sys.stderr,
        )

    if not apply:
        print(f"=== DRY-RUN: Slices-DB ROW properties for {slice_name} ===")
        print(json.dumps(properties, indent=2, ensure_ascii=False))
        print("=== (no token used, no network call) ===")
        return 0

    # --- live path (gated; UNVERIFIED until a token is provisioned) ---
    token = os.environ.get("NOTION_TOKEN")
    if not token:
        print(
            "NOTION_TOKEN not set — the live REST writer is blocked by workspace "
            "perms. Use --dry-run, or apply the row via the MCP bundle from "
            "`notion_sync.py --emit-apply-plan`.",
            file=sys.stderr,
        )
        return 2
    ids = notion_sync.resolve_apply_ids(slice_name)
    page_id = ids["row_page_id"]
    if not page_id:
        for err in ids["errors"]:
            if "slice_row_ids" in err:
                print(err, file=sys.stderr)
        return 2
    return patch_row(page_id, properties, token)


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    p = argparse.ArgumentParser(
        prog="notion_apply.py",
        description="Headless REST writer for a slice's Slices-DB ROW (dry-run by "
        "default; --apply is token-gated + UNVERIFIED).",
    )
    p.add_argument("--slice", dest="slice_name", metavar="NAME", required=True)
    mode = p.add_mutually_exclusive_group()
    mode.add_argument(
        "--dry-run",
        action="store_true",
        help="build + validate the REST payload offline; no token, no network (default)",
    )
    mode.add_argument(
        "--apply",
        action="store_true",
        help="live PATCH the row via REST (requires NOTION_TOKEN; UNVERIFIED)",
    )
    return p.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    return run(args.slice_name, apply=args.apply)


if __name__ == "__main__":
    sys.exit(main())
