# Server Workspace Guide

## Purpose

This `/home/ubuntu` workspace is operated with Codex as a primary implementation
agent across multiple project directories. Humans define intent, constraints,
and acceptance criteria. Codex inspects the relevant project, implements scoped
changes, verifies them, and reports the result.

## Workspace Map

- `FKSFold-Boltz_Advancement/`, `DeepTernary/`, `BindCraft/`, and similar
  top-level directories are project workspaces.
- `f105_pdbs_upload/` is an uploaded/input data area and may be a symlink to
  shared storage.
- `docs/` is the human-maintained source of truth: `product/`, `architecture/`,
  `adr/`, `runbooks/`, `qa/`. Agents read these but do not regenerate them.
- `.agent/` contains Codex harness artifacts for planning, checklists, remote
  work, evals, skills, tools, and knowledge. `.agent/knowledge/` is the
  agent-readable compiled view of `docs/`, not a duplicate.
- `.agent/projects/` contains project-specific harness designs inferred from
  active workstreams.
- `scripts/` contains standard harness entrypoints such as `verify.sh`.
- `skills/` contains the server-local copy of harness skills.
- `.codex/` contains the user-level Codex configuration and installed skills.

## Precedence

- If a project has its own `AGENTS.md`, follow that project file first.
- If a nested directory has a more specific `AGENTS.md`, follow the nested file
  for that subtree.
- Use this file as the default rule set when no project-specific guide exists.

## Agent Handoff Protocol

Chat sessions (Codex, Claude, Cursor) are not durable. Working state
lives in the repo, not the chat.

- At session start: read `.agent/handoffs/CURRENT.md` before acting. It
  is a DERIVED lab-wide index showing which session owns which slice; it
  is regenerated from `.agent/status/<slice>.md` files and must not be
  hand-edited.
- Identify the slice you will work on, then read that slice's
  `.agent/status/<slice>.md`. The per-slice status file is the
  authoritative baton for `owner_session`, `heartbeat`,
  `remaining_actions`, and `contract_pointers`.
- Baton hygiene (this feeds the Notion Navigator action queues): in
  `remaining_actions`, lead with the ACTUAL next action — not a `✅`-done
  summary — and prefix items with `DECISION:` / `AGENT:` / `BLOCKED:` so
  they classify into the right cockpit queue. Keep each item valid YAML
  (quote strings with `:` or `'`; a bare apostrophe breaks `yaml.safe_load`).
  See `.agent/status/README.md` for the full convention.
- When taking over a slice owned by another agent or session, read
  `.agent/handoffs/takeover-prompt.md` and use its per-slice liveness
  rules. A fresh heartbeat under a different `owner_session` means the
  slice may still be live; coordinate before writing.
- Before context runs out, before switching agents, or before pausing
  for approval: update only your slice's `.agent/status/<slice>.md`, run
  `./scripts/handoff.sh <next-agent> <slice>`, then run
  `./scripts/status.sh index` to regenerate the derived `CURRENT.md`
  index.
- For terminal slice closure (the work is genuinely done, not just
  paused), use `./scripts/handoff.sh --release <slice>` — this clears
  owner fields, sets `state: released`, and bumps `version`. It is
  idempotent. Do not use `--release` mid-session.
- See `.agent/handoffs/README.md` for the full protocol.

### Per-slice baton schema

`.agent/status/<slice>.md` carries a YAML frontmatter block. The
canonical field list lives in `.agent/status/README.md`; the managed
fields are:

- `owner_session`, `owner_label`, `owner_agent` — live ownership.
- `version`, `last_updated`, `heartbeat` — bump/stamp on each write.
- `remaining_actions`, `contract_pointers` — per-slice next steps and
  links.
- `state` — lifecycle: `active` | `closed` | `released`. Defaults to
  `active` if absent. `handoff.sh` **preserves** `state` if present;
  only `handoff.sh --release <slice>` flips it to `released`. Sessions
  must not hand-edit `state` to skip the release verb.

This protocol is shared by Codex (`AGENTS.md`, `.codex/skills/handoff-writer/`)
and Claude (`CLAUDE.md`, `skills/handoff-writer/`).

## Notion IA (v0.5)

Notion is a **derived view** of `.agent/` state (reverse sync is a non-goal).
v0.5 consolidates the old five surfaces into **three databases** fronted by a
**Navigator home**. Real IDs live in `.agent/notion_map.yaml` (`v0_5:`); full
detail is in `docs/notion-sync-runbook.md`. This is a concise summary, not a
duplicate.

The three databases (one row each):

- **Slices DB** — one row per slice. `Status` is derived from the slice's
  `state:` frontmatter: `active→활성`, `closed→완료`, `released→릴리즈`,
  `dormant→휴면` (missing/blank defaults to `활성`). Identifiers stay English.
- **Decisions DB** — restructured as an **ADR registry**. ADR `Status`
  (Proposed / Accepted / Rejected / Implemented / Superseded) is derived from the
  source contract's `status:`: `pending→Proposed`, `approved→Accepted`,
  `done→Implemented`. `Rejected` / `Superseded` are set manually.
- **Experiments DB** — one row per SLURM job / phase / release (W&B pattern).

**Navigator home** = five linked views: Active Slices / Recent Decisions /
Running Experiments / Recent Reports / Docs.

**Lifecycle.** v0.5 `/handoff` Step 5 is shipped and live-verified as of
2026-06-01 for MCP-backed handoff sessions: Slices row refresh, contract
`approved→done` ADR updates, and selected SLURM→Experiments upserts have been
verified. It is still **MCP-only / compute-then-apply**: `scripts/notion_sync.py
--migrate {slices,contracts,slurm,home,all}` prints upsert-keyed JSON; the
in-session Notion MCP applies writes. The headless token remains blocked, so do
not imply daemon/cron or headless network writes. Codex uses the warn-only mirror
in `.codex/skills/handoff-writer/SKILL.md`; if MCP is unavailable, skip Notion
and keep `.agent/` as the source of truth. See `docs/notion-sync-runbook.md` for
the full procedure.

## Quick Router

For day-to-day work, start at `WORKFLOW.md` (one-screen decision tree). It
routes to the right `.agent/projects/*.md` harness, lists contract triggers,
and names approval gates. Read this file (`AGENTS.md`) for the underlying
rules when the router points back here.

## Working Rules

- Read the relevant `AGENTS.md` before planning or editing.
- For active FKSFold-Boltz work, read the matching document under
  `.agent/projects/` before editing or launching jobs.
- Read `.agent/checklists/change-discipline.md` before non-trivial edits.
- For complex work, create or update a plan under `.agent/contracts/`.
- Prefer existing project patterns over new abstractions.
- Keep changes scoped to the user request and the affected project.
- Do not modify secrets, production config, or destructive infrastructure paths
  unless explicitly approved.
- Do not treat unrelated top-level project directories as part of the same
  change unless the user asks for cross-project work.

## 출력 문체 (한국어, anti-AI)

모든 한국어 출력(채팅 답변·리포트·Notion 저장)에 적용한다. 의미·수치·고유명사·인용·기술용어는
보존하고 과편집하지 않는다(표·데이터는 장르대로 유지; 30% 넘게 고치면 경고, 50% 정지).
출처: github.com/epoko77-ai/im-not-ai.

- em-dash(—)를 쓰지 않는다. 마침표·괄호로 끊는다.
- 볼드(`**`)·이모지·★ 장식은 최소화한다. 표는 데이터 용도로만 둔다.
- [S1] 연결어미 뒤 쉼표 금지: "~하고,", "~하며,", "~여,".
- [S1] AI 상투구 금지: 결론적으로, 시사하는 바가 크다, 주목할 만하다, (불필요한) 혁신적인.
- 첫째/둘째/셋째 나열을 쓰지 않는다. 흐르는 문장으로 쓴다.
- 문장 머리에 또한/따라서/즉/그리고를 반복하지 않는다.
- 번역투 금지: ~를 통해, ~에 대해, ~에 있어서, 이중피동(~되어진다), 불필요한 "가지고 있다".
- 과한 헤지("~할 수 있을 것으로 보인다")와 수식 중복(매우/정말 겹침)을 피한다.
- 문장 길이와 어미를 다양화한다. 평서체(-다) 기조는 리포트 규약대로 유지하되 단조로움을 피한다.
- 영어 병기는 한국어 대응어가 있을 때만 줄이고, 학술·기술 용어(metadynamics, near-attack 등)는 그대로 둔다.

## Worktree Discipline

For parallel-worker execution (design pattern B: independent write scopes
running concurrently), prefer git worktrees over branches in the same checkout.
Rules:

- One worktree per concurrent task. Write scopes must not overlap.
- The main checkout is reserved for integration, conflict resolution, and the
  final verification run — not for in-flight worker writes.
- Worktree lifecycle is managed by the harness (`EnterWorktree` / `ExitWorktree`
  on Claude; equivalent isolation on Codex). Do not invent ad-hoc worktree
  directories outside that flow.
- This workspace (`/home/ubuntu`) is not a git tree, so worktree discipline
  applies inside each project repo (e.g. `FKSFold-Boltz_Advancement/`), not at
  the workspace root.

## Approval Gates

Stop and ask before:

- DB schema changes
- deployment or release changes
- destructive file operations
- secret or credential rotation
- external side effects on production services
- **any GPU/CUDA execution** — model loading, inference, training, or even
  a "quick smoke test." This applies regardless of path: SLURM submission,
  a direct inline call, or a subagent doing it as a side effect of some
  other task. The `ubuntu` account/session must NEVER touch a GPU directly
  — all real GPU compute goes through SLURM under the `kim` account/QOS
  (see `reference_uncontainerize_gpu` in memory). Ask again each time, even
  if a prior GPU run was approved — approval does not carry over to the
  next job. When delegating a task to a subagent, explicitly forbid GPU use
  in the prompt unless this gate has already been cleared for that specific
  run; do not leave it as an implicit option ("CPU or available GPU") for
  the subagent to choose.
- **any CPU compute expected to run ≥10 minutes** — must go through SLURM
  (a CPU-only allocation is fine, it doesn't need to be a GPU job) rather
  than running directly/inline on whatever node the session happens to be
  on. GPU-partition nodes are frequently shared: `nvidia-smi` showing an
  idle GPU does NOT mean the node's CPUs are idle — check `squeue -w
  <node>` first. If something genuinely needs to run inline/direct despite
  this (e.g. a short exploratory step that then turns out to run longer
  than expected), cap `OMP_NUM_THREADS`/`MKL_NUM_THREADS`/equivalent to a
  small number (2-4) so it can't default to all cores on a node other
  users' SLURM jobs are actively running on.

## Required Verification

Run the most specific project verification command when one exists. If no
project-specific command exists, use:

```bash
./scripts/verify.sh
```

For task-specific work, also use the matching harness gate:

- Web UI changes: `./scripts/browser-check.sh`
- AI behavior, search, ranking, recommendation, agent, or RAG changes:
  `./scripts/eval.sh`
- Tool, MCP, plugin, or Skill changes: `./scripts/tool-audit.sh`
- Skill registry changes: `./scripts/skills-sync.sh --dry-run`
- Remote SSH work: read `.agent/remote/policies.md` first, then use
  `./scripts/remote-verify.sh <alias> <remote-repo-path>` when applicable.

## Completion Rules

Do not claim completion unless:

- implementation is done
- changed scope is limited to the request
- required verification ran, or the reason it could not run is stated
- task-specific QA ran when applicable
- remaining failures or risks are explained
