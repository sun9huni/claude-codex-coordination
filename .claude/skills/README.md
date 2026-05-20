# Skills (slash commands)

Each `<name>/SKILL.md` becomes `/name` once Claude Code picks it up.
The SKILL.md body becomes the prompt Claude receives when the skill
is invoked, with `$ARGUMENTS` substituted from the user's slash call.

## Process skills (cross-agent coordination)

| Skill | Purpose |
|---|---|
| `/handoff` | Update `.agent/handoffs/CURRENT.md` + run `./scripts/handoff.sh`. |
| `/slice-status` | Consolidate static `.agent/status/<slice>.md`, live scan, and project-repo git status into one view. |
| `/contract-check` | Check whether in-flight work crosses a `WORKFLOW.md §2` contract trigger; draft contract from `_template.md` if yes. |
| `/route` | Map a free-form work signal to a slice + harness file using `WORKFLOW.md §1`. |

## Expertise skills (opinionated code work)

| Skill | Purpose |
|---|---|
| `/code-review` | Review the current diff through 5 lenses + Karpathy guardrails. Default verdict REQUEST_CHANGES. |
| `/refactor-simplify` | Find what to DELETE / INLINE / RENAME in existing code. Net-line negative required. |
| `/test-gen` | Generate pytest scaffolds. Behavior list first, user confirms, then writes the file. |
| `/debug` | Hypothesis-first failure diagnosis. Proposes ONE diagnostic, never a fix in the same turn. |

## Workflow skills (spec → plan → execute chain)

| Skill | Purpose |
|---|---|
| `/brainstorm` | Socratic spec gate. 5 questions → contract draft at `.agent/contracts/`. HARD-GATE before implementation. |
| `/write-plan` | Decompose an approved contract into 2-5 min tasks at `.agent/plans/`. Refuses if contract pending. |
| `/execute-plan` | Subagent task loop with `/code-review` gate per task. One commit per task. Refuses if plan pending. |

## SKILL.md format

```yaml
---
name: my-skill
description: One sentence on when Claude (or the user) should invoke this.
argument-hint: "[optional positional args]"
allowed-tools: Read Edit Bash(git status:*)
---

# Body — becomes the prompt at invocation time.
Use $ARGUMENTS for user-supplied args. Use !`cmd` blocks to inject
shell command output at invocation time.
```

## Adding a skill

1. Create `.claude/skills/<name>/SKILL.md` with the frontmatter above.
2. Keep the body short, action-oriented, and explicit about
   forbidden actions ("Do NOT ...").
3. Restart Claude Code to pick it up in the slash menu.

## Removing or hiding from `/`

- `disable-model-invocation: true` — only the user can invoke it.
- `user-invocable: false` — hidden from `/` menu, only Claude
  auto-invokes when description matches.
