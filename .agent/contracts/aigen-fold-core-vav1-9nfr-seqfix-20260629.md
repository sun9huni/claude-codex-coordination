---
status: approved
slice: aigen-fold-core
topic: vav1-9nfr-seqfix
date: 2026-06-29
owner: claude
approved_by: sunghoon.kim
requested: 2026-06-29
cross_slice: []
triggers_matched:
  - "SLURM/GPU 제출 — 6 cells (ARM-0×3 + ARM-2×3)"
  - "shared-storage writes — /mnt/kfs2 워크스페이스 + 출력"
  - "신규 YAML 1개 + MSA CSVs 재추출 (9NFR crystal sequences)"
---

# VAV1 9NFR 서열 정합 파이프라인 재구성

## Purpose

현재 contact_fix_9nfr 파이프라인의 DQcv=0.084는 예측 품질이 아닌
**서열 불일치 채점 오류**로 확인됐다.

- YAML CRBN: 375aa (9UUM 기반 추정) vs 9NFR 결정체 CRBN: 353aa (resid 77–436)
- YAML DDB1: 745aa (도메인만) vs 9NFR 결정체 DDB1: 1119aa (resid 2–1140)
- DockQ가 CRBN을 정렬하지 못한 채 interface를 채점 → DQcv 인위적 하락

VAV1-CRBN 계면은 실제로 23쌍 <4Å (BRD4 27쌍과 동등)로 본질적
어려움이 없다. 9NFR 결정체 체인 서열로 YAML/MSA/contacts를 완전히
재구성하면 진짜 DQcv를 측정할 수 있다.

## Current State

- WS: `/mnt/kfs2/data/users/ubuntu/contact_fix_9nfr_20260626/`
- 기존 YAML: A=CRBN(375aa), B=VAV1(61aa), C=SMILES, D=DDB1(745aa) — 서열 소스 불명
- 9NFR crystal: A=DDB1(1119aa), B=CRBN(353aa resid77-436), C=VAV1-SH3c(55aa)
- best DQcv=0.084(ARM-2 seed123)

## Plan

1. **WS 생성** + symlinks (src_local, closure_spec)
2. **9NFR 서열 추출** — gemmi로 chain B(CRBN 353aa), chain A(DDB1 1119aa),
   chain C(VAV1 55aa) 서열 추출 → MSA CSVs 작성. 리간드 SMILES 추출(MRT-23227).
3. **Contacts 재추출** — 9NFR 결정체 heavy-atom 최소거리:
   - CRBN-DDB1: top 10 쌍 <5Å (chain B ↔ chain A)
   - CRBN-VAV1: top 8 쌍 <6Å (chain B ↔ chain C)
   DDB1 resid-map (gaps 있음, enumerate 필요). CRBN YAML_pos = crystal_resid − 76.
4. **YAML 작성** (vav1_9nfr_seqfix.yaml):
   A=CRBN(353aa), B=VAV1(55aa), C=MRT-23227 SMILES, D=DDB1(1119aa)
   contacts force:true max_distance:8.0, templates×5, MSA CSVs
5. **런처** + dry-run
6. **⛔ GPU GATE** — `sudo -u kim sbatch --qos=normal`, ARM-0×3 + ARM-2×3 = 6 cells
7. **채점** — DockQ `ABD:BCA` vs 9NFR_crystal.pdb (pred 서열 == GT 서열)
   DQcv vs old baseline(0.084) 비교표 + 결과 문서

## Constraints

- allowed change scope:
  - WS: `/mnt/kfs2/data/users/ubuntu/vav1_9nfr_seqfix_20260629/`
  - 신규 파일: yaml, msa csvs, launcher, closure_spec 복사본
  - 결과 문서: `/home/ubuntu/analysis/crl_integrative/vav1_9nfr_seqfix_results.md`
  - PNG: `/home/ubuntu/analysis/crl_integrative/png/vav1_9nfr_seqfix_overlay.png`
- forbidden:
  - 기존 contact_fix_9nfr WS 변경 금지
  - 공유 closure_spec_generic.json 변경 금지
- external:
  - GPU: `sudo -u kim sbatch --qos=normal`
  - SLURM logs chmod 777
  - GPU 선택: memory.free > 75000 MiB

## Non-Goals

- contact_fix_9nfr 기존 실험 수정
- DDB1 도메인만 사용하는 변형 실험 (full 1119aa 사용)
- ARM-2 oracle config 재보정 (기존 config 재사용, OOM 시 num_particles=1 fallback)

## Done When

```bash
find /mnt/kfs2/data/users/ubuntu/vav1_9nfr_seqfix_20260629/out/ \
  -name "*_model_0.pdb" | wc -l
# → ≥3 (ARM-0 3개 최소, ARM-2 성공시 추가)
test -f /home/ubuntu/analysis/crl_integrative/vav1_9nfr_seqfix_results.md
```

판정 기준:
- 진짜 DQcv(서열 정합 채점) 수치 확인
- old DQcv=0.084와 비교 표 작성
- 파이프라인 자체 품질 vs 채점 오류 분리

## Rollback

```bash
sudo -u kim scancel <JOBID>
sudo -u kim rm -rf /mnt/kfs2/data/users/ubuntu/vav1_9nfr_seqfix_20260629/
```
