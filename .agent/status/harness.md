---
owner_session: 0703faa4-d560-444a-a827-3a33675c58a2
owner_label: 
owner_agent: claude
version: 48
last_updated: 2026-06-26
heartbeat: 2026-06-26T10:48:04Z
remaining_actions:
  - "OPTIONAL: 다른 프로젝트(Harness 등) 허브도 자동화 — notion_map.yaml v0_5.project_hubs에 항목 + .agent/notion_project_<slug>.md 템플릿 추가(aigen-fold와 동일 패턴). aigen-fold 허브 자동-sync는 2026-06-26 SHIPPED."
  - "DECISION/OPS: headless NOTION_TOKEN provision(워크스페이스 권한) → scripts/notion_apply.py --apply 를 UNVERIFIED→live 전환(ROW 무인 동기화 완성) = 마지막 무인 스위치. HOME/프로젝트-허브 cockpit 은 설계상 MCP 유지. 토큰 전까지는 --emit-apply-plan/--emit-project-plan MCP 번들 + --dry-run 이 적용면."
  - "OPTIONAL/DEFERRED: v0.5.0 doc+skill PARITY (upstream README/AGENTS/CLAUDE/docs/concepts/skill churn 미포팅; functional/security 절반은 LIVE. 특정 doc drift가 물면 선택 포팅)."
contract_pointers:
  - .agent/contracts/harness-notion-headless-apply-20260609.md
  - .agent/contracts/harness-experiment-autopilot-20260604.md
  - .agent/contracts/harness-home-trust-20260604.md
  - .agent/contracts/harness-notion-home-renderer-20260604.md
  - .agent/contracts/harness-notion-cockpit-restructure-20260602.md
  - .agent/contracts/harness-notion-ux-action-queues-20260602.md
  - .agent/contracts/harness-hermes-agent-port-20260602.md
  - .agent/contracts/harness-notion-redesign-20260529.md
  - .agent/contracts/harness-v042-notion-report-format-20260529.md
  - .agent/contracts/harness-v041-lifecycle-hotfix-20260529.md
  - .agent/contracts/harness-template-v040-port-20260527.md
  - .agent/contracts/harness-concurrent-handoff-20260526.md
  - .agent/contracts/harness-notion-sync-20260527.md
  - .agent/contracts/harness-notion-handoff-log-20260527.md
state: active
---
# Harness / Coordination Status

As of: 2026-06-02 (claude took over the Notion-UX slice from codex 7258d358,
which hit a usage limit mid-Task-2 review; codex heartbeat was stale ≥30min;
user explicitly handed it over)

## Current status

- **NOTION HOME + 프로젝트-허브 블록 재설계 & 프로젝트-허브 자동-sync — SHIPPED ✅
  (2026-06-26).** User: home/AIGEN-Fold 페이지를 anti-AI 미니멀 블록 형식으로 +
  프로젝트 허브가 "자동 세션"이 되게.
  - **Home cockpit 재설계** (`render_home()` + `.agent/notion_home_tail.md`): 장식
    이모지·em-dash 제거 → 2-컬럼 카드 그리드(결정=red_bg / 큐=blue_bg) + 동기화 상태
    표. 커밋 `c901fda`(미니멀)→`d0ea07c`(콜아웃 블록)→`2e1dcc9`(그리드+색+표). 라이브
    적용·fetch 검증(자식 11 보존, em-dash 0).
  - **AIGEN-Fold 허브 재설계** (`36d1e76c…95bb`): placeholder 제거 + 블록 스타일 +
    리포트 명료화(먼저 읽기 digest + 개별 6개 큐레이션 + 단일 라이브 Reports 뷰).
    중복 Reports 링크뷰 2개 제거(allow_deleting_content; 컬렉션 94d8277f 데이터 보존).
  - **프로젝트-허브 자동 렌더 (NEW)**: `notion_sync.py` `render_project_hub` +
    `--emit-project-plan <slug>`; 편집 본문=버전관리 템플릿
    `.agent/notion_project_aigen.md` ({{SLICES}}=baton 라이브 주입, {{DATE}}),
    config=`notion_map.yaml` `v0_5.project_hubs.aigen-fold`. 커밋 `ab312ad`.
  - **자동-sync 배선 (NEW)**: `--project-for-slice` / `--stamp-project-applied`;
    `handoff.sh`가 handoff slice→프로젝트 매핑해 `notion-project-pending` 마커 드롭;
    SessionStart + Stop 훅이 노출(home의 `notion-sync-pending`과 동형). 커밋 `8b98f90`.
    검증: 4파일 bash -n/py syntax OK, slice→project 매핑(aigen-fold-core·fragmap→
    aigen-fold), 마커 생성→stamp 클리어 OK. 천장: MCP 쓰기는 헤드리스 불가(home 동일).
  - **anti-AI 문체 하네스 임베드** (세션 전반): AGENTS.md/CLAUDE.md §출력 문체 +
    publish-notion SKILL + notion_report_template + `render_home` `_short`(em-dash strip).

- **UPSTREAM v0.5.0 (hardening) → WORKSPACE PORT — SHIPPED ✅ (2026-06-12).**
  User: "git 업데이트 우리 서버에도 적용." Upstream `sun9huni/claude-codex-coordination`
  advanced v0.4.2→**v0.5.0** (`7c20338`; 31 audited fixes: BSD/macOS portability,
  **gate-bypass hardening**, spec alignment). Ported the **functional/security half**
  into the live home-level harness (`/home/ubuntu/.claude`, `/home/ubuntu/scripts`,
  `/home/ubuntu/tests`); reference checkout `scratch/claude-codex-coordination`
  ff'd to `7c20338` (ahead=0 behind=0). This is the REVERSE direction of the
  usual workspace→upstream flow (v0.5.0 was authored upstream).
  - **Gates (security core).** `pre-bash-destructive-gate.sh` + `pre-bash-db-gate.sh`
    were byte-identical to pristine v0.4.2 → CLEAN-COPIED v0.5.0 (heredoc/here-string
    body strip so `rm -rf`/DDL/`sbatch` can't be smuggled after `<<`; quoted-flag
    strip `rm "-rf"`; env-var-prefix anchor `FOO=1 rm -rf`; `git -C/-c` global-opt
    handling; split-flag `rm -r -f`; lowercase `drop table`). `pre-bash-slurm-gate.sh`
    HUNK-PORTED (heredoc strip + README.md contract-exclusion) preserving the live
    `../..` ROOT + FragMap FEA advisory. SHARED_PATHS_REGEX (`/mnt/`…) unchanged.
  - **Session lifecycle.** `session-start-decay-check.sh` += >7d marker prune (the
    live `session-markers/` had **49 leaked markers** back to 06-02 — now swept);
    NEW `session-end-cleanup.sh` (removes this session's marker at SessionEnd);
    `.gitignore` += `session-markers/`; `settings.json` += per-hook `timeout`s +
    `SessionEnd` wiring. KEPT absolute `/home/ubuntu/...` paths (did NOT adopt
    upstream's `$CLAUDE_PROJECT_DIR` — would resolve to the active project, not the
    home-level harness, and break the hooks).
  - **Scripts.** `handoff.sh` hunk-ported (mkdir-lock self-heal w/ reap mutex +
    PID/TTL; `--release` inserts `owner_agent: human`; digits-only version guards;
    pure-shell `realpath` strip; derived-index CURRENT.md detection skips phantom
    version bump; lexicographic snapshot rotation, no GNU `find -printf`) —
    preserved the workspace inline notion-sync-pending + refresh block. `status.sh`
    hunks 1-6 (quote-aware `split_flow`, `cell()` `|`/newline escaping, `utcnow()`
    deprecation fix); hunks 7-8 (awk `fm_field`) N/A — live status.sh has no awk
    fm_field. `baton-drift.sh` CLEAN-COPIED upstream (live was pre-seam: gained
    AGENT_ROOT seam + `iso_to_epoch` py-fallback + bash4 gating; production
    behavior identical, seam falls back to `$ROOT/.agent`).
  - **Tests.** Imported `tests/fixtures/` (28), `tests/run-hook-tests.sh` (ADAPTED:
    gate paths drop `optional/`; slurm no-contract cases run vs a throwaway
    empty-contracts root), `tests/run-baton-drift-tests.sh`.
  - **VERIFIED (all GREEN):** run-hook-tests 30/30, run-baton-drift 5/5, lifecycle
    4/4 (baseline 4/4 → no regression), concurrency 5/5 (baseline 5/5), session-start
    PASS, stop-hook PASS, notion-autosync PASS, skill-lint 15/15. Marker prune +
    session-end cleanup verified end-to-end. Committed master `478a8f3` (port
    files only; pre-existing dirty tree left untouched). Doc/skill parity
    DEFERRED (see remaining_actions[0]).

- **FOLLOW-ON FIX — notion_sync.py `--emit-apply-plan` MCP ROW payload — DONE ✅
  (2026-06-12).** Surfaced during THIS session's harness /handoff Step 5: the
  emitted `update_properties` JSON 400'd on the live Slices DB — it carried
  `Next` (a home-navigator hint, not a column) and emitted the date-typed
  `Last Heartbeat`/`Last Updated` as bare strings. Root cause: `emit_apply_plan`
  + the `--slice` ROW emit printed the SEMANTIC `slice_to_db_row()` dict raw,
  skipping the API-translation the docstring promised. FIX: new
  `_row_to_mcp_properties()` (MCP sibling of REST `notion_apply.build_row_properties`)
  — drops `Next`, expands dates to `date:{col}:start` + `:is_datetime`
  (time-component detection + PyYAML space→`T` ISO normalization); select/text/
  title pass through. `slice_to_db_row` UNCHANGED (home_navigator + test still
  need `Next`). +3 tests; pytest 56/56 GREEN. harness HOME/ROW were already
  live-applied + fetch-verified this session via manual schema-correction; the
  fix makes the emit directly-applicable next time.

- **UPSTREAM TEMPLATE v0.4.2 (auto-freshness) — SHIPPED ✅ (2026-06-11).**
  Synced the workspace harness upgrades into the public template
  `sun9huni/claude-codex-coordination`. Diagnosed that only the GENERIC half of
  the workspace `ffe4bbb` auto-freshness work was missing upstream; the
  Notion/FEA suite is project-specific and stays in-workspace (scrub gate clean).
  Ported `scripts/baton-drift.sh` (NEW; heartbeat-age any-bash + sacct/bash4-gated
  scheduler drift, AGENT_ROOT seam, never non-zero) + auto-`status.sh index` regen
  on handoff (claim+release via `refresh_derived_views`), SessionStart Job 0, and
  PreCompact, + docs. PR #3 squash-merged (CI green ubuntu+macos), main `989ffe8`,
  tag `v0.4.2` (`ac97a0f`) pushed. Tests: concurrency 5/5, lifecycle 4/4, hook
  13/13, skill-lint 11/11. NOTE (user-acknowledged, NOT scrubbing): pre-existing
  v0.1.0 biology traces remain upstream by choice — `memory-policy.md` "VAV1"
  example, `execute-plan` `mmgbsa-stage-check` example, research-deployment README
  origin note. v0.4.2 itself is biology-free.
- **NOTION APPLY AUTOMATION ("무인 직전") — SHIPPED ✅ (2026-06-10, contract
  `harness-notion-headless-apply-20260609`, claude took over harness this session).**
  Root-caused the recurring stale-HOME (the apply is MCP-manual + last session
  deferred it + the HOME page-id was unrecorded → it froze at 2026-06-08/ffe4bbb;
  re-applied live this session). Then built the friction-removal layer up to the
  auth boundary: (1) `notion_map.yaml` `v0_5:home_page_id` (28d1e76c…) +
  `slice_row_ids[m-relativity]` (37a1e76c…); (2) `notion_sync.py --emit-apply-plan
  <slice>` = zero-discovery one-shot (resolves HOME+ROW ids from the map, embeds the
  preflight verdict, FAIL-loud exit≠0 on unresolved id / HOME_RENDER_UNSAFE); (3)
  footer `stale {n}`→`findings {n}` (the misleading label — it's audit findings, not
  stale slices); (4) **`scripts/notion_apply.py`** = the baton's pre-scoped "B"
  headless ROW writer — REST PATCH, `NOTION_TOKEN`-gated, `--dry-run` builds+validates
  the payload OFFLINE (reuses `slice_to_db_row`; live path UNVERIFIED until a token is
  provisioned). HOME cockpit stays MCP (ceiling unchanged). Verified pytest 38/38 (8
  new) / verify.sh / tool-audit / skill-lint 15-0 (also fixed pre-existing
  publish-notion lint fail) / scoped diff-check. Docs: runbook §headless-apply +
  handoff Step 5. **Auto-flow directives WIRED ✅ (2026-06-10, follow-on):**
  SessionStart hook / Stop hook / handoff.sh recipe now emit `--emit-apply-plan`
  (was `--handoff-emit`); run-session-start-tests + run-stop-hook-tests + harness
  concurrency/lifecycle all GREEN. FOLLOW-UPS (remaining_actions): provision the
  token to flip ROW live; reconcile pre-existing handoff-writer source↔mirror drift.
- **AUTO-FRESHNESS (derived-index regen + baton-drift) — SHIPPED ✅ (2026-06-08,
  commit `ffe4bbb`).** Closes the stale-cockpit recurrence at the layer the Notion
  AUTO-SYNC (below) did NOT cover: the DERIVED index `CURRENT.md` only refreshed on
  a manual `status.sh index` (handoff Step 4), so sessions that updated batons but
  skipped it froze the index + Notion (06-04→06-08 real case: `fea` missing from
  the index, aigen-fold-core shown pre-Track-B, fragmap shown "RUNNING 81/120" 3 days
  after job 6245 COMPLETED). FIX: `handoff.sh` (both per-slice claim+release paths),
  `pre-compact-inject.sh`, and `session-start-decay-check.sh` now auto-run
  `status.sh index`; new `scripts/baton-drift.sh` flags (a) a baton asserting
  RUNNING for a SLURM-terminal job — suppressed if the baton records it done
  elsewhere — and (b) heartbeats ≥2d old, surfaced at all three points. status.sh
  takes no lock → no deadlock with handoff's flock. `bash -n` clean on all 4; both
  hooks verified emitting fresh index + drift. Complements (not duplicates) the
  Notion AUTO-SYNC marker flow: that syncs the Notion ROW, this keeps the
  derived index + drift live without MCP.
- **FEA — Phase 2d (fksfold CRBN-anchor preflight) — SHIPPED ✅ (2026-06-04,
  `/write-plan`→`/execute-plan`, 5 tasks, plan `…-phase2d-fksfold`).**
  `python -m scripts.fea preflight-fksfold --cif X --chain B --w400-index N`
  checks the submitted `--w400_residue_index` maps to a real **W (tryptophan)** in
  the construct CRBN chain — catches the production `355`→G/L/P/S bug + author-vs-seq
  off-by-one. PURE `verify_anchor_residues` (synthetic tests) + CIF adapter
  `run_anchor_preflight` reusing `verify_heldout_anchor.modeled()` (Bio.PDB **lazy**,
  graceful WARN if absent). Real-data integration test: 9NGT idx 355→'L' FAIL,
  321→W PASS (matches STAGEB_RECIPE 4/4). **This COMPLETES the umbrella's "3
  known-bad configs" criterion** (FragMap-mode=2a, coupling=2c, CRBN-anchor=2d).
  pytest 16/16. Commits `89aba60`(T1)…`0350730`(T4). Deferred: GPU-UUID
  submit-script check (infra half).
- **FEA — Phase 2c (mmgbsa coupling preflight) — SHIPPED ✅ (2026-06-04,
  `/write-plan`→`/execute-plan`, 5 tasks, plan `…-phase2c-mmgbsa`).**
  `python -m scripts.fea preflight-mmgbsa --md-length-ns L --window A B` catches
  the **first-Nns-of-Mns under-sampling** bug (the ranking-corrupting 5ns/20ns
  case) BEFORE submit. Reuses the **committed** `mmgbsa_coupling.py`
  (`derive_frame_range`/`coupling_check`, 8489bc0) for arithmetic + adds the
  FEA-side **coverage guard** (`coupling_undersampled`) that `coupling_check`
  lacks (it only flags window>traj). **Does NOT touch the blocked `run_mmpbsa.py`**
  — B4 single-source wiring stays the mmgbsa slice's deferred task; FEA is a
  read-only/arithmetic pre-submit validator. pytest 12/12. Commits
  `72051d0`(T1)…`ce0ab26`(T4). 남은 Phase 2: Stage 2 watch, aigen-fold-core preflight,
  mmgbsa post-hoc run-dir audit.
- **FEA — Phase 2a (fragmap preflight) — SHIPPED ✅ (2026-06-04,
  `/write-plan`→`/execute-plan` against umbrella contract, 8 tasks, plan
  `…-phase2a`).** *Before-GPU* 입력 검증: `python -m scripts.fea preflight
  <config> [--input-yaml X] [--strict]` = forbidden mode(`feature`/`atom`;
  source-of-truth `fragmap_steering.py`) + NPZ/reference_pdb 존재 + channels
  비어있음 = ERROR; VAV1 pocket contacts vs GT{16-20} (±1 tol) = WARN. 실제
  2개 feature-mode config 거부·good config 통과·off-by-one pocket 경고 검증.
  `pre-bash-slurm-gate.sh`에 **warn-only advisory** 추가(sbatch 시 `--fragmap_config`
  토큰 best-effort preflight → `[fea-preflight]` stderr, **gate verdict 절대
  불변** — self-contained regression test로 보증). docker 내부 config는 안 보일 수
  있음(silent=미검증 아님, 명시). pytest 9/9 + gate test ALL PASS. 커밋
  `71696fb`(T1)…`6ff19c4`(T7). 남은 Phase 2: Stage 2 watch + mmgbsa/fksfold 일반화.
- **FEA — Experiment Autopilot, Phase 1 (Stage 3+4 fragmap) — SHIPPED ✅
  (2026-06-04, `/brainstorm`→`/write-plan`→`/execute-plan`, 12 tasks, contract+
  plan `harness-experiment-autopilot` + `…-phase1`).** Closes the manual
  post-SLURM loop: `scripts/fea/` `report <job_dir>` = classify_cells (per-cell
  success/silent_fail/oom/node_fault — real-data 125/20 match on job 5638) →
  load_metrics (delegates to `eval_ab_139batch.py`) → `run_gates`
  (scaffold-blocked grouped-OOF + permutation_null from the frozen
  `activity_eval_gates.py`; **groups REQUIRED, no pooled path**) → ResultsCard.
  `capture <card>` = gated DRAFTS only (`fragmap.md.fea-draft` baton via house
  `_parse_frontmatter` + targeted edits, never the live file; Notion payload
  JSON; nothing applied). **Primary criterion MET**: reproduces the documented
  induced-fit-inverted KILL end-to-end (raw −0.305 / oof −0.117 / perm_p 0.73,
  n=84, 62 scaffolds). Plan Amendments 1 (oracle swap dc50-scan→induced-fit) +
  2 (house-parser vs safe_load) recorded during execution. pytest 4/4. Commits
  `96aec40`(T1)…`<T12>`. Phase 2 (Stage 1 preflight gate + Stage 2 watch +
  mmgbsa/fksfold generalization) = follow-up contract.
- **Notion AUTO-SYNC (handoff → marker → auto-catch-up) — SHIPPED ✅
  (2026-06-04, `/brainstorm`→`/write-plan`→`/execute-plan`, 9 tasks, contract+
  plan `harness-notion-autosync` done).** Closes the "handoff updates the baton
  but Notion stays stale" gap (the fragmap case). `handoff.sh` now drops
  `.agent/handoffs/state/notion-sync-pending` (per-slice line, `|| true`-guarded
  so it can't fail a handoff) + prints the apply recipe; the SessionStart hook
  injects `⚠️ NOTION SYNC PENDING: <slices>` so the next MCP-capable session
  AUTO-APPLIES via `notion_sync.py --handoff-emit <slice>` (one block = home body
  + Slices-row payload → one MCP replace_content + update_properties);
  `--stamp-home-applied` clears the marker; the Stop hook escalates
  `[notion-sync-pending]` while unresolved. A non-MCP (Codex) session leaves the
  marker for the next Claude session (cross-session catch-up). `NOTION_SYNC_REPO_ROOT`
  env override makes notion_sync.py fixture-testable from bash. Commits
  `0767077`(T1)…`7f61fff`(T8). Verified pytest 30 / run-notion-autosync-tests.sh +
  run-session-start-tests.sh + run-stop-hook-tests.sh PASS / tool-audit / verify.sh /
  skill-lint 14. **Hard ceiling: Notion writes are MCP-only; the styled home
  cockpit can never go headless. B = headless NOTION_TOKEN DB-row writer is the
  next available follow-up contract (true no-agent ROW sync; cockpit stays MCP).**
- **Home TRUST (baton-lint + decision-first + freshness) — SHIPPED ✅
  (2026-06-04, `/brainstorm`→`/write-plan`→`/execute-plan`, 11 tasks, contract+
  plan `harness-home-trust` done).** Root-causes the home's trust gap beyond the
  auto-renderer: **(D1)** `notion_sync.py --lint-baton <slice>` validates a baton
  at WRITE time (frontmatter parse health + remaining_actions hygiene: no
  done-led leading item, DECISION:/AGENT:/BLOCKED: prefixes) and the Stop hook
  surfaces it non-blocking as `[baton-lint]`; **(D2)** `render_home` queues drop
  done-lines + cap one live line/slice (legacy/cross-agent bridge); **(D3)** the
  cockpit is now decision-first — 🙋 결정 대기 is a full-width callout on top
  (🤖 Agent queue + 🩺 health below), empty → `✅ 결정 대기 없음`; **(D4)** the
  home carries a `🕐 렌더 <date> · baton @ <rev> · stale N` stamp,
  `--stamp-home-applied` records each apply to `.agent/handoffs/state/
  home-render.stamp`, and the Stop hook warns `[home-stale]` when a baton changed
  since the last apply. Commits `0defbec`(T1)…`1643717`(T9). Verified pytest 27 /
  `run-stop-hook-tests.sh` PASS / `--render-home` exit 0 (preflight clean, 8
  preservation IDs) / skill-lint 14. #2 auto-heartbeat + #3 git fallback
  dashboard split OUT to separate follow-up contracts.
- **Notion home AUTO-RENDERER (Task-18) — SHIPPED ✅ (2026-06-04,
  `/brainstorm`→`/write-plan`→`/execute-plan`, 8 tasks, contract+plan
  `harness-notion-home-renderer` done).** Closes the hand-rendered-home drift
  (it went stale twice: fragmap MD-SILCS→GCMC). `notion_sync.py --render-home`
  renders the FULL Notion-flavored home body: dynamic Mission-Control cockpit
  (`render_home()` — 🛰️ banner + metrics + 🕐 stamp + decision-first stacked
  🙋 Decisions / 🤖 Agent-queue / 🩺 health callouts with chips, all from
  `home_navigator_payload()` + `notion_audit_payload()`; layout updated by
  home-trust D3/D4) + `---` + the verbatim static tail
  `.agent/notion_home_tail.md` (Slices board, Archives DBs, Projects/More pages,
  Docs). Applied by one MCP `replace_content`; `assert_home_preserves` preflight
  refuses (`HOME_RENDER_UNSAFE`, exit 2) if any of the 4 child `<page>` + 4 inline
  `<database>` URLs would drop. Live-applied this session + fetch-confirmed all 8
  preservation blocks intact + cockpit accurate (fragmap = GCMC 6245 RUNNING).
  Verified pytest 21 / skill-lint 14 / tool-audit / verify.sh / scoped diff-check.
  Next refresh = just re-run `--render-home` (handoff Step 5). Known: the
  agent-queue reflects baton-hygiene noise faithfully (convention is the fix).
- **Notion cockpit RESTRUCTURE — SHIPPED ✅ (2026-06-02, `/brainstorm`→
  `/write-plan`→`/execute-plan`, 14 tasks/14 commits `d82eb7a`…`, contract+plan
  `harness-notion-cockpit-restructure` done).** Follows the user's "장기적으로
  최선" question → realign the Notion surface to what is *reliably maintained*.
  **Home**: first viewport = action queues + LIVE Slices board only; the
  ADR/Experiments/Reports inline views moved into a collapsed 🗄️ Archives
  toggle (3 DBs PRESERVED, not trashed) — they are on-demand archives, backfill
  via `--migrate` when needed. **Code**: `_regex_extract_frontmatter` parses any
  key's block sequence into a list; `_parse_frontmatter` regex-fallback so a
  quote/colon-rich baton (fragmap) populates instead of going blank; audit
  reports a distinct `Regex fallback` (vs `Parser warning`); `_action_queue_fields`
  skips ✅/DONE leading lines (word-boundary, independent-review fix). **Docs**:
  handoff Step 5.2 (Claude+Codex) pushes the 8 cockpit fields; runbook
  §Cockpit-vs-Archives; status README + AGENTS baton-hygiene convention. fragmap
  row re-pushed (Fresh + populated), aigen-fold-core Agent Next reclassified.
  Verified pytest 19/skill-lint 14/tool-audit/verify.sh/scoped diff-check. The
  ONLY reliably-live home surface is now the Slices cockpit (by design).
- **Home 시각 정제 — DONE (2026-06-02, LIVE Notion only, NO repo/code change).**
  User asked "더 멋있게" → "더 세련되게". Home `28d1e76c…` redesigned as a
  **Mission Control dashboard**: gradient cover (`gradients_8.png`) + clean text
  header (no banner box) + 2-column callout cards (🙋 orange Decisions / 🤖 blue
  Agent queue, short scannable bullets) + 🩺 gray Sync-health strip + muted-gray
  governance line; colored boxes trimmed 5→3 (color only on the human-facing
  cards). Also de-staled (removed done "Task 6 승인 대기" items). Home is STILL
  hand-rendered (no Task-18 auto-renderer) — these edits are not reproduced by
  `--migrate home`; a re-render would need re-applying this layout. Open polish
  options offered (not done): cover swap, per-slice status chips, all-gray+
  colored-text-heading palette.
- **Notion Navigator action queues — SHIPPED ✅ (2026-06-02, claude takeover
  from codex).** Contract + plan both `status: done` (all 7 tasks). Design
  `8b619c2`/`4ec672a`; codex landed plan + Tasks 1-2 (`bda63c9` RED test,
  `50694ea`+`3b7c0de` queue extraction); claude continued the
  RED→GREEN→review→commit loop for **Task 3** sync-trust `--audit` (`d96a305`),
  **Task 4** home `action_queues` payload (`354ad57`), **Task 5** runbook
  section (`30abe23`); then user approved "전체 적용" → **Task 6 Notion MCP
  APPLIED**: Slices DB `01c936b7…` +8 props (Headline/Now/Decision Needed/Agent
  Next/Blocker = text; Health + Sync Status = SELECT trust enums; Last Sync
  Source); 6 rows upserted (harness/mmgbsa/aigen-fold-core Fresh; arl/vav1 Stale;
  **fragmap = Parser warning MARKER, not blank-overwritten** — trust layer
  prevents the user's "blank fragmap row" recurrence); Navigator home
  `28d1e76c…` first viewport = 내가 결정할 것 / 에이전트가 실행할 것 / 동기화
  신뢰도, stale setup callout removed, 5 DB-linked sections preserved. Verified
  via live fetch (home + harness + fragmap rows). Verification PASS (pytest
  14/14, `--audit`/`--migrate` exit0, `tool-audit.sh`, `verify.sh`, scoped
  `diff --check`). ★ `--audit` surfaced a REAL defect (the user's complaint,
  root-caused): `fragmap` baton frontmatter fails `yaml.safe_load`; `arl`/`vav1`
  Stale (unclaimed). Fixing those = their slices' owners (cross-slice).
  Artifacts: design `docs/superpowers/specs/2026-06-02-notion-navigator-action-queues-design.md`,
  contract `.agent/contracts/harness-notion-ux-action-queues-20260602.md`,
  plan `docs/superpowers/plans/2026-06-02-notion-navigator-action-queues.md`.
- **Hermes Agent 이식성 평가 — RECORDED (2026-06-01).** User asked whether
  `NousResearch/hermes-agent` can be transplanted into this system and what the
  tradeoffs are. Local read-only clone inspected at `/tmp/hermes-agent-inspect`
  commit `6c73e8f`; upstream README/AGENTS/pyproject/LICENSE checked. Verdict:
  import is feasible, but full runtime transplant is not recommended now.
  Preferred path is pattern-port selected ideas or run Hermes as an isolated
  on-demand sidecar; avoid replacing Codex/Claude `.agent` harness ownership.
  Record: `.agent/scratch/harness-hermes-agent-assessment-20260601.md`.
- **Hermes Agent 이식계획 설계 — SPEC WRITTEN ✅ (2026-06-02, commit
  `4b1df7d`).** Brainstorming-approved design saved to
  `docs/superpowers/specs/2026-06-02-hermes-agent-port-design.md`. Source
  baseline refreshed to Hermes main `272c2f30aa60d6d98b2c97dde6ba42a9231d4f56`.
  Design locks first phase to pattern-port governance improvements; sidecar and
  search prototype are later-contract options; runtime merge is a non-goal.
  User approved the spec on 2026-06-02.
- **Hermes Agent 이식계획 실행계획 — PLAN WRITTEN ✅ (2026-06-02, commit
  `59a98e5`).** Contract:
  `.agent/contracts/harness-hermes-agent-port-20260602.md`; plan:
  `.agent/plans/harness-hermes-agent-port-20260602.md`. Plan uses
  `writing-plans`, keeps Hermes reference-only, and breaks implementation into
  inventory, tool taxonomy, tool-audit enforcement, skill-governance checklist,
  verification, baton update, and contract closure. Next gate: choose
  subagent-driven or inline execution.
- **Hermes Agent pattern-port implementation — DONE ✅ (2026-06-02).**
  Completed the approved first phase: durable pattern inventory, tool
  side-effect taxonomy, tool-audit enforcement, and skill-governance checklist.
  Hermes remains reference-only. No runtime install, no gateway/cron/messaging,
  no credentials, no direct skill mutation, and no Notion reverse sync.
  Verification: `skills-sync --dry-run`, skill-lint, `tool-audit.sh`,
  `verify.sh`, and scoped diff-check passed. Global `git diff --check` is
  blocked by unrelated `.agent/status/mmgbsa.md` trailing whitespace in another
  slice's dirty baton.
- **Session handoff record — READY FOR CLAUDE ✅ (2026-06-02).** Files touched
  for Hermes pattern-port: `docs/superpowers/specs/2026-06-02-hermes-agent-port-design.md`,
  `.agent/contracts/harness-hermes-agent-port-20260602.md`,
  `.agent/plans/harness-hermes-agent-port-20260602.md`,
  `.agent/tools/hermes-agent-pattern-inventory-20260602.md`,
  `.agent/tools/inventory.md`, `.agent/skills/hermes-skill-governance-20260602.md`,
  `scripts/tool-audit.sh`, `.agent/status/harness.md`, and regenerated
  `.agent/handoffs/CURRENT.md`. Failure/error log: n/a. Approval required:
  none for completed pattern-port; any search-index or isolated-sidecar pilot
  needs a new contract and explicit approval gates.
- **Codex harness parity sync — DONE ✅ (2026-06-01).** Reviewed Claude Code
  harness state and synchronized Codex-facing gaps: `route` + `slice-status`
  team/Codex skills, `harness` mapping coverage, `handoff-writer` source mirror
  parity, and stale AGENTS Notion v0.5 lifecycle wording. Verification:
  `skills-sync --dry-run`, skill-lint, tool-audit, and `verify.sh` pass.
- **Code-review follow-up — DONE ✅ (2026-06-01).** Applied reviewer findings:
  Claude `/slice-status` now permits the root git commands it documents for
  `harness`; Claude `/handoff` recognizes `harness` as a valid active slice;
  `status.sh harness` reports `.claude/skills`, `skills/`, and `.codex/skills`;
  `skills-sync --dry-run` now checks source-vs-Codex mirror drift; frontmatter
  `remaining_actions` trimmed back to current next actions only. The new drift
  check found and fixed a pre-existing `skills-governance` Codex mirror drift.
- **SkillOpt(/route) 적용 검토 — DONE ✅ (2026-06-01, commit `10250ee`).** Microsoft
  SkillOpt를 하네스 스킬 최적화에 적용할지 논의 → 코드 정독 → `/route`를 유일한
  scorable testbed로 식별 → zero-compute 사전등록(`PREREG.md`, 임계값 선약속) → 28-신호
  §1 ceiling probe. **최대 오류원 = `harness`가 §1 + `status.sh` SLICES 양쪽에 미등록.**
  싸고치기 3줄로 realistic 정확도 67.9%→96.4%, taxonomy-gap 8→0 → 사전약속 매트릭스상
  **천장 hit → `/route` SkillOpt env KILL** (diagnose-before-scale 실증). Path A 규율은
  `.agent/skills/skill-tuning-discipline.md`로 문서화 (commit `c944cb3`, skills-governance 참조).
  증거: `.agent/scratch/skillopt_route_prereg/`.
- **harness-notion-redesign (v0.5 Notion IA) — SHIPPED ✅ (2026-06-01, 28/28 tasks).**
  Contract + plan both `status: done` (`.agent/{contracts,plans}/harness-notion-redesign-20260529.md`).
  3-pattern 통합 (Engineering Wiki Slices / ADR Decisions / W&B Experiments) + Navigator 홈.
  Phase A+B (T1–16) committed 2026-05-29 (`6c75e23`→`87fad95`): Slices DB (`3435079f`) + 6 rows;
  Decisions ADR schema + 107 rows; Experiments DB (`949a3553`) + 252 rows; 5 hub reparent; Reports cleanup.
  Phase C (T17–23) committed 2026-06-01 (`1de3cbc`/`293f95b`/`d333d2e`/`00efc49`/`696aa62`/`57221b7` + Notion 홈):
  `home_navigator_payload()` (T17); `--migrate {slices,contracts,slurm,home,all}` CLI (T23, sacct 30d);
  runbook v0.5 (T21, 410 lines); AGENTS+template v0.5 IA (T22); 홈 Navigator 5 sections (T18);
  /handoff Step 5 v0.5 (T19, skill-lint PASS:14); Codex warn-only mirror (T20).
  Phase D (T24–28) committed 2026-06-01 (`6ed6e06`/`e5a6c60`): 4-scenario walk-through + cold-start sim
  (`.agent/handoffs/notion-redesign-walkthrough.md`); user spot-check gate passed ("Finalize 진행"); finalize.
  Each code task /code-review APPROVE (T23 REQUEST_CHANGES→fixed).
  **Follow-ups:** (a) ✅ DONE (2026-06-01, user): 3 filtered inline linked-views
  (Slices Status=활성 / Decisions recent+Accepted|Implemented / Experiments Status=Running)
  added in Notion UI — mention links promoted to real filtered views;
  (b) ✅ DONE (2026-06-01): v0.5 Step 5 Notion auto-flow fully LIVE-VERIFIED — 5.2 Slices-row
  update (Task 28); 5.3 contract done→ADR Implemented (redesign 8 ADRs ADR-66..73 flipped
  Accepted→Implemented, matched by Title+Linked-Contract since `ADR ID` is auto-increment);
  5.4 SLURM→Experiments (Run ID=5754 row exactly matches function output = idempotent no-op,
  no dupes). Residual (non-blocking): 5.4 Metrics empty (Task 13 job_name↔output-dir glob limit).
- **Template v0.4.1 SHIPPED** (2026-05-29). Per-slice lifecycle hotfix:
  `state: active|closed|released` field, `handoff.sh --release SLICE` verb,
  auto-commit of slice's untracked contracts/plans (with dirty-tree guard +
  `--no-auto-commit` opt-out), Stop hook missed-handoff warning via per-session
  marker file (`session-markers/SESSION_ID.start`). Codex parity included.
  Bonus: fixed a stdin-hang bug (`json.load(sys.stdin)` blocked when stdin
  connected but empty) — `select.select(0.05s)` guard in both hooks.
- Upstream `sun9huni/claude-codex-coordination` is now at `989ffe8` (v0.4.2).
  **v0.4.2 (auto-freshness) SHIPPED upstream 2026-06-11** — PR #3 squash-merged
  (CI green ubuntu+macos), tag `v0.4.2` pushed (`ac97a0f`). Ported the GENERIC
  half of the workspace `ffe4bbb` auto-freshness work: new `scripts/baton-drift.sh`
  (heartbeat-age any-bash + sacct/bash4-gated scheduler drift, scrubbed of project
  specifics) + auto-`status.sh index` regen on handoff (claim+release),
  SessionStart (Job 0), and PreCompact + docs. The workspace-only Notion/FEA
  coupling (notion-sync-pending marker, baton-lint, home-stale, fea/) was
  deliberately EXCLUDED (project-specific; scrub gate clean). v0.4.1's PR #2 was
  squash-merged 2026-05-29T01:30Z.
- v0.4.0 (per-slice migration), v0.4.1 (lifecycle hotfix), and v0.4.2
  (auto-freshness) are all LIVE on upstream main and mirrored in workspace.
- Open follow-ups (parked, not blocking):
  - **PRIMARY NEXT:** none for harness-notion-redesign — v0.5 is SHIPPED (28/28) and
    BOTH follow-ups are now closed: (a) ✅ 3 filtered inline linked-views added in Notion UI
    (2026-06-01, user); (b) ✅ Step 5 auto-flow fully live-verified (5.2/5.3/5.4, 2026-06-01).
    harness slice has no in-flight work — next session picks a new contract. (Only residual:
    5.4 Metrics extraction is empty due to a known Task 13 glob limitation — non-blocking polish.)
  - Notion handoff-log v2 — SLURM auto-detect, granular Decisions/Artifacts
    auto-pop, Codex `/handoff` Step 5 mirror.
  - Retroactive `state: closed` for fragmap (body says CLOSED but frontmatter
    still has `state: active`). Run `./scripts/handoff.sh --release fragmap`
    whenever desired.
  - Deeper per-slice git-snapshot audit log (v0.3.x state/diff.patch
    equivalent for slice mode).

## Verification run (post-v0.4.1)

- `bash tests/run-harness-concurrency.sh` → 5/5 GREEN (regression preserved)
- `bash tests/run-harness-lifecycle.sh` → 4/4 GREEN (new in v0.4.1)
- `bash tests/run-skill-lint.sh` → 14/14 PASS (workspace) · 11/11 (upstream)
- `bash tests/run-hook-tests.sh` (upstream) → 13/13 PASS
- `bash -n` clean across all modified files; settings JSON + workflow YAML valid
- PR #2 CI: ubuntu-latest + macos-latest both green (~12s each)
- Scrub gate (`git diff main...HEAD | grep -iE 'fragmap|mmgbsa|fksfold|slurm|notion|9nfr|/mnt/data|kim|sunghoon'`) → empty

## Files touched (v0.4.1)

Workspace (commits ac688b2..eeb3cd8 + fix 915b84b):
`scripts/handoff.sh`, `scripts/status.sh`,
`.claude/hooks/{session-start-decay-check,stop-handoff-check}.sh`,
`tests/run-harness-lifecycle.sh` (new), `.agent/status/README.md`,
`.claude/skills/handoff/SKILL.md`, `AGENTS.md`,
`.codex/skills/handoff-writer/SKILL.md`.

Upstream (commits ca0d07e..5b64f43 + fix b005cdd, squashed into f9a59b0):
same set minus Codex/AGENTS workspace docs, plus `CHANGELOG.md` [0.4.1] and
`.github/workflows/test.yml` (new CI step).

## Approval / blockers

- No destructive or production-side effects performed.
- Workspace tree has many pre-existing untracked files; per-slice auto-commit
  correctly SKIPPED on this handoff with "working tree has other dirty changes"
  warning (safeguard working as designed). Manually commit contracts/plans
  later if desired.
- Secrets/runtime (`.codex/.credentials.json`, sqlite WAL, `__pycache__`,
  `.superpowers/`) and pre-existing untracked data dirs intentionally NOT
  committed.
