---
owner_agent: human
last_updated: 2026-05-20
active_slice: ~
session_title: "Initial setup — claude-codex-coordination harness adopted"
files_touched_count: 0
verification_run: false
verification_result: "n/a"
failure_log: "n/a"
remaining_actions:
  - "Fill in WORKFLOW.md §1 routing table with your project's slices"
  - "Create .agent/status/<slice>.md and .agent/projects/<slice>-harness.md per slice"
  - "Update .claude/hooks/stop-handoff-check.sh VALID_SLICES set"
approval_required: []
contract_pointers: []
schema_version: 1
---

<!--
This file is the single entry point for "what is happening right now".
Any agent (Claude / Codex / Cursor / human) MUST read this before acting.
Update this file at the end of every working session, or before context
runs out. Do not rely on chat history — assume the next agent has none.

The YAML frontmatter above is machine-readable (validated by
.claude/hooks/stop-handoff-check.sh). The Markdown body below is the
human-readable detail. Both must stay consistent.
-->

# CURRENT WORK STATE

## Goal

This workspace was just initialized from the claude-codex-coordination
template. Before doing any project work, complete the setup checklist
in `remaining_actions` above.

## Current status

Template files are in place. Slice routing table is empty.

## Files touched this session

n/a — initial commit only.

## Verification run

n/a.

## Failure / error log location

n/a.

## Memory / contract pointers

- No contracts yet.
- No status files yet.

## Next agent actions

See `remaining_actions` in the frontmatter above. The session-start
hook will warn you about empty slice mappings and missing status
files until you fill them in.
