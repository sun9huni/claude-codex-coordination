---
status: approved
slice: vav1-ubq
topic: rotamer-contact-analysis
date: 2026-06-26
approved_by: user (2026-06-26, "승인")
requested: 2026-06-26
triggers_matched:
  - "4+ files (rotamer generator + minimizer + scorer + report)"
references:
  - analysis/crl_integrative/steered_regen/nfr_dock_poses.py (MCS-aligned poses)
  - analysis/crl_integrative/steered_regen_residence_pilot_results_20260626.md (τ-RAMD null)
---

# Rotamer Optimization + SH3c Contact Analysis — S003 vs DC50

## Purpose

τ-RAMD null의 근본 원인 확정: MCS-aligned 포즈에서 비-MCS 치환기가 ARG796/TRP820과
물리적 clash(1.2-2.5Å)를 형성. 이 치환기들이 **rotamer 최적화 후 productive contact**을
만드는지, 아니면 원천적으로 이 계면과 맞지 않는지 판정. productive contact 수/에너지가
DC50과 상관하면 → 구조 기반 SAR 단서. null이면 → S003 DC50은 CRBN binary 친화력 기반.

## Success Criteria (사전 등록)

- **방향**: ρ(logDC50, SH3c_engagement_energy) < 0 (강 compound = 더 좋은 SH3c contact)
- **크기**: |ρ| > 0.3 (τ-RAMD ρ=+0.245 대비 개선 필요)
- **PASS**: 위 두 조건 + p < 0.1 (n=12, 단측 검정)
- **FAIL**: null 또는 inverted → S003 DC50이 SH3c 계면 안정성과 무관 확정

## Confirmed Design Decisions

1. **단백질 유연성**: ARG796/TRP820/D797/S799 sidechain만 이완; 나머지 rigid
2. **Rotamer 샘플링**: RDKit ETKDG constrained (MCS 고정, 비-MCS 50-200 컨포머)
3. **Productive contact 정의**: 비-MCS 원자 ↔ ARG796+TRP820 거리 2.5-4.0Å (clash <2.5Å 제외)
4. **Clash 해소**: rotamer sweep → clash-free 선택 → OpenMM CPU minimization (MCS restraint k=1000 kJ/mol/nm²)
5. **Scoring**: OpenMM MM interaction energy (non-MCS group ↔ ARG796+TRP820)

## Scope

12 S003 compounds (9NFR MCS-aligned 포즈 기반). ZERO-GPU, CPU only.

## Out of Scope

글루 전체 CRBN 결합 에너지 변경, 전체 MD, GPU 생성/RAMD 추가 실험.

## Rollback

분석 스크립트 + tsv/보고서만 → rm 무해.
