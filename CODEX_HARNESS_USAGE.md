# Codex Harness Usage

Single readable usage guide. Three layers — pick the lightest one that fits.

| 무엇을 원하나 | 어디 봐 |
| --- | --- |
| 지금 진행 중 task가 뭐였지? | `.agent/handoffs/CURRENT.md` |
| 어느 슬라이스 작업이지, 어디로 가지? | `WORKFLOW.md` (한 화면 라우터) |
| 그 슬라이스 어디까지 갔지? | `.agent/status/<slice>.md` (사람 요약) |
| 라이브 상태 (plans, outputs, git) 자동 확인 | `./scripts/status.sh <slice>` |
| 슬라이스 규칙 deep dive | `.agent/projects/<slice>-harness.md` |
| 워크스페이스 규칙 전반 | `AGENTS.md` / `CLAUDE.md` |

This harness is shared by **Codex, Claude, and Cursor**. They read the same
`AGENTS.md` / `CLAUDE.md` / `WORKFLOW.md` / `.agent/` tree. Working state is
held in repo files, not in chat history.

## Daily Flow

세션 시작 → 작업 → 종료 3단계.

### 시작 (3분 안)

1. `.agent/handoffs/CURRENT.md` — in-progress task 있으면 그것부터.
2. `WORKFLOW.md` §1 표에서 슬라이스 결정.
3. 그 슬라이스의 `.agent/status/<slice>.md` 읽기. 작성일이 7일 넘었으면
   `./scripts/status.sh <slice>`로 라이브 확인.
4. 필요하면 `.agent/projects/<slice>-harness.md`로 deep dive.

새 에이전트에 처음 들어가는 거면 첫 메시지로 한 줄:

```
WORKFLOW.md 보고 시작해.
```

이전 세션 이어가는 거면:

```
.agent/handoffs/takeover-prompt.md 그대로 따라.
```

### 작업 (라우터가 알려주는 대로)

1. `WORKFLOW.md` §2의 contract 트리거에 해당하면 → `.agent/contracts/<task>.md`
   먼저 작성, 사용자 승인 대기.
2. 비-trivial 변경이면 `.agent/checklists/change-discipline.md`도 참조.
3. 슬라이스 경계 섞지 말 것 (예: ranking task에서 diffusion 내부 손대지 말기).
4. `WORKFLOW.md` §3 승인 게이트(SLURM 제출, output 덮어쓰기, ranking 의미 변경,
   backup-import commit, remote 실행 등)에 걸리면 멈추고 사용자 승인.

### 종료

1. 슬라이스별 게이트 + `./scripts/verify.sh`. UI는 `browser-check.sh`, AI 행동은
   `eval.sh`, 도구/스킬은 `tool-audit.sh` / `skills-sync.sh --dry-run`.
2. **status 갱신**: 작업한 슬라이스의 `.agent/status/<slice>.md`를 25줄 이내로
   덮어써. "어디까지 / 다음 액션 / live truth 경로 / open" 4섹션.
3. `./scripts/handoff.sh <next-agent>` 실행 + `CURRENT.md` 채우기. placeholder
   남기지 말 것 (스크립트가 경고함).

## Agent Handoff (Cursor / Claude / Codex)

Chat sessions are not durable. The repo is. Use the handoff protocol any
time a session ends, context drops below ~20%, you switch agents, or you
start work that must outlive the current chat (SLURM, MMGBSA, ensemble
runs).

### Before ending a session

```bash
./scripts/handoff.sh <next-agent>   # e.g. codex / claude / cursor / human
```

Then fill in `.agent/handoffs/CURRENT.md`:

- Owner agent, today's ISO date, active project
- Goal (observable), current status
- Files touched, verification command + result
- Failure / log path (or `n/a`)
- 1–3 concrete remaining actions
- Approval-required list (or `none`)

`handoff.sh` warns if any `<placeholder>` is left. It also writes a
snapshot to `.agent/handoffs/state/`:

- `git-status.txt`, `git-log.txt`, `diff.patch`, `diff-staged.patch`
- `session-note.md` (free-form notes for the next agent)
- `meta.txt` (timestamp, next agent, host)

### Resuming in a new session

Open the new agent (Claude / Codex / Cursor) and send this as the
first message:

```
.agent/handoffs/takeover-prompt.md 를 그대로 따라.
```

Or paste the contents of that file directly. The takeover prompt forces
the incoming agent to:

1. Read `CURRENT.md`, related contract, project harness.
2. Inspect `git status`, `git diff`, and `state/*` snapshots.
3. Cross-check "Files touched" against the actual diff.
4. Restate the goal and propose the next action — and **wait for human
   approval before any write or run**.

### Mid-session trigger

When the context gauge gets low, you can tell the agent:

```
handoff-writer 방식으로 인계 파일 갱신해줘.
```

The `handoff-writer` skill (`skills/handoff-writer/SKILL.md`, mirrored to
`.codex/skills/handoff-writer/SKILL.md`) drives the workflow.

### Quick reference

| When | Command / Action |
| --- | --- |
| Session start (new agent) | First message: "`WORKFLOW.md` 보고 시작해." |
| Resuming previous work | Paste `.agent/handoffs/takeover-prompt.md` as first message |
| 지금 어디까지 갔는지 빠른 확인 | `./scripts/status.sh <slice>` (또는 `all`) |
| 슬라이스 요약 (사람 작성) | `.agent/status/<slice>.md` |
| Context near limit | "handoff-writer 방식으로 인계 파일 갱신해줘" |
| Switching agent / ending session | `./scripts/handoff.sh <next-agent>` + update `CURRENT.md` + slice `status` |
| Approval-gated action pending | Note it in `CURRENT.md` "Approval required", stop |

### Forbidden at handoff time

- Leaving `<placeholder>` fields in `CURRENT.md`.
- Background jobs without a PID / SLURM id / log path in `CURRENT.md`.
- "See chat above" — inline it.
- Starting a destructive or approval-gated action during the handoff.

Full protocol: `.agent/handoffs/README.md` and `.agent/handoffs/handoff.md`.

## Per-Slice Status

For active slices (FragMap, MMGBSA, VAV1 ranking, FKSFold core, ARL), each has
two layers:

- **사람 작성 요약** (`.agent/status/<slice>.md`): 25줄 이내. "어디까지 / 다음
  액션 / live truth 경로 / open". 세션 종료 시 갱신 의무.
- **자동 라이브 스캔** (`./scripts/status.sh <slice>`): read-only. Cursor plans,
  shared `outputs/`, local git, ARL PHASE 파일을 그 자리에서 스캔해 출력. 작성
  0건, 의사결정 0건.

### Slice list

| Slice | 신호 | Status file | Harness |
| --- | --- | --- | --- |
| `fragmap` | FragMap / 9NFR / pharmacophore / target occupancy | `.agent/status/fragmap.md` | `.agent/projects/fksfold-fragmap-9nfr-harness.md` |
| `mmgbsa` | MMGBSA / SLURM / F105 / normtest / DDG merge / backup import | `.agent/status/mmgbsa.md` | `.agent/projects/fksfold-mmgbsa-slurm-harness.md` |
| `vav1` | VAV1 ranking, `vav1_ensemble_rank.py`, `*ranking*.yaml` | `.agent/status/vav1.md` | `.agent/projects/vav1-ranking-harness.md` |
| `fksfold-core` | src/boltz, steering 내부, configs, workflow | `.agent/status/fksfold-core.md` | `.agent/projects/fksfold-boltz-core-harness.md` |
| `arl` | ARL Co-Scientist (paper discovery → experiment) | `.agent/status/arl.md` | `.agent/projects/arl-threads-coscientist-harness.md` |

### 운영 규칙

- 사실은 status.sh, 해석은 status.md, 규칙은 harness. 셋이 충돌하면 사실(스크립트)이
  옳음.
- status.md가 7일 넘으면 status.sh로 사실 확인 후 갱신.
- 새 슬라이스 추가 시: `WORKFLOW.md` §1 표 + `.agent/status/<slice>.md` +
  `scripts/status.sh`의 `slice_<name>` 핸들러 동시 추가.

## Task Routing

| Task | Read | Run |
| --- | --- | --- |
| Any task — route first | `WORKFLOW.md` | `./scripts/status.sh <slice>` |
| Slice resume / status check | `.agent/status/<slice>.md` | `./scripts/status.sh <slice>` |
| Small code change | `.agent/checklists/change-discipline.md` | `./scripts/verify.sh` |
| Large feature/refactor | `.agent/contracts/_template.md` | `./scripts/verify.sh` |
| Web UI change | `.agent/qa/browser-checklist.md` | `./scripts/browser-check.sh` |
| AI/RAG/search behavior | `.agent/evals/eval-plan.md` | `./scripts/eval.sh` |
| Architecture exploration | `.agent/knowledge/wiki/index.md` | `./scripts/knowledge-build.sh` if sources changed |
| Remote SSH work | `.agent/remote/policies.md` | `./scripts/remote-verify.sh <alias> <repo>` |
| MCP/tool change | `.agent/tools/mcp-policy.md` | `./scripts/tool-audit.sh` |
| Skill change | `.agent/skills/sync-policy.md` | `./scripts/skills-sync.sh --dry-run` |
| Delegated generation/review | `.agent/delegation/policy.md` | update `.agent/delegation/log.md` |
| Session end / agent switch / context near limit | `.agent/handoffs/handoff.md` | `./scripts/handoff.sh <next-agent>` + update `CURRENT.md` |
| New session / continuation | `.agent/handoffs/CURRENT.md` | paste `.agent/handoffs/takeover-prompt.md` into the agent |

## Prompt Templates

### Session start

```text
WORKFLOW.md 보고 시작해. 슬라이스 정해지면 .agent/status/<slice>.md 읽고, 7일 넘었으면 ./scripts/status.sh <slice>로 라이브 확인. 그 다음 다음 액션 제안하고 승인 기다려.
```

### Implementation

```text
Follow WORKFLOW.md routing and change-discipline. If this is a large change, create a contract first and stop for approval. After implementation, run the relevant verification scripts, update the slice status file, and report the result.
```

### Review

```text
Review this with a bug/regression mindset. Prioritize behavioral regressions, missing tests, boundary violations, security risks, and unrelated diffs. Include file/line references.
```

### Session Wrap

```text
Summarize repeated mistakes, repeated workflows, missing docs, and missing verification from this session. Suggest candidates for rule, checklist, skill, or eval-case promotion.
```

## Maintenance Cadence

Weekly:

```bash
./scripts/verify.sh
./scripts/tool-audit.sh
./scripts/skills-sync.sh --dry-run
```

Per session (every time):

```bash
# at start: route + read live status
./scripts/status.sh <slice>

# at end: snapshot + update CURRENT.md + slice status file
./scripts/handoff.sh <next-agent>
```

Monthly:

- Deprecate unused Skills.
- Disable unused tools.
- Add real failures to `.agent/evals/dataset.jsonl`.
- Refresh stale knowledge.
- Review remote host inventory.
- Shorten `AGENTS.md` by moving details into scoped docs.
