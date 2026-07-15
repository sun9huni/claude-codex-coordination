# m-relativity 정식화 — Qunova FMO/HI-VQE × committor 엔진 통합 워크플로우·플랫폼 설계

> Status: **approved**
> Slice: `m-relativity` (다른 세션 0ac3a4b2 소유 — contract는 공유 아티팩트, status 파일 미편집)
> Approval: requested 2026-06-11 · approved by: **사용자(sunghoon.kim) 2026-06-11**
> Triggers matched (WORKFLOW §2): **none (설계/제안서 정식화 행위 자체는 코드/SLURM/ranking 트리거 아님)**.
> └ 단, downstream 실계산(W₃/FMO/HI-VQE/QPE)은 각자 별도 compute-approval contract 필요 (선례: `m-relativity-w3-prototype-20260610` approved/DONE).
> Related: `.agent/scratch/m_relativity_proposal_20260609.md` (제안서 전문, Notion 발행), 2026-06-11 회의 전사(Qunova).

## Purpose

국책 제안서(양자이득 실증 × OOD degradation)의 **워크플로우와 플랫폼을 정식 설계**한다.
m-relativity의 committor/W₃ **운명(fate) 엔진** 내러티브와 Qunova의 FMO/HI-VQE
**계면 에너지(energetics) 플랫폼**을 하나의 "AI 후보생성 → 양자화학 채점 → wet 피드백"
하이브리드로 통합하고, RFP의 난제 1/2/3 + QAOA + metal ion 요구를 **전문가 심사를 통과하는
형태로** 매핑한다. 산출물은 *제안서에 그대로 들어갈 설계 문서*(워크플로우 도식 + 난제 매핑 +
검증 설계)이며, 코드 구현이 아니다.

## Current State

- **m-relativity 제안서 전문 존재**(~120K자, 9절+부록 A/B, Notion 발행, 적대적 검증 4회 통과).
  핵심 규약: **R(표현가능성, W₃^FF≡0 무조건) vs Q(양자컴퓨터 필요성 M∧F∧P, 저우선) 절대 분리**,
  "양자가치=표현가능성(속도 아님)". → 본 대화에서 독립 재유도한 **V1/V2와 동치**.
- **W₃ 프로토타입 완료**(`m-relativity-w3-prototype-20260610`): 9NFR glue 계면 3체
  {VAV1 Asp797 / glue A1BYX / CRBN His353}에서 counterpoise DFT(wB97X-V/def2-SVP)
  **W₃=+0.572 kcal/mol**, **W₃^FF≈−5.7e-14≈0** 수치증명(FF 구조적 눈멈 = R 실증). 단 metal 케이스 아님.
- **Qunova 회의(2026-06-11) 입력**: FMO(프래그먼트 QM, ~2–3천 atom, 5–6Å 트렁케이션) +
  FMO의 classical QM 파트를 **HI-VQE로 보강**(6개월+ 데이터), PIEDA 히트맵, ternary
  바이너리 대비 에너지비(협동성). 56큐빗 <2 kcal/mol(top), QPU+RIKEN matrix 72→76큐빗.
- **보유 검증 데이터 = CRBN 일색**: heldout ternary 7개 전부 글루타리미드(CRBN), 합성/assay
  ~130개도 CRBN MGD. **VHL/IAP 구조 데이터 0** (repo 전수 확인).
- **metal-at-interface 스캔 완료(본 세션)**: CRBN zinc = 구조 아연(4-Cys 323/326/391/394),
  글루에서 ~18Å, interface 5–6Å QM region **밖** → "interface metal" 데모로 **부적격**.

## Assumptions And Questions

- 가정: 난제 1/2/3 = (1) 전자구조/계면 에너지 정확도(metal·strong H-bond·π-π·water-bridge),
  (2) 협동성/ternary 랭킹, (3) linker conformation. QAOA는 IN(scoped).
- 2026-06-11 RFP 사실 확정(사용자): 난제1/2/3 = 사용자 제공 텍스트가 **공식 문구**(난제1=전자구조/상호작용
  에너지). QAOA = **"양자최적화 기법 활용"** 수준(특정 구현 강제 아님). metal ion = **RFP 미명시**(선택적 예시).
- 2026-06-11 RFP 성과지표 RESOLVED: B(R²≥0.80/0.85)·양자유용성(①/②)·hit rate2x·lead·SOP·DMTA / 배점 30·30·40.
  데이터 공개범위 RESOLVED: 비공개+SOP 확산(C지표).
- open questions (제출 전제):
  - **R² 정합성 대상 RESOLVED**: 1단계=**VAV1/CRBN**(보유, W₃ 기실증). 2단계=**IDO1**(open-shell heme Fe가 약물형
    저해제에 2.0Å 직접 배위 → **R+Q 동시**, 양자 merit 극대화; PDB 실측 scout 워크플로우 2026-06-11) [+ **HDAC6**=R-only
    헤지, TPD 성숙도 최상]. ❌ **NEK7 폐기**: 저해제 구조에 금속 부재 + closed-shell Mg(R-only) → 양자 서사 빈약
    (증거: `.agent/scratch/m_relativity_metal_demo_scan.md`). ⚠ IDO1 보완: degrader ternary 공개구조 희박(R+Q는 저해제 포켓 근거) + Fe 산화상태/스핀 명시.
  - **1단계/2단계 경계·기간·예산·마감일** 미정. [입력 필요]
  - **주관기관(수요처 AIGEN 권장)·공동(Qunova)·매칭투자(현물/현금)/신규채용** 구성 미정(40% 직결). [결정 필요]
  - **committor(fate) ↔ FMO(energetics) 통합 지점** — 핵심 미해결 설계 과제.
  - (선택) metal 데모 — W₃ 실증이 이미 R(표현가능성) 충족; metal은 추가 예시로만, blocking 아님.
- tradeoffs: 방어력 ↑ 위해 scope를 좁히면 RFP "범용 플랫폼(CRBN+VHL+IAP)" 야망과 충돌 →
  VHL/IAP는 "설계상 확장 가능 + 데이터는 prospective"로 명시 분리.

## Constraints

- allowed change scope: 제안서/설계 문서(markdown), 워크플로우 도식, 난제 매핑표, 검증 프로토콜.
  `.agent/scratch/` 및 m-relativity 제안서 계열 문서.
- forbidden change scope: `src/` 등 프로젝트 소스 코드, SLURM 제출, ranking 의미 변경 — 본 contract 범위 아님.
- external constraints (Q3 하드 제약):
  - **RFP 필수 KPI**: B지표 R²≥0.80(1)/0.85(2) 정합(양자 vs 고전 SOTA) · 양자유용성(탐색≥10배 ① 또는 자원추정 ②)
    ＋ hit rate≥2배 · 실증 lead · DMTA(1→2회) · SOP · 특허(1→2)/JCR10% 논문. 난제1/2/3(공식문구) + "양자최적화 기법 활용".
    *metal ion = RFP 미명시(선택 예시).*
  - **평가 배점**: 문제정의 30%(양자이득 FOM 논리성·실현가능성·검증계획) · 연구역량 30%(수요처 주관 우대) ·
    활용성·사업성 40%(매칭투자 현물+현금/신규채용 우대).
  - **데이터 비공개 OK**: 보안/영업기밀 → 데이터 공개 대신 **SOP로 확산**(C지표). 130 데이터 공개범위 이슈 해소.
  - **Qunova HW/엔진 종속**: 자체 양자HW 없음 — FMO/HI-VQE 엔진 + QPU(IBM/RIKEN) 접근 전제.

## Non-Goals (Q2 — 명시적 OUT, ⚠ 단계 구분)

- 신규 wet 실험·lead 합성은 **1단계 엔진/정합성 작업의 OUT**(1단계=보유 130 CRBN retrospective + 기초 in vitro
  데이터셋). **단 2단계 wet/lead/DMTA·hit rate는 RFP 필수 → 제안서가 그 *계획*을 반드시 기술.** (VHL/IAP는 확장으로만)
- HI-VQE 알고리즘 내부 개선 (Qunova 엔진=given; 큐빗·정확도 경쟁은 Qunova 책임. 우리는 FMO 통합·적용·검증만).
- 엔진이 **절대 ΔG/친화도(K_d·DC50 절댓값)를 *예측*하는 것**은 OUT(엔진 출력=정합성 물리량·ranking·feature).
  *lead의 IC50은 wet 측정값(2단계 산출물)이지 엔진 예측 아님 — 충돌 없음.*
- (경계) 플랫폼 코드 구현 — 본 contract는 *설계 정식화*까지. 구현은 /write-plan→execute 별도.

## Done When (측정 가능 — "심사 방어력" = RFP KPI·평가배점 방어)

**RFP 성과지표 매핑(1·2단계 분리):**
1. **B지표 정합성(필수)**: 양자(HI-VQE/FMO) vs 고전 SOTA(MD/FEP/DFT) **R²≥0.80(1단계)/0.85(2단계)**
   on 동일 TPD 삼원복합체 — **1단계=VAV1/CRBN(보유), 2단계=IDO1(open-shell heme Fe, R+Q) [HDAC6=R-only 헤지]**. 비교
   물리량=전자구조·결합E·삼원복합체E·링커 엔트로피 ΔS. R²+MAE 산출(엔트로피 관점 달성도 포함). ← **정합성=양자≈고전(신뢰성), 우월성 아님.**
2. **양자유용성(필수, ① 또는 ②)**: ① 동일 자원/시간 내 탐색공간 **≥10배**(2단계 ≥100배; diversity=Tanimoto·
   unique scaffold·PCA/t-SNE) **또는** ② **자원추정**(qubit·depth·shot·wall-clock·고전후처리) 스케일링 정량
   **＋ 상위후보 in vitro hit rate ≥2배**(또는 활성도 20%↑ 대체).
3. **실증 lead**: 1단계=정합성용 기초 in vitro 데이터셋 / 2단계=IC50 lead 도출. 비내재화(non-internalizing)
   링커 최적화 프로토콜 포함.
4. **C/D지표**: 양자활용 SOP(1단계 초안→2단계 유형별) · 폐쇄형 DMTA(AI+양자 즉각 통합, 1단계 1회→2단계 2회+추이).
5. **A지표**: 특허(1단계 1건→2단계 누적 2건+) · JCR 상위10% 논문(2단계).

**설계 품질(방어력):**
6. **양자이득 FOM 명시·정당화**(문제정의 30%) — R/Q(≡V1/V2) 분리 유지: 정합성 R²="양자≈고전 SOTA(신뢰성)",
   차별화=R(표현가능성, W₃^FF≈0) + Q(탐색/스케일). "정합성=우월성" 혼동 **0건**.
7. **난제 1/2/3 각각** 4요소(baseline·양자보강·검증지표·한계+fallback) 매핑 + **committor↔FMO 통합 도식** 1장.
8. **활용성·사업성(40%) 반영**: 수요처(AIGEN) 주관 + 사업모델 + 매칭투자/신규채용 요소를 설계에 연결.
9. (게이트) 적대적 리뷰 1회 통과 + RFP 성과지표·평가주안점 체크리스트 **gap 0**.

## Implementation Steps (/write-plan이 분해 — 본 turn에서는 실행 금지)

1. RFP 원문 확보 → 난제 1/2/3 + QAOA + metal ion 요구를 체크리스트로 추출. verify: 체크리스트 항목 = RFP 문장 1:1.
2. metal 데모 케이스 선정(HDAC/IAP PDB 검증) + CRBN 부적격 증거표 확정. verify: 선정 케이스에서 metal이 결합계면 ≤6Å.
3. 난제 1/2/3 4요소 매핑표 작성(R/Q 귀속 명시). verify: 혼동 0건 셀프체크.
4. committor↔FMO 통합 워크플로우 도식 + AI생성+HI-VQE채점 primary / QAOA exploratory 분리. verify: 도식에 QAOA가 primary 경로에 없음.
5. 6개월 retrospective 검증 프로토콜(지표·baseline·margin) 명세. verify: 관찰가능한 합격 margin 정의됨.
6. 적대적 리뷰(/code-review 또는 외부 전문가) + RFP 체크리스트 대조. verify: gap 0.

## Change Discipline

- simplest adequate approach: 기존 m-relativity 제안서에 **Qunova 엔진/난제-매핑/검증설계만 증분 통합** (재작성 금지).
- new abstractions: 난제 1/2/3 4요소 매핑표, committor↔FMO 통합 도식 (신규 문서 구조).
- unrelated code touched: 없음(설계 문서 한정).
- request-to-diff trace: 사용자 "/brainstorm 워크플로우·플랫폼 설계" → 본 contract(설계 정식화 spec).

## Verification

- task-specific: RFP 요구 체크리스트 대조 → gap 0; R/Q 혼동 셀프스캔 0건.
- manual check: 적대적 리뷰 1회(난제별 baseline·한계·fallback 명시 확인).
- (downstream 실계산은 별도 compute-approval contract에서 검증 — 본 contract 범위 외.)

## Risks

- regression risk: 기존 m-relativity 제안서의 R/Q 규약을 통합 과정에서 흐트러뜨릴 위험 → Done When #2로 가드.
- integration risk: committor(kinetics) ↔ FMO(energetics) 통합 도식이 작위적이면 심사에서 "두 과제를 억지로 붙였다"로 읽힘 → Done When #6 + 적대적 리뷰.
- hidden dependency risk: metal 데모·130 데이터 공개범위·마감일 미확정 → open questions 해소 전 제출 불가.

## Rollback

- revert strategy: 설계 문서는 markdown → git revert로 완전 복구. 통합이 방어 불가로 판명 시
  해당 난제를 **fallback framing**(예: QAOA→AI생성+HI-VQE채점만, metal→R-only FMO>FF 데모)으로 후퇴.
- containment strategy: 코드/SLURM/`/mnt/data` 영향 없음 — 격리 불요. 미승인 상태(pending)에서는 제안서 본문 미반영.

## Progress Log

- 2026-06-11: /brainstorm 5문항(성공기준=심사방어력 / OUT 3항 / 하드제약 2항 / 귀속=m-relativity 정식화) → 본 contract 초안. status=pending, 승인 대기.
- 2026-06-11: 사용자 승인 → status=approved. /write-plan으로 분해 진행.
- 2026-06-11: RFP 사실 보정(사용자) — 난제1/2/3 공식문구 확정, QAOA="활용" 수준, metal ion RFP 미명시→선택. Done When #2/#3/#4·Constraints·open-questions 갱신. (success criterion·전체 scope 불변)
- 2026-06-11: RFP 성과지표·평가배점 입수 → Done When 전면 KPI 매핑 재작성(B R²≥0.80/0.85·양자유용성 ①/②·hit rate2x·lead·SOP·DMTA·특허/논문 / 30·30·40). Non-Goals 단계구분(2단계 wet/lead=RFP필수). 데이터=SOP비공개. 신규 open Q: R² 대상시스템(KRAS vs VAV1)·단계경계·주관/매칭.
- 2026-06-11: metal-at-interface scout 워크플로우(5타깃 PDB 실측) → 2단계 **NEK7→IDO1 전환**(잠정, AskUserQuestion 도구 장애로 권고안 진행·되돌림 가능). IDO1 heme Fe 2.0Å 직접배위(R+Q), NEK7=저해제 구조 금속부재+closed-shell Mg로 폐기, HDAC6=R-only 헤지. 증거: `.agent/scratch/m_relativity_metal_demo_scan.md`.
