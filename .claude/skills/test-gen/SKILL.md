---
name: test-gen
description: Generate unit-test scaffolds for a function, module, or recent diff. Propose test cases by intent (happy path, edge cases, error paths, invariants), then write a pytest file ONLY after the user confirms the proposal. Use when adding tests for new code, backfilling coverage for an untested function, or covering a bug fix with a regression test before /code-review or /handoff.
argument-hint: "<file-path | file-path::function | (empty = uncommitted diff)>"
allowed-tools: Read Grep Edit Write Bash(grep:*) Bash(find:*) Bash(wc:*) Bash(awk:*) Bash(git diff:*) Bash(git log:*) Bash(*pytest --collect-only:*) Bash(*pytest -q:*)
---

# /test-gen — Test-case scaffolder

The goal is to produce **runnable test cases that assert specific
behaviors**, not boilerplate that exercises code without checking
anything. A test that mocks everything tests nothing.

## Step 1 — Resolve target

`$ARGUMENTS` shapes:
- `path/to/file.py` → test the public surface of this module.
- `path/to/file.py::function_name` → test this specific function.
- empty → take the uncommitted diff from the project repo; test
  each touched function that has no existing test.

If the diff spans > 5 functions, ask the user to pick one. Wide
test-gen produces shallow tests; depth on one function is more useful.

## Step 2 — Read the target and its neighborhood

1. The target function / module itself.
2. Its callers (`grep -rn '<name>(' <repo>/` to find them) — the
   tests should reflect how the code is actually used.
3. Existing tests for adjacent code (`grep -l 'def test_' tests/`
   close to the target) — match the project's test style.
4. The project's `conftest.py` and pytest config — what fixtures
   exist? what plugins?

## Step 3 — List behaviors to test

Produce a **bulleted list** of behaviors before writing any code:

```
For function `<name>(<sig>)`:
- happy path: <input shape> → <expected output shape>
- edge: empty input → <behavior>
- edge: single-element input → <behavior>
- edge: <boundary value, e.g. zero, negative, max-size>
- error: <invalid input> raises <ExceptionType>
- invariant: <property that should hold for all inputs of class X>
```

Aim for **3-7 cases per function**. More than 7 means either
(a) the function is doing too many things and should be split, or
(b) you are testing trivial permutations.

## Step 4 — Show the proposal to the user, wait for confirmation

Before writing a file: present the test-case list from Step 3 and
the proposed file path (e.g. `tests/unit/test_<module>.py`). Wait
for "go" / "modify" / "skip" from the user.

Do **NOT** write the file silently. Test files end up in version
control; producing them without review is the same as merging
unreviewed code.

## Step 5 — Write the skeleton

After confirmation, write the pytest file with:

- One `def test_*` per behavior from step 3.
- Real assertions (`assert result == expected`, `pytest.raises(...)`,
  `assert math.isclose(...)` for floats).
- `@pytest.mark.parametrize` when 2+ cases share a setup; each row
  in the parametrize must carry the expected value, not just the
  input.
- Fixtures from `conftest.py` when applicable; do NOT re-create
  identical fixtures locally.
- For property-based tests on numeric code, use `hypothesis` IF
  it's already in the project's dependencies — never add a new
  dependency as part of /test-gen.

For functions you don't know the exact expected output of, write
the test against the **observable invariant** instead:

```python
def test_normalize_preserves_sum():
    out = normalize([1, 2, 3])
    assert math.isclose(sum(out), 1.0)
```

This is honest: it claims a property you can check, not a value
you guessed.

## Step 6 — Verify by collecting (don't run)

After writing, run `pytest --collect-only <test-file>` to verify
the tests parse. Do **NOT** run the tests themselves — that's the
user's call, and a passing-on-first-try test you wrote is suspect
anyway. Let the user run them and report.

## Karpathy alignment

- **Think Before Coding**: the test-case list in step 3 is the
  "think" gate. No tests get written without one.
- **Simplicity First**: parametrize beats copy-paste. One assertion
  per behavior, not three weakly-related ones.
- **Surgical Changes**: do NOT refactor production code to make it
  testable as part of /test-gen. If the target can't be tested
  without changes, say so and route the refactor through a
  separate contract.
- **Goal-Driven**: each `test_*` name must state the behavior
  (`test_returns_empty_on_empty_input`), not the input
  (`test_with_empty_list`).

## Red Flags

| Rationalization | Reality |
|---|---|
| "I'll write the assertions later, this is just structure." | A test without an assertion is a benchmark. Either assert now or drop the test. |
| "Mocking the database lets us test the happy path." | If every dependency is mocked, you tested the test, not the code. Use a fake / in-memory store. |
| "100% coverage is the goal." | Coverage is necessary, not sufficient. A line can be covered by a test that asserts nothing. |
| "I'll make the function take a fake clock so I can test time." | Pass-the-clock is fine. Refactoring it into the function as part of /test-gen is scope creep. |
| "The test was passing before my edit, so the regression isn't tested." | Write the regression test first (red), then the fix (green). Never skip the red step. |

## When NOT to test

- One-off scripts under `/.agent/scratch/`, `/tmp`, `*_smoke.py`.
- Notebooks (.ipynb).
- Throwaway analyses tagged `# wip` or `# experimental`.
- Files in a slice's `recent-cursor-activity-*.md` snapshot zone
  (likely temporary).

If the user explicitly asks for tests on these, comply but warn
that the test value depreciates fast for code likely to be deleted.

## Forbidden

- Do NOT write the test file before the user confirms the proposal
  in Step 4.
- Do NOT add new dependencies (`hypothesis`, `factory_boy`, etc.)
  as part of /test-gen — propose them, let the user add them.
- Do NOT generate tests for private (`_underscored`) functions
  unless the user explicitly asks; test through the public API.
- Do NOT run the tests after writing — let the user do that.
