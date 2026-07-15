# Notion Project Reporting IA Design

Date: 2026-05-27
Status: written for user review
Scope: `meeting-to-notion`, `notion-knowledge-capture`, and Notion workspace information architecture

## Purpose

The current `meeting-to-notion` path can publish a reviewed digest to Notion, but the first E2E test showed that the destination structure is still too flat for long-term human use. Reports should not read like machine logs or isolated snapshots. They should help a person understand what changed, why it matters, what is believed, what is uncertain, and what should happen next.

This design creates a human-centered Notion structure for project and slice reporting while preserving structured databases for search, filtering, automation, and evidence tracking.

## Design Principles

1. Put human judgment before evidence tables.
2. Separate the reading experience from the database layer.
3. Treat reports as time snapshots, not the only source of current truth.
4. Use project and slice hub pages as living entry points.
5. Keep legacy pages reachable without forcing a big-bang migration.

## Target Information Architecture

Use a hybrid structure:

```text
Research / Project Home
├─ Project Hubs
│  ├─ FKSFold-Boltz Advancement
│  │  ├─ Overview
│  │  ├─ Slice: fragmap
│  │  ├─ Slice: mmgbsa
│  │  ├─ Slice: vav1
│  │  └─ Slice: fksfold-core
│  └─ Harness / Agent Ops
│     ├─ Overview
│     └─ Slice: harness
├─ Reports DB
├─ Decisions DB
└─ Artifacts DB
```

Project and slice pages are written for humans. They should summarize current understanding, show recent reports, expose open decisions, and link to relevant artifacts.

The shared databases hold structured records. They should not replace readable hub pages.

## Shared Databases

### Reports DB

Stores project-level and slice-level reports.

Core properties:

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

Suggested `Report Type` values:

- `Weekly Digest`
- `Meeting Brief`
- `Research Update`
- `Experiment Closeout`
- `E2E Verification`
- `Operational Update`

Suggested `Status` values:

- `Draft`
- `Reviewed`
- `Published`
- `Superseded`

### Decisions DB

Stores decisions, deferred calls, alternatives, rationale, and outcomes.

Core properties:

- `Title`
- `Project`
- `Slice`
- `Decision Status`
- `Date`
- `Owner`
- `Related Reports`
- `Related Artifacts`
- `Outcome`

Suggested `Decision Status` values:

- `Open`
- `Decided`
- `Deferred`
- `Reversed`
- `Superseded`

### Artifacts DB

Stores evidence pointers and reusable references rather than embedding local files in reports.

Core properties:

- `Title`
- `Project`
- `Slice`
- `Artifact Type`
- `Path or URL`
- `Date`
- `Related Reports`
- `Related Decisions`
- `Notes`

Suggested `Artifact Type` values:

- `Contract`
- `Status Baton`
- `Local File`
- `Figure`
- `Dataset`
- `Script`
- `SLURM Output`
- `Notion Page`

## Reader Experience

The first screen of any report should support a three-minute pre-meeting read.

Report body order:

1. One-line conclusion
2. Most important changes
3. What we believe now
4. What we should not believe yet
5. Decisions needed
6. Next actions
7. Evidence and source links

Evidence remains mandatory, but it appears after the human-readable interpretation. Detailed source pointers should be collected in the final section and linked through `Artifacts DB` relations when available.

## Publishing Model

Use a mixed publishing model.

Project-level reports:

- Weekly reports
- Meeting briefs
- Cross-slice status summaries
- Leadership or stakeholder summaries

Slice-level reports:

- Experiment closeouts
- Important technical decisions
- Blocker analyses
- Focused research updates

`meeting-to-notion` should require a publish scope before drafting:

- `project`
- `slice`

It should also require these fields:

- Project
- Slice, if scope is `slice`
- Report Type
- Audience
- Date range

## Hub Page Templates

### Project Hub

Project hubs are living pages. They should answer: "Where are we, and what should I read next?"

Recommended structure:

```markdown
# {Project Name}

## Current Read
One paragraph on the current state and why it matters.

## This Week's Most Important Changes
- Change 1
- Change 2
- Change 3

## Current Beliefs
- What is reliable enough to act on
- What remains uncertain

## Open Decisions
Linked Decisions view filtered by Project and non-closed status.

## Recent Reports
Linked Reports view filtered by Project, sorted by Date descending.

## Slices
Links to slice hub pages.

## Legacy References
Links to important pages from the old `프로젝트기록` database.
```

### Slice Hub

Slice hubs are living pages for a specific workstream.

Recommended structure:

```markdown
# {Slice Name}

## Question This Slice Answers
One sentence describing the slice's purpose.

## Current Conclusion
The best current answer, including confidence and caveats.

## Recent Reports
Linked Reports view filtered by Project and Slice.

## Open Decisions
Linked Decisions view filtered by Project, Slice, and non-closed status.

## Key Artifacts
Linked Artifacts view filtered by Project and Slice.

## Legacy References
Links to high-value older pages.
```

## Migration Strategy

Use a progressive hybrid migration.

1. Create the clean `Reports`, `Decisions`, and `Artifacts` databases.
2. Create the first project hubs for `FKSFold-Boltz Advancement` and `Harness / Agent Ops`.
3. Create slice hubs for active slices.
4. Keep the existing `프로젝트기록` database as a legacy archive/reference.
5. Link high-value old pages from the relevant project or slice hubs.
6. Migrate old pages only when they become active again or are needed for a new report.

Do not bulk-migrate old Notion pages during the first implementation pass.

## Skill Behavior Changes

### `meeting-to-notion`

The skill should:

1. Resolve project, slice, date range, report type, and audience.
2. Generate a human-first draft in the report body order above.
3. Show the draft to the user before any Notion write.
4. Publish only after confirmation.
5. Create or update records in `Reports DB`.
6. Link related decisions and artifacts when they already exist.
7. Return the Notion URL and a short local handoff note.

The skill should not:

- Publish unreviewed drafts.
- Put evidence tables before the human summary.
- Treat local image paths as embedded Notion images.
- Modify local `.agent/status/*` files unless the user asks for local state updates.

### `notion-knowledge-capture`

The skill should:

1. Prefer the new shared databases for structured captures.
2. Use project and slice hubs as human-facing surfaces.
3. Search legacy `프로젝트기록` pages before creating duplicate content.
4. Link legacy pages rather than moving them during the first migration phase.

## Data Flow

```text
Local harness state
  ├─ .agent/status/<slice>.md
  ├─ .agent/handoffs/CURRENT.md
  ├─ .agent/contracts/*.md
  ├─ git history
  └─ job/artifact paths
        ↓
meeting-to-notion draft
        ↓ user review
notion-knowledge-capture publish
        ↓
Reports DB record
        ├─ related Decisions
        ├─ related Artifacts
        └─ appears in Project/Slice hub views
```

## Error Handling

- If Notion MCP is unavailable, stop and report the setup steps instead of pretending to publish.
- If the target database or hub page cannot be found, create a draft plan and ask for approval before creating new Notion structure.
- If multiple candidate legacy pages exist, link the most relevant pages and note ambiguity in the report.
- If source evidence is missing, omit the claim or mark it as user-provided context.
- If a publish succeeds but relation updates fail, return the page URL and list the missing relation updates.

## Verification

Implementation should be considered successful when:

1. A project-level report can be drafted, reviewed, published, and fetched back from Notion.
2. A slice-level report can be drafted, reviewed, published, and fetched back from Notion.
3. Reports include human-first sections before evidence.
4. Reports can be filtered by Project, Slice, Date, Type, and Status.
5. Existing `프로젝트기록` pages remain untouched and linked as legacy references.
6. `tests/run-skill-lint.sh`, `scripts/tool-audit.sh`, and `scripts/skills-sync.sh --dry-run` pass.

## Non-Goals

- No bulk migration of all existing Notion pages.
- No deletion or restructuring of `프로젝트기록` in the first pass.
- No automatic local handoff status edits after publish unless explicitly requested.
- No attempt to make every artifact externally accessible; local paths may remain text references.

## Open Implementation Notes

- Database creation and schema changes require explicit approval before execution.
- Linked database views should be created only after the target databases and hub pages exist.
- Existing E2E page `0527 harness meeting-to-notion E2E 검증` should be treated as a test artifact, not as the final IA model.
