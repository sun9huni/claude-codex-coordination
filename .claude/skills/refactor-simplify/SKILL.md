---
name: refactor-simplify
description: Find simplification opportunities in existing code — dead code, duplicates, premature abstractions, over-defensive guards, wrong primitives. Bias is DELETE / INLINE / RENAME, never ADD. Produces a prioritized list with delete-line estimate per item. Use proactively on a file or directory; never mid-feature (mixing with feature work violates Surgical Changes).
argument-hint: "<file-path | directory>"
allowed-tools: Read Grep Bash(grep:*) Bash(find:*) Bash(wc:*) Bash(awk:*) Bash(git log:*) Bash(git blame:*)
---

# /refactor-simplify — Find what to delete or collapse

The goal is fewer lines, not more. If a finding *adds* code, you are
not refactoring — you are designing, and that goes through a
contract / spec first.

## Step 0 — Test gate

Before recommending any refactor that changes runtime behavior
(extracting, inlining, merging, splitting), check:

```bash
git -C <project-repo> grep -l 'def test_\|class Test' tests/   # or equivalent
```

If the target has no test coverage, **only the safe refactors below
are allowed**:

- pure deletion of dead code (unused imports, unreachable branches)
- rename (single-symbol, no semantic change)
- inline of a single-use private helper

Anything else (DRY extraction, abstraction collapse, primitive
swap): refuse and tell the user "tests first, then refactor".

## Step 1 — Resolve scope

`$ARGUMENTS` is a file or directory. If empty, ask the user.

If a directory: scan only files modified in the last 90 days
(`git -C <repo> log --since=90.days --name-only --pretty=format:`).
Old, untouched files are usually load-bearing in ways that aren't
obvious from reading; leave them alone unless explicitly asked.

## Step 2 — Run seven lenses

For each file, walk these in order:

| Lens | Smell to find | Recipe |
|---|---|---|
| **Dead code** | Unused imports, unreferenced helpers, dead branches after early return. | `grep -n` for the symbol across the repo; if 0 callers, propose delete. |
| **Duplication** | Copy-pasted blocks across files (3+ lines, 2+ sites). | `awk` sliding window on N-line shingles, or visual scan. Propose extraction *only when the second site exists*; never abstract for hypothetical N=2. |
| **Premature abstraction** | Interface with one impl. Factory returning one type. Config flag with one value. | Search for the abstraction's call sites; if 1, propose inline. |
| **Over-defensive guards** | `if x is None: raise ValueError` when caller can't pass None per signature. `try / except / pass`. | Propose deleting the guard; add a comment explaining the invariant if non-obvious. |
| **Wrong primitive** | `dict-of-tuples` for what's clearly a `@dataclass`. Manual string parsing when `re` or `pathlib` fits. Loop-and-append where a comprehension reads. | Propose the simpler primitive with a tiny side-by-side. |
| **Complexity hotspot** | Cyclomatic > 8, nesting > 3, function > 50 lines. | `awk '/^def /,/^def /'` to bound the function, then count branches. Propose extracting the inner block or flattening with early returns. |
| **Naming drift** | Function name says `validate_X` but body returns parsed Y. Variable named `data` carries 3 different shapes. | Propose rename only if current name actively misleads. Meh-names get a pass. |

## Step 3 — Karpathy alignment

Every proposed refactor must score on these:

1. **Simplicity First** — does this remove more than it adds? (Net
   lines should be negative.)
2. **Surgical Changes** — does the refactor touch only what the
   smell demands? Reformat-while-refactoring is a separate commit.
3. **Goal-Driven** — what is the observable improvement? "Cleaner"
   is not. "Removes 80 lines, drops one indirection layer, lets
   `foo()` be tested without the `Bar` mock" is.

If any refactor fails one of these, demote it from `propose` to
`note` ("I noticed this; not recommending action").

## Step 4 — Output

```
## /refactor-simplify summary
- Scope: <path>
- Files scanned: <N>
- Total proposed delete: ~<sum> lines
- Risk gate: <PASS (tests exist) | BLOCKED (no tests, only safe ops) >

## Propose (do these)
- [path:line] <smell name> — current: <1-line shape> → proposed: <1-line shape>. Net: -<N> lines. Risk: low|med|high.
- ...

## Notes (FYI, not recommending action)
- [path:line] <observation>

## Out of scope
- <smells found but require redesign / contract — list briefly>
```

Keep proposals to ≤ 10. If more, group and ask the user to pick a
priority — death by 30 suggestions is worse than 5 acted-on ones.

## When NOT to refactor

This skill exists alongside research/exploratory code. Skip refactor
on:

- Scripts under `/.agent/scratch/`, `/tmp`, or any path ending in
  `*_smoke.py`, `*_diagnostic.py` — exploration artifacts.
- Notebooks (`.ipynb`).
- Files marked with a header comment `# refactor:skip` or `# wip`.
- Code under a slice whose `.agent/projects/<slice>-harness.md`
  marks it as "in flight" or "pre-stable".

Research code's job is to be discarded once the experiment is done.
Polishing it before it has earned its stable status is wasted work.

## Red Flags

| Rationalization | Reality |
|---|---|
| "This refactor will make future changes easier." | YAGNI. Refactor in response to a *second* concrete need, not a hypothetical one. |
| "It's a small style improvement — counts as refactor." | If `post-edit-format.sh` would fix it, it's not a refactor; it's noise. |
| "Net +5 lines, but the new abstraction is cleaner." | Refactor is *delete*. Net-positive line counts get demoted to Notes, not Propose. |
| "I'll add tests as part of the refactor." | Tests land in a *separate* commit *before* the refactor, so they verify the refactor didn't regress. |
| "Bundle the rename with the bug fix — one PR." | Two PRs. Bundling violates Surgical Changes and makes reviews lie about what changed. |
| "The function is 50 lines but the logic is simple — leave it." | 50 lines hides bugs in eye-track. Extract or flatten with early returns; size is not "simple". |
| "Naming is fine, just unconventional." | Unconventional names mislead readers. Rename if a future reader will mis-predict behavior; tolerate if just stylistic. |

## Forbidden

- Do NOT propose introducing a new module, class, or interface
  without an explicit reuse case (2+ existing call sites).
- Do NOT bundle a refactor with a bug fix. If you notice a bug
  while refactoring, file it separately and do not include it.
- Do NOT propose style changes that `post-edit-format.sh` would
  fix automatically.
- Do NOT propose tests-then-refactor as a single PR. Tests land
  first, separately, and prove the refactor is safe.
