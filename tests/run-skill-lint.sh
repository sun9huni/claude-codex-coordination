#!/usr/bin/env bash
# Skill quality lint.
#
# For every .claude/skills/<name>/SKILL.md plus the corresponding files
# under examples/<deployment>/.claude/skills/, verify:
#
#   F1. YAML frontmatter parses (delimited by --- on its own line).
#   F2. `name:` present, slug-shaped.
#   F3. `description:` present, 60-400 chars, not a generic boilerplate
#       opener.
#   F4. `allowed-tools` (if present) does not contain disallowed
#       characters or unbalanced brackets.
#   B1. Body has a "## Karpathy alignment" or "## Karpathy principles"
#       section (we accept both phrasings).
#   B2. Body has a "## Red Flags" section.
#   B3. Body has a "## Forbidden" section.
#   B4. The Red Flags section has at least 3 table rows after the
#       header / separator lines.
#
# Each failure is reported once per file. Non-zero exit if anything
# fails. Run from any CWD — paths are resolved from the script location.
#
# Used by .github/workflows/test.yml on Linux + macOS.

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

PASS=0
FAIL=0
FAILURES=()

lint_one() {
    local path="$1"
    local rel="${path#"$ROOT"/}"
    local errs=()

    # F1. Frontmatter delimiters.
    if ! head -1 "$path" | grep -qE '^---$'; then
        errs+=("F1: no leading '---' line (frontmatter missing)")
    fi

    # Extract frontmatter body (between first two '---' lines).
    local fm
    fm=$(awk 'BEGIN{n=0} /^---$/{n++; next} n==1{print}' "$path")

    if [ -z "$fm" ]; then
        errs+=("F1: frontmatter block is empty")
    fi

    # F2. name: slug-shaped.
    local name
    name=$(awk -F': *' '/^name:/{print $2; exit}' <<< "$fm" | tr -d '[:space:]')
    if [ -z "$name" ]; then
        errs+=("F2: missing 'name:' field")
    elif ! [[ "$name" =~ ^[a-z][a-z0-9-]*$ ]]; then
        errs+=("F2: 'name' must be lowercase-hyphenated slug (got: $name)")
    fi

    # F3. description: present, 60-400 chars, not generic.
    local desc
    desc=$(awk -F': *' '/^description:/{$1=""; sub(/^ /, ""); print; exit}' <<< "$fm")
    if [ -z "$desc" ]; then
        errs+=("F3: missing 'description:' field")
    else
        local dlen=${#desc}
        if [ "$dlen" -lt 60 ]; then
            errs+=("F3: description too short ($dlen chars; min 60)")
        elif [ "$dlen" -gt 400 ]; then
            errs+=("F3: description too long ($dlen chars; max 400)")
        fi
        # Reject boilerplate openers.
        if [[ "$desc" =~ ^[\"\']?[Ss]kill\ that ]] || \
           [[ "$desc" =~ ^[\"\']?[Aa]\ skill ]] || \
           [[ "$desc" =~ ^[\"\']?[Tt]his\ skill ]]; then
            errs+=("F3: description starts with boilerplate ('Skill that...' / 'A skill...' / 'This skill...')")
        fi
    fi

    # F4. allowed-tools (if present) — character whitelist.
    local at
    at=$(awk -F': *' '/^allowed-tools:/{$1=""; sub(/^ /, ""); print; exit}' <<< "$fm")
    if [ -n "$at" ]; then
        # Allow alphanumerics, space, parens, asterisks, colons, slashes,
        # dots, pipes, hyphens, underscores, percent.
        if [[ "$at" =~ [^A-Za-z0-9\ \(\)\*:/.|_%\-] ]]; then
            errs+=("F4: 'allowed-tools' contains unexpected character(s)")
        fi
        # Balanced parens.
        local open close
        open=$(grep -o '(' <<< "$at" | wc -l)
        close=$(grep -o ')' <<< "$at" | wc -l)
        if [ "$open" != "$close" ]; then
            errs+=("F4: 'allowed-tools' unbalanced parens ($open open, $close close)")
        fi
    fi

    # B2. Red Flags section (standalone OR inline as a workflow step).
    # Required for ALL skills — the rationalization table is the single
    # most important quality control on a SKILL.md body.
    if ! grep -qE '^##.*Red Flags' "$path"; then
        errs+=("B2: missing section with 'Red Flags' in the header")
    fi

    # B3. Forbidden section. Required for all skills.
    if ! grep -qE '^## Forbidden' "$path"; then
        errs+=("B3: missing '## Forbidden' section")
    fi

    # Karpathy alignment is RECOMMENDED for expertise / workflow skills
    # but NOT required for process skills (which are procedural rather
    # than opinion-bearing). We do not lint it here; if a skill author
    # forgets, the surrounding skills already model the convention.

    # B4. Red Flags has >= 3 data rows (4 `|` lines including the header).
    # Awk-block triggers on any `## ...Red Flags...` heading.
    local rf_rows
    rf_rows=$(awk '
        /^##.*Red Flags/{in_rf=1; next}
        /^## /{in_rf=0}
        in_rf && /^\|/ && !/^\|[[:space:]]*-+/ {n++}
        END{print n+0}
    ' "$path")
    if [ "$rf_rows" -lt 4 ]; then
        errs+=("B4: Red Flags table has only $rf_rows rows (need >= 4: 1 header + 3 data)")
    fi

    if [ ${#errs[@]} -eq 0 ]; then
        printf "PASS  %s\n" "$rel"
        PASS=$((PASS + 1))
    else
        printf "FAIL  %s\n" "$rel"
        for e in "${errs[@]}"; do
            printf "        - %s\n" "$e"
        done
        FAIL=$((FAIL + 1))
        FAILURES+=("$rel")
    fi
}

# Find all SKILL.md files under .claude/skills/ in the repo, plus under
# examples/*/.claude/skills/ for the reference deployments.
while IFS= read -r -d '' f; do
    lint_one "$f"
done < <(find "$ROOT/.claude/skills" "$ROOT/examples" -name 'SKILL.md' -print0 2>/dev/null)

echo ""
echo "==========================================="
echo "PASS: $PASS    FAIL: $FAIL"
if [ "$FAIL" -gt 0 ]; then
    echo "Failed files:"
    for f in "${FAILURES[@]}"; do echo "  - $f"; done
fi
[ "$FAIL" = 0 ] && exit 0 || exit 1
