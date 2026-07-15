---
status: approved
slice: harness
topic: fea-slice-split
date: 2026-06-04
owner: claude
approved_by: user ("승인") 2026-06-04
design_spec:
implementation_plan: .agent/plans/harness-fea-slice-split-20260604.md
decisions:
  - "New slice name = `fea` (matches the shipped scripts/fea/ package + the FEA = FKSFold Experiment Autopilot program). Two ongoing harness workstreams (Notion/coordination infra vs experiment autopilot) currently contend on the single harness baton + Slices-DB row; give FEA its own slice so they stop ping-ponging owner/remaining_actions."
  - "Two phases. PHASE 1 (now, ADDITIVE — touches ZERO bytes of .agent/status/harness.md): create the `fea` slice infra — a fea.md baton stub, WORKFLOW.md §1 routing entry, status.sh SLICES, the /slice-status skill mapping, stop/▸ hook VALID_SLICES if present, a Notion Slices-DB `fea` row + notion_map.yaml slice_row_ids[fea] + slice_to_db_row project mapping. PHASE 2 (GATED): once the concurrent autopilot session's harness claim goes STALE (heartbeat >30min, owner a346c0dc), MIGRATE the FEA `Current status`/remaining_actions out of the harness baton into fea.md and leave harness carrying only Notion/coordination-infra work; then sync Notion."
  - "User chose 'infra now + claude migrates the baton once stale' (over defer-all or leave-for-autopilot). Honest caveat recorded: editing another session's baton content — even when its claim is stale — is mild overreach (they know what's current); Phase 2 migrates their CONTENT verbatim from git (no fabrication) and is reversible. If the autopilot session adopts `fea` itself first, Phase 2 becomes a no-op."
  - "FEA CODE (scripts/fea/, analysis/) is NOT moved — re-slicing is about the BATON/coordination/Notion identity, not relocating source. The fea baton points at the existing FEA contracts/plans (experiment-autopilot + phase1/phase2a)."
---

# Harness — Split FEA into its own `fea` slice

## Purpose

The harness slice now hosts two distinct, ongoing programs: (1) Notion +
coordination infrastructure (the auto-renderer, home-trust, auto-sync — this
session) and (2) FEA, the FKSFold Experiment Autopilot (a concurrent session:
Phase 1 + 2a shipped, more phases + mmgbsa/fksfold generalization queued). They
share ONE harness baton + ONE Slices-DB row, so ownership and remaining_actions
ping-pong every time either session hands off (observed live this session:
harness baton churned v34→v36 between two sessions). Giving FEA its own `fea`
slice — its own baton, Notion row, and owner — ends the contention: each program
has a stable home, and the Navigator shows both as first-class slices.

## Current State

- `harness` baton (`.agent/status/harness.md`) currently carries BOTH workstreams
  (autosync entries + FEA Phase 1/2a entries); it is owned by the live-ish
  autopilot session (owner_session a346c0dc, heartbeat 2026-06-04T17:18Z — within
  the 30-min fresh window as of drafting).
- FEA is defined by `.agent/contracts/harness-experiment-autopilot-20260604.md`
  (+ plans phase1 / phase2a, both done) and the `scripts/fea/` package +
  `analysis/` battery. It has NO slice identity of its own — it rides `harness`.
- Slice registration surface (where a slice must appear): `.agent/status/<slice>.md`;
  WORKFLOW.md §1 routing table; `scripts/status.sh` SLICES list; the `/slice-status`
  skill mapping (`.claude/skills/slice-status/SKILL.md`); Notion Slices-DB row +
  `.agent/notion_map.yaml` `v0_5:slice_row_ids` + `slice_to_db_row` project map;
  possibly a hook VALID_SLICES set. (Note: `harness` itself is only partially
  registered — it works via the index + CLAUDE.md but is absent from some
  VALID_SLICES/skill mappings; `fea` should be registered at least as well.)
- CURRENT.md is the derived index (regen by `status.sh index`), so a new baton
  auto-appears once status.sh knows the slice.

## Assumptions And Questions

- assumptions: a new slice = a new baton + the registration surface above; the
  derived CURRENT.md picks it up via `status.sh index`; creating a Notion
  Slices-DB row is an additive MCP insert (no schema change); the autopilot
  session's heartbeat will eventually go stale (it handed off v36 = likely
  wrapping up).
- open questions (resolve at plan time): the `fea` Project mapping in
  `slice_to_db_row` — "Harness / Agent Ops" (FEA is agent-ops tooling) vs a new
  Project; default = "Harness / Agent Ops". Whether VALID_SLICES exists in the
  current stop hook (add `fea` if so).
- tradeoffs: Phase-1 infra is useless until the autopilot session ADOPTS `fea`
  (writes fea.md instead of harness.md) OR Phase-2 migrates for it. Accepted: the
  infra is cheap, safe, and unblocks adoption; Phase 2 (gated) finishes the job.

## Constraints

- allowed change scope (PHASE 1, additive): `.agent/status/fea.md` (new stub);
  `WORKFLOW.md` (§1 routing); `scripts/status.sh` (SLICES); `.claude/skills/slice-status/SKILL.md`
  (mapping); a hook VALID_SLICES set if present; `.agent/notion_map.yaml`
  (slices + `v0_5:slice_row_ids[fea]`); `scripts/notion_sync.py` (`_SLICE_TO_PROJECT[fea]`);
  a Notion Slices-DB `fea` row (MCP insert); this contract + the harness baton's
  contract_pointers only. (PHASE 2, gated): `.agent/status/harness.md` +
  `.agent/status/fea.md` (the migration) + a Notion sync.
- forbidden change scope: editing the harness baton's body/remaining_actions
  during PHASE 1 (contested — autopilot owns it); moving/relocating FEA source
  (`scripts/fea/`, `analysis/`); re-slicing any other slice; the headless
  NOTION_TOKEN writer (separate); changing the action-queue/render LOGIC.
- external constraints: PHASE 2 is GATED on the autopilot harness-claim being
  STALE (heartbeat >30min) — do NOT write the harness baton while its claim is
  fresh; Notion writes via in-session MCP only; `.agent/` source of truth;
  Korean-first; a session writes only batons it owns (Phase 2's harness write is
  only permitted once the claim is stale, per the user's explicit choice).

## Non-Goals

- Relocating FEA code (`scripts/fea/`, `analysis/`) — identity/coordination only.
- Forcing the live autopilot session to adopt `fea` (it adopts on its next
  handoff, or Phase 2 migrates once its claim is stale).
- The Notion-sync headless writer (B) or #2/#3 follow-ups.
- A general slice-registration refactor (only `fea` is added; `harness`'s own
  partial registration is noted, not fixed here).

## Done When

- **PHASE 1 (additive, now)**:
  - `.agent/status/fea.md` exists with valid frontmatter (a stub: owner empty /
    unclaimed, state active, remaining_actions pointing at the FEA contract+plans
    and "adopt this slice on the next autopilot handoff", contract_pointers →
    experiment-autopilot + phase1/phase2a). `--lint-baton fea` exit 0.
  - `fea` is registered: `./scripts/status.sh fea` runs without "unknown slice";
    `./scripts/status.sh index` lists `fea` in CURRENT.md; the `/slice-status`
    mapping includes `fea`; `notion_map.yaml` has `fea` under slices +
    `slice_row_ids[fea]`; `slice_to_db_row("fea")` returns a row with a Project.
  - A Notion Slices-DB `fea` row exists (MCP insert), populated from
    `slice_to_db_row("fea")`.
  - **`git diff .agent/status/harness.md` is EMPTY** after Phase 1 (proof the
    additive phase did not touch the contested baton).
  - Verification: `./scripts/status.sh index` + grep `fea` in CURRENT.md;
    `--lint-baton fea` exit 0; `bash tests/run-skill-lint.sh`; `./scripts/verify.sh`.
- **PHASE 2 (gated — only once autopilot claim heartbeat >30min stale)**:
  - The harness baton no longer carries FEA `Current status`/remaining_actions;
    those moved verbatim (from git) into `fea.md`; harness carries only
    Notion/coordination-infra work. Both batons `--lint-baton` clean.
  - Notion synced (both rows + the home via `--handoff-emit`/render → MCP →
    `--stamp-home-applied`).
  - Verification: `git diff` shows the move; `status.sh index`; both rows + home
    reflect the split on fetch.

## Implementation Steps

1. PHASE 1: write `.agent/status/fea.md` stub (valid frontmatter; --lint-baton clean)
   verify: `--lint-baton fea` exit 0
2. PHASE 1: register `fea` in WORKFLOW.md §1 + status.sh SLICES + /slice-status mapping (+ VALID_SLICES if present)
   verify: `./scripts/status.sh fea` no "unknown slice"; `status.sh index` lists fea
3. PHASE 1: notion_map.yaml (slices + slice_row_ids[fea]) + notion_sync.py `_SLICE_TO_PROJECT[fea]`
   verify: `slice_to_db_row("fea")` returns a row with Project; pytest if a test added
4. PHASE 1: create the Notion Slices-DB `fea` row (MCP insert from the payload)
   verify: fetch the new row; confirm Name=fea + fields
5. PHASE 1 close: confirm `git diff .agent/status/harness.md` EMPTY; regen index; verify suite; commit
   verify: harness-baton diff empty; `verify.sh`/`skill-lint`/`tool-audit`
6. PHASE 2 [GATED]: when autopilot claim stale (>30min), migrate FEA content harness→fea + clean harness
   verify: both batons lint-clean; `git diff` shows the move
7. PHASE 2: sync Notion (both rows + home); close contract + handoff
   verify: fetch shows split; full suite

## Change Discipline

- simplest adequate approach: reuse the existing slice-registration surface; the
  fea baton is a stub pointing at existing FEA contracts (no fabricated state);
  the migration (Phase 2) is a verbatim git move, not a rewrite.
- new abstractions introduced: one new slice (`fea`) + its registration entries.
  No new code paths beyond a project-map entry.
- unrelated code touched: none (no FEA source moved; no other slice touched).
- request-to-diff trace: user "동시 autopilot 세션 조정 먼저" → "FEA 독립 슬라이스
  분리" + "인프라 지금 + claude가 stale 되면 baton 이전" + name `fea` → this 2-phase
  split.

## Verification

- `./scripts/verify.sh`; `./scripts/status.sh index` + grep fea; `--lint-baton fea`;
  `bash tests/run-skill-lint.sh`; `./scripts/tool-audit.sh`
- Phase-1 guard: `git diff --stat .agent/status/harness.md` → empty.
- manual: Notion fetch of the new `fea` row (Phase 1) and, post-Phase-2, the
  split across both rows + the home.

## Risks

- contested-baton risk: Phase 2 writes the harness baton — MUST be gated on the
  autopilot claim being stale (>30min). Mitigated: Phase 1 is fully additive
  (harness-baton diff empty, asserted); Phase 2 refuses until stale; the move is
  verbatim-from-git + reversible.
- orphan-slice risk: `fea` infra exists but the autopilot session keeps writing
  harness.md (never adopts) → `fea` sits empty + contention persists. Mitigated:
  Phase 2 migrates the content so `fea` is populated regardless; the stub + a
  coordination note invite adoption.
- registration-drift risk: missing one registration site → `fea` half-registered
  (like harness today). Mitigated: the Done-When enumerates every site +
  `status.sh index`/`--lint-baton fea` verify.

## Rollback

- PHASE 1 (additive): revert the WORKFLOW/status.sh/skill/notion_map/notion_sync
  edits via `git revert`; `rm .agent/status/fea.md`; delete (or archive) the
  Notion `fea` row. No harness baton change to undo.
- PHASE 2: restore `.agent/status/harness.md` + `.agent/status/fea.md` from git
  (the pre-migration commit); re-sync Notion.
- containment: zero compute / no SLURM / no /mnt/data / no secret; Phase 1 cannot
  affect the contested baton (diff asserted empty); Phase 2 gated on stale claim.

## Progress Log

- 2026-06-04: drafted via /brainstorm. Slice name `fea`. Sequencing = "additive
  infra now + claude migrates the baton once the autopilot claim is stale"
  (user choice, over defer-all / leave-for-autopilot). 2-phase: Phase 1 additive
  (zero harness-baton bytes, asserted), Phase 2 gated on autopilot heartbeat
  >30min stale. Approval: pending.
