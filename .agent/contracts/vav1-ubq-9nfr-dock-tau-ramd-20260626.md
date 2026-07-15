---
status: approved
slice: vav1-ubq
topic: 9nfr-dock-tau-ramd
date: 2026-06-26
approved_by: user (2026-06-26, "진행")
requested: 2026-06-26
triggers_matched:
  - "SLURM/GPU submission (τ-RAMD egress, staged)"
  - "shared-storage writes (/mnt outputs)"
  - "4+ files (pose generator + MD build + τ-RAMD driver 재사용 + report)"
references:
  - analysis/crl_integrative/steered_regen_residence_pilot_results_20260626.md (선행 null pilot, pivot 근거)
  - analysis/crl_integrative/steered_regen/ramd_force.py (재사용 RAMD 모듈)
  - analysis/crl_integrative/steered_regen/tau_ramd_run.py (재사용 드라이버)
  - /home/ubuntu/best_structures/9NFR_reference.cif (crystal 구조 소스)
---

# 9NFR Crystal Docking → τ-RAMD S003 Residence Pilot

## Purpose / Hypothesis

선행 pilot(steered-regen τ-RAMD)에서 GATE-B null의 근본 원인이 확정됐다: **9NFR-앵커 스티어링이
모든 S003 화합물을 동일 CRBN-SH3c 배치로 수렴(cross-compound spread 0.4Å)시켜 compound-specific
glue-SH3c 접촉 차이를 제거**. τ-RAMD 방법론 자체는 맞으나 시작 포즈가 차이를 포착하지 못했다.

이 컨트랙트는 그 **한 가지 전제를 바꾼다**: 9NFR crystal 구조(chain B=CRBN+A1BYX, chain C=VAV1-SH3c)를
사용해 **각 S003 화합물을 MRT-23227(A1BYX) crystal 위치에 MCS-align**하면 compound-specific
glue-protein 접촉이 복원되고 τ-RAMD discrimination이 가능해지는지 검증한다.

가설: *"9NFR crystal 기반 MCS-aligned 포즈는 S003 화합물 간 glue-protein 접촉 차이를 포착하고,
τ-RAMD egress 순위가 DC50 tier를 분리한다."*

## Scope

- **Phase-0 (zero-GPU)**: 9NFR crystal에서 CRBN + VAV1-SH3c + MRT-23227(A1BYX) 추출 →
  각 S003 화합물을 RDKit MCS로 A1BYX에 정렬 → clash check + 국소 최소화 → 12 compound-specific 포즈.
- **Phase-1 (GPU)**: 선행 pilot T8 파이프라인(build_subset_systems.py) 재사용 → 12 MD 시스템.
- **Phase-2 (GPU)**: 선행 pilot T9+ 파이프라인(tau_ramd_run.py, ramd_force.py) 재사용 →
  force=56, stride=500으로 τ-RAMD; 12화합물 × 5 replica GATE-B → tier separation 판정.
- **GATE-B 기준**: ρ(logDC50, egress) 및 tier-separation. 선행보다 discrimination signal이 개선되는지.

## Out of Scope

- AI 재생성(steered 포즈) — 이 pilot의 핵심 교체 대상.
- 새로운 force/stride 탐색 — 선행에서 확정된 56/500 재사용.
- 전체 143-set, 교차-scaffold 비교.
- S003 이외 화합물.

## Success Criteria

- **Phase-0 PASS**: 12/12 화합물 MCS-aligned 포즈 생성, crystal 포켓 내 충돌 없음.
  검증: `nfr_dock_poses.tsv` (compound·MCS_atoms·clash_check·clash_resolved).
- **Phase-2 GATE-B PASS**: ρ(logDC50, median_egress) 부호가 음수(-) 방향이고 |ρ| > 0.3,
  strong tier median > weak tier median. (선행 ρ=+0.245에서 개선.)
- FAIL = 선행과 동일 null 재현 → τ-RAMD가 이 시스템에 불적합 확정, SPR 권고.

## Resource Budget

- Phase-0: zero-GPU (~30 min compute).
- Phase-1: ~5–10 GPU-hr (12시스템 빌드, 선행 재사용).
- Phase-2: ~30–60 GPU-hr (12화합물 × 5 replica × ~50–200ps, 선행 equil 재사용 가능).

## Approval

- GPU 게이트: Phase-1(시스템 빌드), Phase-2(GATE-B) 각각 execute-plan이 제출 직전 확인.

## Rollback

- 포즈 파일 = /mnt 및 analysis/ dir — 삭제 무해.
- MD 시스템/egress = /mnt 빈 브랜치 — 삭제 무해.
- 코드는 기존 파이프라인 재사용, 신규 파일은 nfr_dock_poses.py 하나.

## Progress Log

- 2026-06-26: 선행 pilot null로 9NFR-docking pivot 결정. 사용자 "진행" 승인. status: approved.
