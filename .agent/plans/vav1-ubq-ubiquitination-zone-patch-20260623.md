---
contract: .agent/contracts/vav1-ubq-ubiquitination-zone-patch-20260623.md
slice: vav1-ubq
status: done
total_tasks: 9
estimated_total_min: 80
---

# Plan — VAV1 Ubiquitination-Zone Patch (9NFR-anchored, STRUCTURE-only)

> **DONE 2026-06-23**. T1–T8 executed (all gates passed), zero-GPU. T5 clash
> "gate-fail" reinterpreted = body-dangles diagnosis (9UUM is the IKZF3 productive
> assembly → real neosubstrate body is unresolved/dangling). **Answer: degron-
> presented patch {K804, K788, K810}** (K804 robust dominant) + low-occupancy SH2
> body tail; IKZF3-cross-validated. Body tier (#2) checked zero-GPU via tether +
> ensemble upper-bound (zone_body_reach.py) → T9 (gated GPU cross-check) NOT needed.
> Report: analysis/crl_integrative/zone_patch_results_20260623.md.


공통: env=`/home/ubuntu/miniconda3/bin/python` (numpy/scipy/mdtraj; ANM은 scipy `eigh`/prody, SASA는 mdtraj `shrake_rupley`/freesasa). 신규 스크립트 dir=`/home/ubuntu/analysis/crl_integrative/` (`zone_` 접두사). 대용량 앙상블 좌표=`/mnt/kfs2/data/users/ubuntu/vav1_zone_patch_20260623/` (kfs5 회피). frozen 기하·매핑은 `closure_spec.json`/`closure_map.json`에서 읽기(하드코딩 인덱스 금지). 프레임 규약: **9UUM을 고정 platform으로 두고 9NFR(+grafted VAV1)을 9UUM 프레임으로 가져온다** — cone·platform(CUL4-NEDD8-E2~Ub)이 이미 9UUM 좌표계라.

---

## Task 1: 9NFR P3' degron 접촉 검증 (앵커 sanity)

- **Status**: pending
- **Prereq tasks**: none
- **Files touched**: `analysis/crl_integrative/zone_9nfr_anchor.py` (new)
- **Change shape**: 9NFR_reference.cif 로드 → VAV1·CRBN 사슬 식별 → 서열-앵커로 9NFR 번호를 P15498/closure_map에 매핑 → P3' 3접촉(R796↔W400, D797↔H357, S799↔N351) 최단 중원자 거리 계산 + 잔기 정체-assert. closure_map.json의 expected 정체와 대조.
- **Verification**: `python zone_9nfr_anchor.py` → 3 접촉 거리 모두 출력 + `all 3 contacts <= 6.0A: True` + `identity_ok: True`. (게이트: 접촉 부재 시 멈추고 앵커 가정 재검토.)
- **Estimated time**: 8 min
- **Rollback**: rm zone_9nfr_anchor.py

## Task 2: CRBN 중첩 9NFR→9UUM + cone 거리 (배치)

- **Status**: pending
- **Prereq tasks**: 1
- **Files touched**: `analysis/crl_integrative/zone_superpose_crbn.py` (new), 출력 `…/vav1_zone_patch_20260623/9nfr_in_9uum.pdb`
- **Change shape**: 9NFR CRBN과 9UUM CRBN(chain C)을 **서열-앵커 Cα 정렬**(잔기번호 신뢰 금지; 서열 align으로 공통 Cα 짝, offset reconcile) → Kabsch R,t → 9NFR 전체(CRBN+DDB1+VAV1-SH3+glue)를 9UUM 프레임으로 변환·저장. closure_spec.json cone apex로 9NFR SH3 5라이신(788/804/810/814/815) Nζ 거리 보고. DDB1 9NFR↔9UUM Cα RMSD를 sanity로 보고.
- **Verification**: `python zone_superpose_crbn.py` → `CRBN align RMSD = <1.5A` + reconciled offset 출력 + 5라이신 Nζ→apex 거리표 + `DDB1 sanity RMSD` 출력. (게이트: RMSD>1.5Å 멈춤.)
- **Estimated time**: 12 min
- **Rollback**: rm zone_superpose_crbn.py + 출력 pdb

## Task 3: AF full-VAV1 graft (몸통 부착)

- **Status**: pending
- **Prereq tasks**: 2
- **Files touched**: `analysis/crl_integrative/zone_graft_fullvav1.py` (new), 출력 `…/vav1_zone_patch_20260623/fullvav1_grafted.pdb`
- **Change shape**: AF-P15498-F1.pdb 로드 → AF SH3c(native 782–842) Cα를 9NFR SH3(9UUM 프레임)에 Kabsch 정렬 → 변환을 AF 전체에 적용 → full-VAV1을 활성 프레임에 저장. full 표면 라이신 인벤토리(P15498 번호, 전 도메인) 추출 + 정체-assert(전부 LYS). graft RMSD 보고.
- **Verification**: `python zone_graft_fullvav1.py` → `SH3c graft RMSD = <2.0A` + `surface Lys inventory: N=<count>` + P15498 라이신 번호 리스트(788/804/810/814/815 포함 확인). (게이트: RMSD>2Å 멈춤=fold 불일치.)
- **Estimated time**: 10 min
- **Rollback**: rm zone_graft_fullvav1.py + 출력 pdb

## Task 4: full-VAV1 body conformer 앙상블 생성 (zero-GPU)

- **Status**: pending
- **Prereq tasks**: 3
- **Files touched**: `analysis/crl_integrative/zone_ensemble.py` (new), 출력 `…/vav1_zone_patch_20260623/ensemble/conf_*.pdb` (N≥50)
- **Change shape**: grafted full-VAV1에서 **SH3c(782–842)를 고정 앵커**로 두고 몸통 conformer 생성 — (a) 전장 VAV1 탄성망 ANM 저주파 hinge 모드(scipy `eigh`/prody)를 ±진폭으로 변형 + (b) SH3c↔몸통 링커를 hinge로 강체 회전 스윕. SH3c·CRBN·platform은 불변. N≥50 conformer 저장 + 각 conformer의 몸통 RMSD-from-AF 분포.
- **Verification**: `python zone_ensemble.py` → `wrote <N>=>50 conformers` + `body RMSD-from-AF spread: min/median/max` 출력(스프레드>0=실제 다양성) + SH3c Cα가 전 conformer서 불변(RMSD~0) assert.
- **Estimated time**: 15 min
- **Rollback**: rm zone_ensemble.py + 출력 ensemble/

## Task 5: clash 체크 + 가짜-clash 해소 입증

- **Status**: pending
- **Prereq tasks**: 4
- **Files touched**: `analysis/crl_integrative/zone_clash.py` (new), 출력 `…/vav1_zone_patch_20260623/clash_hist.tsv`
- **Change shape**: 각 conformer의 몸통 중원자(SH3c 외 native resid) vs 9UUM platform(CRBN-DDB1-CUL4-NEDD8-E2~Ub) 중원자 KDTree 충돌 카운트(컷 ~2.2Å heavy-heavy, full_vav1_steric.py 규약 재사용). conformer별 clash 수 히스토그램 + clash-free(또는 ≤경미) 멤버 수. ★단일 rigid AF(conf 0=원본)의 clash와 대비.
- **Verification**: `python zone_clash.py` → clash 히스토그램 + `clash-free members: <k>` 출력. k≥1이면 가짜-clash 아티팩트 격파(=실복합체서 full-VAV1 입체수용 가능); k=0이면 정직히 inconclusive 기록 + Stage C 게이트 트리거.
- **Estimated time**: 10 min
- **Rollback**: rm zone_clash.py + 출력 tsv

## Task 6: zone-patch readout (핵심 산출)

- **Status**: pending
- **Prereq tasks**: 5
- **Files touched**: `analysis/crl_integrative/zone_patch_readout.py` (new), 출력 `…/vav1_zone_patch_20260623/patch_table.tsv`
- **Change shape**: clash-수용 conformer마다 표면 라이신별 판정 — (i) Nζ→cone apex 거리 ≤ reach 13.5Å, (ii) cone 각도 envelope(axis 기준; angle_enabled=false면 reach만+각도는 보조보고), (iii) SASA-노출>임계(mdtraj shrake_rupley, side-chain Nζ 근방). 앙상블 전반 집계 = patch 집합 + 라이신별 **accessible-conformer fraction**(★Boltzmann 확률 아님 라벨). K810 행 강조 비교.
- **Verification**: `python zone_patch_readout.py` → patch 표(lysine P15498, fraction, median Nζ→apex, mean SASA) 출력 + `K810 in patch: True/False, fraction=<f>` + patch 라이신 수.
- **Estimated time**: 12 min
- **Rollback**: rm zone_patch_readout.py + 출력 tsv

## Task 7: robustness / 민감도 그리드 (정직 가드)

- **Status**: pending
- **Prereq tasks**: 6
- **Files touched**: `analysis/crl_integrative/zone_sensitivity.py` (new), 출력 `…/vav1_zone_patch_20260623/sensitivity.tsv`
- **Change shape**: readout를 reach 임계 그리드(10/13.5/17Å) × SASA 임계(2~3 값)로 재집계 → patch 멤버십 안정성(어느 라이신이 전 설정서 살아남나=robust patch). 앙상블 source 교차(hinge-only vs ANM-only 부분집합)로도 비교. 임계-요동 라이신 플래그.
- **Verification**: `python zone_sensitivity.py` → 그리드 표 + `robust patch (survives all thresholds): {lysines}` + 요동 라이신 리스트 출력.
- **Estimated time**: 8 min
- **Rollback**: rm zone_sensitivity.py + 출력 tsv

## Task 8: STRUCTURE-only 결과 리포트 + baton/contract 갱신 (doc)

- **Status**: pending
- **Prereq tasks**: 7
- **Files touched**: `analysis/crl_integrative/zone_patch_results_20260623.md` (new), `.agent/status/vav1-ubq.md` (baton entry + contract_pointer 추가), contract Progress Log
- **Change shape**: 리포트 작성 — patch + accessible-conformer fraction + robustness + 한계(단일 AF body·hinge 근사·glue-불변 가정·Boltzmann 가중 아님) + STRUCTURE-only 면책 + (해당 시) inconclusive 정직 기록. 워크스페이스 repo 커밋(내 파일만). baton 갱신 + neue contract를 contract_pointers에 추가. `./scripts/handoff.sh claude vav1-ubq` + `./scripts/status.sh index`.
- **Verification**: 리포트에 필수 섹션 존재(patch 표 / robustness / STRUCTURE-only 면책 / 한계) — `grep -c` 로 헤더 확인; `git log --oneline -1` 새 커밋; baton에 contract_pointer 포함.
- **Estimated time**: 12 min
- **Rollback**: git revert 해당 커밋 (내 파일만)

## Task 9: (GATED, 조건부 GPU) AF-multiseed / 짧은 MD 교차검증

- **Status**: pending (게이트: T5 clash-free=0 **또는** T7 patch 임계-요동 심함일 때만)
- **Prereq tasks**: 5, 7
- **Files touched**: `analysis/crl_integrative/zone_xcheck.py` (new) + SLURM 런처(승인 후)
- **Change shape**: hinge 앙상블이 불충분하다 판명 시에만 — AF-multiseed(MSA-subsample) full-VAV1 앙상블 또는 grafted body의 짧은 implicit-solvent MD 완화로 독립 앙상블 생성 → zone-patch readout 재실행 → hinge patch와 일치/발산 보고. **사용자 승인 게이트 필수**(GPU).
- **Verification**: xcheck 앙상블의 robust patch가 hinge patch와 일치(교집합 보고); 발산 시 원인 분석. (실행 전 사용자 승인.)
- **Estimated time**: 게이트 뒤 결정 (zero-GPU 부분 ~10 min + GPU 런 별도)
- **Rollback**: rm zone_xcheck.py + 런 취소

---

## 실행 순서
Stage A (T1→T2→T3, zero-GPU) → Stage B (T4→T5→T6→T7, zero-GPU) → Stage D (T8, doc). T9는 T5/T7 결과가 inconclusive일 때만 게이트.
