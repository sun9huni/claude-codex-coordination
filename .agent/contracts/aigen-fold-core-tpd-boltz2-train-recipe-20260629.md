---
status: approved
slice: aigen-fold-core
topic: tpd-boltz2-train-recipe-derisk
date: 2026-06-29
owner: claude
approved_by: sunghoon.kim
requested: 2026-06-29
cross_slice: []
triggers_matched:
  - "4+ files (new build dir: env setup + StructureV2 converter + Boltz-2 datamodule/config + smoke)"
  - "new code authoring that begins the TPD self-model build"
---

# TPD 자체 모델 빌드 슬라이스 0 — Boltz-2 학습 경로 de-risk (GPU 0)

## Purpose

수개월의 검증 끝에 도달한 결론: TPD/MGD 자체 모델 빌드는 feasible하나
유일한 코딩 리스크가 "Boltz-2 finetune 레시피가 출하돼 있지 않다"에 몰려
있다(출하 train.py/config 전부 Boltz-1; trainingv2.py가 V1 Structure를 V1
featurizer에 먹이는 내부모순; raw CIF→StructureV2 배치 변환기 미연결).
부품은 라이브러리로 존재(parse_mmcif가 결정구조 좌표를 StructureV2로 읽음,
Boltz2Featurizer/Boltz2Tokenizer, StructureV2 load/dump, inferencev2 템플릿).

이 슬라이스는 GPU 없이 그 리스크를 코드로 깨는 단일 milestone이다.
**성공 기준 = 우리 GT 결정구조에서 진짜 Boltz-2 학습 배치가 CPU에서
end-to-end로 흐른다.** 이게 서면 빌드 전체가 "가능"으로 증명되고,
코퍼스 재구축(증명됨)과 GPU finetune으로 진행한다.

## 검증으로 확정된 전제 (출처: feasibility workflow 2026-06-29)

- DeepTernary 전처리→.pth: RESOLVED(키 정확 일치, CPU 1~3h/12,776, 57GB).
- RCSB fetch: RESOLVED(250/250, 고유 PDB 2,700개).
- cone 포텐셜: 런타임 작동(autograd+steering pass), 단 미커밋 block2_insertion=7
  edit가 스모크 1개 깸 — 별도 reconcile, 본 슬라이스 범위 밖.
- Boltz-2 학습 포맷: StructureV2 npz(atoms/coords/ensemble/pocket/bonds)
  + records/<id>.json + manifest.json + msa_dir, 실제 npz로 확인.

## Scope (allowed)

- 신규 빌드 디렉토리에만 작성: `/home/ubuntu/analysis/tpd_build/` (신규).
- 전용 conda/venv 환경 생성(boltz importable). upstream `/tmp/boltz_upstream`
  (jwohlwend/boltz v2.2.0, data 모듈 포함) 사용 또는 fork에 data 재부착.
- 작성물:
  - `crystal_to_structurev2.py`: GT 결정구조(PDB→mmCIF gemmi 변환 포함)를
    parse_mmcif로 StructureV2 npz + records/<id>.json + manifest.json + split
    으로 변환. 비-CCD degrader ligand는 RDKit mols dict 공급.
  - Boltz-2 datamodule/train config 경로: StructureV2 → Boltz2Featurizer/
    Boltz2Tokenizer → `boltz.model.models.boltz2.Boltz2`, cluster/random sampler.
  - `smoke_cpu_batch.py`: 변환된 2~3개 타깃으로 datamodule가 실제 배치를
    내는지 + (가능하면) CPU forward 1회.
- 입력 GT: examples/heldout CIF, benchmark refs, 9NFR 등 64개 중 2~3개.

## Constraints (forbidden)

- 기존 dirty git tree(FKSFold-Boltz_Advancement, DeepTernary) 수정 금지.
  특히 미커밋 crl_closure block2_insertion edit 건드리지 말 것.
- GPU 사용 금지. sbatch 금지. 장시간 잡 금지(스모크는 2~3개 타깃 한정).
- 시스템 python 오염 금지(전용 env에만 설치).
- ranking/production config 변경 없음.

## Non-Goals

- 코퍼스 전량 재구축(별도 슬라이스, 증명됨).
- GPU finetune(별도 슬라이스, 본 스모크 통과가 게이트).
- cone offset reconcile(별도).
- MSA 대량 사전계산(스모크는 single-seq 또는 더미 MSA 허용).

## Done When

```bash
# 1) 변환기가 StructureV2 npz를 만들고 StructureV2.load로 열린다
test -f /home/ubuntu/analysis/tpd_build/out/structures/*.npz
# 2) datamodule가 CPU에서 실제 학습 배치를 낸다 (로그에 batch tensor shape)
grep -q "BATCH_OK" /home/ubuntu/analysis/tpd_build/smoke_cpu_batch.log
```

판정: 변환기가 결정구조 좌표를 담은 StructureV2를 내고, Boltz-2 datamodule가
그걸 읽어 CPU에서 배치 1개를 (이상적으로 forward 1회까지) 통과시키면 PASS.
실패 시 정확히 어디서 막혔는지(import/parse/featurize/collate)와 다음 수를 보고.

## Rollback

```bash
rm -rf /home/ubuntu/analysis/tpd_build   # 신규 디렉토리만; 기존 레포 무영향
conda env remove -n tpd_boltz2 2>/dev/null || true
```

## Progress Log

- 2026-06-29: contract 승인(사용자 "진행"). feasibility 4종 실행 완료를 전제로
  슬라이스 0 착수. 실행 결과는 본 로그에 append.
