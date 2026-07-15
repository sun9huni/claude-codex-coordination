---
slice: aigen-fold-core
status: approved
approved_by: sunghoon.kim@aigensciences.com
approved_date: 2026-06-29
triggers:
  - SLURM_SUBMIT
  - GPU_COMPUTE
---

## Scope

VAV1-9NFR 3-chain 재설계 실험 (vav1_9nfr_3chain_20260629).
세 가지 구조적 변화를 동시에 적용한다:
1. **DDB1 제거** — 4-chain(CRBN+VAV1+degrader+DDB1) → 3-chain(CRBN+VAV1+degrader). 시스템 크기 1530aa → 410aa. E2~Ub 위치는 CRL closure potential의 Kabsch 정렬(CRBN-only)로 결정되므로 DDB1 불필요.
2. **9NFR crystal 템플릿 추가** — chain B(CRBN 353aa), chain C(VAV1 55aa)를 CIF로 추출해 template으로 추가. Goal 1(CRBN 정렬) 직접 공략.
3. **GD potential 재활성화** — `crl_closure_potential.py`에 `vav1_sig` spec-override 추가 + `closure_spec`에 `"vav1_sig": "GTAKARYDFCAR"` + P3' contacts(RDRS motif B:12-16 ↔ CRBN groove A:275-321) 추가. IK generic mode p3_contacts 충돌 패치.

## Out of scope

- CRBN-DDB1 contact constraint 재설정 (DDB1 제거로 불필요)
- scoring script 업데이트 (별도 작업)
- seqfix 실험과 병렬 비교 분석 (결과 나온 후)

## Success criteria

12 cells(ARM-0×6 + ARM-2×6) PDB 생성 완료.
`find /mnt/kfs2/data/users/ubuntu/vav1_9nfr_3chain_20260629/out -name "*_model_0.pdb" | wc -l` → 12

ARM-2 best DQcv > 0.10 (seqfix best 0.080 대비 개선).

## Resource budget

- GPU: 2× A100 on host-10-0-5-36, 12h time limit
- Estimated: ~4-6h (3-chain = ~1/4 크기 → 12 cells × ~20min/cell ÷ 2 GPU)
- Storage: ~2GB on kfs2

## Rollback

`rm -rf /mnt/kfs2/data/users/ubuntu/vav1_9nfr_3chain_20260629/out/`

## Files touched

- `/mnt/kfs2/data/users/ubuntu/vav1_9nfr_3chain_20260629/` (신규 workspace)
- `/mnt/kfs2/data/users/ubuntu/template_9nfr_20260626/refs/9NFR_crbn.cif` (신규)
- `/mnt/kfs2/data/users/ubuntu/template_9nfr_20260626/refs/9NFR_vav1.cif` (신규)
- `vav1_9nfr_3chain_20260629/stage/src_local/boltz_extension/steering/crl_closure_potential.py` (vav1_sig patch)
- `vav1_9nfr_3chain_20260629/stage/src_local/boltz_extension/steering/crl_closure_ik.py` (generic mode patch)
