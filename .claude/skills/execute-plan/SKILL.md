---
name: execute-plan
description: Execute an APPROVED plan by running each task in order, delegating implementation to a fresh subagent, then routing the resulting diff through /code-review. Updates plan status per task and commits only when /code-review verdict is APPROVE. Use only after /write-plan and plan approval; refuse if status:pending. Will pause and ask before any task that crosses an approval gate.
argument-hint: "<path to approved .agent/plans/<slug>.md>"
allowed-tools: Read Grep Edit Bash(git status:*) Bash(git diff:*) Bash(git log:*) Bash(git add:*) Bash(git commit:*) Bash(ls:*) Bash(cat:*) Bash(grep:*) Bash(find:*) Bash(awk:*) Bash(sed:*)
---

# /execute-plan — Subagent-driven task loop

This skill is the only piece of the chain that writes production
code. It does so by delegation, not by Edit, so the implementing
context is isolated from this skill's context and from prior
turns.

## Step 0 — Verify input

`$ARGUMENTS` must be a path to a plan file under `.agent/plans/`.
If empty, list approved plans and ask which to execute:

```bash
grep -l 'status: approved' .agent/plans/*.md 2>/dev/null
```

Open the plan. Verify:
- Frontmatter `status: approved` — required. If pending, refuse:
  "Plan not approved. Mark frontmatter status:approved first."
- `contract:` field points to a real file whose status is also
  `approved`.

If either check fails, route back to the appropriate upstream
skill with a clear message.

## Step 1 — Mark in-progress

Edit the plan's frontmatter: `status: in-progress`. This is the
single-writer commitment — only one /execute-plan loop runs per
plan at a time.

## Step 2 — Task loop

For each task in order (respecting `Prereq tasks:` dependencies):

### 2a. Pre-flight check on the task

- Read the task spec verbatim.
- If task crosses an approval gate (SLURM submit, DB DDL,
  destructive file op, /mnt/data writes, public-API change), STOP
  and ask the user before delegating.
- If task's `Prereq tasks:` list isn't all `Status: done`, refuse
  to run it and tell the user which prereqs are pending.

### 2b. Delegate the implementation

Use the Agent tool with `subagent_type: general-purpose` (or a
narrower custom subagent if one fits — e.g. `mmgbsa-stage-check`
for stage verification tasks). Construct a self-contained prompt:

```
You are implementing one task from an approved plan. Do exactly
the task, nothing else. Surgical Changes is non-negotiable.

Task: <verbatim task block from the plan>

Context:
- Active slice: <from contract>
- Files touched: <from task>
- Verification command: <from task>

When done:
1. Run the verification command yourself and report its output.
2. Do NOT commit. Leave the diff for review.
3. Summarize what you changed in 3 lines.
```

Wait for the subagent's response.

### 2c. Code-review the diff

Run `/code-review` on the uncommitted diff (no `$ARGUMENTS` means
default to `git diff`). Capture the verdict:

- **APPROVE / APPROVE_WITH_NITS** → proceed to 2d.
- **REQUEST_CHANGES** → re-delegate to the subagent with the
  review findings as feedback, up to 2 iterations. After 2
  failed iterations, mark the task `Status: blocked`, write a
  one-line reason to the plan, and stop the loop. Tell the user.

### 2d. Spec-conformance check (light)

A separate, quick check that the diff matches the task's
`Change shape` and `Files touched` — not architectural review,
just "does this match the spec".

If a file outside `Files touched` was changed, flag it. Either
update the task (with user confirmation) or revert the extra
change.

### 2e. Commit + update plan

If both reviews pass, commit:

```bash
git -C <project-repo> add <files-from-task>
git -C <project-repo> commit -m "<plan-slug> task <N>: <task-name>"
```

Edit the plan: set this task's `Status: done`. Move to the next
task.

## Step 3 — Loop completion

When all tasks are `Status: done`:

1. Edit plan frontmatter: `status: done`.
2. Edit the contract: `Status: done` + a one-paragraph "Notes"
   summary referencing the plan path.
3. Run /handoff to record the session state.
4. Tell the user: "Plan complete. <N> tasks, <commits> commits.
   Verification command: `<command from contract success criteria>`."

## Hard stops

Bail out immediately and tell the user when:

- A task's `Files touched` includes anything outside the project
  repo for its slice.
- The verification command fails after task 2c review approved
  it (means the verification is wrong, not the code — go back to
  /write-plan).
- A subagent attempts to chain tasks itself (it should only do
  the assigned task).
- Two consecutive tasks fail code-review on the first attempt —
  signals the plan is wrong, not the implementation.

## Karpathy alignment

- **Surgical Changes**: per-task delegation isolates scope.
  Subagent literally can't go off-task because its tools are
  bounded.
- **Goal-Driven**: every commit is gated by the task's
  verification command + /code-review. No green-without-evidence
  commits.
- **Simplicity First**: the loop is dumb. It doesn't make decisions
  the plan didn't make; if the plan is unclear, it stops.

## Red Flags

| Rationalization | Reality |
|---|---|
| "I'll just batch the next two tasks since they're small." | The plan said two tasks. Two commits. Bundling defeats the per-task review gate. |
| "The diff also touches an adjacent file — leaving it." | If it's outside `Files touched`, revert it or update the task. Silent scope creep is exactly what this chain blocks. |
| "/code-review said REQUEST_CHANGES but it's a nit." | A nit is APPROVE_WITH_NITS, not REQUEST_CHANGES. Either the reviewer was wrong (push back) or it's not a nit. |
| "Let me skip ahead, this task is trivial." | Order respects Prereq tasks for a reason. Trivial-looking tasks set up state for later tasks. |
| "I'll commit and update the plan in one go." | Commit, then update plan. If the commit fails, you haven't lied about plan status. |

## Forbidden

- Do NOT execute a plan whose contract is also not approved.
- Do NOT skip /code-review on any task, however small.
- Do NOT modify the plan's task definitions during execution —
  if a task is wrong, stop the loop and route back to
  /write-plan.
- Do NOT chain into the next plan automatically — one plan per
  /execute-plan invocation.
- Do NOT proceed past Step 2a if the task triggers an approval
  gate without explicit user "go".

## What this skill produces

Per task: one commit + plan entry updated to `Status: done`.
Per plan completion: contract status: done + plan status: done +
/handoff snapshot. The audit trail is the git history.
