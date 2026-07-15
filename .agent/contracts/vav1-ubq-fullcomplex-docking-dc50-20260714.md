---
slice: vav1-ubq
cross_slice: [sar]
status: done
requested: 2026-07-14
approved_by: user 2026-07-14
---

# VAV1 full-complex Glide docking-score vs DC50 (논문 658527 프로토콜, receptor 교체)

## Purpose

논문 658527 Fig 4B/4D가 IKZF3에서 보인 것 — full ubiquitylation 복합체에 IMiD를 Glide docking한 점수가 분해 효능과 강상관(R²=0.74) 하나 ternary(8D7Z)는 실패(R²=0.30, r=−0.55) — 을 VAV1로 전이 검증한다. 논문 프로토콜(plain Glide SP, 글루-중심 grid, docking score vs log-potency)은 그대로 두고 receptor만 우리 VAV1 baseline으로 교체하고 GDI-side를 VAV1용으로 재정의한다. 목적은 "full-complex docking이 VAV1 DC50을 예측하나(ternary가 못 하던 것)"의 판정이다.

## Current State

- receptor 확정: `.agent/scratch/ikzf3_gt/dock/vav1_fullcx_nativepose_declashed_full.pdb` (commit 87a4f26d) — 9NFR native pose(K804 Nζ→Ub 12.1Å 최근접) + strong-backbone-restrained OpenMM min으로 clash 제거, full 9-chain(C/D/N/U/R/B/A/V/G) heavy-atom clash-free.
- 논문 방법 교차검증 완료: Maestro 14.1 + Glide SP + 글루-중심 grid + docking score, constraint/IFD 없음(plain). 상관 R²0.74/r0.85/ρ0.91(Fig4B), ternary R²0.30(Fig4C).
- grid 기하 실측: 글루(A1B, chain G) centroid = (133.18, 93.86, 153.25). TBD(W400/W386/W380/H353) 5-8Å, CRBN Lon(H103 19.5/F102 15.1/F150 17.5Å center) — Lon이 TBD-only 글루서 15-20Å 밖.
- 이전 arc: ternary docking + coord-GD reaching = null(structure↔DC50 무상관). full-complex 계면이 full-complex-only라 ternary가 못 봄이 근본 원인(results_vav1_fullcomplex_gdi.md).
- Maestro(Schrödinger)는 유저 로컬(이 환경엔 라이선스 없음). 우리는 receptor/grid/compound 준비 + 상관분석 담당.

## Assumptions And Questions

- assumptions: same-source/same-assay DC50가 존재한다(strict bar 성립 전제); baseline pose가 productive VAV1 배열의 합리적 근사다(GT 없음).
- open questions: VAV1 congeneric series가 Lon-reach 다양성이 있나(없으면 GScore flat 예상); 어느 배치가 단일-실험 DC50인가(Task 1서 확정).
- tradeoffs: strict R²>0.7은 single-assay 데이터에서만 공정; 데이터 pooling하면 cross-assay 노이즈로 bar 미달해도 방법 유효할 수 있음.

## Constraints

- allowed change scope: `.agent/scratch/` (receptor/grid/compound prep, correlation 스크립트, results 문서). zero-GPU.
- forbidden change scope: 엔진/api 코드 수정 금지(read-only); host tree 미변경; 새 GPU/SLURM 잡 없음(내 몫). glue 설계 루프·full-length VAV1 모델링은 별도 계약.
- external constraints: **DC50는 same-source/same-experiment(단일 assay)만 사용**(유저 요구, strict bar 전제). receptor = 확정 baseline 파일 고정. Glide는 **plain SP unconstrained**(논문 그대로, constraint/IFD 금지 — 재현 조건). Maestro docking은 유저 실행.

## Non-Goals

- Lon-reaching VAV1 글루 신규 설계(별도 계약).
- full-length VAV1 인접도메인 ZF3-analog 모델링(별도).
- IKZF3 GDI 판별자(이미 done, results_vav1_fullcomplex_gdi.md).
- dynamics(MD/WTMetaD) 재측정 — 이 계약은 static docking-score 축 검증만. docking이 flat이면 "신호는 dynamics" 결론으로 종료(별도 계약이 dynamics).

## Done When

- (판정, 성공/실패 둘 다 valid outcome) same-source/single-assay VAV1 시리즈에서 full-complex Glide GScore(또는 Lon-engagement 거리) vs log-DC50 상관을 측정하고 ternary 대조와 비교해 아래 중 하나로 판정:
  - PASS: **full-complex가 R²>0.7 또는 Pearson r>0.8**(논문 Fig4B 급) AND **full >> ternary**(ternary R²가 유의하게 낮음, Fig4B vs 4C 재현). 이 경우 full-complex docking이 VAV1 효능 예측자로 확립.
  - NULL: full-complex GScore가 flat/무상관 → static docking은 VAV1 효능 축 아님(신호는 dynamics), 명확히 문서화.
- pilot(≥15 화합물, DC50 spanning) hard gate 통과(GScore/Lon-engagement가 퍼지고 DC50 방향으로 흔들림)해야 100개(또는 전체 단일-assay 셋) 확장. flat이면 pilot서 중단.
- 검증 커맨드: `python3 .agent/scratch/ikzf3_gt/dock/docking_dc50_correlation.py` → full/ternary R²·Pearson·Spearman + n + same-assay 출처 명시 출력.
- 산출: results 문서(analysis or scratch)에 full vs ternary 상관표 + pilot 게이트 결과 + PASS/NULL 판정.

## Implementation Steps (개략 — 상세는 /write-plan)

1. 단일-출처/단일-assay VAV1 DC50 시리즈 식별 + SMILES 매핑(sar/vav1-ubq 데이터). verify: n + 출처 단일성 확인.
2. Receptor A(full, Prep-ready) + Receptor B(ternary 대조 = 촉매모듈 strip) 준비 + A1B ref ligand 추출. verify: 체인·clash·chain-ID.
3. grid 스펙 문서화(center 133.18/93.86/153.25, inner ~12Å outer ~32-36Å, GDI-side=CRBN Lon H103/F102/F150). verify: 좌표·box가 TBD~Lon 포괄.
4. pilot(~15-20) LigPrep+Glide SP(유저 Maestro) → GScore/Lon-engagement 추출 → **hard gate**. verify: spread + DC50 방향.
5. gate PASS 시 전체 단일-assay 셋 docking(유저) → full+ternary. verify: 완주.
6. 상관분석(GScore + Lon-engagement, full vs ternary) + PASS/NULL 판정 + results 문서. verify: 검증 커맨드.

## Verification

- `python3 .agent/scratch/ikzf3_gt/dock/docking_dc50_correlation.py` (full/ternary R²·r·ρ, n, 출처)
- pilot gate 로그(GScore/Lon-engagement 분포 + DC50 trend)

## Triggers matched

- cross_slice: sar(DC50 데이터) 참조. shared-storage 쓰기(kfs2 scratch 출력 가능). Maestro=유저 외부도구. **SLURM/GPU 게이트 없음**(내 몫 전부 zero-GPU). 4+ 파일 가능(scratch prep).

## Resource budget

- 내 몫: zero GPU-hour(receptor/grid/compound prep + 상관분석, gemmi/numpy/OpenMM-CPU-min만). Maestro Glide docking은 유저 compute(외부).

## Re-scope 2026-07-15 (도커 교체)

유저가 Glide(Schrödinger) 접근 불가 → 도커를 **gnina**(CNN scoring, Glide-급 오픈소스, GPU)로 교체, **executor=claude**(Maestro handoff 제거). 논문 raw-score 방법 재현(MM-GBSA rescoring은 pilot flat일 때만 예비). 근거: 논문 Fig4D가 congeneric mezig analog을 raw docking score로 R²=0.84 달성 → raw docking이 congeneric에서도 유효(단 Glide-급 scorer 필요, gnina CNN이 최근접). **triggers 추가: GPU/SLURM**(gnina docking; 활성 계약 하에 kim sbatch 허용). budget: zero → GPU-hour(pilot 소량 + full 399 병렬 ~수 GPU-hr). 나머지 스펙(receptor A/B, grid, full vs ternary, same-assay DC50, pilot hard gate, PASS/NULL bar) 불변.

## Rollback plan

- 전부 `.agent/scratch/` + git commit이라 revert로 원복. 외부 부작용 없음(Maestro는 유저 로컬, 우리 저장소/서버 미변경). 잘못된 receptor/grid면 파일 교체 후 재분석. NULL 판정이어도 유효한 결과(문서화하고 dynamics 축으로 이관).

## Notes

NULL 판정으로 종결한다. 실 Schrödinger Glide SP docking(receptorA_full, n=388)이 log-DC50과 무상관이다(r=+0.026, R²=0.001, non-censored r=-0.092). congeneric 층위도 flat(within-cluster Butina0.3 rho=-0.005). 메커니즘은 글루가 TBD-only 결합체라 full-complex 전용 계면을 접촉하지 않고 촉매 apex(Ub-Gly76)까지 median 24Å 떨어져 정적 포즈가 productive geometry를 분별하지 못하는 것이다. static docking 축은 여기서 닫고 dynamics로 이관한다(`vav1-ubq-gdi-occupancy-md-dc50-20260715`가 대체). results: `results_docking_dc50.md`.
