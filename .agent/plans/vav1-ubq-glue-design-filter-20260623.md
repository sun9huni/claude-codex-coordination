---
contract: .agent/contracts/vav1-ubq-glue-design-filter-20260623.md
slice: vav1-ubq
status: done
total_tasks: 4
estimated_total_min: 55
---

# Plan — VAV1 Glue Design Competence Filter (necessary-condition, STRUCTURE-only)

공통: env `/home/ubuntu/miniconda3/bin/python` (gemmi/numpy/scipy). 신규 진입점
`analysis/crl_integrative/glue_competence.py`. 부품 재사용(2fd2f77): zone_compare_generated
(CRBN 서열-앵커 중첩 auto-offset), zone_patch_readout/zone_body_reach(라이신→apex zone),
zone_clash(KDTree clash), zone_9nfr_anchor(content-based 사슬 식별 + degron 접촉). frozen
기하 closure_spec.json (apex, zone ≤21Å). refs: 9NFR best_structures/9NFR_reference.cif,
9UUM analysis/crl_integrative/refs/9UUM.cif. 검증쌍: 9nfr_in_9uum.pdb(PASS sanity),
completed_seed42.pdb(FAIL). **필요조건 필터지 ranker 아님 — actives must pass, inactive 통과 무관.**

---

## Task 1: glue_competence.py — 단일 competence 진입점

- **Status**: pending
- **Prereq tasks**: none
- **Files touched**: `analysis/crl_integrative/glue_competence.py` (new)
- **Change shape**: 임의 글루 삼원(PDB/CIF) 입력 → (a) **사슬 content-식별**(CRBN by W400/N351/H357,
  VAV1 by RDxS@796-799; --crbn-chain/--vav1-chain override 가능), (b) **CRBN 서열-앵커 9UUM
  중첩**(auto-offset scan + Kabsch, RMSD 보고; zone_compare_generated 로직 일반화 = seed42
  하드코딩 제거·입력 파라미터화), (c) VAV1을 9UUM 프레임으로 변환, (d) **유사도**: SH3c CA RMSD
  vs 9NFR ref(9nfr_in_9uum.pdb) + **degron 접촉 회복**(R796↔W400/D797↔H357/S799↔N351 min-heavy +
  n/3), (e) **라이신 거리**: VAV1 표면 Lys Nζ→apex, zone(≤21Å, 17Å도 보고) 내 patch, (f) **clash**:
  VAV1+글루 vs 9UUM platform KDTree(2.5Å). 출력 = JSON + 표 + **제약별 PASS/FAIL**(접촉≥2/3 ·
  zone Lys≥1 · clash 허용범위) + 실패 시 어느 제약·잔기. STRUCTURE-only 면책 1줄.
- **Verification**: `python glue_competence.py --ternary /mnt/kfs2/data/users/ubuntu/vav1_zone_patch_20260623/9nfr_in_9uum.pdb`
  → 리포트에 CRBN RMSD, SH3c RMSD, degron n/3, zone Lys 리스트, clash, 종합 verdict 전부 출력(에러 없이).
- **Estimated time**: 18 min
- **Rollback**: rm glue_competence.py

## Task 2: 검증쌍 — 9NFR PASS / seed42 FAIL 어서트

- **Status**: pending
- **Prereq tasks**: 1
- **Files touched**: `analysis/crl_integrative/glue_competence.py` (--assert-pair 모드 또는 별도 호출), 출력 `/mnt/kfs2/data/users/ubuntu/vav1_zone_patch_20260623/competence_validation.tsv`
- **Change shape**: 두 포즈에 도구 실행 + 기대 verdict 어서트. **9nfr_in_9uum**(=ref, MRT-23227
  placement): degron 3/3, 라이신 zone 내, **종합 PASS**(ref vs self라 RMSD~0 = sanity). **completed_seed42**
  (생성, 23Å off, A=CRBN/V=VAV1/C=LIG): degron 0–1/3, R796↔W400≈7.5Å, **종합 FAIL**. 두 verdict가
  기대와 일치하는지 assert(불일치 시 비-zero exit).
- **Verification**: `python glue_competence.py --assert-pair` → `9NFR: PASS (degron 3/3) ✓` +
  `seed42: FAIL (degron <=1/3, R796-W400 ~7.5A) ✓` + `validation PASS`. (도구가 competent/incompetent를 정확히 가름.)
- **Estimated time**: 8 min
- **Rollback**: rm 출력 tsv

## Task 3: 광역 특성화 — 가용 후보 포즈 일괄 채점 + edge-case

- **Status**: pending
- **Prereq tasks**: 2
- **Files touched**: `analysis/crl_integrative/glue_competence_sweep.py` (new), 출력 `/mnt/kfs2/.../vav1_zone_patch_20260623/competence_sweep.tsv`
- **Change shape**: 워크스페이스의 가용 MRT6160/글루 삼원 포즈를 **discover**(productive-ternary
  out/ md_injection_productive_20260622, chirality_ensemble deliverable, glue-MD systems, productive_pose)
  → glue_competence를 일괄 적용 → competence 분포 표(포즈별 degron n/3·zone Lys·clash·verdict). **edge-case
  내성 확인**: 다양한 numbering(native/offset+45/local)·사슬명·누락 사슬에서 content-식별+auto-offset이
  견디는지; 깨지면 graceful 보고(crash 금지). silent-truncation 금지(스캔 못 한 포즈는 log).
- **Verification**: `python glue_competence_sweep.py` → ≥5 포즈 채점 표 출력 + numbering 변형들에서
  사슬 식별 성공/실패 명시 + 못 스캔한 포즈 명시 로그.
- **Estimated time**: 18 min
- **Rollback**: rm glue_competence_sweep.py + 출력 tsv

## Task 4: 리포트 + baton + 커밋

- **Status**: pending
- **Prereq tasks**: 3
- **Files touched**: `analysis/crl_integrative/glue_competence_results_20260623.md` (new), `.agent/status/vav1-ubq.md`, contract Progress Log
- **Change shape**: 리포트 — 도구 사용법(입력/출력) + 검증쌍 결과(9NFR PASS/seed42 FAIL) + 광역 sweep
  요약 + **필요조건 필터지 ranker 아님** 명시(potency out) + 한계(입력 포즈 품질 의존·zone 임계 민감도).
  워크스페이스 repo 커밋(내 파일만, never -A). baton 갱신 + contract_pointer 추가. handoff.sh + status.sh index.
- **Verification**: 리포트에 필수 섹션(사용법/검증쌍/sweep/STRUCTURE-only/한계) `grep -c` 확인;
  `git log --oneline -1` 새 커밋; baton에 contract_pointer 포함.
- **Estimated time**: 11 min
- **Rollback**: git revert 해당 커밋 (내 파일만)

---

## 실행 순서 (ultracode: 워크플로우 fan-out)
T1(도구) → T2(검증쌍 어서트) → T3(광역+edge-case) → T4(doc). 실행 시 워크플로우로:
구현(T1) → [검증쌍 어서트 ‖ competence 로직 적대적 검증(numbering/누락사슬/zone임계 edge) ‖ 광역 sweep] 병렬 → 합성 리포트(T4).
