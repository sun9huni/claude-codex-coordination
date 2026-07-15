---
name: debug
description: Diagnose a failure (stack trace, failing test, unexpected output, or "something broken in X") by ranking hypotheses against evidence and proposing the single most-informative next diagnostic — NOT a fix. Default behavior is hypothesis-first; fixing is a separate skill (/code-review on the proposed patch). Use when an error appears, a test starts failing, or behavior diverges from expectation.
argument-hint: "<symptom: stack trace / test name / 'file does X but should do Y'>"
allowed-tools: Read Grep Bash(git log:*) Bash(git blame:*) Bash(git show:*) Bash(git diff:*) Bash(grep:*) Bash(find:*) Bash(awk:*) Bash(wc:*) Bash(tail:*) Bash(head:*) Bash(cat:*) Bash(*pytest --lf:*) Bash(*pytest -x:*) Bash(*pytest --collect-only:*) Bash(env:*) Bash(which:*)
---

# /debug — Hypothesis-first failure diagnosis

The bug is information you don't have yet. The job of /debug is to
narrow the search, not jump to a fix. If you find yourself writing
an Edit before you've ranked at least two hypotheses with evidence,
stop.

## Step 1 — Capture the symptom

Read `$ARGUMENTS`. Resolve to one of:
- **Stack trace** → identify the deepest frame in *our* code (not
  stdlib, not third-party).
- **Test name** (e.g. `test_foo.py::test_bar`) → re-collect with
  `pytest --collect-only` to confirm it exists; read its source.
- **"File does X but should Y"** → ask: what command was run, what
  output appeared, what was expected. Get the verbatim command if
  not given.
- **Pointer into a log file** → tail the log (`tail -50` first;
  don't load the whole file) and identify the error block.

Also consult the active slice's `.agent/status/<slice>.md` frontmatter
`failure_log` field (optional, per-slice) if it points at a known path
— recent failures often live there.

## Step 2 — Read the failing location

1. The exact `path:line` (or test) where the failure surfaces.
2. The function containing it.
3. Its direct callers — `grep -rn '<funcname>(' <repo>/`.
4. The most recent change to the file:
   `git -C <repo> log -p -3 -- <path>` and `git blame -L <line>,<line> -- <path>`.

Most bugs are recent. If the failing line was edited in the last
10 commits, that edit is hypothesis #1 by default.

## Step 3 — Rank hypotheses

Walk these six lenses **in order**. Stop as soon as you have 2-4
non-trivial candidates with evidence; do not chase to seven.

| Lens | Trigger | Evidence to gather |
|---|---|---|
| **Recent change** | Failing file/line touched in last N commits. | `git blame -L`, `git log -p -- <path>`. Cite commit SHA + author + date. |
| **Boundary value** | Failure on empty / None / zero / max-size / unicode / negative. | Re-read the function's input contract and trace what value fired it. |
| **Wrong assumption** | Code assumes shape X (file exists, list non-empty, key present, network up) but reality is Y. | `find`, `ls`, `env`, `cat config.yaml`. Compare written assumption vs observed reality. |
| **Concurrency / state** | Intermittent. Order-dependent. Worked the first run, failed the second. | Look for global state, mutable defaults, shared caches, race-prone file writes. |
| **Wrong dependency / env** | Worked yesterday / on another machine. | `which <bin>`, version flag (`--version`), check `pyproject.toml` / lockfile diff, `env \| grep <RELEVANT>`. |
| **Test artifact** | Only the test fails; manual reproduction works. | Read the test fixtures / mocks. Could the test setup itself be wrong? |

For each candidate hypothesis, state:

```
H<N>: <one-sentence claim about cause>
  Evidence: <file:line or log line or git ref>
  Confidence: high | med | low
  Distinguishing test: <command that would prove or disprove this>
```

If you cannot name a distinguishing test, the hypothesis is too
vague — sharpen it or drop it.

## Step 4 — Propose ONE diagnostic, not a fix

Pick the single command whose output most cleanly separates your
top two hypotheses. Report it like:

```
Next diagnostic:
  Run: <command>
  Looking for: <signal that confirms H1 vs H2>
  If <output A> → H1 confirmed
  If <output B> → H2 confirmed
  If neither → drop both, re-rank
```

The diagnostic should be **cheap** (seconds to run, no side effects)
and **decisive** (its outcome eliminates ≥ 1 hypothesis).

## Step 5 — Stop. Wait for the user.

Do **NOT** apply a fix in the same turn as diagnosis. Even if you
are 95% sure. The user runs the diagnostic and reports back; the
fix is a separate cycle, ideally routed through `/code-review` or
a `/contract-check` if it touches contract-trigger territory.

When the user reports the diagnostic outcome:
- If a hypothesis is confirmed → describe the **shape** of the fix
  (file:line + what changes + why) but still do not apply unless
  the user says "apply".
- If both hypotheses survive → repeat Step 3-4 with the new evidence
  in hand.

## Karpathy alignment

- **Think Before Coding**: hypotheses before edits. The Step 5
  pause exists exactly to enforce this.
- **Simplicity First**: prefer fixes that delete defensive code
  whose absence wouldn't have caused the bug.
- **Surgical Changes**: the fix should match the narrowest
  hypothesis. Don't generalize.
- **Goal-Driven**: success = the original failure no longer
  reproduces with the same command. Not "looks better".

## Red Flags

| Rationalization | Reality |
|---|---|
| "It's flaky, add a retry." | Flakiness is a real bug — a hidden state variable or race. Retries hide it from CI while leaving production exposed. |
| "Works on my machine." | The env diff is the bug. Find it (env vars, package versions, file paths, OS) before any fix. |
| "Probably a race." | Without evidence (timing logs, repro under load), this is hand-waving. Demote to low-confidence and look elsewhere first. |
| "Let's catch and ignore." | Silenced exceptions hide the real failure. Either let it propagate or handle it with a specific recovery; never `except: pass`. |
| "It's an upstream bug." | Possible — but first prove our code uses the upstream correctly. Most "upstream bugs" are local misuse. |
| "Just print and we'll see." | Print-debugging is fine, but if it ships in the diff, the diff is wrong. Print → diagnose → remove before /code-review. |
| "Roll back the suspicious commit, see if it goes away." | OK as a **diagnostic**, not as a fix. Even if reverting clears the symptom, you still need to know *why* before re-landing. |

## Special cases

### Slurm / long-running job failures (workspace-specific)

For sbatch failures, the diagnostic path is:
1. `squeue -j <id>` or `sacct -j <id> --format=State,ExitCode,Start,End`
2. Read `<log-dir>/*<jobid>*.{out,err}` via `tail -100` first.
3. Common patterns: OOM (look for `oom`, `Killed`), MSA timeout, GPU
   alloc fail (look for `CUDA out of memory`), docker-init race.

Delegate to `Agent(subagent_type="slurm-status", ...)` if the user
needs cluster-side context rather than code-side.

### Test failures that pass locally

Always check:
1. `pyproject.toml` / lockfile vs the CI lockfile diff.
2. Env var differences (`env > /tmp/local.env`; compare with CI).
3. Time-zone / locale / float-precision (especially on macOS vs
   Linux runners).
4. Random seed determinism — was the seed pinned?

## Forbidden

- Do NOT apply a fix in the diagnosis turn.
- Do NOT propose a hypothesis without an evidence anchor (`path:line`,
  log line, or git ref).
- Do NOT include the print-debugging output in any committed change.
- Do NOT suggest "add try/except" without naming the specific
  exception class and the recovery action.
- Do NOT silently re-run a flaky test until it passes. Diagnose
  the flakiness or mark `xfail` with a ticket.
