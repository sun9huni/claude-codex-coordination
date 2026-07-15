# WORKFLOW

One-screen router. No facts here — only "어디로 가라". 사실 정보는 전부
`.agent/projects/*.md`와 `AGENTS.md`에 있음. 이 파일이 그것들과 어긋나면
이 파일이 틀린 것.

## 0. 세션 시작 (3-step ritual, every session)

This is the **same** 3-step ritual that `CLAUDE.md` and
`.agent/handoffs/takeover-prompt.md` (steps 1-3) use. If you ever
see them in different orders, this file or those files are wrong —
they MUST match.

1. **Read the `.agent/handoffs/CURRENT.md` index** — 파생 인덱스
   (derived lab-wide view of which session owns which slice). Trust the
   per-slice status files over chat history. 작업할 슬라이스의
   `owner_agent` ≠ you 면 `takeover-prompt.md` 의 추가 step 4-7 수행.
2. **Identify your slice and read its `.agent/status/<slice>.md`** —
   the authoritative per-slice baton (`owner_session`, `heartbeat`,
   `remaining_actions`, …). 인덱스에서 슬라이스를 찾거나, 안 보이면 §1
   routing table 참조. 세션은 `owner_session` + `heartbeat` 로 슬라이스를
   "claim" 한다 — SessionStart hook 이 다른 `owner_session` 의 heartbeat
   가 fresh 한 슬라이스(contested)에 들어가면 경고함. mtime > 7 days 면
   `./scripts/status.sh <slice>` 로 live state 확인.
3. **Drill down only if the task needs more context** —
   `.agent/projects/<slice>-harness.md`. Do NOT pre-read all of them;
   pull on demand.

## 1. 어느 슬라이스인가

슬라이스는 `CURRENT.md` 인덱스(파생) 또는 per-slice `.agent/status/<slice>.md`
에서 식별한다 — `active_slice` scalar 필드는 더 이상 없음. 신호로 못 좁히면
아래 표를 쓴다.

| 작업 신호 | status (먼저) | 하네스 (deep dive) | 절대 잊지 말 것 |
| --- | --- | --- | --- |
| SILCS-Lite map build (GCMC / GrandLig / probe / channel / GFE) · FragMap scoring·overlay · 9NFR pharmacophore | `.agent/status/fragmap.md` | `.agent/projects/aigen-fold-fragmap-9nfr-harness.md` | 지도 생성·점수 **전용**. placement/steering 실행·검증(held-out·AB)은 **aigen-fold-core** (이 슬라이스 = 지도 생산자). **6단계 사다리** 건너뛰기 금지 |
| MMGBSA / SLURM / F105 / normtest143 / DDG merge / backup import | `.agent/status/mmgbsa.md` | `.agent/projects/aigen-fold-mmgbsa-slurm-harness.md` | Stage 1–4 **분리 보고**, SLURM 제출은 **승인 후** |
| VAV1 ranking / `vav1_ensemble_rank.py` / `*ranking*.yaml` | `.agent/status/vav1.md` | `.agent/projects/vav1-ranking-harness.md` | **shared가 active**, baseline/production **두 모드 유지** |
| src/boltz / steering 내부·실행 / generation·placement 검증 (held-out · AB · DockQ) / boltz·steering config / workflow script | `.agent/status/aigen-fold-core.md` | `.agent/projects/aigen-fold-boltz-core-harness.md` | 경계 슬라이스 **섞지 말 것**. FragMap '지도/점수'는 **fragmap** (이 슬라이스 = 지도 소비자). (`configs` 단독은 신호 아님) |
| MRT6160/VAV1 **productive ubiquitination 방향** / 2C forced-template orientation steering / swept-reach 도달성 / lysine→E2(UBE2D2 C85) reachability / completed CRL4–E2~Ub overlay | `.agent/status/vav1-ubq.md` | contract `fksfold-core-mrt6160-productive-orientation-20260609` + `fksfold-core-swept-reach-judge-20260612` | 2026-06-12 aigen-fold-core에서 분리(엔진 일반=aigen-fold-core·랭킹=vav1과 **구분**). 계약 slug은 legacy `fksfold-core-` 접두(파일명 불변). Tier2 GPU는 게이트 후 |
| ARL / paper discovery / LangGraph / coscientist | `.agent/status/arl.md` | `.agent/projects/arl-threads-coscientist-harness.md` | `make check`만, `make ci-full`/`test-integration` 금지 (`experiments` 단독은 신호 아님) |
| harness / Notion sync / ADR·Decisions·Experiments DB / runbook / skill·hook / Navigator / notion_sync.py | `.agent/status/harness.md` | `.agent/status/README.md` (baton 스키마) + `CLAUDE.md` | process 어휘(baton/handoff/status)는 **전 슬라이스 공통 → 라우팅 키워드 아님**; 모호하면 사용자 질문. `CURRENT.md` 직접편집 금지 |
| FEA / experiment autopilot / `scripts/fea` / preflight·watch·postflight·capture / SLURM 실험 루프 자동화 | `.agent/status/fea.md` | `.agent/contracts/harness-experiment-autopilot-20260604.md` | advisory/gated 파이프라인; 코드=`scripts/fea`+`analysis`(슬라이스 분리 시 이동 안 함). harness(Notion·조정 인프라)와 **구분** |
| M-RELATIVITY / 양자보조 committor / OOD 분해 양자이득 실증 제안서 / committor·운명장·W₃·QPE·degradation grant | `.agent/status/m-relativity.md` | `.agent/scratch/m_relativity_proposal_20260609.md` (제안서 전문) | 독립 연구 grant 과제 — VAV1 degrader 파이프라인 슬라이스와 **구분**. Notion 발행본 존재. 양자=표현가능성(R) vs 양자컴퓨터 필요성(Q) **분리** 규약 유지. 범용 Notion 발행 툴화는 harness 소관 |
| "이 파일 어디 있지", local vs shared 헷갈림, CLI/config merge 확인 | `.agent/projects/aigen-fold-actual-file-map-20260518.md` | local repo는 dirty, **shared에 active 버전 존재** |
| "지난 주 뭐 했지" / 신규 Cursor plan 검출 | `.agent/projects/recent-cursor-activity-20260518.md` | 1주일 지나면 stale, 재스캔 |
| 해당 없음 / 새 도메인 | 사용자에게 질문 | 자의적으로 슬라이스 만들지 말 것 |

## 2. Contract 필요한가 (FKSFold 한정)

다음 중 **하나라도 해당** → `.agent/contracts/_template.md`로 contract 먼저
작성, 승인 대기:

- diffusion sampling / steering potential / score scaling 의미 변경
- ranking 의미·순서·가중 변경 (production_rank 정의 건드림)
- SLURM workflow script 수정 또는 신규 제출
- 벤치마크/acceptance metric 변경
- 4개 파일 이상 수정
- local repo와 shared workspace를 같은 task에서 동시 수정
- FragMap 신규 scoring mode 추가 (= 새 contract)

## 3. 멈추고 승인 받아야 하는 동작

- SLURM 제출 (정확한 resource request도 함께)
- **GPU/CUDA 실행 전부** (SLURM 여부 무관 — 인라인 "빠른 smoke test"도 포함).
  `ubuntu` 계정/세션은 GPU를 직접 만지지 않는다. 실제 GPU 연산은 전부
  `kim` 계정으로 SLURM을 통해서만. 이전에 한 번 승인받았어도 다음 GPU
  실행마다 다시 물어볼 것 — 승인은 이월되지 않는다. subagent에게 위임할
  때 "CPU or available GPU" 식으로 선택지를 열어두지 말고, 이 게이트가
  이번 건에 대해 이미 통과됐을 때만 GPU를 명시적으로 허용한다
  (자세한 내용은 `AGENTS.md` §Approval Gates).
- `/mnt/data` output 디렉터리 삭제·덮어쓰기
- ranking production 기본값 의미 변경
- backup-import 포팅 파일 commit
- `scripts/remote-bootstrap.sh` 원격 실행
- `.codex/skills/` 또는 `~/.claude/` 기존 파일을 덮어쓰는 동기화 (`--delete` 동반)
- 파괴적 git 동작 (force push, hard reset, branch -D 등)

## 4. 종료

- 게이트: 슬라이스 게이트 + `./scripts/verify.sh` (UI면 `browser-check.sh`,
  AI 행동이면 `eval.sh`, 도구/스킬이면 `tool-audit.sh`/`skills-sync.sh
  --dry-run`).
- 인계: 자기 슬라이스의 `.agent/status/<slice>.md`(frontmatter + body) 갱신 →
  `./scripts/handoff.sh <next-agent> <slice>` → `./scripts/status.sh index` 로
  파생 `CURRENT.md` 인덱스 재생성. `CURRENT.md` 는 직접 편집하지 말 것.
  placeholder 남기지 말 것.
- **status 갱신**: 이 세션이 어떤 슬라이스 작업이었든, 그 슬라이스의
  `.agent/status/<slice>.md`를 "지금 어디까지/다음 액션/live truth" 기준으로
  덮어쓸 것. 본문 25줄 이내 유지.

## 5. 이 파일이 답을 못 주면

라우터 한계. 해당 하네스를 직접 읽고, 작업 끝나면 라우터를 갱신.
