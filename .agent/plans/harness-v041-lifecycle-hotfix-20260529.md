---
contract: .agent/contracts/harness-v041-lifecycle-hotfix-20260529.md
slice: harness
status: done
total_tasks: 15
estimated_total_min: 62
---

# Plan — Harness v0.4.1 lifecycle hotfix

Bundles 4 follow-on items from the v0.4.0 system-issues review:
(1) Stop hook detects missed `/handoff` per-slice, (2) `state:
active|closed|released` frontmatter field, (3) `handoff.sh --release
<slice>` verb, (4) auto-commit of the slice's own untracked
contracts/plans on handoff.

Phase order: **Red test → Schema/Core (workspace) → Docs/Codex parity
(workspace) → Verify workspace → Port upstream → Verify upstream →
Push gate**.

Workspace work goes onto `master` directly (workspace convention from
the v0.4.0 work). Upstream port goes onto a branch
`v0.4.1-lifecycle-hotfix` in `scratch/claude-codex-coordination`.

Session-marker design (used by Tasks 5+6): both SessionStart and Stop
hooks read `session_id` from the stdin JSON Claude Code passes to them
and write/read per-session markers under
`$AGENT_DIR/handoffs/state/session-markers/<session_id>.start`
(epoch in the file content). This is multi-session-safe — each session
reads its own marker. Falls back silently if stdin is empty or not JSON.

Auto-commit safeguards (Task 4): only acts on untracked files matching
`.agent/contracts/<slice>-*-*.md` and `.agent/plans/<slice>-*-*.md`;
refuses if the working tree has OTHER dirty changes (tracked
modifications or non-slice-prefixed untracked); non-fatal — warns and
returns 0 if it can't commit.

---

## Task 1: Red lifecycle test (failing baseline)

- **Status**: done (2026-05-29, commit ac688b2; 4/4 FAIL as designed; hermetic sandbox+AGENT_ROOT pattern; scrub clean; code-review APPROVE)
- **Prereq tasks**: none
- **Files touched**: `tests/run-harness-lifecycle.sh` (new, workspace)
- **Change shape**: New hermetic test (sandbox repo + AGENT_ROOT, same pattern as `tests/run-harness-concurrency.sh`). 4 assertions, each currently RED: (A1) `handoff.sh --release <slice>` clears `owner_session`/`owner_label`/`heartbeat` and sets `state: released`; (A2) handoff.sh on a baton with no `state:` field treats it as `active`, and a baton with `state: released` shows that value preserved through a subsequent claim; (A3) auto-commit — on a clean fixture git repo with two untracked files `.agent/contracts/slice-1-foo-20260529.md` + `.agent/plans/slice-1-foo-20260529.md`, running `handoff.sh claude slice-1` creates exactly one new commit whose message starts `slice-1:` and includes those two files; on a fixture with an UNRELATED dirty file, the same run does NOT auto-commit and prints a one-line warning; (A4) Stop hook missed-handoff — with a SessionStart-written session-marker dated NOW and a slice-1 baton whose heartbeat is from 24h ago AND owner_session matches the current session, Stop prints `[handoff-check] session ended without running handoff.sh for slice 'slice-1'`. Each assertion follows the `pass N "..."` / `fail N "..."` pattern. Verdict: `lifecycle: $FAILS/4 FAIL` or `4/4 GREEN`. Make executable.
- **Verification**: `bash -n /home/ubuntu/tests/run-harness-lifecycle.sh`; `bash /home/ubuntu/tests/run-harness-lifecycle.sh; echo $?` → exit 1 (RED — 4/4 FAIL expected, since none of the 4 features land until later tasks).
- **Estimated time**: 7 min
- **Rollback (if this task only)**: `rm /home/ubuntu/tests/run-harness-lifecycle.sh`

## Task 2: handoff.sh — `state` field handling

- **Status**: done (2026-05-29, commit 8ea2584; insert_default[state]=active, dedicated preserve-line branch; A2 PASS; code-review APPROVE)
- **Prereq tasks**: 1
- **Files touched**: `/home/ubuntu/scripts/handoff.sh`
- **Change shape**: In slice mode, add `state` to the managed fields list (6 → 7). Behavior: if the existing frontmatter has `state:`, preserve its value verbatim (do NOT auto-flip on every claim); if absent, INSERT `state: active` at the closing `---`. Update the `awk BEGIN { split(...); val[...] = ...; ... }` block and the field count. Do NOT change `--release` semantics yet (that's Task 3). NO behavioral change for an already-correct baton; only additive default for batons missing the field.
- **Verification**: smoke: temp baton with no `state:` → after `handoff.sh claude slice-1` against a temp AGENT_ROOT, grep `^state: active$` in the file. Smoke: temp baton with `state: released` → after claim, grep `^state: released$` (preserved). `bash -n` clean. Lifecycle-test A2 will pass after this task; A1/A3/A4 stay RED.
- **Estimated time**: 5 min
- **Rollback (if this task only)**: `git -C /home/ubuntu checkout scripts/handoff.sh`

## Task 3: handoff.sh — `--release <slice>` verb

- **Status**: done (2026-05-29, commit c0cb918; release rewriter parallel to claim rewriter, owner_agent preserved, idempotent; A1 PASS; code-review APPROVE)
- **Prereq tasks**: 2
- **Files touched**: `/home/ubuntu/scripts/handoff.sh`
- **Change shape**: Add a `--release <slice>` invocation. Argv parsing: `--release` (or `-r`) must come BEFORE the slice arg or as `handoff.sh --release <slice>`; if `--release` is set, the script runs a release path that (a) acquires the lock, (b) reads the slice file, (c) rewrites frontmatter — clears `owner_session`/`owner_label`/`heartbeat` to empty strings, sets `state: released`, bumps `version`, sets `last_updated` to today; preserves `owner_agent`, `remaining_actions`, `contract_pointers`, body verbatim, (d) exits 0. Usage line updated. Idempotent: re-running `--release` on an already-released slice just refreshes `last_updated` (no harm). Skip auto-commit on release (that's Task 4, which on release path means: still scan for untracked slice contracts/plans, but with the same dirty-tree guard).
- **Verification**: smoke: temp baton with `owner_session: foo`, `heartbeat: 2026-05-29T...Z`, `state: active` → `handoff.sh --release slice-1` against temp AGENT_ROOT → grep shows `owner_session: $`, `heartbeat: $`, `state: released`; body and `remaining_actions` preserved. Second run = idempotent (no diff except `last_updated`/heartbeat-which-stays-empty/version). `bash -n` clean. Lifecycle-test A1 PASS after this task.
- **Estimated time**: 5 min
- **Rollback (if this task only)**: `git -C /home/ubuntu checkout scripts/handoff.sh`

## Task 4: handoff.sh — auto-commit untracked slice contracts/plans

- **Status**: done (2026-05-29, commit b22697e; slice_auto_commit() shared by claim+release paths, dirty-tree policy ignores baton+outside noise, --no-auto-commit opt-out; A3 PASS; code-review APPROVE w/ documented spec relaxation for outside-noise handling)
- **Prereq tasks**: 3
- **Files touched**: `/home/ubuntu/scripts/handoff.sh`
- **Change shape**: After the slice frontmatter write (BOTH normal `<agent> <slice>` and `--release <slice>` paths), AND after the lock is released, run an auto-commit step: (1) only if `git -C "$ROOT" rev-parse --is-inside-work-tree` succeeds; (2) collect `git status --porcelain` output; (3) check that NO line starts with anything other than `?? ` (untracked) — i.e., zero modified/added/deleted tracked files — AND that all untracked lines match either `?? .agent/contracts/<slice>-` or `?? .agent/plans/<slice>-`; (4) if BOTH conditions hold AND at least one such file exists, `git add` them and `git commit -m "<slice>: contracts/plans auto-commit (handoff)"`; (5) if conditions fail, print one-line warning (`[handoff] auto-commit SKIPPED: working tree has other dirty changes` or `... has no untracked slice contracts/plans`) to stderr and continue (exit 0). NEVER fails the handoff. Add a `--no-auto-commit` flag to opt-out.
- **Verification**: smoke under temp git repo (`git init` a fixture, copy handoff.sh into it, seed `.agent/status/slice-1.md` baton + two untracked files matching the slice pattern, run `handoff.sh claude slice-1`, then `git -C "$REPO" log -1 --name-only` should show those 2 files and message starts with `slice-1:`). Smoke: same but with an extra modified tracked file → no new commit, warning printed. `bash -n` clean. Lifecycle-test A3 PASS after this task.
- **Estimated time**: 6 min
- **Rollback (if this task only)**: `git -C /home/ubuntu checkout scripts/handoff.sh`

## Task 5: SessionStart hook — write per-session marker

- **Status**: done (2026-05-29, commit 9afd49d; Job 1c between 1b and 2, terminal-check guard, JSON-failsafe; 3 smokes pass; code-review APPROVE)
- **Prereq tasks**: 1
- **Files touched**: `/home/ubuntu/.claude/hooks/session-start-decay-check.sh`
- **Change shape**: At the END of the existing Job 1 / Job 1b section (BEFORE Job 2), add a new block: parse stdin JSON if present (`python3 -c 'import json,sys; d=json.load(sys.stdin); print(d.get("session_id",""))'`) to extract `session_id`; if non-empty, `mkdir -p "$AGENT_DIR/handoffs/state/session-markers"` and `printf '%s\n' "$(date +%s)" > "$AGENT_DIR/handoffs/state/session-markers/$session_id.start"`. If stdin is empty / not JSON / session_id missing, do nothing silently. Best-effort; never fails the hook. Independent of the existing claim-check.
- **Verification**: simulate stdin: `echo '{"session_id":"test-abc"}' | bash <hook>` against temp AGENT_ROOT → assert `<AGENT_DIR>/handoffs/state/session-markers/test-abc.start` exists and its content parses as an epoch (digits only). Empty stdin: `bash <hook> </dev/null` → no error, no marker file created. `bash -n` clean.
- **Estimated time**: 4 min
- **Rollback (if this task only)**: `git -C /home/ubuntu checkout .claude/hooks/session-start-decay-check.sh`

## Task 6: Stop hook — missed-handoff warning + state-enum validation

- **Status**: done (2026-05-29, commit e999e6c; both checks additive, iso_to_epoch+fm_scalar copied to avoid sourcing; lifecycle 4/4 GREEN, concurrency 5/5 preserved; code-review APPROVE)
- **Prereq tasks**: 5
- **Files touched**: `/home/ubuntu/.claude/hooks/stop-handoff-check.sh`
- **Change shape**: TWO additive checks. (a) Missed-handoff: parse stdin JSON for `session_id` (same helper as Task 5); if non-empty AND `$AGENT_DIR/handoffs/state/session-markers/<session_id>.start` exists, read its epoch as `session_start`; then for EACH slice baton with non-empty `owner_session` matching the current session's `owner_session` (probed via env `OWNER_SESSION` if set, OR via Claude harness convention — best-effort), check heartbeat epoch vs `session_start`: if heartbeat < session_start, print `[handoff-check] session ended without running handoff.sh for slice '<slice>' (heartbeat <N>m before session start)`. If env not set, do a weaker check: for any claimed slice whose heartbeat is older than `session_start`, warn (less precise — may catch other-session work, but useful). (b) State-enum validation: in the existing `validate_slice` python block, after the required-fields check, validate `state` if present must be in `{active, closed, released}`; absent is OK (defaults to active). Adds one line to `errs` on bad value.
- **Verification**: fixture 1 (missed handoff): tmp AGENT_ROOT, write `session-markers/sX.start` with NOW, write `status/slice-1.md` with `owner_session: sX`, `heartbeat: <24h ago>`; `echo '{"session_id":"sX"}' | OWNER_SESSION=sX bash <hook>` → stderr contains `session ended without running handoff.sh for slice 'slice-1'`. Fixture 2 (good state): baton has `state: active` → validation passes. Fixture 3 (bad state): baton has `state: bogus` → stderr contains `state must be one of` or similar. `bash -n` clean. Lifecycle-test A4 PASS after this task.
- **Estimated time**: 6 min
- **Rollback (if this task only)**: `git -C /home/ubuntu checkout .claude/hooks/stop-handoff-check.sh`

## Task 7: status.sh index_mode — `state` column

- **Status**: done (2026-05-29, commit c0ed783; column + emoji rendering, per-slice headers updated; live workspace index regenerated showing column; concurrency 5/5 preserved; code-review APPROVE)
- **Prereq tasks**: 2
- **Files touched**: `/home/ubuntu/scripts/status.sh`
- **Change shape**: In the index_mode `index_mode()` python heredoc, add a `state` field to the per-slice dict (default `"active"` if absent); add a `state` column to the rendered Markdown table between `agent` and `last_updated` (or wherever fits); render `closed` and `released` distinctly (e.g. `🔒 closed`, `📦 released`, `live` for active w/ fresh heartbeat). Update the per-slice detail section header to include the state.
- **Verification**: temp AGENT_ROOT with 3 slice fixtures (one active, one `state: closed`, one `state: released`) → `AGENT_ROOT=... bash scripts/status.sh index` → grep `closed` and `released` in the resulting CURRENT.md; grep `^| state` or `state | ` in the table header. `bash -n` clean.
- **Estimated time**: 5 min
- **Rollback (if this task only)**: `git -C /home/ubuntu checkout scripts/status.sh`

## Task 8: Doc — `.agent/status/README.md` schema + verbs

- **Status**: done (2026-05-29, commit 07282c0; state field + Lifecycle verbs + Auto-commit subsection; surgical additions only; code-review APPROVE)
- **Prereq tasks**: 2,3,4
- **Files touched**: `/home/ubuntu/.agent/status/README.md`
- **Change shape**: Add `state` to the frontmatter schema (one bullet: `state — lifecycle: active | closed | released. Default active.`); update the YAML example to include `state: active`. Add a new short section "Lifecycle verbs": (a) `handoff.sh <agent> <slice>` — claim/refresh, default `state: active`. (b) `handoff.sh --release <slice>` — clear ownership, set `state: released`. (c) Auto-commit note: handoff.sh auto-commits untracked `.agent/contracts/<slice>-*-*.md` and `.agent/plans/<slice>-*-*.md` if the working tree is otherwise clean (use `--no-auto-commit` to skip).
- **Verification**: `grep -q '^- `state`' .agent/status/README.md` and `grep -q 'Lifecycle verbs' .agent/status/README.md` and `grep -q -- '--release' .agent/status/README.md`.
- **Estimated time**: 3 min
- **Rollback (if this task only)**: `git -C /home/ubuntu checkout .agent/status/README.md`

## Task 9: /handoff skill + Codex parity (AGENTS.md + .codex SKILL.md)

- **Status**: done (2026-05-29, commit eeb3cd8; 3 files updated in parallel, skill-lint 14/14 preserved; code-review APPROVE)
- **Prereq tasks**: 2,3,4
- **Files touched**: `/home/ubuntu/.claude/skills/handoff/SKILL.md`, `/home/ubuntu/AGENTS.md`, `/home/ubuntu/.codex/skills/handoff-writer/SKILL.md`
- **Change shape**: (a) `/handoff` SKILL body: in the step that runs `handoff.sh <agent> <slice>`, note that the script auto-commits untracked slice contracts/plans (if tree otherwise clean) and that `--release` is available for slice closure. (b) `AGENTS.md` § Per-slice schema: add `state` to the field list; mention `--release` for terminal handoff. (c) Codex `.codex/skills/handoff-writer/SKILL.md`: same parity — Codex sessions must preserve `state` like the other managed fields and may use `--release` for slice closure.
- **Verification**: `grep -q 'state' /home/ubuntu/AGENTS.md` (state field documented); `grep -q -- '--release' /home/ubuntu/.claude/skills/handoff/SKILL.md`; `grep -q 'state' /home/ubuntu/.codex/skills/handoff-writer/SKILL.md`. Skill-lint check: `bash /home/ubuntu/tests/run-skill-lint.sh` → still PASS (handoff skill must keep its lint compliance).
- **Estimated time**: 4 min
- **Rollback (if this task only)**: `git -C /home/ubuntu checkout .claude/skills/handoff/SKILL.md AGENTS.md .codex/skills/handoff-writer/SKILL.md`

## Task 10: Workspace verification GATE

- **Status**: done (2026-05-29; concurrency 5/5 GREEN, lifecycle 4/4 GREEN, skill-lint 14/14, bash -n clean on all 5 modified files. Workspace is fully functional for the 4 v0.4.1 features.)
- **Prereq tasks**: 1,2,3,4,5,6,7,8,9
- **Files touched**: none (verification only)
- **Change shape**: Run all workspace tests. NO code change. If any fails, stop the loop and route the failing area back for fix.
- **Verification**: `bash /home/ubuntu/tests/run-harness-concurrency.sh` → 5/5 GREEN (regression preserved); `bash /home/ubuntu/tests/run-harness-lifecycle.sh` → 4/4 PASS; `bash /home/ubuntu/tests/run-skill-lint.sh` → still PASS; `bash -n` clean on all 3 modified shell scripts.
- **Estimated time**: 3 min
- **Rollback (if this task only)**: n/a (verification)

## Task 11: Upstream branch + port handoff.sh + status.sh

- **Status**: done (2026-05-29, upstream commit ca0d07e; branch v0.4.1-lifecycle-hotfix; both files byte-identical to workspace in modified regions; scrub clean; code-review APPROVE)
- **Prereq tasks**: 10
- **Files touched**: `scratch/claude-codex-coordination/scripts/{handoff.sh, status.sh}` (on new branch `v0.4.1-lifecycle-hotfix`)
- **Change shape**: `git -C scratch/claude-codex-coordination checkout -b v0.4.1-lifecycle-hotfix` off main @ f5dd897. Port Tasks 2+3+4 changes into upstream `scripts/handoff.sh` (the workspace version is byte-identical for these regions, so this is a direct copy of the modified sections). Port Task 7's `state` column changes into upstream `scripts/status.sh` index_mode (the index_mode portion is byte-identical between workspace and upstream — keep it that way).
- **Verification**: `git -C scratch/claude-codex-coordination branch --show-current` = `v0.4.1-lifecycle-hotfix`. `bash -n` clean on both files. Smoke against temp AGENT_ROOT in `scratch/claude-codex-coordination`: `handoff.sh --release slice-1` works as in workspace Task 3. Scrub: `git -C scratch/claude-codex-coordination diff main...HEAD scripts/ | grep -iE 'fragmap|mmgbsa|fksfold|slurm|notion|9nfr|/mnt/data|kim|sunghoon'` → empty.
- **Estimated time**: 5 min
- **Rollback (if this task only)**: `git -C scratch/claude-codex-coordination checkout main && git -C scratch/claude-codex-coordination branch -D v0.4.1-lifecycle-hotfix`

## Task 12: Upstream port — hooks + status README + ritual docs

- **Status**: done (2026-05-29, upstream commit 6a29a82; preserved pre-existing upstream drift while applying additive v0.4.1 changes; .agent/templates/AGENTS.md.example does not exist upstream — skipped per task; code-review APPROVE; scrub CLEAN)
- **Prereq tasks**: 11
- **Files touched**: `scratch/claude-codex-coordination/.claude/hooks/{session-start-decay-check.sh, stop-handoff-check.sh}`, `scratch/claude-codex-coordination/.agent/status/README.md`, `scratch/claude-codex-coordination/.agent/templates/AGENTS.md.example` (if exists in upstream)
- **Change shape**: Port Task 5 (SessionStart marker), Task 6 (Stop hook missed-handoff + state enum), Task 8 (status README schema + verbs) into upstream. The workspace hook files share the same logic; copy the modified regions. README.md schema update is the same. The Codex `.codex/skills/handoff-writer/SKILL.md` does NOT exist upstream (Codex skills are workspace-specific); skip that file. If `.agent/templates/AGENTS.md.example` exists in upstream, mirror the AGENTS.md state-field doc there too.
- **Verification**: `bash -n` clean on both hooks. Scrub: `git -C scratch/claude-codex-coordination diff main...HEAD | grep -iE 'fragmap|mmgbsa|fksfold|slurm|notion|9nfr|/mnt/data|kim|sunghoon'` → empty.
- **Estimated time**: 5 min
- **Rollback (if this task only)**: `git -C scratch/claude-codex-coordination checkout .claude/hooks/ .agent/status/README.md .agent/templates/` (if applicable)

## Task 13: Upstream port — lifecycle test + CHANGELOG [0.4.1]

- **Status**: done (2026-05-29, upstream commit 5b64f43; lifecycle test 4/4 GREEN standalone upstream — end-to-end proof of T11+T12; CI step wired at matching indentation; CHANGELOG [0.4.1] above [0.4.0]; code-review APPROVE)
- **Prereq tasks**: 12
- **Files touched**: `scratch/claude-codex-coordination/tests/run-harness-lifecycle.sh` (new), `scratch/claude-codex-coordination/.github/workflows/test.yml`, `scratch/claude-codex-coordination/CHANGELOG.md`
- **Change shape**: Port the workspace's `tests/run-harness-lifecycle.sh` (Task 1's neutral-fixture version — the workspace one is already fixture-neutral by design). Wire it into `.github/workflows/test.yml` as a new step after `Run harness concurrency test`. Add `## [0.4.1] - 2026-05-29` entry to `CHANGELOG.md` above `[0.4.0]` describing the 4 added features (state field, --release verb, auto-commit, missed-handoff detection) and the SessionStart marker mechanism.
- **Verification**: `bash -n` on the new test; `cd scratch/claude-codex-coordination && bash tests/run-harness-lifecycle.sh` → 4/4 PASS; YAML valid: `python3 -c "import yaml; yaml.safe_load(open('.github/workflows/test.yml'))"`; `grep -q '\[0.4.1\]' scratch/claude-codex-coordination/CHANGELOG.md`. Scrub: `grep -iE 'fragmap|mmgbsa|fksfold|slurm|notion|9nfr|/mnt/data|kim|sunghoon' tests/run-harness-lifecycle.sh CHANGELOG.md` → empty.
- **Estimated time**: 5 min
- **Rollback (if this task only)**: `git -C scratch/claude-codex-coordination checkout tests/ .github/workflows/test.yml CHANGELOG.md && rm scratch/claude-codex-coordination/tests/run-harness-lifecycle.sh`

## Task 14: Upstream HARD GATE — scrub + all tests

- **Status**: done (2026-05-29; scrub CLEAN of full branch diff; skill-lint 11/11, hook-tests 13/13, concurrency 5/5, lifecycle 4/4 GREEN; bash -n sweep + JSON + YAML all OK. **Found + fixed a real stdin-hang bug** during this gate — Job 1c/missed-handoff json.load(stdin) blocked when stdin connected but empty; replaced with select.select(0.05s). Fix landed in workspace commit 915b84b + upstream commit b005cdd before tests passed.)
- **Prereq tasks**: 13
- **Files touched**: none (verification only)
- **Change shape**: Scrub gate over the full branch diff + run all four template test scripts. NO code change.
- **Verification**: in `scratch/claude-codex-coordination`: (a) `git diff main...HEAD | grep -iE 'fragmap|mmgbsa|fksfold|slurm|notion|9nfr|/mnt/data|kim|sunghoon'` → **empty**; (b) `bash tests/run-skill-lint.sh` → PASS; (c) `bash tests/run-hook-tests.sh` → PASS; (d) `bash tests/run-harness-concurrency.sh` → 5/5 GREEN; (e) `bash tests/run-harness-lifecycle.sh` → 4/4 PASS. CI mirror: `bash -n` all `.sh`, JSON+YAML validity.
- **Estimated time**: 3 min
- **Rollback (if this task only)**: n/a (verification gate)

## Task 15: PUSH GATE — commit, push, open PR, tag v0.4.1 (after merge)

- **Status**: done (2026-05-29; user confirmed at push gate "Push + PR 열기" → pushed v0.4.1-lifecycle-hotfix to origin; opened PR #2 → main; CI green on ubuntu+macos (~12s each, MERGEABLE/CLEAN); user confirmed at merge gate "Merge + tag v0.4.1" → squash-merged (mergeCommit f9a59b0), branch deleted; tag v0.4.1 pushed. main: f5dd897 → f9a59b0. https://github.com/sun9huni/claude-codex-coordination/pull/2)
- **Prereq tasks**: 14
- **Files touched**: none (git commit/push in `scratch/claude-codex-coordination`)
- **Change shape**: **STOP and confirm with the user before pushing** (public-repo push gate, matches v0.4.0 flow). Then commit the branch (one or a few logical commits — handoff.sh / hooks / status.sh / docs+changelog), `git push -u origin v0.4.1-lifecycle-hotfix`, `gh pr create` titled "v0.4.1: per-slice lifecycle hotfix (state field, --release, auto-commit, missed-handoff detection)" against main. After CI passes AND the user confirms a second time at the merge gate, `gh pr merge --squash --delete-branch`, then `git tag -a v0.4.1 -m "..." f5dd897-or-merge-sha && git push origin v0.4.1`. NO direct main push; NO force push.
- **Verification**: `gh pr view --repo sun9huni/claude-codex-coordination` shows the open PR; after merge, `git ls-remote origin main` ≠ f5dd897 (advanced to the merge commit); `git tag -l v0.4.1` returns the tag locally; `git ls-remote origin refs/tags/v0.4.1` returns the tag on origin; `git -C scratch/claude-codex-coordination status -s` clean.
- **Estimated time**: 5 min
- **Rollback (if this task only)**: `gh pr close <n>` + `git push origin --delete v0.4.1-lifecycle-hotfix` (main untouched until merge); if tag pushed by mistake, `git push origin :refs/tags/v0.4.1`
