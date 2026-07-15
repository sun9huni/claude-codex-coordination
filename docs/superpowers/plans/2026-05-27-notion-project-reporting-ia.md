# Notion Project Reporting IA Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a human-centered Notion reporting flow with project/slice hubs plus shared Reports, Decisions, and Artifacts databases, and update the local skills so future reports publish into that structure.

**Architecture:** Local skill instructions define the workflow, templates, and guardrails. Notion holds the human-facing project/slice hubs and the structured shared databases. The implementation is split into local-only changes first, then an explicit approval-gated Notion schema/page creation pass, then E2E publish verification.

**Tech Stack:** Markdown skills, Bash verification scripts, Notion MCP tools, Notion-flavored Markdown, existing `.agent` harness state.

---

## File Structure

Create or modify these files only:

- Modify: `skills/meeting-to-notion/SKILL.md`
- Modify: `.codex/skills/meeting-to-notion/SKILL.md`
- Modify: `.claude/skills/meeting-to-notion/SKILL.md`
- Create: `skills/meeting-to-notion/reference/human-report-template.md`
- Create: `.codex/skills/meeting-to-notion/reference/human-report-template.md`
- Create: `.claude/skills/meeting-to-notion/reference/human-report-template.md`
- Modify: `.codex/skills/notion-knowledge-capture/SKILL.md`
- Modify: `.claude/skills/notion-knowledge-capture/SKILL.md`
- Create: `.codex/skills/notion-knowledge-capture/reference/project-reporting-ia.md`
- Create: `.claude/skills/notion-knowledge-capture/reference/project-reporting-ia.md`
- Create: `docs/superpowers/plans/2026-05-27-notion-project-reporting-ia.md`

Do not edit `.agent/status/*`, `.agent/handoffs/CURRENT.md`, or existing Notion pages during the local skill update tasks.

Notion-side objects to create after explicit approval:

- Page: `Research / Project Home`
- Page: `FKSFold-Boltz Advancement`
- Page: `Harness / Agent Ops`
- Page: active slice hubs for `fragmap`, `mmgbsa`, `vav1`, `fksfold-core`, and `harness`
- Data source: `Reports`
- Data source: `Decisions`
- Data source: `Artifacts`

---

### Task 1: Add the human-first report template to `meeting-to-notion`

**Files:**
- Create: `skills/meeting-to-notion/reference/human-report-template.md`
- Create: `.codex/skills/meeting-to-notion/reference/human-report-template.md`
- Create: `.claude/skills/meeting-to-notion/reference/human-report-template.md`

- [ ] **Step 1: Create the root template**

Create `skills/meeting-to-notion/reference/human-report-template.md` with exactly this content:

````markdown
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
````

- [ ] **Step 2: Copy the template to Codex and Claude skill mirrors**

Run:

```bash
mkdir -p .codex/skills/meeting-to-notion/reference .claude/skills/meeting-to-notion/reference
cp skills/meeting-to-notion/reference/human-report-template.md .codex/skills/meeting-to-notion/reference/human-report-template.md
cp skills/meeting-to-notion/reference/human-report-template.md .claude/skills/meeting-to-notion/reference/human-report-template.md
```

Expected: no output and all three template files exist.

- [ ] **Step 3: Verify the template files match**

Run:

```bash
cmp skills/meeting-to-notion/reference/human-report-template.md .codex/skills/meeting-to-notion/reference/human-report-template.md
cmp skills/meeting-to-notion/reference/human-report-template.md .claude/skills/meeting-to-notion/reference/human-report-template.md
```

Expected: no output from both `cmp` commands.

- [ ] **Step 4: Commit**

Run:

```bash
git add skills/meeting-to-notion/reference/human-report-template.md .codex/skills/meeting-to-notion/reference/human-report-template.md .claude/skills/meeting-to-notion/reference/human-report-template.md
git commit -m "docs: add human-first Notion report template"
```

Expected: commit succeeds with three new files.

---

### Task 2: Update `meeting-to-notion` workflow instructions

**Files:**
- Modify: `skills/meeting-to-notion/SKILL.md`
- Modify: `.codex/skills/meeting-to-notion/SKILL.md`
- Modify: `.claude/skills/meeting-to-notion/SKILL.md`

- [ ] **Step 1: Update the root skill workflow**

In `skills/meeting-to-notion/SKILL.md`, replace the current `## Workflow` section with this text:

```markdown
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
```

- [ ] **Step 2: Add the IA reference note**

In `skills/meeting-to-notion/SKILL.md`, replace the current `## Guardrails` introduction with this text, preserving the existing bullet list below it:

```markdown
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
```

- [ ] **Step 3: Mirror the root skill to Codex and Claude**

Run:

```bash
cp skills/meeting-to-notion/SKILL.md .codex/skills/meeting-to-notion/SKILL.md
cp skills/meeting-to-notion/SKILL.md .claude/skills/meeting-to-notion/SKILL.md
```

Expected: no output.

- [ ] **Step 4: Run skill lint**

Run:

```bash
bash tests/run-skill-lint.sh
```

Expected: `PASS: 14    FAIL: 0`.

- [ ] **Step 5: Commit**

Run:

```bash
git add skills/meeting-to-notion/SKILL.md .codex/skills/meeting-to-notion/SKILL.md .claude/skills/meeting-to-notion/SKILL.md
git commit -m "docs: update meeting-to-notion reporting workflow"
```

Expected: commit succeeds.

---

### Task 3: Add project reporting IA reference to `notion-knowledge-capture`

**Files:**
- Create: `.codex/skills/notion-knowledge-capture/reference/project-reporting-ia.md`
- Create: `.claude/skills/notion-knowledge-capture/reference/project-reporting-ia.md`
- Modify: `.codex/skills/notion-knowledge-capture/SKILL.md`
- Modify: `.claude/skills/notion-knowledge-capture/SKILL.md`

- [ ] **Step 1: Create the Codex IA reference**

Create `.codex/skills/notion-knowledge-capture/reference/project-reporting-ia.md` with exactly this content:

```markdown
# Project Reporting IA

Use this reference when publishing project or slice reports from `meeting-to-notion`.

## Target Structure

- Project and slice hub pages are the human reading layer.
- `Reports`, `Decisions`, and `Artifacts` are the structured database layer.
- Legacy `프로젝트기록` pages remain reachable and should not be bulk-migrated in the first pass.

## Reports DB

Required properties:

- `Title`
- `Project`
- `Slice`
- `Report Type`
- `Date`
- `Status`
- `Audience`
- `Related Decisions`
- `Related Artifacts`
- `Legacy Source`

## Decisions DB

Required properties:

- `Title`
- `Project`
- `Slice`
- `Decision Status`
- `Date`
- `Owner`
- `Related Reports`
- `Related Artifacts`
- `Outcome`

## Artifacts DB

Required properties:

- `Title`
- `Project`
- `Slice`
- `Artifact Type`
- `Path or URL`
- `Date`
- `Related Reports`
- `Related Decisions`
- `Notes`

## Capture Rules

- Search for related project, slice, and legacy pages before creating a new page.
- Prefer linking legacy pages over moving or rewriting them.
- Create a `Reports` record for reviewed reports.
- Create or link `Decisions` records only when a decision is explicit.
- Create or link `Artifacts` records for source files, contracts, figures, datasets, scripts, SLURM outputs, and Notion references.
```

- [ ] **Step 2: Copy the IA reference to Claude**

Run:

```bash
cp .codex/skills/notion-knowledge-capture/reference/project-reporting-ia.md .claude/skills/notion-knowledge-capture/reference/project-reporting-ia.md
```

Expected: no output.

- [ ] **Step 3: Update both `notion-knowledge-capture` SKILL files**

In both `.codex/skills/notion-knowledge-capture/SKILL.md` and `.claude/skills/notion-knowledge-capture/SKILL.md`, add this bullet under `## References and examples`:

```markdown
- `reference/project-reporting-ia.md` — human-centered project/slice reporting IA used by `meeting-to-notion`.
```

- [ ] **Step 4: Run skill lint**

Run:

```bash
bash tests/run-skill-lint.sh
```

Expected: `PASS: 14    FAIL: 0`.

- [ ] **Step 5: Commit**

Run:

```bash
git add .codex/skills/notion-knowledge-capture/reference/project-reporting-ia.md .claude/skills/notion-knowledge-capture/reference/project-reporting-ia.md .codex/skills/notion-knowledge-capture/SKILL.md .claude/skills/notion-knowledge-capture/SKILL.md
git commit -m "docs: add Notion project reporting IA reference"
```

Expected: commit succeeds.

---

### Task 4: Create the Notion IA objects after approval

**Files:**
- No local files modified.

**Approval Gate:** This task creates Notion databases and pages. Before executing, ask the user: "Approve creating the Notion Reports, Decisions, Artifacts databases and the first project/slice hub pages?"

- [ ] **Step 1: Fetch the current home and legacy database**

Use Notion MCP:

```text
notion_fetch id="https://www.notion.so/28d1e76c3b608069a83beab69a131a99"
notion_fetch id="collection://28e1e76c-3b60-8073-995c-000b4348f456"
```

Expected: the first fetch returns the `홈` page; the second returns the legacy `프로젝트기록` data source.

- [ ] **Step 2: Create `Reports` database**

Use Notion MCP `notion_create_database` with this schema:

```sql
CREATE TABLE (
  "Title" TITLE,
  "Project" SELECT('FKSFold-Boltz Advancement':blue, 'Harness / Agent Ops':brown, 'DeepTernary':green, 'BindCraft':purple),
  "Slice" SELECT('none':default, 'fragmap':blue, 'mmgbsa':red, 'vav1':green, 'fksfold-core':purple, 'arl':yellow, 'harness':brown),
  "Report Type" SELECT('Weekly Digest':blue, 'Meeting Brief':green, 'Research Update':purple, 'Experiment Closeout':orange, 'E2E Verification':brown, 'Operational Update':gray),
  "Date" DATE,
  "Status" SELECT('Draft':gray, 'Reviewed':yellow, 'Published':green, 'Superseded':red),
  "Audience" SELECT('internal research':blue, 'engineering handoff':green, 'leadership':purple),
  "Legacy Source" URL
)
```

Parent: `홈` page.

Expected: Notion returns a database URL and a `collection://...` data source ID. Record both in the task notes.

- [ ] **Step 3: Create `Decisions` database**

Use Notion MCP `notion_create_database` with this schema:

```sql
CREATE TABLE (
  "Title" TITLE,
  "Project" SELECT('FKSFold-Boltz Advancement':blue, 'Harness / Agent Ops':brown, 'DeepTernary':green, 'BindCraft':purple),
  "Slice" SELECT('none':default, 'fragmap':blue, 'mmgbsa':red, 'vav1':green, 'fksfold-core':purple, 'arl':yellow, 'harness':brown),
  "Decision Status" SELECT('Open':yellow, 'Decided':green, 'Deferred':gray, 'Reversed':red, 'Superseded':orange),
  "Date" DATE,
  "Owner" RICH_TEXT,
  "Outcome" RICH_TEXT
)
```

Parent: `홈` page.

Expected: Notion returns a database URL and a `collection://...` data source ID. Record both in the task notes.

- [ ] **Step 4: Create `Artifacts` database**

Use Notion MCP `notion_create_database` with this schema:

```sql
CREATE TABLE (
  "Title" TITLE,
  "Project" SELECT('FKSFold-Boltz Advancement':blue, 'Harness / Agent Ops':brown, 'DeepTernary':green, 'BindCraft':purple),
  "Slice" SELECT('none':default, 'fragmap':blue, 'mmgbsa':red, 'vav1':green, 'fksfold-core':purple, 'arl':yellow, 'harness':brown),
  "Artifact Type" SELECT('Contract':blue, 'Status Baton':green, 'Local File':gray, 'Figure':purple, 'Dataset':orange, 'Script':yellow, 'SLURM Output':red, 'Notion Page':brown),
  "Path or URL" RICH_TEXT,
  "Date" DATE,
  "Notes" RICH_TEXT
)
```

Parent: `홈` page.

Expected: Notion returns a database URL and a `collection://...` data source ID. Record both in the task notes.

- [ ] **Step 5: Add relation properties between the three databases**

Use Notion MCP `notion_update_data_source` after all three data source IDs are known.

For the Reports data source, run statements equivalent to:

```sql
ADD COLUMN "Related Decisions" RELATION('DECISIONS_DATA_SOURCE_ID');
ADD COLUMN "Related Artifacts" RELATION('ARTIFACTS_DATA_SOURCE_ID')
```

For the Decisions data source, run statements equivalent to:

```sql
ADD COLUMN "Related Reports" RELATION('REPORTS_DATA_SOURCE_ID');
ADD COLUMN "Related Artifacts" RELATION('ARTIFACTS_DATA_SOURCE_ID')
```

For the Artifacts data source, run statements equivalent to:

```sql
ADD COLUMN "Related Reports" RELATION('REPORTS_DATA_SOURCE_ID');
ADD COLUMN "Related Decisions" RELATION('DECISIONS_DATA_SOURCE_ID')
```

Use the actual data source IDs returned by Steps 2, 3, and 4 in place of the uppercase ID names above.

Expected: fetching all three data sources shows the relation columns.

- [ ] **Step 6: Create project hub pages**

Use Notion MCP `notion_create_pages` under the `홈` page with two pages:

```markdown
# Current Read
This page is the human-facing hub for FKSFold-Boltz project reporting. It summarizes current understanding and links to reports, decisions, artifacts, slice hubs, and legacy references.

## This Week's Most Important Changes
- No project hub summary has been written yet.

## Current Beliefs
- This hub will be updated after the first reviewed project-level report.

## Open Decisions
Linked decisions view to be added after database creation.

## Recent Reports
Linked reports view to be added after database creation.

## Slices
- fragmap
- mmgbsa
- vav1
- fksfold-core

## Legacy References
- Legacy database: 프로젝트기록
```

Title: `FKSFold-Boltz Advancement`

```markdown
# Current Read
This page is the human-facing hub for harness and agent operations reporting. It summarizes Codex/Claude coordination, skills, tools, and handoff infrastructure.

## This Week's Most Important Changes
- No project hub summary has been written yet.

## Current Beliefs
- This hub will be updated after the first reviewed harness project-level report.

## Open Decisions
Linked decisions view to be added after database creation.

## Recent Reports
Linked reports view to be added after database creation.

## Slices
- harness

## Legacy References
- Legacy database: 프로젝트기록
```

Title: `Harness / Agent Ops`

Expected: Notion returns two page URLs.

- [ ] **Step 7: Create active slice hub pages**

Use Notion MCP `notion_create_pages` under the relevant project hub pages:

For `FKSFold-Boltz Advancement`, create pages titled:

- `fragmap`
- `mmgbsa`
- `vav1`
- `fksfold-core`

For `Harness / Agent Ops`, create page titled:

- `harness`

Each page should use this body:

```markdown
## Question This Slice Answers
This section will be filled from the next reviewed slice-level report.

## Current Conclusion
No reviewed slice conclusion has been written into the new reporting IA yet.

## Recent Reports
Linked reports view to be added after database creation.

## Open Decisions
Linked decisions view to be added after database creation.

## Key Artifacts
Linked artifacts view to be added after database creation.

## Legacy References
Legacy pages from `프로젝트기록` should be linked here when they become active again.
```

Expected: Notion returns five page URLs.

- [ ] **Step 8: Create linked views**

Use Notion MCP `notion_create_view` to add linked views:

- On `FKSFold-Boltz Advancement`: Reports filtered to `Project = FKSFold-Boltz Advancement`; Decisions filtered to `Project = FKSFold-Boltz Advancement`; Artifacts filtered to `Project = FKSFold-Boltz Advancement`.
- On `Harness / Agent Ops`: Reports filtered to `Project = Harness / Agent Ops`; Decisions filtered to `Project = Harness / Agent Ops`; Artifacts filtered to `Project = Harness / Agent Ops`.
- On each slice page: Reports, Decisions, and Artifacts filtered by both Project and Slice.

Expected: linked views appear on the hub pages.

- [ ] **Step 9: Fetch created pages**

Use Notion MCP `notion_fetch` for each new project hub, one slice hub, and all three data sources.

Expected: fetch output shows the created content and schemas.

---

### Task 5: Publish one project-level and one slice-level E2E report

**Files:**
- No local files modified unless the user explicitly asks to update `.agent/status/harness.md`.

- [ ] **Step 1: Draft project-level report**

Draft a `Harness / Agent Ops` project-level `Operational Update` using the human-first template.

Minimum content:

```markdown
# Harness / Agent Ops — 2026-05-27 Operational Update

## One-Line Conclusion
The Notion project reporting IA is ready for structured E2E validation after local skill updates and Notion object creation.

## What Changed
- The reporting design now separates human-facing project/slice hubs from structured Reports, Decisions, and Artifacts databases.
- The first E2E Notion write path was already verified through the legacy `프로젝트기록` database.

## What We Believe Now
- Reviewed reports should publish into the shared Reports database.
- Project and slice hubs should be the primary human reading surface.

## What We Should Not Believe Yet
- The legacy `프로젝트기록` database is not migrated.
- Linked views and relations are not validated until the new IA objects exist.

## Decisions Needed
- **Migration pace** — Keep progressive migration and move only high-value legacy pages when needed.

## Next Actions
- Create shared databases and hub pages after approval. Owner: Codex. Trigger: user approval. Artifact: Notion URLs.

## Evidence And Sources
- Spec: `docs/superpowers/specs/2026-05-27-notion-project-reporting-ia-design.md`
- Plan: `docs/superpowers/plans/2026-05-27-notion-project-reporting-ia.md`
- Test page: `https://www.notion.so/36d1e76c3b6081318790ebbac467db0f`
```

- [ ] **Step 2: Ask user to review the project-level draft**

Ask:

```text
Approve publishing this project-level Harness / Agent Ops report to the new Reports database?
```

Expected: user confirms before any write.

- [ ] **Step 3: Publish project-level report**

Use Notion MCP `notion_create_pages` with parent set to the `Reports` data source ID from Task 4.

Properties:

```json
{
  "Title": "Harness / Agent Ops — 2026-05-27 Operational Update",
  "Project": "Harness / Agent Ops",
  "Slice": "none",
  "Report Type": "Operational Update",
  "date:Date:start": "2026-05-27",
  "date:Date:is_datetime": 0,
  "Status": "Reviewed",
  "Audience": "engineering handoff",
  "Legacy Source": "https://www.notion.so/36d1e76c3b6081318790ebbac467db0f"
}
```

Expected: Notion returns a page URL.

- [ ] **Step 4: Draft slice-level report**

Draft a `harness` slice-level `E2E Verification` report using the human-first template.

Minimum content:

```markdown
# harness — 2026-05-27 E2E Verification

## One-Line Conclusion
The `meeting-to-notion` and `notion-knowledge-capture` path can publish reviewed, human-first reports into the new reporting IA.

## What Changed
- The report template now prioritizes human interpretation before evidence.
- The Notion target now distinguishes project, slice, report type, date, status, and audience.

## What We Believe Now
- The flow is usable for project-level and slice-level reports after fetch-back verification.

## What We Should Not Believe Yet
- Relation completeness is not proven until Reports, Decisions, and Artifacts links are exercised.

## Decisions Needed
- **Relation automation depth** — Decide whether relation creation should be manual in the first pass or automated in the next pass.

## Next Actions
- Fetch the published report and verify properties and body. Owner: Codex. Trigger: publish success. Artifact: fetched Notion page.

## Evidence And Sources
- Skill: `skills/meeting-to-notion/SKILL.md`
- Skill: `.codex/skills/notion-knowledge-capture/SKILL.md`
- Verification command: `bash tests/run-skill-lint.sh`
```

- [ ] **Step 5: Ask user to review the slice-level draft**

Ask:

```text
Approve publishing this slice-level harness E2E report to the new Reports database?
```

Expected: user confirms before any write.

- [ ] **Step 6: Publish slice-level report**

Use Notion MCP `notion_create_pages` with parent set to the `Reports` data source ID from Task 4.

Properties:

```json
{
  "Title": "harness — 2026-05-27 E2E Verification",
  "Project": "Harness / Agent Ops",
  "Slice": "harness",
  "Report Type": "E2E Verification",
  "date:Date:start": "2026-05-27",
  "date:Date:is_datetime": 0,
  "Status": "Reviewed",
  "Audience": "engineering handoff"
}
```

Expected: Notion returns a page URL.

- [ ] **Step 7: Fetch and verify both reports**

Use Notion MCP `notion_fetch` for both created pages.

Expected:

- Page titles match the requested titles.
- Properties include Project, Slice, Report Type, Date, Status, and Audience.
- Body begins with `One-Line Conclusion` before evidence.

---

### Task 6: Final verification and local handoff

**Files:**
- Modify only if the user asks: `.agent/status/harness.md`

- [ ] **Step 1: Run local verification**

Run:

```bash
bash tests/run-skill-lint.sh
bash scripts/tool-audit.sh
bash scripts/skills-sync.sh --dry-run
```

Expected:

- `tests/run-skill-lint.sh` ends with `PASS: 14    FAIL: 0`
- `scripts/tool-audit.sh` finishes without error
- `scripts/skills-sync.sh --dry-run` finishes without error

- [ ] **Step 2: Summarize Notion verification**

Prepare this summary:

```text
Notion IA verification:
- Reports DB: paste the created Reports database URL here
- Decisions DB: paste the created Decisions database URL here
- Artifacts DB: paste the created Artifacts database URL here
- Project hub: paste the created project hub URL here
- Slice hub tested: paste the fetched slice hub URL here
- Project-level report: paste the published project-level report URL here
- Slice-level report: paste the published slice-level report URL here
- Fetch-back verification: PASS
```

- [ ] **Step 3: Ask before updating harness status**

Ask:

```text
Do you want me to record these Notion URLs in `.agent/status/harness.md` and refresh the handoff index?
```

Expected: no local handoff status change unless user confirms.

- [ ] **Step 4: If user confirms, update harness status using `handoff-writer`**

Use `handoff-writer` and update only `.agent/status/harness.md`. Then run:

```bash
./scripts/handoff.sh codex harness
./scripts/status.sh index
```

Expected: `.agent/handoffs/CURRENT.md` is regenerated, not hand-edited.

- [ ] **Step 5: Commit local skill changes if any remain uncommitted**

Run:

```bash
git status --short
```

Expected: only unrelated pre-existing dirty files remain. If local skill files from this plan are uncommitted, commit them with:

```bash
git add skills/meeting-to-notion .codex/skills/meeting-to-notion .claude/skills/meeting-to-notion .codex/skills/notion-knowledge-capture .claude/skills/notion-knowledge-capture
git commit -m "docs: finalize Notion reporting skill updates"
```

Expected: commit succeeds or there are no remaining plan-related files to commit.

---

## Self-Review

Spec coverage:

- Human-first report order is implemented in Task 1 and Task 2.
- Project/slice mixed publishing is implemented in Task 2 and verified in Task 5.
- Shared Reports, Decisions, and Artifacts DBs are created in Task 4.
- Progressive legacy handling is included in Task 3 and Task 4.
- E2E Notion write and fetch-back verification are covered in Task 5.
- Local verification commands are covered in Task 6.

Red-flag scan:

- The plan avoids angle-bracket fill-ins.
- Runtime-created Notion IDs and URLs are described as values returned by previous steps.

Approval gates:

- Notion database and page creation is explicitly gated in Task 4.
- Publishing reviewed reports is explicitly gated in Task 5.
- Local handoff status updates are explicitly gated in Task 6.
