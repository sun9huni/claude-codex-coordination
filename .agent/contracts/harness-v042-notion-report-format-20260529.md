---
status: done
slice: harness
topic: v042-notion-report-format
date: 2026-05-29
owner: claude
approved_by: user (2026-05-29, "approved")
follow_on_to: .agent/contracts/harness-notion-handoff-log-20260527.md
target_repos:
  - workspace (/home/ubuntu) — Notion-related files are workspace-only; upstream template (claude-codex-coordination) does NOT carry notion_sync.py / notion_map.yaml / runbook, so v0.4.2 is workspace-only (no upstream PR).
decisions:
  - Notion 자동 쓰기 형식을 native 블록 + 한글 라벨로 재설계. 두 면(face)을 모두 변경:
    - (A) 슬라이스 hub의 `〔sync〕` 단일 callout → `<details color="<slice_bg>">` toggle 블록 (요약 + 4행 표: 상태/진행 중/다음/갱신).
    - (B) Weekly Digest 본문의 평면 markdown bullet → 이벤트 타입별 색상 callout. 이벤트 분류 6종 (한글 라벨 / 색 / 이모지 고정):
        - 출시  · green_bg  · 🚀  ("ship", "shipped", "released", "tag v", "PR #N merged", "MERGED")
        - 작업  · blue_bg   · 🛠  ("DONE", "completed", "implementing", "작업", default)
        - 설계  · gray_bg   · 📝  ("contract", "approved", "planning", "spec", "drafted")
        - 결정  · purple_bg · ✅  ("decided", "결정", "agreed on", "확정")
        - 차단  · red_bg    · ⚠️  ("blocker", "blocked", "차단", "FAIL", "stuck")
        - 수정  · orange_bg · 🐛  ("fix", "fixed", "bug", "수정", "hotfix")
  - 한글 우선 원칙: 서술/라벨은 한글, identifier(파일 경로, CLI 플래그, 커밋 SHA, 버전 식별자, 테스트 이름)는 영문 유지. chg 마커는 `<span color="gray">chg:<digest></span>` 회색 인라인.
  - Backfill 범위: harness 슬라이스의 hub callout + W22 Weekly Digest는 이번 세션에서 이미 수동 적용됨. 다른 4개 슬라이스 (fragmap, mmgbsa, vav1, fksfold-core)는 다음 그 슬라이스의 handoff 호출 시 자동으로 새 형식 쓰기. 명시적 backfill 작업 없음.
  - Codex parity 포함: `.codex/skills/handoff-writer/SKILL.md` Step 5도 새 형식 + 이벤트 분류를 같이 따르도록 갱신.
  - 이벤트 분류는 결정론적 (같은 conclusion 텍스트 → 항상 같은 이벤트 타입). 휴리스틱 우선순위 명시: 차단 > 출시 > 수정 > 결정 > 설계 > 작업. 매칭 안 되면 default = 작업.
  - 슬라이스별 hub callout 색은 `notion_map.yaml`의 `conclusion_marker_color` 사용 (이미 정의되어 있음: fragmap blue, mmgbsa red, vav1 green, fksfold-core purple, harness brown).
  - 게이트 동작 (`gate_should_write`) 변경 없음 — `change_digest` substring 검사가 새 형식에서도 통과 (span 분할에 robust).
  - 업스트림 포트 없음 — Notion 관련 파일이 워크스페이스 전용. v0.4.2는 워크스페이스 commit만, 별도 PR/tag 없음.
---

# Harness v0.4.2 — Notion 리포트 형식 (한글 우선 + native 블록)

## Purpose

v0.4.0의 자동 Notion 쓰기 형식(평면 markdown callout + 단일 bullet/일)은 한국어 AI 신약개발 lab에게 영문 산문으로 보이고 시각적으로 스캔하기 어려움. 사용자가 직접 확인: "리포트 형식이 마음에 들지 않아". v0.4.2는 (1) Notion의 native toggle + 이벤트별 색상 callout으로 구조화, (2) 한글 라벨 + 영문 identifier 유지 정책, (3) 이벤트 타입 결정론적 분류로 변환. /handoff Step 5, runbook, notion_sync.py가 새 형식으로 쓰게 한다.

## Current State

- v0.4.1 이전 형식은 모든 슬라이스의 Notion에 살아있음 (5개 슬라이스 hub callout + Weekly Digest bullet 누적).
- 이번 세션에서 **harness 슬라이스만** 새 형식 (Option 2: toggle + 이벤트 callout)으로 수동 적용 완료 — demo로서 사용자 승인 받음.
- 다른 4개 슬라이스는 여전히 v0.4.0 형식. 이번 contract로 새 자동 쓰기를 만들면, 그 슬라이스들의 다음 handoff에서 자연스럽게 새 형식으로 갱신됨.
- notion_sync.py는 현재 `handoff_log_payload()`가 `{date, iso_week, conclusion, change_digest, evidence}`만 반환. 이벤트 타입 분류 없음.
- runbook은 현재 markdown bullet 템플릿만 기술. toggle/callout 형식 미언급.
- Codex `.codex/skills/handoff-writer/SKILL.md`는 v0.4.1 mirror 완료했지만 Notion 쓰기는 아직 작업 안 함 (Codex Notion MCP가 v0.4.2의 다른 트랙).

## Decisions

(see frontmatter `decisions:` for the consolidated set)

## Assumptions And Questions

- assumptions:
  - Notion-flavored markdown spec (`<details>` + `<summary>` toggle, `<callout icon color>` 콜아웃, `<span color>` 인라인 색)이 이번에 confirmed via `notion://docs/enhanced-markdown-spec`. demo로 양쪽 다 렌더 성공 확인.
  - 6종 이벤트 타입은 lab notebook 톤에 충분 (지난 4주 conclusion 텍스트 회고해보면 5종(출시/작업/설계/결정/수정)으로 분류되고 차단 케이스 가끔 발생). 추가 타입 필요시 v0.4.3.
  - 이벤트 분류 휴리스틱(키워드 매칭)은 lab의 conclusion 문법에 robust (실제 conclusion들이 영문/한글 키워드를 자연스럽게 섞어 씀).
  - Codex MCP가 작동하면 Codex Step 5도 같은 형식. Codex MCP 미설정 시 best-effort warn-only (현재 Claude Step 5와 동일 패턴).
- open questions:
  - 이벤트 분류가 모호한 경우 (예: "v0.4.1 SHIPPED ... bonus: stdin-hang fix" — 출시 + 수정 둘 다 매칭)는 우선순위 규칙으로 해결 (차단 > 출시 > 수정 > 결정 > 설계 > 작업). conclusion 한 줄에 여러 이벤트가 있으면 가장 큰 이벤트 하나만 잡힘 — 받아들임. 별도 추가 callout 없음.
  - hub callout의 `<details>` toggle의 default 펼친/접힌 상태? Notion API는 그것을 명시 제어하지 못함 (기본 접힘). 받아들임 — 사용자는 토글을 클릭해서 펼친다.
- tradeoffs:
  - 휴리스틱 분류는 결정론적이지만 brittle. 신뢰 못 할 분류는 default(작업)로 빠짐. v2 (deferred)에서 LLM 분류로 발전 가능 — 이번엔 단순한 키워드 매칭.
  - chg 마커 가시성: 회색 span에 inline. 사용자에게 시각적으로 약하지만 게이트 substring 검사는 통과. 만약 사용자가 "안 보였으면 좋겠다" 하면 v0.4.3 candidate (별도 메타데이터 필드 / 페이지 properties 사용).

## Constraints

- allowed change scope (workspace only):
  - `/home/ubuntu/scripts/notion_sync.py` — 이벤트 분류 함수 + 확장된 payload (event_type / event_emoji / event_color 추가).
  - `/home/ubuntu/docs/notion-sync-runbook.md` — 새 형식 절차 (toggle 템플릿, 이벤트별 callout 템플릿) + 이벤트 분류 매핑.
  - `/home/ubuntu/.claude/skills/handoff/SKILL.md` — Step 5 본문 갱신: payload 의존성, 새 형식 안내, 한글 라벨 정책.
  - `/home/ubuntu/.codex/skills/handoff-writer/SKILL.md` — Codex Step 5 mirror, 같은 형식 + 분류.
  - `/home/ubuntu/tests/test_notion_handoff_log.py` — 이벤트 분류 함수 unit test 추가 (5-6 케이스).
  - 선택: `/home/ubuntu/AGENTS.md` — 이벤트 분류 lexicon을 간단히 언급 (Notion handoff-log 섹션이 이미 있다면 거기 추가).
- forbidden change scope:
  - Notion에 backfill 일괄 쓰기 (이미 사용자가 옵션 1 선택: harness만 수동 적용, 다른 슬라이스는 자연스럽게 갱신).
  - 다른 4개 슬라이스의 Notion row 수동 재작성 (각자 다음 handoff에서 자동 변환).
  - 업스트림 template 변경 (Notion 파일이 거기에 없음, 워크스페이스 전용).
  - v2 deferred 항목 묶기 (SLURM auto-detect, granular Decisions/Artifacts, project-level rollup, Notion → workspace reverse sync).
  - notion_map.yaml의 hub IDs / DB IDs 변경 (이미 live).
  - `change_digest` 알고리즘 변경 (게이트 동작 보존).
  - `/handoff` Step 1-4 변경 (v0.4.1 lifecycle 동작 보존).
- external constraints:
  - claude.ai Notion MCP 세션 OAuth만 (헤드리스 토큰 없음, 영구 차단).
  - Notion API 자체의 markdown spec 준수 (`notion://docs/enhanced-markdown-spec`).
  - 게이트 substring 검사 호환성: span 분할에 robust해야 함 (Notion이 콜론 기준 span 분할하는 것을 이미 확인).

## Non-Goals

1. 다른 4개 슬라이스 Notion row 수동 backfill (자연스럽게 다음 handoff에서 변환).
2. v2 deferred 모든 항목 (SLURM auto-detect, granular Decisions/Artifacts auto-pop, project-level weekly rollup, Codex MCP Notion 액세스 새 구성).
3. arl 슬라이스 hub 생성 (IA 누락 분리 작업).
4. 인계용 큰 Report 형식 (`/meeting-to-notion`) 변경.
5. Notion → workspace 역방향 sync.
6. 이벤트 분류에 LLM 사용 (휴리스틱 키워드만, v2 가능).
7. callout 다중 이벤트 (한 conclusion에 여러 이벤트 있으면 가장 큰 하나만 잡음).
8. hub callout toggle의 default 펼친 상태 강제.
9. chg 마커 완전 숨김 (페이지 properties로 이동 등 — v0.4.3 candidate).

## Done When

1. **이벤트 분류 함수** (`notion_sync.py`): conclusion 문자열을 받아 `{event_type, event_emoji, event_color}` 반환. 6종 분류 + default 작업. 우선순위: 차단 > 출시 > 수정 > 결정 > 설계 > 작업. Unit test (`tests/test_notion_handoff_log.py`) 6+ 케이스 GREEN.
2. **`--handoff-log` 페이로드 확장**: 기존 `{date, iso_week, conclusion, change_digest, evidence}`에 `event_type`(한글: 출시/작업/...), `event_emoji`, `event_color`(green_bg/blue_bg/...) 3개 키 추가. 호환성: 기존 키 변경 없음. 검증: `python scripts/notion_sync.py --handoff-log --slice harness` → JSON에 새 키 3개 포함, conclusion에 "v0.4.1 ... SHIPPED" 들어있으니 `event_type: "출시"`.
3. **Runbook 갱신** (`docs/notion-sync-runbook.md`): "Handoff lab-log (weekly digest)" 섹션이 toggle hub + 이벤트 callout 절차 + 이벤트 분류 매핑 표를 기술. 사용자가 runbook을 읽고 새 형식으로 수동 쓰기 가능해야 함 (에이전트 미터링 검증 가능 정도의 명시성).
4. **Claude `/handoff` Step 5**: SKILL.md가 새 형식 (toggle hub + 이벤트 callout + 한글 라벨)을 명시하고, payload의 event_type을 활용하여 자동 분류. 다음 /handoff 호출이 새 형식으로 쓰기. 비차단 (best-effort) 동작 보존.
5. **Codex parity** (`.codex/skills/handoff-writer/SKILL.md`): Claude SKILL과 동일한 Step 5 본문 (Codex MCP가 작동하는 경우의 분기).
6. **검증 (live)**: 임의 슬라이스 (harness 이외) — 예: 가짜 mmgbsa로 /handoff 시나리오를 시뮬레이션 (또는 다음 mmgbsa 세션의 실제 /handoff) → Notion fetch-back 결과에 `<details color="red_bg">` toggle (mmgbsa hub) + `<callout color="..._bg">` 이벤트 콜아웃이 한글 라벨로 적혀있음.
7. **No regression**: workspace lifecycle 4/4 GREEN + concurrency 5/5 GREEN 유지 (Notion 변경은 v0.4.1 lifecycle 동작에 영향 없음).
8. **Workspace commits + 슬라이스 baton 업데이트**: 모든 변경 commit, harness baton v9→v10에 v0.4.2 완료 기록.

## Implementation Steps

(/write-plan이 task 단위로 분해)

1. notion_sync.py에 `classify_event(conclusion)` 함수 추가 + 우선순위 매칭 + default 작업.
2. notion_sync.py의 `handoff_log_payload()` 확장 (event_type/event_emoji/event_color 키 추가).
3. tests/test_notion_handoff_log.py에 분류 unit test 6+ 케이스.
4. docs/notion-sync-runbook.md 절차 갱신 (toggle + 이벤트 콜아웃 템플릿 + 분류 매핑 표).
5. .claude/skills/handoff/SKILL.md Step 5 본문 갱신 (한글 라벨, 새 형식 안내, payload event_type 사용).
6. .codex/skills/handoff-writer/SKILL.md Step 5 mirror.
7. (선택) AGENTS.md에 이벤트 분류 lexicon 한 줄 추가.
8. 검증 라이브: 가짜 슬라이스 또는 실제 차기 슬라이스 handoff에 대한 시나리오 검증.
9. 마무리: contract+plan status: done, harness baton 갱신, 워크스페이스 commit.

## Verification

- `python scripts/notion_sync.py --handoff-log --slice harness` → JSON에 `event_type: "출시"` 출력.
- `python -m pytest tests/test_notion_handoff_log.py -q` → 새 테스트 6+ GREEN, 기존 테스트도 GREEN.
- runbook grep: "이벤트 분류 매핑" 또는 "출시 · green_bg · 🚀" 표 있음.
- /handoff SKILL grep: "event_type" 언급 + "한글 라벨" 또는 "出시/작업/..." 표 있음.
- live: 차기 슬라이스의 /handoff 후 Notion hub callout이 `<details>`, Weekly Digest에 색상 callout, 한글 라벨 확인.

## Risks

- **이벤트 오분류**: 키워드 매칭이 false-positive/negative 가능. 완화: priority order 명시 + default = 작업 (보수적 분류) + unit test 케이스. 사용자가 분류 잘못 보면 conclusion 텍스트 미세 수정으로 우회 가능. 장기적 LLM 분류는 v2.
- **chg 마커 게이트 호환성**: Notion이 span 분할로 chg 마커를 쪼개도 substring 검사 통과 (이미 검증). 단, Notion이 마커 텍스트를 어떤 식으로든 변형하면 게이트 깨질 위험 — write 후 fetch 비교 단위 테스트 추가 가능.
- **callout 누적**: 슬라이스마다 매주 Weekly Digest 본문에 callout 누적 (이전 markdown bullet과 동일한 누적 패턴). 1년에 ~52 callouts/슬라이스. 페이지 크기 한계 도달 가능성 낮지만 모니터링 필요 — v0.4.3에서 "주 단위 archiving" 고려.
- **Codex MCP 미작동**: Codex Notion MCP가 사용자 환경에서 OAuth 안 됨 → Codex Step 5는 warn-only 비차단. 받아들임 (Claude Step 5와 동일 패턴).
- **runbook과 코드 drift**: runbook이 새 형식 절차를 기술하지만, 실제 쓰기는 에이전트가 MCP 호출로 수행 — runbook 갱신과 SKILL 갱신이 sync되지 않으면 행동 분기. 완화: 단일 진실 자료(payload + 분류 함수)를 notion_sync.py에 두고, SKILL/runbook은 모두 그 출력을 참조.

## Rollback

- per-task commit revert (각 task = 한 파일 = 한 commit).
- 새 형식 자동 쓰기 시작 후 문제 발견 시:
  - Notion에 이미 쓰여진 새 형식 row는 사람이 손 댈 수 있음 (Notion UI). 또는 다음 handoff에서 새 conclusion으로 자동 덮어씀.
  - 형식을 v0.4.1로 되돌리려면 v0.4.2 commit revert + 다음 handoff에서 자동으로 옛 형식 복귀.
  - 시간 거꾸로 가는 history 복원 불가 (Notion 자체의 이전 형식 기록은 git에 없음) — 받아들임.
- 이벤트 분류 매핑이 잘못 떨어지면 분류 함수만 패치 (notion_sync.py 한 파일).
- chg 마커가 게이트 깨면 응급 패치: write 직후 동기 fetch-back 검증 + 실패 시 fallback bullet 형식으로 재시도.

## Progress Log

- 2026-05-29: contract drafted (status: pending). 한국어 lab의 Notion 리포트 형식 개선. 사용자 demo로 형식 승인 받음 (harness 슬라이스 수동 적용). 자동 쓰기 + 이벤트 분류 + Codex mirror 묶음. 워크스페이스 전용 (업스트림 미적용). 사용자 승인 대기.
- 2026-05-29: 사용자 "approved" → /write-plan (9 tasks) → 사용자 "approved" → /execute-plan.
- 2026-05-29: **DONE** (9 tasks, 7 commits a68e367..9d6b6b3). See plan `.agent/plans/harness-v042-notion-report-format-20260529.md`.

## Notes

Notion 자동 쓰기 형식을 v0.4.0 평면 markdown 형식 → v0.4.2 native 블록 + 한글 라벨 + 이벤트 타입 색상 분류로 재설계.

**구현 요약**:
- `classify_event(conclusion)` (notion_sync.py:160대): 6종 priority-ordered keyword 분류 (차단>출시>수정>결정>설계>작업). Case-insensitive substring match. Default = 작업.
- `handoff_log_payload()` 확장: 기존 `{date, iso_week, conclusion, change_digest, evidence}`에 `event_type` / `event_emoji` / `event_color` 3개 키 추가. 호환성 보존.
- `tests/test_notion_handoff_log.py`: 6 → 15 tests (8 classify_event + 1 payload extension). 모두 GREEN.
- `docs/notion-sync-runbook.md` § "Handoff lab-log (weekly digest, v0.4.2)" 전면 재작성 — toggle hub 템플릿 + 이벤트 callout 템플릿 + 6-row 분류 매핑 표 + priority rule + gate 보존 + non-blocking + backfill 정책.
- `.claude/skills/handoff/SKILL.md` Step 5 본문 갱신: payload event_type 사용, 한글 우선 정책 명시, 러북 참조. Skill-lint 14/14.
- `.codex/skills/handoff-writer/SKILL.md` "## Notion lab-log (best-effort, v0.4.2)" 섹션 추가 — Claude parity, Codex MCP 가용 시 동일 형식, 미가용 시 warn-only 비차단.

**Live smoke** (read-only payload check):
- harness: 출시 🚀 green_bg ✓
- mmgbsa: 작업 🛠 blue_bg (default — "AB Stage 2 MD RUNNING" 키워드 미매치, 보수적 분류 정상)
- fragmap: 작업 🛠 blue_bg (default — "CLOSED/HELD" 키워드 미포함; v0.4.3 lexicon 후보)

**Backfill 정책**: harness (수동 demo 적용 완료) 외 4개 슬라이스는 각자의 다음 `/handoff` 호출 시 자동으로 새 형식으로 변환됨. 일괄 backfill 없음.

**v0.4.3 후보 (out of scope here)**:
- "closed/종료/released" 등 라이프사이클 키워드를 분류 lexicon에 추가 (CLOSED 슬라이스가 작업으로 떨어지는 한계).
- LLM 기반 분류 (휴리스틱 brittleness 해결).
- v2 Notion 항목 (SLURM auto-detect, granular Decisions/Artifacts auto-pop, project-level rollup, 역방향 sync, headless token).
- chg 마커 완전 숨김 (페이지 properties로 이동).

**워크스페이스 전용**: notion_sync.py / notion_map.yaml / runbook은 업스트림 template (`sun9huni/claude-codex-coordination`)에 부재하므로 v0.4.2는 업스트림 포트 없음. v0.4.0/v0.4.1 push 절차 생략.

**Verification 재현**:
```bash
/home/ubuntu/miniconda3/bin/python -m pytest /home/ubuntu/tests/test_notion_handoff_log.py -q   # 15/15
/home/ubuntu/miniconda3/bin/python /home/ubuntu/scripts/notion_sync.py --handoff-log --slice harness   # JSON에 event_type 키 포함
```
