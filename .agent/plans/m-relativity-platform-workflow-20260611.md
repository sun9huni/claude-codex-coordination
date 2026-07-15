---
contract: .agent/contracts/m-relativity-platform-workflow-20260611.md
slice: m-relativity
status: in-progress
total_tasks: 13
estimated_total_min: 57
---

# Plan — m-relativity 정식화 (Qunova FMO/HI-VQE × committor 통합 설계)

산출물 = 제안서에 들어갈 **설계 문서**(난제1/2/3 매핑 + 통합 워크플로우 도식 + 검증 설계).
작업 문서: `.agent/scratch/m_relativity_qunova_platform_design_20260611.md`
기존 제안서: `.agent/scratch/m_relativity_proposal_20260609.md`
주의: m-relativity status 파일은 **다른 세션(0ac3a4b2) 소유** → 직접 편집 금지(Task 13 통지로 대체).

## 실행 현황 (2026-06-11, status=in-progress)

- ✅ **DONE**: Task 1(RFP 체크리스트) · 2·3(metal scout: NEK7→IDO1) · 4·5·6·7·8(핵심 설계문서 `m_relativity_qunova_platform_design_20260611.md`) · 10·11·12(적대적 검증 게이트 — REQUEST_CHANGES 1회 → 7개 결함 수정 → 통과).
- ✅ **DONE**: Task 9(제안서 병합) — §2.6 브리지 + §7.3 [표 3b] crosswalk augment. 기존 thesis 보존, IDO1=likely Q-PASS로 강화.
- ✅ **DONE**: Task 14(KPI 매핑=§7.3 [표 3b])·15(양자이득 FOM=§2.6d). 병합 review 반영(physics 정렬 + IDO1 2-타깃 사전등록).
- ⛔ **BLOCKED(결정권자)**: Task 16(사업성 40%) — 주관/공동기관·PI·실예산·인력·매칭투자 = 결정권자 입력 대기(사용자 패스). 임의작성 금지.
- ⛔ **NEXT**: Task 13(handoff) — 스냅샷·커밋·owner 세션 통지. (Task 16 제외 모두 완료 → 지금 가능)
- 커밋: home-repo 브랜치 모호 + "요청 시 커밋" 규칙상 **/handoff까지 보류**(아티팩트는 /home/ubuntu/.agent에 on-disk).

---

## Phase A — 입력·증거

## Task 1: RFP 요구 체크리스트 추출 — ✅ DONE

- **Status**: done  (37행, `/home/ubuntu/.agent/scratch/m_relativity_rfp_checklist_20260611.md`; metal=선택·QAOA="활용" 표기, 충족위치 TBD)
- **Prereq tasks**: none  (난제1/2/3 공식문구·QAOA='활용'은 사용자 확정 보유. ⚠ external: 성과지표/정량목표·평가배점·마감일은 RFP에서 추가 필요 — 없으면 placeholder)
- **Files touched**: `.agent/scratch/m_relativity_rfp_checklist_20260611.md`
- **Change shape**: 확정된 난제1/2/3(공식문구) + "양자최적화 기법 활용" + (RFP 입수 시)성과지표/배점을 항목별 1:1 체크리스트로. metal ion은 미명시이므로 '선택 차별화'로만 표기. 각 행 = [요구 출처 | 요구 유형 | 충족 위치].
- **Verification**: 체크리스트에 난제1/2/3 + '양자최적화 활용' 행 존재; metal은 '선택'으로 분류; 각 행 충족위치 컬럼 존재.
- **Estimated time**: 5 min
- **Rollback (if this task only)**: `rm .agent/scratch/m_relativity_rfp_checklist_20260611.md`

## Task 2: 금속 interface 검증 (2단계 타깃 선정) — ✅ DONE (de-risk 워크플로우 2026-06-11)

- **Status**: done  (scout 워크플로우 5타깃 PDB 실측; 도구=`/tmp/scout_metal.py`)
- **Files touched**: `.agent/scratch/m_relativity_metal_demo_scan.md`
- **결과**: NEK7=저해제 구조 금속부재+closed-shell Mg → **폐기**. **IDO1=heme Fe 2.0Å 직접배위(R+Q) → 2단계 메인 권고**. HDAC6=Zn 1.87Å(R-only) 헤지. FTO/ALKBH5=open-shell Fe(R+Q)이나 degrader 성숙도↓.
- **Verification**: ✅ 5타깃 metal–ligand 거리·전자티어 표 = `m_relativity_metal_demo_scan.md`.

## Task 3: 증거표 확정 (CRBN 구조아연 부적격 vs IDO1 금속 적격) — ✅ DONE (Task 2에 통합)

- **Status**: done
- **Files touched**: `.agent/scratch/m_relativity_metal_demo_scan.md`
- **결과**: 대조표 기록됨 — CRBN 구조아연 글루서 **~18Å(부적격)** vs IDO1 heme Fe 저해제서 **2.0Å(적격, R+Q)**.
- **Verification**: ✅ `.md` "대조" 표 존재.
- **Estimated time**: 3 min
- **Rollback (if this task only)**: git/편집 단위로 append 블록 제거.

---

## Phase B — 핵심 설계 (작업 문서, 같은 파일 → 순차)

## Task 4: 난제1 매핑 (전자구조/상호작용 에너지)

- **Status**: pending
- **Prereq tasks**: none  (metal Task와 무관 — W₃ 실증을 FMO>FF 근거로 사용)
- **Files touched**: `.agent/scratch/m_relativity_qunova_platform_design_20260611.md`
- **Change shape**: 난제1 섹션 — (i) baseline=MM-GBSA/force field, (ii) 양자보강=FMO + interface fragment HI-VQE, (iii) 검증=degradation ROC-AUC, (iv) 한계+fallback. **R(FMO>FF) 귀속**. FMO>FF 근거 = m-relativity **W₃ 3체 실증** + force-field-weak 상호작용(강 H-bond·π-π·water-bridge·charge-charge PPI); metal은 선택 예시.
- **Verification**: 섹션에 4요소 + "R" 태그 + W₃/force-field-weak 근거 인용 + "Q"(양자컴퓨터 필요) 미혼입(grep).
- **Estimated time**: 5 min
- **Rollback (if this task only)**: 해당 섹션 삭제.

## Task 5: 난제2 매핑 (협동성/ternary 랭킹)

- **Status**: pending
- **Prereq tasks**: 4  (같은 파일)
- **Files touched**: `.agent/scratch/m_relativity_qunova_platform_design_20260611.md`
- **Change shape**: 난제2 섹션 — baseline=interaction-count heuristic, 양자보강=AI N후보 생성 → FMO/HI-VQE 에너지 채점 → 재랭킹. **RFP="양자최적화 기법 활용" 수준 확정** → 이 파이프라인으로 '활용' 충족; QAOA는 mention+exploratory(조합 하위문제). 검증=ternary A/B 판별 + degradation correlation, 한계+fallback.
- **Verification**: 섹션에 "AI생성+HI-VQE채점=primary path(=양자최적화 활용)" + "QAOA=exploratory" 문구 존재(grep).
- **Estimated time**: 5 min
- **Rollback (if this task only)**: 해당 섹션 삭제.

## Task 6: 난제3 매핑 (linker conformation)

- **Status**: pending
- **Prereq tasks**: 5  (같은 파일)
- **Files touched**: `.agent/scratch/m_relativity_qunova_platform_design_20260611.md`
- **Change shape**: 난제3 섹션 — baseline=MD/FEP 샘플링 한계, 접근=classical sampling + quantum-informed scoring("흔들림 큰/접근불가 후보 선별"로 문제 좁힘), **entropy=classical 명시**, 검증, fallback.
- **Verification**: 섹션에 4요소 + "entropy는 classical 처리" 명시(grep).
- **Estimated time**: 4 min
- **Rollback (if this task only)**: 해당 섹션 삭제.

## Task 7: committor(fate) ↔ FMO(energetics) 통합 도식

- **Status**: pending
- **Prereq tasks**: 6  (같은 파일)
- **Files touched**: `.agent/scratch/m_relativity_qunova_platform_design_20260611.md`
- **Change shape**: 통합 섹션 — AI 후보생성 → [FMO/HI-VQE 계면 에너지 ⊕ committor q(x) 운명장] → 통합 스코어 → wet 피드백 루프. mermaid 또는 ascii 도식 1장 + 결합지점(energetics↔kinetics) 설명.
- **Verification**: 도식에 committor·FMO 결합 노드 존재 + QAOA가 primary 경로에 **없음**.
- **Estimated time**: 5 min
- **Rollback (if this task only)**: 해당 섹션 삭제.

## Task 8: 검증 프로토콜 (RFP KPI 정렬)

- **Status**: pending
- **Prereq tasks**: 7  (같은 파일)  (⚠ external: R² 대상시스템 결정 + 130 데이터 라벨)
- **Files touched**: `.agent/scratch/m_relativity_qunova_platform_design_20260611.md`
- **Change shape**: 검증 섹션을 RFP 필수 KPI에 직접 매핑 — (a) **B 정합성**: 양자 vs 고전 SOTA(DFT/FEP/MD) **R²≥0.80(1)/0.85(2)** + MAE, 대상=난치성 삼원복합체(KRAS 또는 VAV1/CRBN, 결정대기), 물리량=전자구조·결합E·삼원E·링커ΔS; (b) **양자유용성** ① 탐색≥10배(Tanimoto·scaffold·PCA/t-SNE) 또는 ② 자원추정(qubit·depth·shot·wall-clock) ＋ **hit rate≥2배**(또는 활성도20%↑); (c) 1·2단계 합격 margin 명시.
- **Verification**: 섹션에 R²≥0.80/0.85·양자유용성 ①or② 기준·hit rate 2x가 1·2단계로 명시.
- **Estimated time**: 5 min
- **Rollback (if this task only)**: 해당 섹션 삭제.

---

## Phase C — 통합

## Task 9: 기존 m-relativity 제안서에 증분 통합 — ✅ DONE

- **Status**: done  (사용자 go. 안전 병합 = augment: §2.6 브리지 신설[난제 매핑·FMO/HI-VQE 엔진·2-타깃 Q배터리·성과지표 layer] + §7.3 [표 3b] RFP KPI crosswalk. 라인 1780→1816, 기존 committor/W₃/Q-NULL thesis 보존. 2단계 IDO1=likely Q-PASS로 thesis 강화. 사업성/FOM 상세는 Task 14·15·16 결정 대기.)
- **Prereq tasks**: 8
- **Files touched**: `.agent/scratch/m_relativity_proposal_20260609.md`
- **Change shape**: Task4–8 섹션을 기존 제안서에 증분 삽입(재작성 금지). R/Q 규약·tier 비혼동 유지하며 Qunova 엔진/난제 매핑/통합 도식/검증 설계 추가.
- **Verification**: 제안서 diff에 난제 매핑·통합 도식·검증 섹션 추가됨 + Task 11 통과(R/Q 보존).
- **Estimated time**: 5 min
- **Rollback (if this task only)**: `git checkout -- .agent/scratch/m_relativity_proposal_20260609.md` (또는 삽입 블록 제거).

---

## Phase D — 검증 (Tests)

## Task 10: RFP 체크리스트 대조 (gap 0)

- **Status**: pending
- **Prereq tasks**: 1, 9
- **Files touched**: `.agent/scratch/m_relativity_rfp_checklist_20260611.md`
- **Change shape**: 통합 문서 vs Task1 체크리스트 — 각 요구 항목의 "충족 위치" 컬럼을 실제 섹션으로 채우고 gap 식별.
- **Verification**: 체크리스트의 모든 행 "충족 위치" 채워짐 = **gap 0**.
- **Estimated time**: 3 min
- **Rollback (if this task only)**: 충족 위치 컬럼 비우기.

## Task 11: R/Q(≡V1/V2) 혼동 셀프스캔

- **Status**: pending
- **Prereq tasks**: 9
- **Files touched**: (검토만 — 결과를 design doc 말미에 기록)
- **Change shape**: 통합 문서에서 "metal이니까 양자컴퓨터/속도" 류 혼동 문장 grep+리뷰. 발견 시 R(표현가능성)/Q(강상관·스케일)로 재귀속.
- **Verification**: 혼동 문장 **0건** (스캔 로그를 design doc 말미에 기록).
- **Estimated time**: 2 min
- **Rollback (if this task only)**: 재귀속 편집 revert.

## Task 12: 적대적 리뷰 1회

- **Status**: pending
- **Prereq tasks**: 10, 11
- **Files touched**: `.agent/scratch/m_relativity_qunova_platform_design_20260611.md` (리뷰 반영)
- **Change shape**: /code-review 또는 외부 전문가 렌즈로 난제별 (baseline·한계·fallback) 방어력 검토; 약한 지점 보강.
- **Verification**: 리뷰 verdict + 지적사항 반영 기록이 문서에 존재.
- **Estimated time**: 5 min
- **Rollback (if this task only)**: 반영 편집 revert.

---

## Phase E — handoff

## Task 13: contract Progress Log + owner 세션 통지

- **Status**: pending
- **Prereq tasks**: 12
- **Files touched**: `.agent/contracts/m-relativity-platform-workflow-20260611.md`
- **Change shape**: contract Progress Log에 완료 기록. m-relativity status는 **다른 세션 소유라 직접 편집 금지** → owner 세션에 전달할 통지 메모를 Progress Log에 남김.
- **Verification**: contract Progress Log에 "정식화 완료 + 통지" 항목 존재.
- **Estimated time**: 2 min
- **Rollback (if this task only)**: Progress Log 항목 제거.

---

## Task 14·15·16 현황 (2026-06-11)

- ✅ **Task 14 (KPI 1·2단계 매핑표)**: DONE — 제안서 **§7.3 [표 3b]** RFP 공식 성과지표 crosswalk + `m_relativity_rfp_checklist_20260611.md`로 충족.
- ✅ **Task 15 (양자이득 FOM 정의)**: DONE — 제안서 **§2.6(d)** FOM = [R: W₃^FF≈0 표현불능량] + [Q: open-shell 강상관 HI-VQE vs 단일참조 DFT 오차], 정합성/탐색배수/hit rate로 환산. R/Q 기반.
- ⛔ **Task 16 (활용성·사업성 40% 섹션)**: BLOCKED — **결정권자(사용자 아님) 입력 대기**. 필요값 = 주관/공동기관 정식명·총괄 PI·실예산·인력 M/M·매칭투자(현물+현금)/신규채용 (= m-relativity status의 기존 §9 `[입력 필요]` 항목과 동일). 임의 작성 금지. §2.6(d)·§7.1·§8에 포인터만 존재.

병합 결과 review 반영(2026-06-11): §2.6(b) committor↔FMO를 physics 인자화(q_total)에 정렬(반-보간 thesis 일관) + §6.6에 IDO1 2-타깃 Q-gate 사전등록 추가(BAc2 likely-NULL ⊕ IDO1 likely-PASS, 반증조건 동결). 설계문서 §5도 동일 정렬.
