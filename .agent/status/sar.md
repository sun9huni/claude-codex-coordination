---
owner_session: 55e87e7b-8c84-4033-a289-ae3bd48e4d1f
owner_label: 
owner_agent: claude
version: 2
state: active
last_updated: 2026-06-29
heartbeat: 2026-06-29T10:07:44Z
remaining_actions:
  - "DECISION: C001-C008 신규 후보 합성 우선순위 확정 — C002(+para-Cl aniline)→C005(meta-F)→C006(Et→Pr) 순 권장. SPR 실험 병행 여부 결정 필요."
  - "AGENT: VAV1_101/379(MCS_ONLY) 제외 민감도 분석 — n=10 재계산 시 ρ 변화 확인(zero-GPU, contact_dc50_correlation.py 수정 1줄)."
  - "AGENT: AIG22 89개 화합물 MMP(matched-molecular-pair) 분석 — 73% MCS=21이라 비-MCS SAR 신호 미미, Dmax%·DC50 공변동(ρ=-0.772) 이상 추가 단서 없음. 신호 있으면 보고."
contract_pointers:
  - .agent/contracts/vav1-ubq-rotamer-contact-analysis-20260626.md
---

# SAR — Structure-Activity Relationship analysis for VAV1 molecular-glue degraders

**Scope**: 9NFR crystal 기반 S003 congeneric series + AIG22(89종) SAR 분석.
τ-RAMD null 이후 대안 in-silico 전략으로 rotamer contact → 설계 규칙 도출 → 신규 후보 생성.

## 현황 (2026-06-29)

### 완료된 분석

| 분석 | 데이터 | 결과 |
|---|---|---|
| Rotamer contact vs DC50 | S003 n=12 | ρ=−0.505, p=0.094 **PASS** |
| 비-MCS 원자수 vs DC50 | 143종(S001-S005) | ρ=−0.259, p=0.0018 (유의) |
| Composite log(Dmax/DC50) | 403종(전체) | ρ=+0.194, p=0.0001 (Simpson 역전 주의) |
| AIG22 Dmax%-DC50 공변동 | 89종 | ρ=−0.772 (같은 dose-response curve 산출물, SAR 아님) |
| 신규 후보 설계 | C001-C008 | glue_competence 8/8 PASS |

### 핵심 SAR 결론 (S003 한정)

- MCS core(21원자 = A1BYX 그 자체)에서 벗어난 치환기가 ARG796/TRP820와 추가 접촉 → DC50 악화
- **설계 규칙**: SH3c 방향 비-MCS 원자 최소화 / CRBN 포켓 방향으로만 탐색
- AIG22 73% MCS=21(비-MCS 변동 없음) → 다른 SAR 논리 지배

### 신규 후보 C001-C008

우선순위: **C002**(+para-Cl aniline, 근거 최강) → **C005**(meta-F, SH3c 회피) → **C006**(Et→Pr, 소수성) → C003·C004·C008(미탐색)

## 핵심 산출물

| 파일 | 설명 |
|---|---|
| `analysis/crl_integrative/rotamer_contact_results_20260626.md` | PASS 리포트 |
| `analysis/crl_integrative/steered_regen/contact_scores.tsv` | 화합물별 engagement score |
| `analysis/crl_integrative/steered_regen/contact_dc50_correlation.py` | 상관 분석 |
| `FKSFold-Boltz_Advancement/configs/vav1_pipeline/custom_compounds.csv` | AIG22 89종 |
| `png/sar_design_candidates.html` | C001-C008 시각화 (Artifact) |

## 미결 질문

1. S003 DC50이 SH3c engagement가 아닌 **CRBN binary 친화력** 기반인가? → SPR 필요
2. AIG22 시리즈에는 별도 SAR 논리가 있는가? (scaffold 다양성 → MMP 불가)
3. C001-C008 중 어느 것을 먼저 합성할 것인가? → DECISION 필요
