---
contract: .agent/contracts/aigen-fold-core-vav1-degrad-head-v1-20260702.md
slice: aigen-fold-core
status: pending
total_tasks: 22
estimated_total_min: 95
---

# Plan — VAV1 degradation-ranking head v1

경로 약칭: WS=`/mnt/kfs2/data/users/ubuntu/vav1_degrad_head_20260702`,
P0=`/home/ubuntu/.agent/scratch/vav1_degrad_head/phase0`,
HOST=`/home/ubuntu/FKSFold-Boltz_Advancement`.
속도 우선: Phase 1(T2-T7)·Phase 0.5(T8)·Phase 2(T9)는 서로 독립 → 병렬. Phase 2(hook)만 GPU(T12) critical-path 선행.
⛔ 승인 게이트: T12(SLURM 배치 제출). T9 커밋은 host 코드라 확인 필요.

---

## Task 1: workspace scaffold
- **Status**: pending
- **Prereq tasks**: none
- **Files touched**: `WS/` (신규 dir), `WS/data/vav1_dataset_final.csv`
- **Change shape**: `WS/{data,inputs,latents,poses,features,models,logs,src}` 생성(chmod 777 logs/latents/poses/models), P0의 `vav1_dataset_final.csv`(388) 복사.
- **Verification**: `ls WS/{data,inputs,latents,poses,features,models,logs,src}` 8 dir + `wc -l WS/data/vav1_dataset_final.csv` = 389.
- **Estimated time**: 2 min
- **Rollback**: `rm -rf WS`

## Task 2: label pre-registration (lookahead 차단)
- **Status**: pending
- **Prereq tasks**: 1
- **Files touched**: `WS/src/label_register.py`, `WS/data/LOCKED_LABEL.md`, `WS/data/labels.parquet`
- **Change shape**: 388에 3후보(dc50≤1000&dmax≥50, dc50≤500&dmax≥70, dmax≥50) 계산·class balance/tier 분포 보고. 사전등록 규칙(positive rate 10-50%, 복수면 Dmax 임계 낮은 것) 적용해 primary 라벨 1개 선정, 근거를 LOCKED_LABEL.md에 고정. binary(active/inactive) 컬럼 저장.
- **Verification**: `python WS/src/label_register.py` → LOCKED_LABEL.md에 선정 라벨+positive rate(∈[10,50]%); labels.parquet 388행.
- **Estimated time**: 4 min
- **Rollback**: 파일 3개 삭제

## Task 3: assay_diversity_check
- **Status**: pending
- **Prereq tasks**: 1
- **Files touched**: `WS/src/assay_check.py`, `WS/data/assay_conditions.txt`
- **Change shape**: 원본 `AIGENFold/data/VAV1_Analysis_Part_*.csv` 컬럼 스캔해 assay 조건(측정법/cell line/농도/시점) 컬럼 유무·고유값 emit. 단일이면 OK, >1이면 BLOCKING 표시 + 사용자 보고.
- **Verification**: `python WS/src/assay_check.py` → assay_conditions.txt에 고유 조건 목록 + `SINGLE` 또는 `BLOCKING`.
- **Estimated time**: 3 min
- **Rollback**: 파일 2개 삭제

## Task 4: censoring scan + GBDT decision
- **Status**: pending
- **Prereq tasks**: 1
- **Files touched**: `WS/src/censor_scan.py`, `WS/data/censoring_report.json`
- **Change shape**: DC50에서 censoring 마커(>, <, N.D., limit, 결측) 검출 → censoring rate, certain-order 필터로 drop되는 censored-censored pair 수(abs/%), fold별 잔여 n 산출. 규칙: dropout>15%면 `gbdt_excluded=true`, <5% keep, 5-15% risk-flag.
- **Verification**: `python WS/src/censor_scan.py` → censoring_report.json에 rate + drop% + `gbdt_excluded` bool.
- **Estimated time**: 4 min
- **Rollback**: 파일 2개 삭제

## Task 5: RDKit2D ligand descriptor
- **Status**: pending
- **Prereq tasks**: 1
- **Files touched**: `WS/src/ligand_desc.py`, `WS/features/ligand_desc.parquet`
- **Change shape**: 388 SMILES에 표준 2D RDKit descriptor(~200: MW/LogP/TPSA/HBD/HBA/rotatable/aromatic 등) 계산, z-score 정규화, raw+norm 저장. NaN/inf는 열 drop 또는 median-impute하고 로그.
- **Verification**: `python WS/src/ligand_desc.py` → ligand_desc.parquet 388행 × D열(D≈200), NaN=0(또는 처리 로그).
- **Estimated time**: 4 min
- **Rollback**: 파일 2개 삭제

## Task 6: ranking-pair tables
- **Status**: pending
- **Prereq tasks**: 2, 4
- **Files touched**: `WS/src/build_pairs.py`, `WS/data/pairs.parquet`, `WS/data/pair_stats.md`
- **Change shape**: global≥3x / within-scaffold≥3x / hard(Dmax<50 vs ≥80 same scaffold) / tier ordinal pair 인덱스 + 그룹 weight 생성. censored certain-order 필터(순서 확정 pair만) 적용. fold별 pair 수 보고. scaffold-split fold는 phase0의 fold 컬럼 사용.
- **Verification**: `python WS/src/build_pairs.py` → pair_stats.md에 그룹별 수(censor-필터 후, global~50,517 근사·within~555·hard~89) + fold별 count.
- **Estimated time**: 5 min
- **Rollback**: 파일 3개 삭제

## Task 7: production-recipe 입력 YAML (seed 16/123/300 × 388)
- **Status**: pending
- **Prereq tasks**: 1
- **Files touched**: `WS/src/make_inputs.py`, `WS/inputs/` (388×3 YAML)
- **Change shape**: production recipe(**Pfull + S2_LON + max_distance 5Å**, S2_Walt 동등 대안)로 CRBN(+DDB1 per recipe)+VAV1+MGD+MSA 입력 YAML을 388 compound × **seed 16/123/300(K=3)** 생성. SMILES는 phase0 canonical, MSA는 shared_msa 재사용. 5-contact combo·d6+·Pcult/Pnone 미사용.
- **Verification**: `python WS/src/make_inputs.py` → `ls WS/inputs/*.yaml | wc -l` = 1164; 랜덤 1개 파싱 OK + recipe 파라미터(Pfull, S2_LON, d5, seed∈{16,123,300}) 확인.
- **Estimated time**: 5 min
- **Rollback**: `rm WS/inputs/*.yaml`; 스크립트 삭제

## Task 8: power simulation → gate2 형태 확정
- **Status**: pending
- **Prereq tasks**: 1
- **Files touched**: `WS/src/power_sim.py`, `WS/data/power_sim.md`
- **Change shape**: 대형 12 scaffold(135 화합물)에서 12-scaffold 5-fold(~27/fold)와 LOSO(~11/fold)의 per-fold n·bootstrap CI 폭·δ=0.05 power를 시뮬(합성 ρ 또는 hand-contact 대용). 5-fold가 primary로 충분한지(CI≤±0.20/power≥0.70) 판정, 부족 시 대안 명시.
- **Verification**: `python WS/src/power_sim.py` → power_sim.md에 per-fold n + CI 폭 + `gate2_primary=5fold` 또는 재설계.
- **Estimated time**: 5 min
- **Rollback**: 파일 2개 삭제

## Task 9: boltz2.py latent-dump hook (host 코드, additive)
- **Status**: pending
- **Prereq tasks**: none
- **Files touched**: `HOST/src/boltz/model/models/boltz2.py`
- **Change shape**: `--dump_latent`(기본 OFF) 시 forward의 trunk s,z + token→residue map + confidence-module 표현을 npz로 저장하는 additive hook. 기존 forward 로직/출력 불변(플래그 OFF면 no-op).
- **Verification**: 플래그 OFF로 1 compound predict 결과가 hook 추가 전과 byte-identical(좌표/confidence diff 0); 플래그 ON smoke는 T12/T11 smoke에서.
- **Estimated time**: 5 min
- **Rollback**: 해당 hunk surgical revert(git restore 아님)

## Task 10: interface-pool + PCA 유틸
- **Status**: pending
- **Prereq tasks**: 9
- **Files touched**: `WS/src/pool_latent.py`
- **Change shape**: dump된 s,z + map을 읽어 계면 토큰(CRBN N351/H357/W400+LON, MGD 전원자, VAV1 RT-loop/K815/W820) contact-based<5Å masked-pool(pair z cross-block + single s group) → compound_vec; PCA(32-50, 90% var, dim>50이면 halt) fit/transform 저장. 1-compound smoke로 단위 검증.
- **Verification**: smoke dump에 `python WS/src/pool_latent.py --smoke` → 고정 dim 벡터 출력, contact-mask<5Å 확인, NaN 없음.
- **Estimated time**: 5 min
- **Rollback**: 스크립트 삭제

## Task 11: SLURM 런처 (K×388, ≤16 GPU) [zero-GPU 작성]
- **Status**: pending
- **Prereq tasks**: 7, 9
- **Files touched**: `WS/run_batch.sh`
- **Change shape**: un-containerized native boltz로 K×388 forward를 ≤16 GPU(2노드×8 또는 가용) 병렬 실행하는 sbatch 스크립트. free-GPU selector(mem.free>75GB), `--dump_latent`, production recipe, 출력 WS/{latents,poses}, world-writable, kim 제출용 헤더(account=default/qos=normal). 재시도/skip 로직.
- **Verification**: `bash -n WS/run_batch.sh`(문법) + 1-compound smoke 셀(≤1 forward)로 latent npz + pdb 생성 확인(제출 아님).
- **Estimated time**: 5 min
- **Rollback**: 스크립트 삭제

## Task 12: ⛔ K×388 배치 제출 + 감시 (승인 게이트)
- **Status**: pending
- **Prereq tasks**: 11
- **Files touched**: (출력) `WS/latents/`, `WS/poses/`, `WS/logs/`
- **Change shape**: `sudo -u kim sbatch WS/run_batch.sh` 제출(⛔ 사용자 "go" 필요). 첫 셀 로그 포그라운드 감시(오류 즉시 보고). token-map<99.5%면 halt+로그.
- **Verification**: K×388 `*_model_0.pdb` + latent npz 생성; token 매핑 ≥99.5%; SLURM state COMPLETED.
- **Estimated time**: 5 min 작업 + 몇 시간 wall
- **Rollback**: `scancel`; WS/{latents,poses} 삭제

## Task 13: features.parquet (pool+PCA+RDKit2D) + contact-freq QC
- **Status**: pending
- **Prereq tasks**: 12, 10, 5
- **Files touched**: `WS/src/build_features.py`, `WS/features/features.parquet`, `WS/features/contactfreq_qc.md`
- **Change shape**: 388 전체에 interface-pool→PCA(T10 규칙)→RDKit2D append(PCA 밖). contact-freq QC(compound<50%면 flag; >5%가 <50%면 halt+pooling 수정). full-s,z 별도 저장.
- **Verification**: `python WS/src/build_features.py` → features.parquet 388행 고정 dim + contactfreq_qc.md 히스토그램 + halt 여부.
- **Estimated time**: 5 min
- **Rollback**: 파일 삭제

## Task 14: pose-conditioned 집계 + z-probe
- **Status**: pending
- **Prereq tasks**: 12
- **Files touched**: `WS/src/pose_features.py`, `WS/features/pose_features.parquet`, `WS/data/z_probe.md`
- **Change shape**: K pose의 confidence-module 표현 + geometry + confidence를 confidence-가중 mean(분산>0.2면 median) 집계. z-probe: subset(~10)에서 VAV1 토큰 마스킹 시 distogram inter-chain 저하 산출(비블로킹 진단). seed-stability(within-compound pose RMSD) 산출.
- **Verification**: `python WS/src/pose_features.py` → pose_features.parquet + z_probe.md(drop 값) + seed_stability median.
- **Estimated time**: 5 min
- **Rollback**: 파일 삭제

## Task 15: hand-contact baseline 388 재계산
- **Status**: pending
- **Prereq tasks**: 12
- **Files touched**: `WS/src/baseline_handcontact.py`, `WS/models/baseline_388.json`
- **Change shape**: ARG796-engagement feature(rotamer 모델, 거리컷≤5Å, 입력=hit pose, 388셋)를 same scaffold-split 5-fold로 계산, fold별 ρ + bootstrap 95% CI 저장.
- **Verification**: `python WS/src/baseline_handcontact.py` → baseline_388.json에 fold별 ρ + pooled ρ±CI + n.
- **Estimated time**: 5 min
- **Rollback**: 파일 삭제

## Task 16: ranking-loss + CV harness (공유 모듈)
- **Status**: pending
- **Prereq tasks**: 6, 13
- **Files touched**: `WS/src/rank_cv.py`
- **Change shape**: pairwise ranking loss(그룹 weight: global w_g init 0.013/within 1/hard 3) + degrader BCE(focal) + tier ordinal; scaffold-split 5-fold CV + 5-7 seed 독립 앙상블(median, per-seed 병기, inflation ρ_ens/ρ_best) 하네스. 모델 클래스 plug 인터페이스.
- **Verification**: `python WS/src/rank_cv.py --selftest`(더미 feature) → CV 루프 완주 + per-seed/ensemble ρ 출력.
- **Estimated time**: 5 min
- **Rollback**: 파일 삭제

## Task 17: loss-grid → top-2 확정
- **Status**: pending
- **Prereq tasks**: 16
- **Files touched**: `WS/src/loss_grid.py`, `WS/models/loss_grid.json`
- **Change shape**: 1 seed + stratified subsample에 w_g∈{0.005,0.013,0.025}·hard∈{1.5,2,3}·deg∈{0,0.2,0.3,0.5} grid → held-out ρ로 top-2 조합 선정.
- **Verification**: `python WS/src/loss_grid.py` → loss_grid.json에 조합별 ρ + `top2`.
- **Estimated time**: 4 min
- **Rollback**: 파일 삭제

## Task 18: co-primary head 학습 (A/B/C)
- **Status**: pending
- **Prereq tasks**: 16, 17
- **Files touched**: `WS/src/train_head.py`, `WS/models/head_{A,B,C}.pt`, `WS/models/cv_metrics.json`
- **Change shape**: (A) linear/ridge pairwise probe, (B) GBDT rank:pairwise+aft(censor gbdt_excluded면 skip), (C) shallow MLP. top-2 loss로 5-7 seed. `--cv scaffold --report`로 §Done When 표 출력. C는 median ρ이 A·B를 >0.03 且 CI 비겹침 ≥3 fold일 때만 승격.
- **Verification**: `python WS/src/train_head.py --cv scaffold --report` → cv_metrics.json에 A/B/C fold별 ρ + ensemble.
- **Estimated time**: 5 min 작업(+ 학습 수 분)
- **Rollback**: 파일 삭제

## Task 19: baseline suite
- **Status**: pending
- **Prereq tasks**: 16
- **Files touched**: `WS/src/baselines.py`, `WS/models/baselines.json`
- **Change shape**: geometry-only, latent-only, ligand-only, label-permuted-null(fold 내 shuffle 1 seed) 4종을 동일 CV로 ρ 산출.
- **Verification**: `python WS/src/baselines.py` → baselines.json 4종 ρ; permuted-null ρ<0.10(아니면 누수 flag).
- **Estimated time**: 4 min
- **Rollback**: 파일 삭제

## Task 20: gate1/gate2 판정 + 통계 검정
- **Status**: pending
- **Prereq tasks**: 18, 15, 19, 8
- **Files touched**: `WS/src/gate_eval.py`, `WS/models/gate_report.md`
- **Change shape**: gate1(latent+ligand held-out ρ≥0.55 且 CI하한>0; baseline-beat CI 비겹침/permutation, escape valve) + gate2(대형 12-scaffold 5-fold ρ≥0.50, LOSO 진단). exploratory(hard-pair Fisher, tier-AUROC pooled CI, Bonferroni α/3). PASS/KILL 판정.
- **Verification**: `python WS/src/gate_eval.py` → gate_report.md에 gate1·gate2 PASS/KILL + p/CI.
- **Estimated time**: 5 min
- **Rollback**: 파일 삭제

## Task 21: ablation + results_v1.md
- **Status**: pending
- **Prereq tasks**: 20, 14
- **Files touched**: `WS/src/ablation.py`, `WS/results_v1.md`
- **Change shape**: feature(trunk/+ligand/+pose-conditioned) · model-class · pooling(pooled vs full) · loss · split(random vs scaffold vs 대형 LOSO) ablation + 중요도 삼각(CVPFI+TreeSHAP+group). pose-conditioned Δρ(vs trunk+ligand) 보고(미채택). results_v1.md에 primary gate 결론.
- **Verification**: `python WS/src/ablation.py` → results_v1.md에 ablation 표 + pose Δρ + go/no-go.
- **Estimated time**: 5 min
- **Rollback**: 파일 삭제

## Task 22: status/handoff 갱신
- **Status**: pending
- **Prereq tasks**: 21
- **Files touched**: `.agent/status/aigen-fold-core.md`
- **Change shape**: v1 게이트 결과(PASS/KILL, ρ, pose Δρ, 다음 단계) 반영 + `./scripts/handoff.sh claude aigen-fold-core` + `./scripts/status.sh index`.
- **Verification**: `head -8 .agent/status/aigen-fold-core.md` 오늘 날짜+bumped version; index 재생성 무경고.
- **Estimated time**: 3 min
- **Rollback**: git으로 status 파일 복원(자기 슬라이스만)
