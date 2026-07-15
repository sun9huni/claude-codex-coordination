# Hermes Agent Pattern-Port Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Port Hermes Agent governance patterns into the existing `.agent` harness without installing or running Hermes.

**Architecture:** The implementation is documentation- and validation-first. It creates a durable Hermes pattern inventory, adds a side-effect taxonomy to the tool inventory, adds a skill-governance comparison note, and strengthens `tool-audit.sh` so the taxonomy is checked.

**Tech Stack:** Bash, Markdown, existing `.agent` harness scripts, existing skill-lint and verify scripts.

---

## File Structure

- Create: `.agent/tools/hermes-agent-pattern-inventory-20260602.md`
  - Durable inventory of Hermes patterns, dispositions, and rejected runtime surfaces.
- Modify: `.agent/tools/inventory.md`
  - Add side-effect classes and classify Hermes as a rejected/deferred runtime surface.
- Create: `.agent/skills/hermes-skill-governance-20260602.md`
  - Checklist for evaluating Hermes optional skills without auto-import.
- Modify: `scripts/tool-audit.sh`
  - Enforce that the tool inventory includes the side-effect taxonomy and required class labels.
- Modify: `.agent/status/harness.md`
  - Record implementation result and next action.
- Regenerate: `.agent/handoffs/CURRENT.md`
  - Run `./scripts/status.sh index` after status update.

## Task 1: Create Hermes Pattern Inventory

**Files:**
- Create: `.agent/tools/hermes-agent-pattern-inventory-20260602.md`

- [x] **Step 1: Confirm Hermes baseline is available**

Run:

```bash
git -C /tmp/hermes-agent-inspect rev-parse HEAD
```

Expected output:

```text
272c2f30aa60d6d98b2c97dde6ba42a9231d4f56
```

- [x] **Step 2: Create the inventory document**

Create `.agent/tools/hermes-agent-pattern-inventory-20260602.md` with this content:

```markdown
# Hermes Agent Pattern Inventory

Date: 2026-06-02
Slice: harness
Source repo: https://github.com/NousResearch/hermes-agent
Source baseline: `272c2f30aa60d6d98b2c97dde6ba42a9231d4f56`
Contract: `.agent/contracts/harness-hermes-agent-port-20260602.md`

## Disposition Labels

- `port`: implement a small harness change in this contract
- `reference`: keep as design guidance only
- `defer`: useful, but needs a later contract
- `reject`: conflicts with current harness ownership, approval gates, or tool budget

## Skills And Skill Metadata

| Hermes surface | Disposition | Harness mapping | Rationale |
| --- | --- | --- | --- |
| `tools/skills_tool.py` progressive disclosure | reference | `SKILL.md` authoring and skill-lint guidance | Good model for keeping skill bodies discoverable without loading every reference eagerly. |
| `tools/skill_manager_tool.py` direct skill mutation | reject | no direct writes to `skills/`, `.codex/skills`, or `.claude/skills` | Our skill changes must remain registry-backed, reviewable, and mirror-verified. |
| `optional-skills/` catalog | defer | future governed skill candidates | Useful source of ideas, but auto-import would bypass team governance. |
| pinned or protected skills | reference | future skill registry metadata | Useful policy concept; not needed for this first contract. |

## Tools, Toolsets, And MCP Surfaces

| Hermes surface | Disposition | Harness mapping | Rationale |
| --- | --- | --- | --- |
| `tools/registry.py` central registry | reference | `.agent/tools/inventory.md` and `tool-audit.sh` | Good model for explicit ownership and availability, but code copy is unnecessary. |
| `toolsets.py` named toolsets | port | side-effect classes in `.agent/tools/inventory.md` | Helps classify context cost and risk for new tools. |
| `tools/mcp_tool.py` optional MCP integration | defer | future MCP-specific contract | Large surface that can carry credentials and external effects. |
| broad core toolset with browser, computer-use, messaging, cron, and code execution | reject | no default enablement | Too much blast radius for the current harness. |

## Approvals And Subagents

| Hermes surface | Disposition | Harness mapping | Rationale |
| --- | --- | --- | --- |
| `tools/approval.py` dangerous-command patterns | reference | root `AGENTS.md` approval gates and tool policy | Useful comparison source, but root approval gates remain authoritative. |
| subagent blocked-tool list in `tools/delegate_tool.py` | reference | Codex subagent rules and delegation skills | Good design reference for preventing recursive or high-risk delegation. |
| subagent auto-deny dangerous commands | reference | future delegation-manager checklist | Useful concept; no immediate code change. |
| cron approval mode | reject | no cron sidecar in this phase | Non-interactive approvals are not needed and increase risk. |

## Memory, Session Search, And State

| Hermes surface | Disposition | Harness mapping | Rationale |
| --- | --- | --- | --- |
| `hermes_state.py` SQLite and FTS5 session search | defer | future read-only `.agent` baton index | Potentially useful, but implementation would be a separate search prototype. |
| `~/.hermes` state root | reject | `.agent/` remains source of truth | A second durable state root would create handoff drift. |
| session compression and splitting | reference | future handoff-history design | Useful concept if handoff logs grow large. |

## Rejected Runtime Surfaces

The following Hermes runtime surfaces are out of scope for this contract:

- global Hermes install
- `HERMES_HOME` creation
- gateway daemon
- cron scheduler
- messaging or notification delivery
- Home Assistant integration
- browser or computer-use enablement
- credentials or provider key persistence
- direct skill mutation
- Notion reverse sync
- Codex or Claude runtime replacement

## Immediate Port Items

1. Add side-effect taxonomy to `.agent/tools/inventory.md`.
2. Teach `scripts/tool-audit.sh` to check for that taxonomy.
3. Add a Hermes skill-governance checklist in `.agent/skills/`.

## Later Contract Candidates

- read-only searchable baton index over `.agent/status`, contracts, plans, and `CURRENT.md`
- isolated Hermes sidecar with gateway, cron, messaging, credentials, and direct skill mutation disabled
- optional Hermes skill review batch using the governed skill checklist
```

- [x] **Step 3: Verify the inventory has no incomplete-marker language**

Run:

```bash
rg -n 'TB[D]|TO[D]O|FIXM[E]|\?\?|place(holder)' .agent/tools/hermes-agent-pattern-inventory-20260602.md
```

Expected: command exits with status `1` and prints no matches.

- [x] **Step 4: Commit**

```bash
git add .agent/tools/hermes-agent-pattern-inventory-20260602.md
git commit -m "docs: inventory hermes agent patterns"
```

Expected: commit succeeds with one new file.

## Task 2: Add Tool Side-Effect Taxonomy

**Files:**
- Modify: `.agent/tools/inventory.md`

- [x] **Step 1: Insert side-effect classes**

Modify `.agent/tools/inventory.md` so it contains this section after `## Tier Labels`:

```markdown
## Side-Effect Classes

- `read-only-local`: reads local files or status only
- `local-write`: writes local files in the workspace
- `external-network`: calls external network services
- `credential-bearing`: requires or can expose credentials, tokens, or provider keys
- `scheduler-daemon`: runs scheduled or background work
- `messaging-notification`: sends messages, notifications, or chat replies
- `production-facing`: can affect production services, infrastructure, or customer data
- `destructive-infra`: can delete, reset, redeploy, rotate secrets, or change infrastructure
```

- [x] **Step 2: Add Hermes row**

Add this row to the inventory table:

```markdown
| Hermes Agent runtime | agent runtime / tool ecosystem | disabled | reference source for skill, toolset, approval, and memory patterns; not installed or run | team | 2026-06-02 | high | high |
```

- [x] **Step 3: Add Hermes runtime note**

Add this section before `## Review Rules`:

```markdown
## Disabled Runtime Surfaces

Hermes Agent is a reference source only for the current harness phase. The
following Hermes surfaces are disabled unless a later approval-gated contract
enables a sidecar: gateway, cron, messaging, Home Assistant, browser,
computer-use, credentials, provider keys, direct skill mutation, and Notion
reverse sync.
```

- [x] **Step 4: Verify section and row exist**

Run:

```bash
rg -n "Side-Effect Classes|Hermes Agent runtime|Disabled Runtime Surfaces" .agent/tools/inventory.md
```

Expected: output contains all three phrases.

- [x] **Step 5: Commit**

```bash
git add .agent/tools/inventory.md
git commit -m "docs: add tool side-effect taxonomy"
```

Expected: commit succeeds with only `.agent/tools/inventory.md` staged.

## Task 3: Strengthen Tool Audit

**Files:**
- Modify: `scripts/tool-audit.sh`

- [x] **Step 1: Update `tool-audit.sh` with required taxonomy checks**

Replace the body after the existing incomplete-entry check with this block:

```bash
required_sections=(
  "## Side-Effect Classes"
  "## Disabled Runtime Surfaces"
)

for section in "${required_sections[@]}"; do
  if ! grep -Fq "$section" "$INVENTORY"; then
    echo "[tool-audit] missing required section: $section" >&2
    exit 1
  fi
done

required_classes=(
  "read-only-local"
  "local-write"
  "external-network"
  "credential-bearing"
  "scheduler-daemon"
  "messaging-notification"
  "production-facing"
  "destructive-infra"
)

for class in "${required_classes[@]}"; do
  if ! grep -Fq "\`$class\`" "$INVENTORY"; then
    echo "[tool-audit] missing side-effect class: $class" >&2
    exit 1
  fi
done

if grep -Fq "Hermes Agent runtime" "$INVENTORY"; then
  if ! grep -Fq "gateway, cron, messaging" "$INVENTORY"; then
    echo "[tool-audit] Hermes runtime row exists but disabled surfaces are not documented" >&2
    exit 1
  fi
fi
```

The final lines of the script should still be:

```bash
echo "[tool-audit] finished"
```

- [x] **Step 2: Run shell syntax check**

Run:

```bash
bash -n scripts/tool-audit.sh
```

Expected: no output and exit status `0`.

- [x] **Step 3: Run tool audit**

Run:

```bash
./scripts/tool-audit.sh
```

Expected output contains:

```text
[tool-audit] starting
[tool-audit] finished
```

- [x] **Step 4: Commit**

```bash
git add scripts/tool-audit.sh
git commit -m "test: enforce tool side-effect taxonomy"
```

Expected: commit succeeds with only `scripts/tool-audit.sh` staged.

## Task 4: Add Hermes Skill Governance Checklist

**Files:**
- Create: `.agent/skills/hermes-skill-governance-20260602.md`

- [x] **Step 1: Create the checklist document**

Create `.agent/skills/hermes-skill-governance-20260602.md` with this content:

```markdown
# Hermes Skill Governance Checklist

Date: 2026-06-02
Contract: `.agent/contracts/harness-hermes-agent-port-20260602.md`
Source baseline: `272c2f30aa60d6d98b2c97dde6ba42a9231d4f56`

## Purpose

Evaluate Hermes optional skills as candidates for this workspace without
auto-importing them or allowing agent-driven skill mutation.

## Required Decision

Each Hermes skill candidate must be classified as one of:

- `reject`: conflicts with policy or has unclear value
- `reference`: useful to read, not installed
- `adapt`: may be rewritten as a governed team skill
- `defer`: needs a separate contract

## Acceptance Checklist

A Hermes skill may become a governed team skill only when all checks pass:

1. The trigger maps to a real repeated workflow in this workspace.
2. The skill has a single clear owner.
3. The skill does not require credentials or external side effects by default.
4. The skill does not write directly to `skills/`, `.codex/skills`, or
   `.claude/skills`.
5. The skill can be expressed as a local `SKILL.md` following current
   skill-lint requirements.
6. The skill appears in `.agent/skills/registry.md` before use.
7. `./scripts/skills-sync.sh --dry-run` reports no mirror drift.
8. `bash tests/run-skill-lint.sh` passes.

## Rejected Import Modes

- bulk copying `optional-skills/`
- enabling Hermes `skill_manage`
- using Hermes to mutate team skills
- importing skills that require gateway, cron, messaging, credentials, or
  production-facing tools as default behavior

## Review Workflow

1. Read the Hermes skill source.
2. Classify it with the required decision labels.
3. If `adapt`, write a local skill from scratch using current workspace
   conventions.
4. Register the skill in `.agent/skills/registry.md`.
5. Mirror with `./scripts/skills-sync.sh --dry-run`.
6. Run `bash tests/run-skill-lint.sh`.
7. Record the decision in the relevant contract or status baton.
```

- [x] **Step 2: Verify no incomplete-marker language**

Run:

```bash
rg -n 'TB[D]|TO[D]O|FIXM[E]|\?\?|place(holder)' .agent/skills/hermes-skill-governance-20260602.md
```

Expected: command exits with status `1` and prints no matches.

- [x] **Step 3: Commit**

```bash
git add .agent/skills/hermes-skill-governance-20260602.md
git commit -m "docs: add hermes skill governance checklist"
```

Expected: commit succeeds with one new file.

## Task 5: Run Full Harness Verification

**Files:**
- No direct file edits

- [x] **Step 1: Run skill mirror dry run**

Run:

```bash
./scripts/skills-sync.sh --dry-run
```

Expected output contains:

```text
[skills-sync] starting
[skills-sync] finished
```

If a managed `SKILL.md` drift is reported, stop and inspect the drift before
continuing.

- [x] **Step 2: Run skill lint**

Run:

```bash
bash tests/run-skill-lint.sh
```

Expected output ends with:

```text
FAIL: 0
```

- [x] **Step 3: Run tool audit**

Run:

```bash
./scripts/tool-audit.sh
```

Expected output contains:

```text
[tool-audit] finished
```

- [x] **Step 4: Run workspace verify**

Run:

```bash
./scripts/verify.sh
```

Expected: command exits with status `0`.

- [x] **Step 5: Run diff whitespace check**

Run:

```bash
git diff --check
```

Expected: no output and exit status `0`.

## Task 6: Update Harness Baton And Handoff Index

**Files:**
- Modify: `.agent/status/harness.md`
- Regenerate: `.agent/handoffs/CURRENT.md`

- [x] **Step 1: Update harness status**

In `.agent/status/harness.md`, update `remaining_actions` to include:

```yaml
remaining_actions:
  - "✅ Hermes Agent pattern-port implementation DONE (2026-06-02): pattern inventory, tool side-effect taxonomy, tool-audit taxonomy enforcement, and Hermes skill-governance checklist completed. Hermes remains reference-only; no runtime install, no sidecar, no gateway/cron/messaging, no direct skill mutation."
  - "NEXT: decide whether to close the contract or open a separate search-index / isolated-sidecar pilot contract."
```

Add this item near the top of `## Current status`:

```markdown
- **Hermes Agent pattern-port implementation — DONE ✅ (2026-06-02).**
  Completed the approved first phase: durable pattern inventory, tool
  side-effect taxonomy, tool-audit enforcement, and skill-governance checklist.
  Hermes remains reference-only. No runtime install, no gateway/cron/messaging,
  no credentials, no direct skill mutation, and no Notion reverse sync.
```

- [x] **Step 2: Regenerate handoff index**

Run:

```bash
./scripts/handoff.sh claude harness && ./scripts/status.sh index
```

Expected output contains:

```text
[handoff] slice=harness
[index] wrote:
```

- [x] **Step 3: Commit final baton update if the worktree permits**

Run:

```bash
git add .agent/status/harness.md .agent/handoffs/CURRENT.md
git commit -m "docs: record hermes pattern port handoff"
```

Expected: commit succeeds if no unrelated dirty-tree guard or local policy blocks committing status files. If the commit is skipped because the wider tree has unrelated changes, leave the baton files updated and report that in the final response.

## Task 7: Close Or Defer Contract

**Files:**
- Modify: `.agent/contracts/harness-hermes-agent-port-20260602.md`

- [x] **Step 1: If all previous verification passed, set contract status**

Change frontmatter:

```yaml
status: done
```

Append to `## Progress Log`:

```markdown
- 2026-06-02: pattern-port implementation completed; Hermes remains reference-only.
```

- [x] **Step 2: Commit contract closure**

```bash
git add .agent/contracts/harness-hermes-agent-port-20260602.md
git commit -m "docs: close hermes pattern port contract"
```

Expected: commit succeeds with only the contract staged.

- [x] **Step 3: If verification failed, keep contract pending**

If any required verification failed, leave `status: pending`, append the failed
command and failure reason to `## Progress Log`, update `.agent/status/harness.md`
with the blocker, and do not claim completion.
