# .agent/ — cross-agent state

This directory is **shared by all agents** operating in this workspace
(Claude, Codex, Cursor) and by humans. It holds:

| Path | What | Read frequency |
|---|---|---|
| `handoffs/CURRENT.md` | Cross-agent SSOT — what's happening now. | Every session start. |
| `handoffs/handoff.md` | The handoff protocol (field requirements). | When ending a session. |
| `handoffs/takeover-prompt.md` | Steps for taking over from another agent. | When `CURRENT.md.owner_agent` ≠ you. |
| `handoffs/state/` | Auto-generated git state snapshot from `scripts/handoff.sh`. | When verifying a takeover. |
| `handoffs/archive/` | Past CURRENT.md + state snapshots (manual rotation). | Rarely; for forensics. |
| `status/<slice>.md` | Per-slice human-written status (≤ ~25 lines). | When entering a slice. |
| `projects/<slice>-harness.md` | Per-slice deep workflow detail. | When the status file isn't enough. |
| `contracts/<slice>-<topic>-<date>.md` | Approved scope/budget/criteria for a non-trivial change. | When `/contract-check` triggers. |
| `contracts/_template.md` | Template for new contracts. | When drafting. |

**Naming convention** for contracts and harness files:
`<slice>-<short-topic>-<YYYYMMDD>.md` for contracts;
`<slice>-harness.md` (or with a date suffix for time-stamped variants)
for project harnesses.

**Workspace-vs-project repos**: this `.agent/` is at the workspace
root and is *not* inside any specific project repo. Project repos
have their own `.git/`; this workspace can also be a git tree (and is
in the recommended setup), so the coordination layer is versioned
separately from your code.
