---
status: pending
slice: aigen-fold-core
topic: degron-steering-optimization-9nfr
date: 2026-06-30
owner: claude
approved_by: <pending — user + aigen-fold-core owner session 0c7db357 coordination>
requested: 2026-06-30
cross_slice: [vav1-ubq]
triggers_matched:
  - "SLURM/GPU 제출 — Phase 1 ~24 cells + Phase 2 sweep"
  - "ranking/steering 의미 변경 — degron 제약 세트 확장, hard vs soft 비교"
  - "shared-storage writes — /mnt 워크스페이스 출력"
  - "다른 세션 소유 슬라이스(0c7db357) GPU·엔진 공유 → 조율 필요"
---

# Degron 제약 · 샘플링 · Steering 최적화 (9NFR / MRT-23227)

## Purpose

진단 체인이 가설을 세웠다(전부 이 세션에서 zero-GPU 검증):
- 9NFR 결정구조 = **direct bridge** (글루 A1B가 CRBN 2.95Å + VAV1 RT-loop 3.10Å).
- VAV1 인식 = CRBN **Y355 induced fit** (χ1 −172, VAV1 유일; 비-VAV1 기질 전부 ~−72; 9NFR/9UUM/6H0F/5HXB/5FQD 패널 확인).
- 생성물이 Y355를 못 맞춤: contact_fix DQcv 런(arm2 전 seed) Y355 χ1 −58~−63 (canonical), VAV1↔CRBN 0.6~0.9Å (clash).
- **VAV1_345(P7, 5/21)만 Y355 −165로 맞춤** — 원인: `--w400_residue_index 355` + `--w400_vav1_residues 16,17,18,19`(=D797-E800)로 RT-loop을 **Y355 패치에 명시적 steering**. 즉 crystal 발견 접촉 R798↔Y355·E800↔H353을 이미 겨눴음. contact_fix는 출판 triad만 써서 Y355 누락.

가설: degron 제약을 출판 triad에서 **확장(+R798↔Y355, +E800↔H353)**하고 hard force보다 soft interface-range steering을 쓰면 Y355 rim이 회복되고 DQcv가 오른다.

## Phase 1 — 통제 매트릭스 (degron × 메커니즘)

같은 9NFR/MRT-23227 시스템(글루 A1B), 동일 MSA·체인.

| Arm | degron 제약 | 메커니즘 | 기대 |
|---|---|---|---|
| A | 출판 triad (R796↔W400,D797↔H357,S799↔N351) | hard force-contact | contact_fix 재현: Y355 −58, clash |
| B | 확장(triad + R798↔Y355 + E800↔H353) | hard force-contact | rim 회복? |
| C | Y355 패치(w400_residue_index=355, RT-loop 16-19) | soft interface-range + GD | VAV1_345 재현(MRT-23227에서) |
| D | 없음 | unsteered | 음성대조 |

- seeds: 6/arm (16,42,123,300,500,777). ~24 cells. 1 GPU each, sampling_steps 50, recycling 3, num_particles 8.
- CRBN/VAV1 번호 매핑은 기존 closure_map/contact_recovery 도구 재사용.

### 채점 (zero-GPU, 본 세션 스크립트 재사용)
- Y355 χ1 (목표 −172) + H357 D797 접촉
- DQcv vs 9NFR crystal (DockQ)
- VAV1↔CRBN clash / min-dist (0.6Å clash 재현 여부)
- contact recovery: triad + 확장(R798↔Y355, E800↔H353)
- SH3c placement RMSD vs 9NFR

### Phase 1 게이트
어느 (degron, 메커니즘)이 **Y355 −172 회복 + DQcv 개선 + clash 제거**인가 판정. 가설대로면 B 또는 C가 A를 이긴다.

## Phase 2 — 샘플링·steering 최적화 (Phase 1 승자 위에서, 게이트 후)

- num_particles {8,16}, sampling_steps {50,100}, interface_lambda {10,20,40}, FragMap {on,off}, interface_gd {on,off}.
- seed 6-12. 목표: DQcv + rim 정합 최대화. 부분요인 설계(전 grid 아님).

## Constraints

- allowed: 신규 WS 디렉토리(/mnt/kfs2 또는 kfs1-4,7 — kfs5/6 가득), 신규 YAML(확장 degron), 런처, 채점 스크립트(analysis/crl_integrative/).
- forbidden: 기존 실험 WS·contact_fix 출력 변경 금지. 공유 closure_spec_generic.json 변경 금지. #12 dirty WIP 미접촉.
- external: GPU = boltz-native un-containerize + `sudo -u kim sbatch --qos=normal`(또는 batch). free-GPU mem.free>75GB. 출력 chmod 777.

## Non-Goals

- 새 화합물(345 외) 일반화 — Phase 1은 9NFR/MRT-23227 단일 시스템 통제.
- productive-geometry MD (vav1-ubq Stage C 소관).
- 모델 finetune (별도 빌드 컨트랙트).

## Done When

- Phase 1 24 cells 완료 + 채점 TSV(Y355 χ1, DQcv, clash, contact-recovery, RMSD) + 비교 리포트.
- "확장 degron / soft steering이 Y355·DQcv를 개선하나" 판정.

## Rollback

```bash
sudo -u kim scancel <JOBIDS>
sudo -u kim rm -rf <new WS out/logs>
```

## Coordination (필수)

aigen-fold-core 현 owner 세션 0c7db357(ARM-2 crbn_align 작업 중)와 GPU·엔진 공유. 제출 전 조율: (a) GPU 동시 사용 충돌 회피, (b) 엔진 코드(diffusionv2_extend.py 등) 동시 수정 회피(본 작업은 코드 무수정, 기존 steering 플래그만 사용). vav1-ubq(2a89764f)는 MD라 무관하나 결과 공유.

## Progress Log

- 2026-06-30: 진단 완료(crystal direct-bridge, Y355 induced fit, 생성물 Y355 miss, VAV1_345 residue-355 steering 원인) → 본 컨트랙트 초안. status pending: 사용자 승인 + owner 조율 + GPU 승인 대기.
