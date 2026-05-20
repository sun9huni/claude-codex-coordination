# Custom Subagents

Define task-specialized subagents here. Each `<name>.md` is a Markdown
file with YAML frontmatter. Claude delegates via the `Agent` tool with
`subagent_type: <name>`.

**Why custom subagents?** Narrower tool surface, lower context cost,
faster turnaround. Deny lists prevent the subagent from accidentally
writing files or running side effects outside its scope.

## Format

```yaml
---
name: my-agent
description: When Claude should delegate to this subagent. Make it specific — Claude uses this to pick.
tools: Read Grep Bash
model: opus[1m]
permissions:
  allow:
    - "Bash(squeue:*)"
    - "Read(/path/**)"
  deny:
    - "Bash(rm:*)"
    - "Edit"
    - "Write"
---

# System prompt for the subagent
You are a <role>. <Mission>. <Mental model>.

## Workflow
1. ...

## Constraints
- ...

## Output format
- ...
```

## Frontmatter fields

| Field | Required | Notes |
|---|---|---|
| `name` | yes | Slug. Used as `subagent_type` argument. |
| `description` | yes | Drives Claude's auto-delegation. Be specific. |
| `tools` | no | Space-separated. Default = all available. |
| `model` | no | `opus[1m]` / `sonnet[1m]` / `haiku[1m]`. Default inherits. |
| `permissions.allow` | no | Specific allow rules in addition to tools. |
| `permissions.deny` | no | Blocks accidental usage. |
| `skills` | no | Space-separated skills to preload. |

## Example deployments

See [examples/research-deployment/.claude/agents/](../../examples/research-deployment/.claude/agents/)
for three reference agents (read-only HPC inspector, zero-compute
diagnostician, stage-gate checker).

## Pattern: read-only inspector

Pair `tools: Bash Read` with explicit `permissions.deny` for the
inspector's write/submit verbs. This is the highest-leverage pattern
for delegations where you want a "look-only, never act" agent.

## Pattern: zero-compute diagnostician

For agents that should diagnose by *reading*, not by running, use:

```yaml
tools: Read Grep Bash
permissions:
  allow:
    - "Bash(ls:*)"
    - "Bash(cat:*)"
    - "Bash(grep:*)"
    - "Bash(awk:*)"
    - "Bash(python3 -c:*)"
  deny:
    - "Bash(python:*)"
    - "Bash(conda:*)"
    - "Edit"
    - "Write"
```

`Bash(python3 -c:*)` is allowed for one-liner math, but full Python
scripts are not.

## Pattern: gate checker

For agents whose only job is "PASS/FAIL/WARN" reports on prereqs,
restrict to read-only Bash and the project's verify scripts. Deny all
writes.
