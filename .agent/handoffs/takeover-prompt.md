# Takeover Prompt

Paste this into Claude / Codex / Cursor when starting a continuation
session. The next agent must not trust chat history — it must
reconstruct state from files only.

---

You are continuing work that another agent started. Chat history from
the previous session is unreliable or unavailable.

Do these steps in order, before acting on anything. **Steps 1-3 are
the same 3-step ritual used by `CLAUDE.md` and `WORKFLOW.md §0`.**
Steps 4-7 are the additional takeover-specific verification.

1. **Read `.agent/handoffs/CURRENT.md`** — cross-agent SSOT. Parse the
   yaml frontmatter (`owner_agent`, `last_updated`, `active_slice`,
   `remaining_actions`, `contract_pointers`). The Markdown body has
   the human-readable detail.
2. **Identify the active slice from `active_slice`**. Read
   `.agent/status/<slice>.md`. If mtime > 7 days, prefer the live
   scan in your harness if one exists.
3. **Drill down to `.agent/projects/<slice>-harness.md`** when the
   remaining action requires more workflow detail than the status
   file carries.
4. Read each contract listed in `contract_pointers`.
5. Run these *read-only* git commands and review:
   - `git status --short`
   - `git --no-pager diff --stat`
   - `git --no-pager log -n 10 --oneline`
6. Open `.agent/handoffs/state/diff.patch` and
   `.agent/handoffs/state/git-status.txt` if they exist. They are the
   snapshot the previous agent left. Cross-check against step 5 — if
   they disagree, stop and report the conflict before doing anything.
7. Read `AGENTS.md` (or `CLAUDE.md` for Claude) at the workspace root,
   and the most specific nested `AGENTS.md` in the active project.

Only then:

8. Restate the goal in your own words and list the next action you
   will take. Wait for the human to confirm before any write, run, or
   submit.

## Hard rules

- Do not invent state that is not in CURRENT.md, git status, or diff.
- Do not redo work that the diff shows is already done.
- Do not act on the `approval_required` list without explicit approval.
- If the goal in CURRENT.md is unclear, ambiguous, or stale, ask first.

## When you finish your turn

Before stopping, run:

```bash
./scripts/handoff.sh <your-agent-name>
```

and update CURRENT.md so the next agent can take over cleanly.
