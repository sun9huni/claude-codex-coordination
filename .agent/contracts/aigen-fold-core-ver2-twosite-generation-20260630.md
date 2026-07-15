---
status: approved
slice: aigen-fold-core
topic: aigenfold-ver2-twosite-clean-generation
date: 2026-06-30
owner: claude (session 223c2056)
approved_by: user (2026-06-30, "지금 바로 설계 후 gpu job 실행까지 진행"); GPU coord with cb49c216/2a89764f
cross_slice: [vav1-ubq, sar, mmgbsa]
triggers_matched:
  - "SLURM/GPU 제출 — ver2 파일럿 + SAR 시리즈 생성"
  - "ranking/steering 의미 변경 — steering 캠페인 장치 전체 제거, soft two-site contact로 전환"
  - "shared-storage writes — /mnt 워크스페이스(kfs1-4,7) 출력"
  - "다른 세션 소유 슬라이스(cb49c216 aigen-fold-core, 2a89764f vav1-ubq, 55e87e7b sar) 조율"
---

# AIGEN-Fold ver2 — clean two-site constrained generation + structure→potency

## Purpose
Boltz-2 steering 캠페인을 audit으로 분해한 결과(이 세션, 3 병렬 코드 audit + 자체 실험):
- 진짜 placement lever = **입력 YAML soft contact(force=false)** → featurizerv2.py:737-764이 contact_conditioning 행렬을 pair에 쓰고 trunkv2.py:27-57이 모든 diffusion step을 편향. base 모델 경로라 steering 루프와 무관.
- interface-steering 캠페인 장치 전체는 no-op/ranking: 목적함수 iPTM-only(biophysical_scorer.py:753-758 key_residue 비면 dist=0.5 중립), FragMap gradient=0(fragmap_steering.py:926-947), w400 early-return no-op(w400_conditioning.py:118-126), FK filter/lambda=ranking-only, diffusion_samples 코드서 1로 강제, use_potentials gated off.
- A-vs-AB retro-validation: AB arm이 더 나은 register를 낸 건 자기도 모르게 LON site를 넣었기 때문(추가 pocket [A,104-109]=canonical LON-loop 149-154, [B,32-41]=nSrc-loop incl K815, contact [A,106=G151]↔[B,35]). two-site 원칙이 기존 데이터로 이미 검증됨.
- 외부 검증(NSMB 2026 G3BP2 논문 + 우리 9NFR 실측): CRBN 인지 자리 = CULT(degron-mimicry) + LON(natural-PPI-mimicry). VAV1 = CULT primary(RT-loop→N351/H357/W400) + LON secondary(K815→F150/G151/I152). 9NFR 좌표서 K815↔I152 3.59Å 확인.

목표: register-correct 생성으로 VAV1 SAR 시리즈의 **structure→DC50 상관**을 세워 하류 차별화(potency/productive-geometry)의 해자를 검증.

## ver2 recipe (코드 변경 없음 — config-only)
base `boltz predict` + 아래 constraints YAML + 다중 seed. steering 플래그 전부 미사용.
- KEEP: --checkpoint, --recycling_steps, --sampling_steps, --step_scale, --seed(앙상블), MSA depth(--num_subsampled_msa/--max_msa_seqs)
- REMOVE: --use_interface_steering 및 그 하위 전부(num_particles, interface_scoring_type, interface_lambda, resampling/lambda_schedule/score_smoothing/potential_type, biophysical_*, fragmap_config, 모든 w400_*, enable_interface_gd+interface_gd_*+gd_start_t, interface_guidance*), use_potentials, diffusion_samples, blind_patch_*, template_steering_config
- OPTIONAL(기본 off; soft-only 부족 시만): crl_closure_*(9UUM 어셈블리 기하), md_reference_*(MD restraint)

### two-site soft contact 블록 (번호 검증 완료 14/14: CRBN local+45=canonical, VAV1 local+781=uniprot)
```yaml
constraints:
  # CULT degron (mutagenesis 검증 triad)
  - contact: {token1: [B, 15], token2: [A, 355], max_distance: 6.0, force: false}  # R796 ↔ W400
  - contact: {token1: [B, 16], token2: [A, 312], max_distance: 6.0, force: false}  # D797 ↔ H357
  - contact: {token1: [B, 18], token2: [A, 306], max_distance: 6.0, force: false}  # S799 ↔ N351
  # LON site (신규; F150A·cryo-EM 검증)
  - contact: {token1: [B, 34], token2: [A, 105], max_distance: 6.0, force: false}  # K815 ↔ F150
  - contact: {token1: [B, 34], token2: [A, 106], max_distance: 6.0, force: false}  # K815 ↔ G151
  - contact: {token1: [B, 34], token2: [A, 107], max_distance: 6.0, force: false}  # K815 ↔ I152
  # glue pocket (binder=C): warhead→tri-Trp, tail→VAV1 degron  (기존 YAML서 가져와 유지)
```
원칙: 검증 접촉(CULT triad + LON K815)만 건다. Y355/H353/H397은 안 건다 — register 맞으면 따라오는 독립 readout(순환 방지).
가드: ver2.yaml 실제 서열로 위 local 인덱스 잔기정체 재확인(B 15/16/18/34=R/D/S/K, A 306/312/355/105/106/107=N/H/W/F/G/I).

## Phase 1 — parent 파일럿 (게이트)
parent = MRT-23227(9NFR 글루). 동일 시스템·MSA·체인.
| arm | config | 기대 |
|---|---|---|
| arm0 | 구식(full interface-steering, CULT-only 제약) | 기존 재현 기준선 |
| arm1 | ver2(base predict, steering 없음, soft two-site) | 9NFR 재현 ≥ arm0, 비용 분수 |
| arm2(필요시) | ver2 + crl_closure | arm1 부족 시 어셈블리 기하 보강 |
- seeds: 8/arm. 채점(zero-GPU): SH3c CA-RMSD vs 9NFR, two-site 접촉 회복(CULT 3 + LON K815), Y355 χ1·H353 접촉(독립 readout), seed-pairwise 수렴, **생성당 wall-clock/GPU 비용**.
- 게이트: arm1이 arm0 이상 재현 + 수렴 + 비용↓ → ver2 채택. 부족 → arm2.

## Phase 2 — SAR 시리즈 → 상관 (게이트 후, vav1-ubq Stage D 조율)
congeneric DC50 시리즈(S001 등) 각 analog을 ver2로 생성(register 앵커, tail 변이 살림) → MD → productive near-attack 점유율 → Spearman(occupancy, logDC50), 가드레일(scaffold-blocked·OOF·permutation·n≥30). PASS=유의+방향일관 → 하류 모델 해자. KILL=재검토.

## Constraints
- allowed: 신규 WS dir(/mnt/kfs1-4,7; kfs5/6 가득), 신규 ver2 YAML/런처/채점 스크립트(analysis/). 코드 변경 없음.
- forbidden: 엔진 소스(diffusionv2_extend.py 등) 수정 금지, #12 dirty WIP 미접촉, 기존 실험 출력 변경 금지.
- external GPU: boltz-native un-containerize + sudo -u kim sbatch --qos=normal(또는 batch), free-GPU mem.free>75GB, 출력 chmod 777.

## Coordination
aigen-fold-core owner cb49c216(엔진), vav1-ubq 2a89764f(productive geometry MD = Phase 2), sar 55e87e7b(DC50). ver2는 코드 무수정·config-only라 엔진 충돌 위험 낮음. GPU 동시사용만 조율.

## Done When
- Phase 1 파일럿 완료 + 채점 TSV(RMSD/접촉회복/수렴/비용) + arm0 vs arm1 판정 → ver2 채택 여부.
- (Phase 2) structure→logDC50 상관 PASS/KILL 판정.

## Rollback
```bash
sudo -u kim scancel <JOBIDS>; sudo -u kim rm -rf <new WS out/logs>
```

## Progress Log
- 2026-06-30: 3 병렬 audit(CLI/steering/constraint) + 자체 실험 종합 → ver2=config-only(base predict + soft two-site contact, steering 장치 전체 제거) 확정. two-site 번호 검증 14/14. 본 contract 초안. status pending: 사용자 승인 + owner 조율 + GPU.
- 2026-06-30: 사용자 승인 → approved. GPU 실행. smoke(seed42, host-5-62 idle A100) PASS: SH3c RMSD vs 9NFR=3.98A, 두 자리 형성(CULT 3.1-3.5A + LON K815-I152 3.84A), 14s, steering 0개. ★Phase1 게이트 PASS: ver2 ≈ 옛 best-steered(~4A) at ~20x lower cost.
- 2026-06-30: ★9NFR 재생성 96-seed array(job 11918, 8x12) 완료. SH3c RMSD median=3.58A, min=2.62A, <=4A 66%/<=5A 79%/<=6A 80%; CULT degron 거의 항상 tight, LON secondary(all-6 9/96), Y355 trans 21/96(readout, RMSD와 무상관 — 결정인자 아님 재확인). 신뢰가능한 9NFR 재생성 확립. 결과=ver2_pilot/results/ver2_9nfr_regen_scores.txt. 다음: Phase2(SAR 시리즈 생성→MD→productive geometry→logDC50 상관) = vav1-ubq Stage D 조율.
