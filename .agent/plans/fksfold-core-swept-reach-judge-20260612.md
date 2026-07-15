---
contract: .agent/contracts/fksfold-core-swept-reach-judge-20260612.md
slice: fksfold-core
status: approved
approved_by: user (2026-06-12 "이어받아 진행"; contract already approved 2026-06-12 "진행")
total_tasks: 9
estimated_total_min: 47
---

# Plan — swept-reach judge (2-tier: geometric screen → 물리 confirm)

> rigid-M1 ~24Å 바닥 → productive 판정을 2-tier로. **Tier 1**(zero-GPU): M1_swept = (E2~Ub 경첩 sweep
> × SH3 lysine rotamer) 위 min Nζ→E2 Cys 거리 → 게이트(survivors or STOP). **Tier 2**(GPU, survivors만):
> flexible docking/짧은 MD로 near-attack 기하의 에너지적 접근성 confirm → productive 확정.
> envelope = deep-research + cryo-EM 교차검증. anchor = MRT6160 active 정합. surface = swept-volume.
> ⚠️ fksfold-core slice baton 타 세션 점유 → 본 plan/contract가 durable 기록(handoff.sh 미실행).
> **Tier 2(Task 6) SLURM/GPU = Tier 1 게이트 통과 + 사용자 go 전 금지.**

## Phase A — reach envelope 확보 (교차검증, zero-GPU)

## Task 1: deep-research — CRL ubiquitination reach 문헌 수치
- **Status**: done (commit 14b85ae) · **Prereq**: none
- **Result**: reach ≤16Å Nζ→Ub-Cterm (PMC9019245); near-attack 3.3–3.5Å/112–128° (PMC4086935); rotamer Cα→Nζ ~6.5Å (PMC4937519); RING sweep RANGE 미확보. 25 claims 3-vote(17 confirmed/8 killed).
- **Files**: `analysis/productive_pose/reach_envelope_research.md`
- **Change shape**: deep-research 1패스 — CRL/CRL4-CRBN의 E2~Ub 유효 reach 거리, RBX1-Cullin 경첩 각도/호
  범위, productive near-attack 거리(thioester→lysine Nζ), lysine rotamer 도달 반경. 각 수치 출처 명기, 없으면 "미확보".
- **Verification**: `cat reach_envelope_research.md` → 4종 수치+출처(또는 미확보); fabricate 0.
- **Est**: 5 min · **Rollback**: 파일 삭제

## Task 2: cryo-EM 1차원리 envelope (2HYE RBX1 + 6TTU E2~Ub)
- **Status**: done (commit 12252e1) · **Prereq**: none
- **Result**: RING graft gate 0.98Å. lever arm(closest) 14.35Å / Zn proxy 26.51Å; near-attack Cys85 Sγ→Cys20 Sγ 2.01Å(SSBOND), Ub C-term proxy 4.87Å; static angle 56.9°. 미확보: 단일 hinge axis 반경·Gly76 진짜 acyl·회전 sweep RANGE(→문헌).
- **Files**: `analysis/productive_pose/reach_envelope_geom.py`, `reach_envelope_geom.md`
- **Change shape**: 2HYE RBX1 RING + 6TTU E2~Ub thioester(Cys D85) 기하에서 경첩 축 + E2 Cys sweep 호
  반경/각도를 1차원리 산출(gemmi/numpy). 문헌 대조용.
- **Verification**: `python reach_envelope_geom.py` → 경첩 축 + reach 반경(Å) + 호 각도; md 기록.
- **Est**: 5 min · **Rollback**: 삭제

## Task 3: envelope 동결 (교차검증 + freeze)
- **Status**: done (commit 14b85ae) · **Prereq**: 1, 2
- **Result**: 문헌 vs cryo-EM 모든 측정값 일치 + sweep range 양쪽 미확보. FROZEN: R_reach 18Å(graded, M1/Nζ→Sγ 단위), L_rot 6.5Å(HARD), near-attack ≤3.5Å(Tier-2), E2-sweep 미확보→relative-rank. GATE: rotamer-only≤18=hard / +E2sweep≤18=soft / else STOP.
- **Files**: `analysis/productive_pose/reach_envelope.md`
- **Change shape**: 문헌(T1) vs cryo-EM(T2) 대조 → 동결 파라미터(경첩각 범위, E2 sweep 반경, rotamer 반경,
  near-attack 임계). 일치/괴리 명시. soft면 "절대판정 불가→상대 rank" 라벨.
- **Verification**: `cat reach_envelope.md` → 파라미터 + 두 출처 비교 + 채택 근거 + (soft 시) rank 모드 명시.
- **Est**: 4 min · **Rollback**: 삭제

## Phase B — Tier 1 geometric screen + 게이트 (zero-GPU)

## Task 4: swept_reach.py — M1_swept judge (E2 sweep × lysine rotamer)
- **Status**: done (commit ac5aa68) · **Prereq**: 3
- **Result**: 세 nested bound(full≤rotamer≤rigid). rigid_M1 = m1_score 재사용→completed_seed42에서 정확 재현(36.2/36.9/46.6/53.1/64.2). raw-build + 완성-overlay 자동감지 둘 다 동작. **실행 env = /home/ubuntu/miniconda3/envs/pymol/bin/python**(pymol+gemmi+numpy). 게이트 미사용 단일pose 검증만 완료.
- **Files**: `analysis/productive_pose/swept_reach.py`
- **Change shape**: completed overlay 입력 → E2~Ub 촉매 Cys를 RBX1 경첩 arc로 sweep **× SH3-5 lysine
  측쇄 rotamer sweep** → M1_swept = min over (E2 × rotamer) of d(Nζ, E2 Cys) + best + candidate 판정
  (≤ near-attack 또는 rank). **rigid M1 나란히 출력**(E2 고정→sweep 바닥 뚫었나). complete_structure/m1_score 재사용.
- **Verification**: `python swept_reach.py --pose completed_seed42.pdb` → lysine별 M1_swept + best + rigid 대비 + 판정.
- **Est**: 7 min · **Rollback**: 삭제

## Task 5: Tier 1 — 48 pose 전체 채점 + 게이트 + MRT6160 anchor
- **Status**: pending · **Prereq**: 4
- **Files**: `analysis/productive_pose/swept_reach_verdict.md`, `swept_reach.csv`
- **Change shape**: **48 scan pose 전체**(rigid-M1 pre-filter 없음) + unsteered에 swept_reach 적용 →
  M1_swept rank 표. **게이트:** survivors(candidate productive) 목록 또는 "전 pose 미도달→STOP" 판정.
  **MRT6160 anchor:** active degrader인데 survivors=0이면 overlay/방법 red flag로 명시(+ DC50 수치 locating
  시도; 못 찾으면 정성 active 근거).
- **Verification**: `cat swept_reach_verdict.md` → 48 pose rank + survivors(또는 STOP) + anchor 정합 노트.
- **Est**: 5 min · **Rollback**: md+csv 삭제

## Phase C — Tier 2 GPU 물리 confirm (survivors만, GATED)

## Task 6: [★GATE/SLURM] Tier 2 — flexible docking/짧은 MD confirm 제출
- **Status**: pending (★ APPROVAL GATE: sbatch — Task 5 survivors>0 + 사용자 go 후에만)
- **Prereq**: 5
- **Files**: `workflow/slurm_swept_confirm_*.sh`(+prep)
- **Change shape**: Task 5 survivors(몇 후보)에 flexible docking 또는 짧은 MD로 near-attack 기하의
  **에너지적 접근성·populated 여부** 평가(SLURM). survivors=0이면 본 task SKIP(STOP 결론, Task 9로).
- **Verification**: `squeue` 제출 → 완료 후 후보별 MD/docking 출력(near-attack 도달 conformation 빈도/에너지).
- **Est**: prep 5 min(MD wall-clock 별도) · **Rollback**: 출력 디렉토리 삭제

## Task 7: Tier 2 분석 → productive orientation 확정
- **Status**: pending · **Prereq**: 6
- **Files**: `analysis/productive_pose/tier2_confirm.md`
- **Change shape**: Tier 2 결과로 survivors 중 near-attack이 에너지적으로 접근 가능한 것 = **확정 productive
  orientation**(경로 명시). 접근 불가면 "기하 도달하나 에너지 미접근" 결론.
- **Verification**: `cat tier2_confirm.md` → 확정 productive orientation(또는 미접근 결론) + 근거.
- **Est**: 5 min · **Rollback**: 삭제

## Phase D — surface + 종합

## Task 8: 선택 구조 swept-volume surface
- **Status**: pending · **Prereq**: 7
- **Files**: `analysis/productive_pose/swept_volume_surface.py`, `REACHABILITY_SURFACE.md`
- **Change shape**: 확정 구조에서 lysine Nζ→E2 도달 swept-volume(cone/부피) + 도달 fraction + E2-zone overlap.
- **Verification**: `python swept_volume_surface.py --pose <확정>` → 부피 출력 + fraction + overlap; md 요약.
- **Est**: 7 min · **Rollback**: 삭제

## Task 9: 종합 리포트 + plan/contract 마감
- **Status**: pending · **Prereq**: 7, 8
- **Files**: `analysis/productive_pose/SWEPT_REACH_REPORT.md`
- **Change shape**: envelope(출처) + Tier1(rigid 대비) + 게이트 + Tier2 confirm + anchor 정합 + 확정
  orientation + surface 종합. 한계(envelope 가정·overlay 오차·MD 길이) 명시. contract/plan done + handoff.
- **Verification**: `cat SWEPT_REACH_REPORT.md` → 최종 결론(productive orientation 또는 STOP) + 재현 + 한계.
- **Est**: 4 min · **Rollback**: 삭제
