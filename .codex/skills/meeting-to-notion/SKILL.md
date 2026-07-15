---
name: meeting-to-notion
description: Use when the user wants to turn a meeting-report style project digest into a structured Notion page. Combines local evidence from .agent/status, contracts, git, and SLURM with notion-knowledge-capture, with user confirmation before writing to Notion.
license: MIT
---

# Meeting To Notion

Turn a local, evidence-backed project digest into a structured Notion page.
This skill bridges the Claude `/meeting-report` workflow and the
`notion-knowledge-capture` skill.

## When To Use

- The user asks to publish a weekly/status/experiment report to Notion.
- The user asks to capture decisions, blockers, or next actions from a
  meeting-report digest.
- The source of truth is local harness state: `.agent/status/<slice>.md`,
  `.agent/handoffs/CURRENT.md`, `.agent/contracts/`, git history, and SLURM
  summaries.

## Workflow

1. Resolve scope before drafting:
   - `scope`: `project` or `slice`
   - `project`: e.g. `FKSFold-Boltz Advancement` or `Harness / Agent Ops`
   - `slice`: required only when `scope` is `slice`
   - `report_type`: `Weekly Digest`, `Meeting Brief`, `Research Update`, `Experiment Closeout`, `E2E Verification`, or `Operational Update`
   - `audience`: e.g. `internal research`, `engineering handoff`, or `leadership`
   - `date_range`: explicit dates
2. Produce or obtain a meeting-report digest:
   - In Claude Code, use `/meeting-report [slice-or-all] [range]` first.
   - In Codex, follow `.claude/skills/meeting-report/SKILL.md` as a read-only recipe: collect from the same files and cite every line.
3. Convert the digest into the human-first format in `reference/human-report-template.md`.
   - Start with the one-line conclusion.
   - Put "What Changed", "What We Believe Now", and "What We Should Not Believe Yet" before detailed evidence.
   - Keep source evidence in the final section.
4. Show the draft to the user and ask for confirmation before any Notion write. Do not publish directly from an unreviewed draft.
5. Use `notion-knowledge-capture` to create or update the Notion page:
   - Search Notion for existing project, slice, and legacy `프로젝트기록` pages first.
   - Publish reviewed reports into the shared `Reports` database when it exists.
   - Link related `Decisions` and `Artifacts` records when they already exist.
   - If the new reporting IA does not exist yet, ask before creating databases or hub pages.
6. Return the Notion page URL and a short local handoff note. If useful, add the Notion URL as a pointer in the relevant slice status only after the user asks for that local state update.

## Notion MCP

If Notion tools are unavailable, pause and set up Notion MCP instead of
pretending the page was published:

```bash
codex mcp add notion --url https://mcp.notion.com/mcp
codex mcp login notion
```

Enable the remote MCP client in Codex config if needed, then restart Codex.

## Project Reporting IA

Target Notion structure:

- Human-facing project and slice hub pages.
- Shared `Reports`, `Decisions`, and `Artifacts` databases.
- Existing `프로젝트기록` remains a legacy archive/reference during the first migration phase.

Report publishing rules:

- Project-level reports are for weekly digests, meeting briefs, and cross-slice summaries.
- Slice-level reports are for experiment closeouts, blocker analyses, and focused technical decisions.
- Evidence is mandatory, but it belongs after the human-readable summary.

## Guardrails

- Do not modify `.agent/status/*`, `.agent/contracts/*`, or
  `.agent/handoffs/CURRENT.md` while compiling the digest.
- Do not publish facts that are not backed by a file, contract, commit,
  job log, or user-confirmed note.
- Do not write to Notion before the user confirms the digest.
- Do not embed local image paths as Notion images; list them as text paths
  unless they are accessible URLs.
- Keep the Notion page concise: summary, decisions, blockers, next actions,
  artifacts, and references.

## Red Flags

| Rationalization | Reality |
|---|---|
| "The report looks obvious, I'll publish it directly." | Notion is durable project memory. Show the digest first and wait for user approval before writing. |
| "I'll fill gaps from chat context." | Chat is not durable. If the fact is not in a source file, commit, job log, or user-confirmed note, leave it out. |
| "I'll update status files while preparing the Notion page." | This skill is read-only on coordination state. Local baton updates are a separate handoff action. |
| "I'll embed local PNG paths." | Notion cannot fetch local `/home` or `/mnt` paths. List them as artifact paths unless they are accessible URLs. |

## Forbidden

- Do NOT write to Notion before the user approves the draft.
- Do NOT modify `.agent/status/*`, `.agent/contracts/*`, or
  `.agent/handoffs/CURRENT.md` during digest compilation.
- Do NOT include uncited claims in the Notion page.
- Do NOT embed local filesystem images as Notion images.
