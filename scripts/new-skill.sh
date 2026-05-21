#!/usr/bin/env bash
# Scaffold a new SKILL.md that passes tests/run-skill-lint.sh on
# first try.
#
# Usage: ./scripts/new-skill.sh <skill-name> [process|expertise|workflow]
#
#   skill-name: lowercase-hyphenated slug.
#   category: optional. Affects the body template (process skills get
#             a procedural template; expertise gets a five-lens
#             template; workflow gets an upstream/downstream-artifact
#             template). Default: expertise.
#
# Creates:
#   .claude/skills/<skill-name>/SKILL.md
#
# Refuses if the directory already exists. Run tests/run-skill-lint.sh
# afterwards to confirm; the scaffold ships with enough Red Flags + a
# Forbidden section to clear the lint, but the human author has to
# fill in the actual workflow steps and replace placeholder Red Flags
# with skill-specific rationalizations.

set -euo pipefail

if [ "$#" -lt 1 ]; then
    cat >&2 <<USAGE
usage: $0 <skill-name> [process|expertise|workflow]

  skill-name: lowercase-hyphenated slug.
  category:   process | expertise | workflow (default: expertise)

USAGE
    exit 2
fi

SLUG="$1"
CATEGORY="${2:-expertise}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILL_DIR="$ROOT/.claude/skills/$SLUG"

if ! [[ "$SLUG" =~ ^[a-z][a-z0-9-]*$ ]]; then
    echo "[new-skill] error: slug must be lowercase-hyphenated (got: $SLUG)" >&2
    exit 1
fi

case "$CATEGORY" in
    process|expertise|workflow) ;;
    *) echo "[new-skill] error: category must be process|expertise|workflow (got: $CATEGORY)" >&2; exit 1 ;;
esac

if [ -e "$SKILL_DIR" ]; then
    echo "[new-skill] error: $SKILL_DIR already exists." >&2
    exit 1
fi

mkdir -p "$SKILL_DIR"

# Category-specific body templates.
case "$CATEGORY" in
process)
    BODY_HEADER="# /$SLUG — <one-line tagline>

<Two-sentence framing: what real problem this skill solves and
when the user reaches for it.>"
    BODY_WORKFLOW="## Step 1 — <Action verb> <object>

<Describe what to inspect / parse / compute in this step.>

## Step 2 — <Action verb> <object>

<Describe the second step. Cite paths the skill must read.>

## Step 3 — <Action verb> <object>

<Describe the terminal step / output.>

## Output

<Describe the format the user sees. Be specific. Cap line count.>"
    RED_FLAGS_ROWS='| "<common rationalization 1>" | <the objection that beats it>. |
| "<rationalization 2>" | <objection 2>. |
| "<rationalization 3>" | <objection 3>. |'
    ;;
expertise)
    BODY_HEADER="# /$SLUG — <one-line tagline>

<Two-sentence framing: what judgement call this skill makes and
the default verdict / bias.>"
    BODY_WORKFLOW="## Step 1 — Identify scope

<Resolve \$ARGUMENTS into a concrete target. If empty, what default.>

## Step 2 — Read the relevant code / context

<List the order: e.g. (1) the change set, (2) its callers,
(3) the slice harness, (4) related contracts.>

## Step 3 — Apply lenses

| Lens | Question |
|---|---|
| <lens 1> | <what to look for> |
| <lens 2> | <what to look for> |
| <lens 3> | <what to look for> |

## Step 4 — Karpathy guardrails

- **Think Before Coding**: <skill-specific application>.
- **Simplicity First**: <skill-specific application>.
- **Surgical Changes**: <skill-specific application>.
- **Goal-Driven**: <skill-specific application>.

## Step 5 — Output

<Format. Be specific. Cap line count.>"
    RED_FLAGS_ROWS='| "<rationalization specific to this skill>" | <objection>. |
| "<rationalization 2>" | <objection 2>. |
| "<rationalization 3>" | <objection 3>. |
| "<rationalization 4>" | <objection 4>. |'
    ;;
workflow)
    BODY_HEADER="# /$SLUG — <one-line tagline>

<Two-sentence framing: which upstream artifact this skill requires
and which downstream artifact it produces.>"
    BODY_WORKFLOW="## Step 0 — Verify upstream artifact

\$ARGUMENTS must point to <upstream artifact, e.g. an approved
contract>. If not, refuse and route to the upstream skill.

## Step 1 — Read input

<What to extract / parse.>

## Step 2 — Produce output

<What downstream artifact this skill writes, where.>

## Step 3 — Wait for approval

Do NOT advance to the next downstream skill automatically. The
user marks the artifact \`Status: approved\` first.

## Karpathy alignment

- **Think Before Coding**: <how this skill encodes the think gate>.
- **Goal-Driven**: <observable success criterion>.
- **Surgical Changes**: <scope discipline>.
- **Simplicity First**: <what to refuse>."
    RED_FLAGS_ROWS='| "<rationalization for skipping the gate>" | <objection: the gate exists for a reason>. |
| "<rationalization for bundling upstream + downstream>" | <objection>. |
| "<rationalization 3>" | <objection 3>. |'
    ;;
esac

cat > "$SKILL_DIR/SKILL.md" <<SKILL
---
name: $SLUG
description: <One-sentence trigger description, 60-400 chars, starting with a verb. Say WHEN to invoke and WHAT it produces. Avoid boilerplate openers like "Skill that..." or "A skill...". Example: "Review the current change set through five lenses... Use before /handoff on any non-trivial change.">
argument-hint: "<positional args, or '(empty = ...)' for default behavior>"
allowed-tools: Read Grep Bash(git status:*)
---

$BODY_HEADER

$BODY_WORKFLOW

## Red Flags

| Rationalization | Reality |
|---|---|
$RED_FLAGS_ROWS

## Forbidden

- Do NOT <thing this skill must never do>.
- Do NOT <second thing>.
- Do NOT <third thing>.

## When NOT to use this skill

- <Out-of-scope case 1>.
- <Out-of-scope case 2>.
SKILL

echo "[new-skill] created: $SKILL_DIR/SKILL.md (category=$CATEGORY)"
echo "[new-skill] next steps:"
echo "  1. Edit description to be concrete (60-400 chars; not boilerplate)."
echo "  2. Replace <placeholders> in the body with real steps."
echo "  3. Replace the Red Flags table with 3-7 skill-specific rationalizations."
echo "  4. Tighten allowed-tools to the minimum needed."
echo "  5. Run: bash tests/run-skill-lint.sh"
echo "  6. Restart Claude Code so the new slash command is discovered."
