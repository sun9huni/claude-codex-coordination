---
status: pending
slice: aigen-fold-core
topic: validation-set-expansion
date: 2026-06-15
owner: claude
approved_by: (대기 — /brainstorm 수렴)
triggers_matched:
  - "SLURM/GPU evaluation run"
  - "multi-target benchmark criteria"
  - "local repo + shared execution workspace"
---

# Validation-set expansion — GT-있는 CRBN ternary held-out PDB 최대 확보

## 목표 (success criterion)
"AIGEN-Fold가 VAV1 외 다른 OOD 타깃의 CRBN-mediated ternary placement도 잘 예측한다"를
**held-out 크리스털 GT로 채점 가능한 검증 케이스를 최대화**해 통계적으로 입증한다. RCSB 전수
enumeration 결과 CRBN(Q96SW2) ternary = 69 엔트리, 기사용 28 → **미사용 ~39개**가 GT를 가진 채 남음.
이를 큐레이션·채점해 벤치마크를 28→~67로 약 2배 확장한다.

**Done when**: 미사용 엔트리 각각 (1) cif 다운로드 + GT_CHAIN_MAP 등록 + self-DockQ=1.0 검증,
(2) baseline(순수 Boltz-2) + aigen(steering) 채점(DockQ+iPTM+ipDE), (3) per-target/per-glue 분포 +
regime(OOD vs co-success) 라벨 요약. 실패/제외 엔트리 명시(silent drop 금지).

## 대상 (미사용 ~39, 전부 GT 보유)
- **A. OOD-class — 이미 검증한 어려운 타깃의 다른 글루 변이 (13)**: CK1α 5FQD; GSPT1 5HXB·6XK9;
  HBS1L 11MR; CDK2 9D0W·9D0X; BRD4 6BN7·6BN8·6BN9·6BNB·6BOY·8RQ9·9SAF.
- **B. degron/co-success — 다른 construct (26)**: Ikaros 6H0F·8D7Z·8D80·8RQC·8TNP·8TNQ;
  SALL4 6UML·7BQU·7BQV·8U15·8U16·8U17·9NWS; Helios 7LPS·8DEY·9O91·9OHQ·9OHR(+7U8F);
  WIZ 9DJT·9DJX; ZNF692 6H0G; Aiolos(반응상태) 9UUM·9V0A·9V0B·9V0F.
- 제외: GLUL(9NR3, 6-mer 펩타이드), TUSC3(4M91, 소분자 리간드 없음).

## 조건
- baseline: 순수 Boltz-2 co-fold(서열만, 제약 없음, num_particles=1).
- aigen: biophysical_hybrid, interface_lambda=20, p8, w400 — 기존 OOD-enrichment 레시피 재사용.
- seeds: 42/16/123 (median). per-target regime = baseline median <0.23 → OOD, 아니면 co-success.

## Out of scope (명시)
- VHL/비-CRBN E3 (다른 제품 = mission 밖).
- 크리스털 없는 prospective 타깃(IDO1/HDAC6 등) — GT 없어 채점 불가, 별건.
- 새 steering 항/파이프라인 변경 (이건 순수 측정 확장).
- 새 distinct OOD 타깃 확보 (RCSB 소진 — 본 확장은 글루-변이·construct·통계력만 늘림).
- 활성(DC50/Dmax) 예측 (placement generator scope).

## 정직성 가드 (해석 한계)
- **새 distinct OOD 타깃 ≈ 0**: 어려운 12종은 이미 사용. 본 확장이 늘리는 건 통계력·글루-robustness·
  co-success 분포 커버이지 새 표적 일반화 증거가 아님(그건 기확보 12종 소관). 결과 해석에 이를 명시.
- **degron(B)의 데이터-누수 위험**: Boltz-2 학습 분포 안 → 일부는 암기. **deposition 날짜로 학습(~2023)
  이후/이전 라벨** 부여, 2023+ 블라인드 케이스를 별도 강조(진짜 prospective 검증력은 거기 있음).
- iPTM/ipDE = guardrail(success metric 아님) 재확인.

## SLURM plan
- OUT_BASE: `/mnt/data/users/ubuntu/workspace/validation_expansion_20260615` (신규).
- 코드 mount: 검증된 OOD-enrichment stage/src 재사용(fragmap 배선 present). Image glueplex-v2,
  QoS batch, array %8, PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True.
- 큐레이션: 기존 stage_ood_enrichment 패턴 + chosen_meta 확장(7개는 chosen_meta_expansion_20260615.json
  에 이미 검증됨 — 재사용). 나머지 ~32개 신규 큐레이션(chain map self-DockQ=1.0 hard gate).
- baseline manifest 먼저 제출 → 채점으로 regime 라벨 → aigen 제출.

## Verification
- 제출 전: bash -n, manifest dry-count, self-DockQ=1.0 전 엔트리(잘못된 chain map 차단).
- 생성 후: pose+confidence 카운트, steering-engage 로그(silent-disable 아님), 누락 명시.
- DockQ: score_heldout_dockq.py (GT chain map).

## Risks / Rollback
- repo dirty: 신규 파일만, 기존 미커밋 파일 git 조작 금지.
- 일부 엔트리는 multi-copy/반응상태(9UUM 등 Ub-transfer) → chain map 복잡, self-DockQ로 거름.
- 6XK9는 glue-pocket contact 부재(이전 드롭) → baseline은 채점 가능, aigen pocket arm은 skip-warn.
- scancel <jobid> / 신규 OUT_BASE는 승인 후 제거. do-not-fork-scorer 유지(config/manifest만).

## Progress log
- 2026-06-15 /brainstorm 수렴으로 초안(status pending). RCSB 전수 enumeration(crbn_enum.py): 69 ternary
  /29 distinct target, 기사용 28 → 미사용 39(A 13 OOD-glue-variant + B 26 degron-construct). 7개 사전
  검증(chosen_meta_expansion). 승인 시 /write-plan.
- 2026-06-15 **데이터 가용성 = 이중 확인(우리 RCSB enumeration + GPT deep-research 독립)**: 새 distinct
  CRBN ternary 타깃(배포 PDB 좌표) = **0**. 코퍼스 고갈 확정.
  • fishing(10 alt-glue baseline)이 알려진 타깃의 다른 글루/도메인에서 **숨은 HARD 3 발견**: 8RQ9 BRD4-BD2
    0.030, 9D0W/9D0X CDK2-PROTAC 0.027-0.054(baseline 붕괴). 새 타깃 아니나 새 steerable hard case.
  • GPT가 **map-only 미래 타깃 2 발견**: **WEE1**(분자글루 compound 10, 큰 키나제 P30291, CRBN-DDB1,
    cryo-EM EMD-46922/46923 3.8/4.2Å, 2024 release=blind, JACS 2024 — **우리 스코프(분자글루·large globular)
    정확히 일치**) · **ESR1/ERα**(ARV-471 PROTAC 임상 degrader, EMD-40261 3.7Å). 둘 다 PDB 원자좌표 없음
    → DockQ 직접 불가하나 **cryo-EM map-fit으로 검증 가능**(IDO1과 달리 GT 밀도 존재).
  → 검증 성장 경로 3: (a) alt-glue robustness ~39 (b) 숨은 hard 3 steering(신규 rescue 증거) (c) WEE1
    prospective(분자글루·map 검증). **새 distinct 타깃 큐레이션은 closed**(이중 확인).
