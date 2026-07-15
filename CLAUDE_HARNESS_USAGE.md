
...?>>>>>>>>>>>>><-/g>.md           ← /write-plan 산출물 (task 분해)
│   └── scratch/                  ← 휘발성 실험 (gitignored)
│
├── scripts/                      ← 운영 도구
│   ├── handoff.sh                ← atomic + locked + versioned snapshot
│   ├── init-slice.sh             ← 신규 슬라이스 scaffold
│   ├── new-skill.sh              ← 신규 SKILL.md scaffold (lint-pass-by-default)
│   ├── status.sh                 ← /slice-status가 호출하는 라이브 스캔
│   └── (기타: skills-sync, verify, eval, smoke 등)
│
├── tests/
│   └── run-skill-lint.sh         ← 모든 SKILL.md 품질 lint (frontmatter + Red Flags + Forbidden)
│
└── docs/                         ← human-maintained source of truth
```

`.codex/`, `skills/` (workspace 루트)는 Codex 영역 — Claude는 직접 읽지 않음.
프로젝트 repo (FKSFold-Boltz_Advancement/, arl-threads-coscientist/, …)는 각자
`.git/`이 있어 본 워크스페이스 git에서 제외 (`.gitignore`).

---

## 3. The 11 slash skills

`/<name>` 호출. 새 세션 시작 시 자동완성 메뉴에 노출.

### Process (4) — cross-agent coordination
| 명령 | 용도 |
|---|---|
| `/handoff [메모]` | `CURRENT.md` 갱신 + `scripts/handoff.sh claude` 실행. 세션 종료, 컨텍스트 < 20%, 에이전트 전환, 긴 잡 제출 직전, 승인 게이트 직전. |
| `/slice-status <slice>` | static `.agent/status/<slice>.md` + 라이브 스캔 + project git status를 한 화면 통합. mtime > 7d 시 stale 플래그. |
| `/contract-check` | WORKFLOW.md §2 triggers (SLURM 제출, 4파일↑ 변경, ranking 변경 등)에 해당하는지 검사. 해당하면 `_template.md` 복사해서 contract 초안 생성. |
| `/route "<자유 텍스트>"` | WORKFLOW.md §1 routing table 매칭. 모호하면 사용자에게 묻고, 미매치면 새 slice 만들지 말고 routing 추가 권유. |

### Expertise (4) — opinionated code work
| 명령 | 용도 |
|---|---|
| `/code-review [파일/PR#]` | 5 lens (정확성·설계·단순화·외과성·테스트가능성) + Karpathy 4-guardrails. 기본 verdict REQUEST_CHANGES. 60-line cap. |
| `/refactor-simplify <path>` | bias = DELETE/INLINE/RENAME. net 음수 라인 필수. 테스트 없으면 safe ops만 허용. research code (`scratch/`, `*_smoke.py`, `# wip`) 자동 skip. |
| `/test-gen <target>` | pytest scaffold. behavior list 먼저 사용자 confirm → 그 다음 파일 쓰기. unknown expected는 invariant assert. `pytest --collect-only`만, 실행 X. |
| `/debug <symptom>` | hypothesis-first. 6 lens (recent change / boundary / wrong assumption / concurrency / wrong env / test artifact). 한 번에 fix 하지 않고 ONE diagnostic 제안 후 대기. |

### Workflow (3) — spec → plan → execute chain
| 명령 | 용도 | 다음 단계 |
|---|---|---|
| `/brainstorm "<주제>"` | Socratic 5-question 게이트 → `.agent/contracts/<slug>.md` 초안. **구현 차단 (HARD-GATE)**. | 사용자 contract `Status: approved` 마킹 후 `/write-plan` |
| `/write-plan <contract>` | 승인된 contract → 2-5분 단위 task로 분해 → `.agent/plans/<slug>.md`. Status pending이면 거부. | 사용자 plan `Status: approved` 마킹 후 `/execute-plan` |
| `/execute-plan <plan>` | 각 task를 fresh subagent에 위임 → `/code-review` 게이트 → APPROVE 시 commit. 2회 REQUEST_CHANGES 시 task blocked + 루프 중단. | 모든 task 완료 시 자동 `/handoff` |

---

## 4. The 6 hooks (auto-enforcement)

| 이벤트 | 훅 | 차단? | 효과 |
|---|---|---|---|
| `SessionStart` | `session-start-decay-check.sh` | ❌ | (a) stderr 경고: CURRENT.md > 24h, status/<slice>.md > 7d, project_* memory leak / (b) stdout JSON: 라이브 bootstrap (slice + skills + gates + memory policy)을 컨텍스트에 강제 주입 |
| `PreToolUse[Bash]` | `pre-bash-slurm-gate.sh` | ✅ | `.agent/contracts/`에 7일 이내 수정된 파일 없으면 `sbatch` 차단 |
| `PreToolUse[Bash]` | `pre-bash-destructive-gate.sh` | ✅ | `rm -rf /mnt/data*`, `rm -rf .agent/.claude/.codex/.git`, `git push --force`, `git reset --hard origin/...`, `git branch -D` 차단 |
| `PreToolUse[Bash]` | `pre-bash-db-gate.sh` | ✅ | `psql` + `DROP TABLE/DATABASE/SCHEMA`, `TRUNCATE`, `ALTER TABLE` 차단 |
| `PostToolUse[Edit\|Write\|MultiEdit]` | `post-edit-format.sh` | ❌ (productive) | `.py` → `ruff format`, `.{js,ts,json,md,yaml}` → `prettier --write`, `.sh` → `shfmt -w`. formatter 미설치면 silent skip. `/tmp`, `.agent/scratch`, `.agent/handoffs/state` skip 리스트. |
| `PreCompact` | `pre-compact-inject.sh` | ❌ | 컨텍스트 압축 직전 CURRENT.md 본문 stdout에 출력 → 압축 요약에 SSOT 보존 |
| `Stop` | `stop-handoff-check.sh` | ❌ | CURRENT.md yaml frontmatter 스키마 검증 (PyYAML 또는 stdlib 폴백), `version` 단조성 (마지막 snapshot 대비) 확인, 60분 미갱신 경고 |

훅 매칭 안전 정책:
- 정규식은 명령 시작 위치에 앵커 (`^|;|&&|\|\||\|<space>|<newline>`) → quoted string 안 키워드는 무시
- heredoc body는 strip (`${cmd%%<<*}`) → commit 메시지의 위험 키워드는 안전
- `jq` 미설치 시 모든 Bash 게이트는 **fail-closed (exit 2)**, productive hook은 silent skip

statusLine (`./.claude/statusline.sh`): 매 assistant turn마다 `[Opus 4.7] slice=fragmap owner=claude v6 age=2h ctx=42%` 식으로 한 줄 표시.

---

## 5. The 3 subagents (Agent tool delegation)

`Agent(subagent_type="<name>", prompt="...")`로 호출. 좁은 tool surface로 컨텍스트 보호 + 사고 방지.

| Subagent | Model | Allow | Deny |
|---|---|---|---|
| `slurm-status` | haiku[1m] | squeue, sacct, sinfo, sacctmgr, scontrol show, awk/grep/sort/head/tail/wc | `sbatch`, `scancel`, `scontrol update/create`, `srun` |
| `fragmap-diagnose` | opus[1m] | Read, Grep, ls/cat/head/tail/grep/awk/find/wc, `python3 -c` (1-liner only) | `sbatch`, `srun`, full `python:*`, `conda:*`, `make:*`, Edit, Write |
| `mmgbsa-stage-check` | opus[1m] | Read, Grep, ls/cat/head/tail/grep/awk/find/wc/stat/du, squeue, sacct, shared workspace read | `sbatch`, `rm:*`, `cp:*`, `mv:*`, Edit, Write |

언제 위임:
- 짧은 잡 상태 확인 → `slurm-status` (haiku로 빠르고 저렴)
- 실험 약한 결과 진단 → `fragmap-diagnose` (input YAML/scoring config audit 먼저)
- MMGBSA 다음 stage 가능한지 게이트 검사 → `mmgbsa-stage-check`

---

## 6. Daily workflows (recipes)

### A. 휴식 후 작업 재개
1. 새 세션 시작 → `SessionStart` 훅이 bootstrap 컨텍스트 자동 주입
2. `CURRENT.md` 읽고 active_slice + remaining_actions 확인 (이미 컨텍스트에 있음)
3. 첫 remaining_action 수행
4. 끝나면 `/handoff`

### B. 새 기능/실험 시작 (non-trivial)
```
1. /brainstorm "<one-liner>"
   → 5 Socratic Q&A → .agent/contracts/<slug>.md 초안 생성
2. (contract review, user marks Status: approved)
3. /write-plan .agent/contracts/<slug>.md
   → 2-5분 task로 분해 → .agent/plans/<slug>.md
4. (plan review, user marks Status: approved)
5. /execute-plan .agent/plans/<slug>.md
   → task별 subagent + /code-review → task commit
6. (자동) /handoff
```

빠른 우회 (`/brainstorm` 생략 가능 케이스): 4파일 미만 + trigger 0개 + 명확한 의도 + 사용자가 명시적으로 "그냥 해" 한 경우.

### C. 다른 agent로 인계
```
1. /handoff "다음 세션 첫 액션 한 줄"
2. Stop 훅이 frontmatter 검증 + version 단조성 확인
3. 안전하게 close
```

### D. 다른 agent 작업 이어받기
```
1. .agent/handoffs/CURRENT.md 읽기 (owner_agent 확인)
2. owner_agent ≠ self → .agent/handoffs/takeover-prompt.md 4-7 단계 실행
   - contracts 읽기
   - read-only git status/diff/log
   - state/latest/diff.patch와 cross-check
   - 적절한 AGENTS.md/CLAUDE.md
3. 목표 재진술 후 사용자 confirm
```

### E. 실패/에러 진단
```
1. /debug "<symptom>" or paste stack trace
   → 6 lens로 가설 2-4개 평가 + ONE 진단 명령 제안
2. (user runs the diagnostic, reports back)
3. /debug confirms hypothesis → 수정 모양 제안 (NO 자동 fix)
4. /code-review on proposed patch
```

SLURM/cluster 측 문제면 `Agent(subagent_type="slurm-status", prompt="job <id> 상태와 로그 위치")`.

### F. PR 전 코드 검토
```
/code-review              # uncommitted diff
/code-review PR#123       # GitHub PR
/code-review path/to/file # 단일 파일
```

verdict REQUEST_CHANGES면 `/refactor-simplify`로 단순화 가능성 추가 검토.

### G. SLURM 잡 제출
```
1. /contract-check
   → SLURM trigger 매칭 → contract 초안 생성
2. (user approve)
3. sbatch workflow/foo.sh
   → pre-bash-slurm-gate가 contracts/ 7-day window 확인 → 통과
```

### H. 신규 스킬 추가
```
1. ./scripts/new-skill.sh <slug> [process|expertise|workflow]
2. SKILL.md placeholder 채우기 (description, 본문 step들, Red Flags 항목들)
3. bash tests/run-skill-lint.sh → 11/12 PASS 확인
4. Claude Code 재시작 → /<slug> 자동완성 등록
```

### I. 신규 슬라이스 추가
```
1. ./scripts/init-slice.sh <slice-name>
2. WORKFLOW.md §1 routing 표에 row 추가
3. .claude/hooks/stop-handoff-check.sh VALID_SLICES에 slice 이름 추가
4. .agent/status/<slice>.md + .agent/projects/<slice>-harness.md 채우기
```

---

## 7. CURRENT.md schema (cross-agent SSOT)

매 turn 시작 시 SessionStart 훅이 자동으로 파싱해서 컨텍스트에 주입함.

### 필수 frontmatter (Stop 훅 검증)
```yaml
---
owner_agent: claude            # claude | codex | cursor | human
last_updated: 2026-05-21       # ISO date, ≤ 7 days old
active_slice: fragmap          # fragmap | mmgbsa | vav1 | fksfold-core | arl
remaining_actions:             # 1-3 items
  - "concrete next step 1"
  - "concrete next step 2"
schema_version: 1
version: 6                     # handoff.sh가 자동 증가, 직접 수정 금지
---
```

### 선택 frontmatter
`session_title`, `files_touched_count`, `verification_run`, `verification_result`,
`failure_log`, `prior_slice_archive`, `approval_required`, `contract_pointers`.

### body 섹션 (사람 읽기용)
Goal / Current status / Files touched / Verification run / Failure log location /
Remaining actions / Approval required / Memory contract pointers /
Critical lessons / Key result snapshot.

### 갱신 두 가지 방법
1. **`/handoff` 호출** (권장): skill이 필드 가이드해서 채움 + handoff.sh 실행 → version 자동 증가
2. **직접 Edit**: 본문은 자유, frontmatter는 schema 준수. Stop 훅이 위반 시 stderr 경고

---

## 8. Memory policy

`~/.claude/projects/-home-ubuntu/memory/`는 **3종만**:

| 저장 OK | 저장 금지 |
|---|---|
| `user_profile.md` — 사용자 역할/배경/선호 | `project_*.md` — 프로젝트 상태는 `.agent/`로 |
| `feedback_*.md` — "이렇게 하지 마/이렇게 해" 규칙 | 코드 패턴/파일 경로 (codebase가 SoT) |
| `reference_*.md` — 외부 시스템 포인터 (Linear, Grafana) | 휘발성 디버깅/임시 컨텍스트 |

SessionStart 훅이 `project_*.md` 재출현을 자동 감지해 경고.

---

## 9. Approval gates 정리

PreToolUse 훅이 자동 차단 + 사용자 승인 후에만 실행:

| 동작 | 우회 |
|---|---|
| `sbatch <script>` | `.agent/contracts/`에 7일 이내 수정된 contract 만들기 (`/contract-check`로 자동 생성) |
| `psql ... DROP TABLE/TRUNCATE/ALTER TABLE` | 사용자 명시 승인 후 한정 패턴을 `settings.local.json` allow에 |
| `rm -rf /mnt/data*` | 동일 |
| `rm -rf .agent/.claude/.codex/.git` | 동일 (보통 의도하지 않은 실수 캐치용) |
| `git push --force` / `-f` | 동일 |
| `git reset --hard origin/...` | 동일 |
| `git branch -D` | 동일 |

heredoc body 내 키워드는 안전 (commit 메시지 등) — 훅이 `${cmd%%<<*}`로 strip.

---

## 10. Quality enforcement

### Skill lint (`bash tests/run-skill-lint.sh`)
모든 `SKILL.md`에 적용:
- F1 frontmatter `---` delimited
- F2 `name:` lowercase-slug
- F3 `description:` 60-400 chars, boilerplate opener 금지 ("Skill that...", "A skill...", "This skill...")
- F4 `allowed-tools` 균형 잡힌 괄호, 허용 문자 집합
- B2 `## Red Flags` 또는 본문 inline에 Red Flags 섹션
- B3 `## Forbidden` 섹션
- B4 Red Flags 표 데이터 행 ≥ 3

현재 11/11 PASS. 신규 skill은 `scripts/new-skill.sh`로 scaffold 시 자동으로 lint-pass.

### Hook tests (template repo CI)
Template `tests/run-hook-tests.sh` — 13 golden JSON fixture로 각 hook의 block/allow 동작
검증. Linux + macOS matrix.

---

## 11. Troubleshooting

| 증상 | 원인 / 해결 |
|---|---|
| 슬래시 명령이 자동완성에 안 보임 | Claude Code 재시작. 새 SKILL.md는 세션 시작 시 스캔. |
| 훅이 정상 명령 차단 (false positive) | 해당 훅 `.sh` 정규식 정밀화 OR `.claude/settings.json` `hooks` 블록에서 일시 제거. heredoc body는 이미 strip됨. |
| Stop hook이 `frontmatter validation` 경고 | 빠진 필드 추가 OR schema_version: 1 + 필수 키 (owner_agent/last_updated/active_slice/remaining_actions) |
| `sbatch`가 계속 차단됨 | `find .agent/contracts -name '*.md' ! -name '_template.md' -mtime -7` 결과 빈 → 새 contract 만들기 (`/contract-check`) |
| `Agent(subagent_type=foo)` 호출 안 됨 | `.claude/agents/foo.md` 존재 확인, Claude Code 재시작 |
| Codex 세션에서 yaml frontmatter가 보임 | 의도된 동작. Codex는 무시하고 본문만 읽음 (하위 호환) |
| memory에 `project_*` 재출현 경고 | 해당 파일 삭제 + 내용은 `.agent/status/<slice>.md`로 |
| `post-edit-format` 작동 안 함 | formatter 미설치 (silent skip). `which ruff prettier shfmt`로 확인 |
| handoff.sh OWNER.lock 못 잡음 | 30초 타임아웃. 다른 handoff 실행 중. stale이면 `find .agent/handoffs -name OWNER.lock.d -delete`. |
| statusLine 안 보임 | `chmod +x .claude/statusline.sh` 확인. settings.json `statusLine.command` 경로 확인. |

---

## 12. Extension cheat sheet

| 추가하고 싶은 것 | 방법 |
|---|---|
| 새 slash command | `./scripts/new-skill.sh <slug> [process\|expertise\|workflow]` → SKILL.md 편집 → lint → 재시작 |
| 새 subagent | `.claude/agents/<name>.md` (frontmatter: name, description, tools, model, permissions) → 재시작 |
| 새 enforcement hook | `.claude/hooks/<name>.sh` + `.claude/settings.json` `hooks` 블록 등록 + `bash -n` 검증 |
| 새 slice | `./scripts/init-slice.sh <name>` → WORKFLOW.md §1 row 추가 → stop-handoff-check.sh VALID_SLICES 추가 |
| 새 contract trigger | WORKFLOW.md §2 항목 추가 → `/contract-check` skill 본문 update |
| 새 MCP server | (선택) `.mcp.json` 작성. template의 [docs/concepts/mcp-servers.md](https://github.com/sun9huni/claude-codex-coordination/blob/main/docs/concepts/mcp-servers.md) 참고 |
| 새 productive hook (다른 language formatter 등) | `.claude/hooks/post-edit-format.sh` case 추가 OR 별도 PostToolUse 훅 |

---

## 13. Quick reference

### 매일 가장 자주 쓰는 5가지
1. `CURRENT.md` 읽기 (자동, SessionStart inject)
2. `/handoff` 세션 종료
3. `/code-review` PR 전
4. `Agent(subagent_type="slurm-status", ...)` 잡 상태
5. `/contract-check` 비-사소한 변경 시작 전

### 절대 직접 하지 말 것
- `sbatch` 직접 (gate 우회) — `/contract-check` 먼저
- `psql` DDL 직접 — 사용자 명시 승인 먼저
- `git push --force` / `--no-verify` — 사용자 명시 승인 먼저
- `project_*.md`를 메모리에 저장 — `.agent/`로
- `CURRENT.md`의 `version:` 직접 편집 — `handoff.sh`가 관리
- `.agent/handoffs/state/latest/*` 직접 편집 — handoff.sh 출력물

### 파일 위치 cheat sheet
| 정보 | 위치 |
|---|---|
| "지금 무슨 일이 벌어지나" | `.agent/handoffs/CURRENT.md` |
| 한 슬라이스의 25줄 요약 | `.agent/status/<slice>.md` |
| 한 슬라이스의 deep workflow | `.agent/projects/<slice>-harness.md` |
| 승인된 commitment | `.agent/contracts/<slug>.md` |
| 진행 중인 task 분해 | `.agent/plans/<slug>.md` |
| 진입 ritual | `CLAUDE.md` (3 step) |
| Routing 표 | `WORKFLOW.md §1` |
| Contract trigger 목록 | `WORKFLOW.md §2` |
| 절대 안 되는 동작 | `WORKFLOW.md §3` + `pre-bash-*-gate.sh` |
| 사용자 선호 / 외부 ref | `~/.claude/projects/-home-ubuntu/memory/` |

---

## Appendix: 관련 문서

- [CLAUDE.md](CLAUDE.md) — 3-step session ritual
- [AGENTS.md](AGENTS.md) — 공유 규칙 (Codex/Cursor도 읽음)
- [WORKFLOW.md](WORKFLOW.md) — 1-screen router
- [.agent/handoffs/handoff.md](.agent/handoffs/handoff.md) — handoff protocol 상세
- [.agent/handoffs/takeover-prompt.md](.agent/handoffs/takeover-prompt.md) — cross-agent 인계 7-step
- 공개 템플릿: <https://github.com/sun9huni/claude-codex-coordination> (v0.3.1, 동일 구조 + generic placeholder)
- 설계 배경: [.claude/plans/dreamy-doodling-pnueli.md](.claude/plans/dreamy-doodling-pnueli.md)
