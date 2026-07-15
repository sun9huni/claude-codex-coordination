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
