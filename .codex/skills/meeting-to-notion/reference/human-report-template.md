# Human-First Report Template

Use this template for reports created through `meeting-to-notion`.

## Required Metadata

- Project:
- Slice: Use `none` for project-level reports.
- Scope: `project` or `slice`
- Report Type:
- Audience:
- Date Range:
- Status: `Reviewed` after user confirms the draft.

## Body Order

Reports are for humans first. Put interpretation before evidence.

```markdown
# {Project or Slice} — {YYYY-MM-DD} {Report Type}

## One-Line Conclusion
{The decision-grade takeaway in one sentence.}

## What Changed
- {The most important change, written as a human-readable claim.}
- {The second most important change.}
- {The third most important change, if needed.}

## What We Believe Now
- {A conclusion reliable enough to act on.}
- {Another current belief, including confidence if useful.}

## What We Should Not Believe Yet
- {A tempting but unsupported conclusion.}
- {A remaining uncertainty or known limitation.}

## Decisions Needed
- **{Decision title}** — {What must be decided and why now.}

## Next Actions
- {Action} — Owner: {owner or role}. Trigger: {when to do it}. Artifact: {expected output}.

## Evidence And Sources
- Status: `.agent/status/{slice}.md`
- Index: `.agent/handoffs/CURRENT.md`
- Contract: `.agent/contracts/{contract}.md`
- Notion legacy reference: {page URL if relevant}
- Local artifact: `{path}`
```

## Writing Rules

- Do not put evidence tables before the human summary.
- Do not include a claim unless it is backed by a file, Notion page, job log, commit, or user-confirmed note.
- Use project-level reports for weekly digests, meeting briefs, and cross-slice summaries.
- Use slice-level reports for experiment closeouts, blocker analyses, and focused research updates.
- Keep the first read short enough for a three-minute pre-meeting scan.
