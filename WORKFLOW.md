# WORKFLOW

One-screen router. **No facts here** — only "where to look next".
Authoritative content lives in `.agent/projects/*.md` and `AGENTS.md`.
If this file disagrees with them, this file is wrong.

## 0. Session start (3 steps, every session)

This is the **same** 3-step ritual that `CLAUDE.md` and
`.agent/handoffs/takeover-prompt.md` (steps 1-3) use. If you ever
see them in different orders, those files are out of sync — fix them.

1. **Read `.agent/handoffs/CURRENT.md`** — cross-agent SSOT. Trust
   this, not chat history. If `owner_agent` ≠ you, follow
   `takeover-prompt.md` steps 4-7 in addition.
2. **Identify the active slice**. If `CURRENT.md.active_slice` is
   set, use it. Otherwise consult §1 routing table below. Then read
   `.agent/status/<slice>.md`; if mtime > 7 days, prefer the live
   scan.
3. **Drill down only if the task needs more context** —
   `.agent/projects/<slice>-harness.md`. Do NOT pre-read all of them;
   pull on demand.

## 1. Which slice (fill in for your project)

| Work signal | Status (read first) | Harness (deep dive) | Critical reminder |
| --- | --- | --- | --- |
| `<keyword for slice-1>` | `.agent/status/slice-1.md` | `.agent/projects/slice-1-harness.md` | `<one-line caveat>` |
| `<keyword for slice-2>` | `.agent/status/slice-2.md` | `.agent/projects/slice-2-harness.md` | `<one-line caveat>` |
| (does not match) / new domain | ask the user | do NOT invent a slice | |

Add one row per workstream. Keep the work-signal column concrete
(filenames, feature names, ticket prefixes) — not abstract verbs.

## 2. Contract required? (project-scoped)

For your project, list the changes that REQUIRE creating a contract
under `.agent/contracts/<slice>-<short-name>-<YYYYMMDD>.md` before
acting. Default suggestions (delete what does not apply):

- 4 or more files modified in one logical change.
- Submitting a long-running / expensive job (training run, HPC
  submission, batch ETL).
- Changing ranking, scoring, or evaluation semantics.
- Modifying a public API contract.
- Touching two write scopes in one task (e.g. local repo and shared
  storage).
- Adding a new "mode" to a feature that has a registry of modes.

The PreToolUse hook `pre-bash-slurm-gate.sh` (if enabled) enforces
the SLURM trigger automatically. Other triggers are enforced by
agent discipline + the `/contract-check` skill.

## 3. Stop and request approval before

These are user-visible side effects. Always confirm before:

- Submitting long-running jobs (and include the exact resource
  request in the ask).
- Deleting or overwriting outputs under shared storage.
- Changing production defaults (ranking, scoring, anything user
  software depends on).
- Committing imported / backported files from another branch.
- Executing remote bootstrap scripts.
- Synchronizing with `--delete` over an existing tree.
- Destructive git operations (force push, hard reset, branch -D).

The destructive ones are auto-blocked by
`pre-bash-destructive-gate.sh`.

## 4. End of session

- Verification gate: slice-specific check + workspace
  `scripts/verify.sh` (you provide).
- Handoff: `./scripts/handoff.sh <next-agent>` + fill in
  `CURRENT.md` (use `/handoff` to be guided). No `<placeholder>`
  fields.
- **Status refresh**: whichever slice you worked on, overwrite its
  `.agent/status/<slice>.md` with the current snapshot. Keep under
  ~25 lines.

## 5. When this router cannot answer

You hit a routing edge case. Read the relevant harness directly,
then update the table in §1 so the next session does not hit the
same edge.
