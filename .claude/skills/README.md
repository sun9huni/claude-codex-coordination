# Claude-Native Skills

Slash-invokable skills for `/home/ubuntu`. Each `<name>/SKILL.md` becomes
`/name` once Claude Code picks them up. The workspace-root `skills/`
folder is Codex's mirror — Claude reads these under `.claude/skills/`.

| Skill | Purpose |
|---|---|
| `/handoff` | Update the active slice's `.agent/status/<slice>.md` and snapshot via `./scripts/handoff.sh <agent> <slice>`; CURRENT.md is the derived index. Use at end of session, near context limit, before switching agents, or before a long-running job. |
| `/slice-status` | Show the current state of one slice — combines static `.agent/status/<slice>.md`, live `./scripts/status.sh`, and project-repo `git status`. |
| `/contract-check` | Decide if the in-flight work crosses a WORKFLOW.md §2 contract trigger (SLURM, ranking change, 4+ files, etc.). If yes, draft a contract from `_template.md`. |
| `/route` | Map a free-form work signal to the right slice + harness file using WORKFLOW.md §1. |
| `/meeting-report` | Compile source-backed per-slice digest for meetings or stakeholder updates. |
| `/meeting-to-notion` | Turn a meeting-report digest into a reviewed Notion page using `notion-knowledge-capture`. |

Skill format follows Claude Code conventions:
- YAML frontmatter: `name`, `description` (drives auto-invocation when
  applicable), optional `argument-hint`, optional `allowed-tools`.
- Body becomes the prompt Claude receives when the skill is invoked.
- `$ARGUMENTS` substitutes user-supplied args; `!cmd` blocks run shell
  commands at invocation time and inject the output.
