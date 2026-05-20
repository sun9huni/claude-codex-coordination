#!/usr/bin/env bash
# Scaffold a new slice: status file, harness file, gentle reminder to
# register it in WORKFLOW.md §1 and stop-handoff-check.sh.
#
# Usage: ./scripts/init-slice.sh <slice-name>
#
# Example: ./scripts/init-slice.sh backend
#   Creates:
#     .agent/status/backend.md
#     .agent/projects/backend-harness.md
#   Prints reminders for:
#     - WORKFLOW.md §1 routing row
#     - .claude/hooks/stop-handoff-check.sh VALID_SLICES update

set -euo pipefail

if [ "$#" -lt 1 ]; then
  echo "usage: $0 <slice-name>" >&2
  exit 2
fi

SLICE="$1"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DATE="$(date +%Y-%m-%d)"

STATUS="$ROOT/.agent/status/${SLICE}.md"
HARNESS="$ROOT/.agent/projects/${SLICE}-harness.md"

# Validate slice name (slug-friendly).
if ! [[ "$SLICE" =~ ^[a-z][a-z0-9-]*$ ]]; then
  echo "[init-slice] slice name must be lowercase letters / digits / hyphens, starting with a letter." >&2
  exit 1
fi

if [ -e "$STATUS" ]; then
  echo "[init-slice] error: $STATUS already exists. Edit or delete it first." >&2
  exit 1
fi
if [ -e "$HARNESS" ]; then
  echo "[init-slice] error: $HARNESS already exists. Edit or delete it first." >&2
  exit 1
fi

cat > "$STATUS" <<STATUS_END
# Status: ${SLICE} (as of ${DATE})

## Done
- (nothing yet — this is a fresh slice)

## In flight
- (nothing yet)

## Next action
1. Define the scope of this slice in ${SLICE}-harness.md.
2. Add the first task and link a contract under .agent/contracts/.

## Open risks
- (none recorded)

## Pointers
- harness: \`.agent/projects/${SLICE}-harness.md\`
- contracts: (none yet)
STATUS_END

cat > "$HARNESS" <<HARNESS_END
# ${SLICE} harness

> Workflow design for the ${SLICE} slice. Read when the status file
> alone is not enough context.

## Mental model

(One paragraph: what this slice is about, what stages it has, what
vocabulary is local to it.)

## File map

- \`<key directory>\`: <what's there>

## Common workflows

### Adding a new <thing>
1. ...
2. ...

### Investigating a failure of <component>
1. ...

## Pitfalls (avoid these)

- (none recorded yet)

## Verification

How to know this slice is healthy. Specific commands here when known.
HARNESS_END

echo "[init-slice] created:"
echo "  - $STATUS"
echo "  - $HARNESS"
echo
echo "[init-slice] don't forget to:"
echo "  1. Add a row to WORKFLOW.md §1 routing table for '${SLICE}':"
echo "     | <work signal keyword> | .agent/status/${SLICE}.md | .agent/projects/${SLICE}-harness.md | <reminder> |"
echo "  2. Add '${SLICE}' to VALID_SLICES in .claude/hooks/stop-handoff-check.sh"
echo "     (so the Stop hook recognizes it as a valid active_slice value)"
echo "  3. If this slice maps to a project repo, document the path in the harness file's File Map section."
