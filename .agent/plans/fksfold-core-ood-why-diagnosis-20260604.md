---
contract: .agent/contracts/fksfold-core-ood-why-diagnosis-20260604.md
slice: fksfold-core
status: done
total_tasks: 5
estimated_total_min: 18
---

# Plan: OOD WHY 진단 (Track A, zero-GPU)

작업 디렉토리: `FKSFold-Boltz_Advancement/analysis/heldout_placement_20260601/ood_rescue_20260602/`

---

## Task 1: H1 — 9DUR PROTAC 거리 측정

- **Status**: done
- **Prereq tasks**: none
- **Files touched**:
  `analysis/heldout_placement_20260601/ood_rescue_20260602/why_h1_protac_distance.py`
- **Change shape**:
  신규 스크립트. 9DUR/9DWW/9OS2/9NFQ CIF를 읽어 CRBN chain과 target chain의
  center-of-mass 간 거리(Å)를 출력. 9DUR는 PROTAC linker가 두 포켓을 물리적으로
  분리시켜 거리가 MGD보다 크다는 H1을 수치로 검증. 추가로
  `ood_rescue_dockq.tsv`에서 9DUR nativeAB median < baseline 확인 한 줄 출력.
  BioPython `MMCIFParser` 사용 (verify_heldout_anchor.py 패턴 재사용).
- **Verification**:
  `python3 why_h1_protac_distance.py`
  → CRBN–target CoM distance 테이블 + `9DUR nativeAB < baseline: True/False` 출력
- **Estimated time**: 4 min
- **Rollback**: 파일 삭제

---

## Task 2: H2 — Pocket 잔기 노출도 분석

- **Status**: done
- **Prereq tasks**: none
- **Files touched**:
  `analysis/heldout_placement_20260601/ood_rescue_20260602/why_h2_pocket_burial.py`
- **Change shape**:
  신규 스크립트. 9DWW / 9OS2 / 9NFQ nativeAB YAML에서 pocket_contacts 잔기를
  읽어 CIF에서 해당 잔기 Cα 좌표를 추출. 각 잔기의 "이웃 Cα 수" (8Å 반경,
  같은 chain 내)를 계산 → 많을수록 buried, 적을수록 surface-exposed.
  타깃별 평균 이웃 수 + 표준편차 출력 (proxy: PDE6D shallow pocket → 낮음,
  NEK7 kinase cleft → 높음).
  chain 매핑: YAML chain B → CIF에서 서열 길이 매칭으로 자동 식별.
- **Verification**:
  `python3 why_h2_pocket_burial.py`
  → 타깃별 `mean_neighbors(pocket_residues)` 테이블 출력
- **Estimated time**: 5 min
- **Rollback**: 파일 삭제

---

## Task 3: H3 — 9OS2 chain architecture 감사

- **Status**: done
- **Prereq tasks**: none
- **Files touched**:
  `analysis/heldout_placement_20260601/ood_rescue_20260602/why_h3_9os2_chains.py`
- **Change shape**:
  신규 스크립트 (짧음). 9OS2 CIF에서 chain 별 길이·엔티티 타입 출력.
  9OS2 YAML의 chain A/B/C 서열 길이와 대조하여 누락 chain(790aa, 124aa × 2)이
  generation input에 포함됐는지 확인. CIF chain D(124aa)가 chain C(124aa)와
  동일 서열인지 비교(중복 여부). GT에 extra chain이 있으면 partial rescue의
  구조적 이유로 기록.
- **Verification**:
  `python3 why_h3_9os2_chains.py`
  → `YAML_chains vs CIF_chains` 비교표 + `extra_chain_in_GT: yes/no` 한 줄
- **Estimated time**: 3 min
- **Rollback**: 파일 삭제

---

## Task 4: H4 — CRBN anchor 품질 (OOD 5 타깃 전수)

- **Status**: done
- **Prereq tasks**: none
- **Files touched**:
  `analysis/heldout_placement_20260601/ood_rescue_20260602/why_h4_anchor_quality.py`
- **Change shape**:
  `verify_heldout_anchor.py`는 9NYR/9NGT/9NFQ/9OS2 4개 대상. 신규 스크립트는
  OOD 5타깃(9NFQ/9OS2/9DWW/9DUR + 9W2F 참고)으로 확장. 각 타깃에서
  W400 재유도 결과(anchor residue index, CIF 잔기 문자)를 출력하고
  CRBN pocket_residues 중 몇 개가 각 CIF에서 성공적으로 매핑됐는지 수 출력.
  매핑 수가 rescue rate와 상관하는지 표로 정리.
  `_parse_heldout.py`의 `CRBN_Q96SW2` + `THREE2ONE` 재사용.
- **Verification**:
  `python3 why_h4_anchor_quality.py`
  → 타깃별 `w400_pos | mapped_pocket_count | rescue_rate` 테이블
- **Estimated time**: 3 min
- **Rollback**: 파일 삭제

---

## Task 5: WHY_ANALYSIS.md 종합 보고서

- **Status**: done
- **Prereq tasks**: 1, 2, 3, 4
- **Files touched**:
  `analysis/heldout_placement_20260601/ood_rescue_20260602/WHY_ANALYSIS.md`
- **Change shape**:
  Tasks 1-4 출력 수치를 인용하여 마크다운 보고서 작성:
  - §1 데이터 요약 (120-cell DockQ 표)
  - §2 가설 판정표: H1~H4 각각 `CONFIRMED / REFUTED / INCONCLUSIVE` + 근거 수치
  - §3 타깃별 분류: 9DUR(PROTAC out-of-scope) / 9DWW(강 구제) / 9OS2(partial) / 9NFQ(미구제)
  - §4 Track B 권고: "9OS2를 우선 타깃으로, [파라미터 방향] 시도" 또는 Kill
  검증 커맨드용 키워드(`CONFIRMED`, `REFUTED`, `INCONCLUSIVE`) 반드시 포함.
- **Verification**:
  `grep -cE 'CONFIRMED|REFUTED|INCONCLUSIVE' analysis/heldout_placement_20260601/ood_rescue_20260602/WHY_ANALYSIS.md`
  → `4` (H1~H4 각 1회 이상)
- **Estimated time**: 3 min
- **Rollback**: git checkout -- 해당 파일 (또는 파일 삭제)
