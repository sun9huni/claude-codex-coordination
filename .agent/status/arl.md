---
owner_session: ""
owner_label: ""
owner_agent: ""
version: 0
last_updated: 2026-05-26
heartbeat: ""
remaining_actions: []
contract_pointers: []
---
# ARL Co-Scientist Status

As of: 2026-05-18

## Where we are

- 현재 milestone: **Phase 37 — Production Hardening** (`PHASE37_PRODUCTION_HARDENING.md`).
- Phase 36 완료 상태: Discovery → V1 → Docker → V2 → Critic → PR 생성 E2E
  통과, DB에 pr_urls/selected_count/tokens_used 저장, `make check` 727 tests
  통과, 스케줄러 09:00 UTC 설정됨.
- Phase 37 미해결 (P0): Docker 컨테이너 305개 누적 (`--rm` 미설정),
  Celery 워커 실행 안 됨, `arl doctor`가 :8000 체크 (실제 :8099),
  `ARL_V1_REAL_TESTS=false` (코드 검증 우회), Qdrant unhealthy.

## Next action

Phase 37 Task 1 (Docker `--rm` 플래그). 변경은 `arl/experiment/` boundary
모듈, 단일 task로 가능. `make check` 게이트 < 3분.

## Live truth

- Phase 파일: `arl-threads-coscientist/PHASE37_PRODUCTION_HARDENING.md`
- Repo rules: `arl-threads-coscientist/AGENTS.md`, `CLAUDE.md`
- 게이트: `cd arl-threads-coscientist && make check`

## Open

- Phase 37 Task 우선순위 P0/P1 명시는 PHASE37 본문 안에 있음 — 순서대로
  하나씩 끝낼지, P0 5개를 한 contract로 묶을지 사용자 결정 필요.
