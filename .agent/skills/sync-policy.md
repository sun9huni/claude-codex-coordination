# Skill Sync Policy

## Source Of Truth

- Team Skills live in the repository `skills/` directory.
- User-local Skills are personal and must not be assumed by the repo.
- Admin/system Skills are environment-provided and should be referenced only when required.

## Sync Rules

- Run sync in dry-run mode before applying changes.
- Preserve Skills not managed by this repository.
- Keep the last successful sync state when a sync fails.
- Update `.agent/skills/registry.md` when adding, renaming, or removing a Skill.

## Review Cadence

- monthly for active Skills
- immediately after a repeated failure
- before sharing with another repo or remote server
