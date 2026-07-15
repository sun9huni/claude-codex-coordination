---
contract: .agent/contracts/fksfold-core-productive-pose-protocol-20260608.md
slice: fksfold-core
status: done
total_tasks: 8
estimated_total_min: 34
---

> **완료 2026-06-09 (catastrophic 분기):** Task 1–5 done, Task 6–7 SKIP(catastrophic), Task 8 done.
> 판정 = 🔴 CATASTROPHIC (distal lysine 변위 41Å@50° ≫ tol 15Å). 병목 = SH3 docking 정확도.
> 결과: `analysis/productive_pose/PHASE0_RESULTS.md`. committor(Phase 1, 다른 agent)는 docking 조인 뒤로.

# Plan — M-RELATIVITY **Phase 0** 전처리·진단 (재작성 2026-06-09)

> **범위: Phase 0만.** overlay 복원 + lever-arm 민감도 진단 + 9NFR/mrt23227 보정. committor·양자·생성·
> surface = **다른 agent / Phase 1+ → 미접촉.** static k_ubq = proxy floor(답 아님).
> 순서는 **lever-arm 게이트(Task 5)에 최단·최저비용으로 도달**하도록 짬 — 그게 Phase 1 진입 여부를 가름.
> HARD: 다른 agent의 양자/committor 미접촉 · 측정 전 기준 동결 · production 미변경.

## Task 1: k_ubq 아티팩트 인벤토리 (중복 방지)

- **Status**: done
- 결과: k_ubq 산출물 전무(fresh build), 구조 reference 다운로드 가능. → `inventory_kubq_reuse.md`

## Task 2: Spec freeze — Phase 0판 (overlay 기준 + lever-arm 정의 + 판정 임계)

- **Status**: pending (초안 있음 — Phase 0으로 갱신 + 사용자 확정: 판정 임계)
- **Prereq tasks**: 1
- **Files touched**: `.agent/scratch/productive_pose/PREREGISTRATION.md`
- **Change shape**: Phase 0로 재작성 — overlay 정합 기준(SH3 Cα / CRBN+DDB1 Cα, RMSD<2Å), lever-arm
  측정 정의(docking Δθ당 lysine 변위 증폭계수), **tractable/catastrophic 임계 동결**, 화합물 정정
  (앵커=mrt23227/A1BYX, sample=MRT6160). committor·양자·DC50·생성 전부 제거.
- **Verification**: `grep -c TBD PREREGISTRATION.md` → 0; Phase 0 항목만 존재(committor/양자 없음)
- **Estimated time**: 4 min · **Rollback**: 파일 삭제

## Task 3: full-length VAV1 모델 확보 (lever-arm 최소 의존)

- **Status**: pending
- **Prereq tasks**: 2
- **Files touched**: `analysis/productive_pose/refs/AF-P15498-F1.pdb`, `refs/README.md`
- **Change shape**: AlphaFold DB AF-P15498-F1(full-length VAV1) 다운로드, chain/노출 lysine/도메인 경계 +
  inter-domain PAE 신뢰도 기록. (lever-arm 진단엔 VAV1만 먼저 필요 — CRL/E2는 Task 6.)
- **Verification**: `ls refs/AF-P15498-F1.pdb` 존재; README에 노출 lysine 수 + SH3 도메인 resid 범위
- **Estimated time**: 4 min · **Rollback**: 파일 삭제

## Task 4: full-length VAV1 → pose SH3 overlay 스크립트 + 1-pose smoke

- **Status**: pending
- **Prereq tasks**: 3
- **Files touched**: `analysis/productive_pose/complete_structure.py`
- **Change shape**: pose의 SH3(또는 9NFR 앵커)에 full-length VAV1 SH3를 Cα superpose → distal lysine 전부
  CRBN 좌표계로 복원 + 정합 RMSD 로그.
- **Verification**: `python complete_structure.py --pose <one>` → 완성 VAV1+CRBN PDB + SH3 RMSD<2Å
- **Estimated time**: 5 min · **Rollback**: 스크립트 삭제

## Task 5: ★ lever-arm 민감도 진단 [GATE]

- **Status**: pending
- **Prereq tasks**: 4
- **Files touched**: `analysis/productive_pose/lever_arm_sensitivity.py`, `LEVER_ARM_RESULTS.md`
- **Change shape**: 9NFR/mrt23227 앵커 기준 SH3 docking을 Δθ(예 0–120°)로 교란하며 **각 lysine Nζ 변위**를
  측정 → 증폭계수(Å/deg) + 우리 docking 불확실성(102–151° spread)에서의 변위 범위. **동결 임계로
  tractable/catastrophic 판정.** (E2 없이 VAV1 lever만으로 1차 증폭 수치.)
- **Verification**: `python lever_arm_sensitivity.py` → Δθ-변위 곡선 + 증폭계수 + **tractable/catastrophic**
- **Estimated time**: 5 min · **Rollback**: 산출물 삭제

## Task 6: CRL4A–RBX1–E2~Ub 다운로드 + full overlay (tractable 시)

- **Status**: pending
- **Prereq tasks**: 5
- **Files touched**: `refs/3LRQ.pdb`, `refs/<E2Ub>.pdb`, `complete_structure.py`(CRL 추가)
- **Change shape**: Task 5가 tractable면 — PDB 3LRQ + E2\~Ub frame 다운로드, CRL을 pose CRBN(+DDB1)에
  superpose해 **acceptor(E2 Cys) 기하 복원**. catastrophic면 이 task SKIP하고 Task 8로(docking이 병목).
- **Verification**: `ls refs/3LRQ.pdb refs/<E2Ub>.pdb`; 완성 assembly에 E2 Cys 좌표 존재
- **Estimated time**: 5 min · **Rollback**: refs/CRL 파일 + 변경 revert

## Task 7: 9NFR/mrt23227 보정 NULL band + static k_ubq proxy floor

- **Status**: pending
- **Prereq tasks**: 6
- **Files touched**: `analysis/productive_pose/kubq_proxy.py`, `pose_scores.csv`
- **Change shape**: mrt23227 crystal pose에 overlay+static k_ubq(거리×각×SASA) 적용 → in-distribution
  기준선(NULL band). 기존 MRT6160 pose에도 적용. **결과는 "committor coarse proxy"로 명시 라벨.**
- **Verification**: `python kubq_proxy.py && head pose_scores.csv` → crystal 기준선 + pose별 proxy값
- **Estimated time**: 4 min · **Rollback**: 스크립트+CSV 삭제

## Task 8: Phase 0 리포트 + [GATE] Phase 1 핸드오프 / docking 회귀

- **Status**: pending
- **Prereq tasks**: 5, 7
- **Files touched**: `analysis/productive_pose/PHASE0_RESULTS.md`
- **Change shape**: overlay + lever-arm 판정 + 보정 NULL band + proxy floor 종합. **tractable → Phase 1
  (다른 agent committor)에 넘길 입력 패키지 + 핸드오프 노트** / **catastrophic → "docking 정확도가 병목,
  committor 전에 placement부터" 결론** 문서화. (양자/committor 자체는 미수행.)
- **Verification**: `cat PHASE0_RESULTS.md` → 판정 + 다른 agent로의 핸드오프(또는 docking-병목 결론)
- **Estimated time**: 3 min · **Rollback**: 산출물 삭제

---

## Phase 1+ (이 plan 범위 밖 — 다른 agent / 후속)

committor q_NAC(MD 이완→비순환 클러스터→string TS) · 거리자 g=D⁻¹ · kinetics(Da, τ_res) · R(W₃)/Q(QPE)
양자 tier · 방향-bias 2차 생성 · surface 산출물 · active/inactive 통계 검증. **전부 미접촉.**
