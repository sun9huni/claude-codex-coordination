# .agent/plans/ — task-level decomposition of approved contracts

Plans are the **execution layer** between a contract (the spec /
intent) and the actual code changes. One plan = one approved
contract, decomposed into a sequence of 2-5 minute tasks that can
be executed by `/execute-plan`.

## Lifecycle

```
/brainstorm "<topic>"
  └─ writes spec to .agent/contracts/<slice>-<topic>-<YYYYMMDD>.md
     status: pending

(user approves contract → status: approved)

/write-plan .agent/contracts/<slice>-<topic>-<YYYYMMDD>.md
  └─ writes plan to .agent/plans/<slice>-<topic>-<YYYYMMDD>.md
     status: pending

(user approves plan → status: approved)

/execute-plan .agent/plans/<slice>-<topic>-<YYYYMMDD>.md
  └─ runs each task via subagent delegation
  └─ /code-review the diff at each step
  └─ updates plan status: in-progress → done per task
```

## File naming

Same convention as contracts: `<slice>-<short-topic>-<YYYYMMDD>.md`.
The plan and its contract share the slug — they are 1:1.

## Plan file structure

Each plan starts with yaml frontmatter for machine-readability:

```yaml
---
contract: .agent/contracts/<slug>.md
slice: <slice-name>
status: pending | approved | in-progress | done | cancelled
total_tasks: <N>
estimated_total_min: <sum of per-task minutes>
---
```

Followed by a numbered task list. Each task:

```markdown
## Task <N>: <short-name>

- **Status**: pending | done | skipped
- **Prereq tasks**: <list of task numbers, or "none">
- **Files touched**: <paths>
- **Change shape**: <one paragraph describing the diff>
- **Verification**: <exact command + expected output>
- **Estimated time**: <2-5 min>
```

## Rotation

When a plan is fully `done`, move it to
`.agent/plans/done/YYYY-MM/<slug>.md`. Keep the active directory
flat — only in-progress / pending / approved plans live there.

## See also

- [.agent/contracts/README.md](../contracts/README.md) — the upstream
  artifact.
- [.claude/skills/brainstorm/SKILL.md](../../.claude/skills/brainstorm/SKILL.md)
- [.claude/skills/write-plan/SKILL.md](../../.claude/skills/write-plan/SKILL.md)
- [.claude/skills/execute-plan/SKILL.md](../../.claude/skills/execute-plan/SKILL.md)
