---
status: approved
slice: aigen-fold-core
topic: vav1-degrad-head-v1
date: 2026-07-02
owner: claude
requested: 2026-07-02
approved_by: sunghoon.kim
revision: 5 (속도 우선 재설계: GPU 풍부(≤16) → K=1-first thrift staging 제거, K=4-6 단일 병렬 배치. z-probe는 배치 출력에서 산출(비블로킹). zero-GPU 검증 게이트(label 사전등록/scaffold-split/null/baseline)는 wall-clock 0이라 유지, 2026-07-02)
cross_slice:
  - "sar — VAV1 DC50/Dmax assay 데이터 원천(AIGENFold/data/VAV1_Analysis), tier 라벨"
  - "vav1-ubq — hand-crafted rotamer-contact 베이스라인(388 재계산), productive-geometry discriminator, strong2 DC50 sweep(pose recipe/hit-rate)"
triggers_matched:
  - "SLURM/GPU submission — K=3(seed 16/123/300) × 388 = 1,164 forward 단일 병렬 배치(최대 16 GPU; K↑ 허용)"
  - "host-repo 코드 변경 — boltz2.py latent-dump hook (additive/flag-gated)"
  - "shared-storage writes — /mnt/kfs2 workspace + latent/pose parquet"
  - "4+ files (clinic, latent hook, extractor, ligand-desc, head 학습, CV 평가)"
---

# VAV1 degradation-ranking head v1 (frozen Boltz-2 latent + ligand descriptor → DC50/Dmax ranking)

## Purpose

Frozen Boltz-2 표현(trunk latent, 그리고 조건부로 pose-conditioned latent) + 리간드 descriptor에
VAV1 분해 활성 신호가 있는지, 우연(prior 0/36 FDR 구조-채점 null)을 넘고 hand-crafted contact
baseline을 이기는지 결정한다. "구조모델 표현 → assay phenotype 번역기"의 make-or-break 게이트.

⚠️ 생성 상태 종속. Boltz-2 표현은 현재 frozen + production recipe 상태에서 수집된다. 생성
파이프라인을 고치면 표현이 바뀌므로 재검증/재수집 필요. v1 결론은 이 환경에 한해 유효.

## Current State

**Phase 0 데이터 클리닉 DONE. 수치 전부 최종 388셋.**
- 원천 `AIGENFold/data/VAV1_Analysis_Part_1~3.csv`(dedup 403) → N=388. 제외 broken SMILES 9
  (144,151,279,294,396,416,422,426,460) + assay 없음 6(134,147,191,192,398,399).
- tier A=274/B=67/C=47. DC50 1.56–13,797.8nM(3.9 decades). Dmax median 91%, tail <20% 3/<50% 31/<70% 59/<80% 96.
- scaffold 221 고유, 크기≥5 12개(135 화합물), singleton 180, 크기≤4 253.
- ranking pair(검증): global ≥3x 50,517 / within-scaffold ≥3x 555 / hard 89 / tier 388.
- 산출 `.agent/scratch/vav1_degrad_head/phase0/`.

**strong2 DC50 sweep(8 congener × 3 seed × recipe = 960 PDB) — 조심스럽게 반영.**
- hit은 recipe 지배(S2_LON/S2_Walt+Pfull+d5 = 24/24; Pcult/Pnone 0/96).
- 성공 pose는 한 9NFR attractor 수렴(high-DockQ 간 VAV1 CA RMSD 0.7-1.0Å).
- DockQ hit ≠ DC50(411@1.99nM hit 9.2% 최저, 390@615nM 73%, inactive 474도 docking).
- ⚠️ n=8 한계: 이 sweep은 "recipe 지배 + DockQ≠DC50"를 보이나, **8 congener로 388 전역의
  "pose 신호 부재"를 단정할 수 없다.** 그래서 우선순위를 리간드 화학+미세계면으로 두되,
  pose 경로는 죽이지 않고 gate1 실패 시 재고. production recipe = S2_LON/S2_Walt+Pfull+d5.

**method 리서치(deep-research, 인용 검증) — 조심스럽게 반영.**
- dense frozen embedding에선 linear-probe/MLP가 트리와 경쟁(engineered-tabular 트리우위와 별개) → co-primary.
- 구조 embedding은 소규모(<~5k)에서 약할 수 있음(Boltz-2 PPI r=0.153@n=248, 단 이는 PPI
  과제라 ligand-binding에 직접 전이 아님) → RDKit2D 리간드 descriptor는 **신중한 헤지**(필수 아님,
  Phase 5 ablation으로 기여 확인).
- pairwise>listwise; pairwise 샘플링이 imbalance 흡수. PCA 32-50. 중요도 CVPFI+TreeSHAP+group-ablation.
  uncertainty ensemble+conformal.

**Boltz-2 아키텍처:** trunk s,z(L504)는 diffusion(L585) 전 1회(pose-불변, compound-level).
confidence 모듈은 생성 좌표 입력받아 pose-conditioned 표현 생성.

**베이스라인:** rotamer-contact −0.505는 historical n=12 → 388 same-CV 재계산+bootstrap CI가 게이트 기준.

## Assumptions And Questions

- **single-assay**: Phase 1 `assay_diversity_check`로 원본 assay 조건 스캔. single ≡ 동일 측정법+cell
  line+readout. 이질 시: 소수 drop / 다수 stratified-pair / 불명 blocking.
- **primary 라벨 — 사전등록 규칙(lookahead 차단).** 3후보(dc50≤1000&dmax≥50, dc50≤500&dmax≥70,
  dmax≥50)를 388 전체에 계산해 class balance + tier 분포 보고. **선택 규칙을 Phase 3 GPU 제출 전
  문서로 고정: positive rate 10-50%인 것 채택, 복수면 Dmax 임계 낮은 것.** 사후 재선택은 컨트랙트
  위반(Round 2로 이연).
- **z-신호 전제(게이트 crux)**: trunk z가 CRBN-VAV1 계면 belief를 담는지 — 배치 출력 subset에서
  VAV1 마스킹 z-probe로 진단(비블로킹); 미달이면 pose-conditioned 신뢰 안 하고 trunk+리간드로.
- **censored 규모(open, Phase 1)**: censoring rate + certain-order 필터로 drop되는 pair 수 미측정 →
  Phase 1에서 측정 후 GBDT co-primary 채택 여부 결정.
- **pose-conditioned가 기여하나**: v1에선 **완전 exploratory**(보고만, 채택 안 함). n=8 sweep이
  pose 신호 약함을 시사하나 단정 불가라, 측정하되 v1 모델엔 안 넣는다.

## Constraints

- allowed: `boltz2.py` latent-dump hook만 additive·flag-gated(`--dump_latent`, 기본 OFF). 나머지
  스크립트는 workspace/scratch.
- forbidden: Boltz-2 fine-tuning; WIP 파일(crl_closure_*, diffusionv2_extend) 접촉; production
  ranking/scoring 변경.
- pose 생성 recipe 고정: S2_LON/S2_Walt+Pfull+d5. Pcult/Pnone negative control만.
- external: `sudo -u kim sbatch`; 출력 kfs1/2/3/4/7 world-writable; hook 커밋 surgical + WIP 조율.

## Non-Goals (v1 밖)

- 대형 K(>6) pose ensemble, productive-diversity 집계.
- pose-conditioned latent을 v1 최종 모델에 채택(v1은 report-only exploratory; 채택은 Round 2, Δρ≥0.05+독립검증).
- 연속 Dmax 회귀/multi-task(degrader BCE는 이진).
- counterfactual, cell-context, e2lys geometry, 큰 transformer/GNN, cross-target, 재학습/from-scratch.
- B200 이전(K=3×388=1,164 단일 배치는 ≤16 A100로 몇 시간; B200은 Round 2 대규모 때 재검토).

## Design (v1 확정 스펙)

**pose 생성 — 단일 병렬 배치(속도 우선).** production recipe = **Pfull pocket + S2_LON(기본;
S2_Walt 동등) + max_distance 5Å**, **검증 seed 16/123/300(K=3 base, 이상 허용)**. strong2에서 8
congener 전부 3/3, DockQ floor ~0.60, 실패 0(inactive 474도 3/3); 5-contact combo(S2+LON+Walt)도
d5서 동일 천장이라 미채택(단순 recipe 유지). GPU 풍부(≤16)라 **K×388을 한 배치로 최대 16 GPU 병렬**
생성(K=3이면 1,164 forward, 몇 시간). trunk latent(pose-불변, primary)는 공짜로, pose-conditioned
latent(exploratory)도 같은 배치에서 확보. K는 다양성이 아니라 coverage/seed-stability용(strong2: 성공
pose 한 attractor). ⚠️ 이 recipe는 **pose 구조 생성용이지 potency 판별용 아님**(DockQ는 선택기준/proxy
금지). GPU-thrift 직렬 staging만 제거; zero-GPU 검증 게이트(label 사전등록/scaffold-split/null/baseline)는
wall-clock 0이라 유지.

**feature 스트림(무게중심 = trunk + 리간드).**
1. [primary] trunk s,z interface-masked-pool(contact-based <5Å; pair z 주, single s 보조) → PCA.
2. [primary] RDKit2D 리간드 descriptor(~200 표준 2D: LogP/TPSA/MW/HBD/HBA/rotatable 등), z-score,
   **PCA 밖에서 append**(embedding과 공동축소 안 함), raw 저장(ablation용).
3. [exploratory, v1 미채택] pose-conditioned latent(confidence-module 표현) + geometry + confidence,
   K pose를 confidence-가중 mean(z_agg=Σconf_i·z_i/Σconf_i; conf 분산>0.2면 median)으로 집계.
   Δρ(trunk+ligand+pose vs trunk+ligand)를 95% CI+permutation p로 **보고만**.

**차원.** PCA는 train-fold embedding에 적합. 90% variance가 dim<32면 32(하한) 사용; dim>50 필요면
halt+escalate(중복 feature). 최종 dim+transform 저장(추론 일관).

**모델 — co-primary(scaffold-split ranking으로 선택).**
- (A) linear/ridge pairwise probe, −log σ(ŷi−ŷj) (PRIMO식). honest baseline-to-beat.
- (B) GBDT rank:pairwise + censoring용 survival:aft. (단 censored dropout>15%면 co-primary서 제외.)
- (C) shallow MLP(→64→1) pairwise — median ρ이 A·B를 >0.03 且 fold별 CI 비겹침 ≥3 fold일 때만 승격, 아니면 GBDT default.

**loss(가중치 = 초기값, Phase 5b grid로 확정).**
`L = w_g·L_rank_global + w_w·L_rank_within + w_h·L_rank_hard + w_d·L_deg + w_t·L_tier`.
초기값 w_g=0.013(그룹 pair-수 균형), w_w=1, w_h=3, w_d=0.3, w_t=0.2. **Phase 5b 경량 grid**
(1 seed + stratified subsample): w_g∈{0.005,0.013,0.025}, w_h∈{1.5,2,3}, w_d∈{0,0.2,0.3,0.5} →
held-out ρ로 top-2를 Phase 5c(5-7 seed)로. 최종은 data-driven, `loss_grid.json` 보고. imbalance는
pairwise 샘플링이 흡수(scale_pos_weight 아님). degrader BCE는 이진(확정 라벨), focal.

**censored.** certain-order pair만(순서 확정 시). GBDT는 survival:aft(dropout<15%일 때). 고정값 imputation 금지.
test-time censored compound는 test서 제외 또는 upper-bound impute만.

**중요도/불확실성.** CVPFI(k≥5, mean+std)+TreeSHAP+group-ablation, ≥2 일치만. uncertainty=5-7 앙상블
std + scaffold-disjoint calibration split conformal(단 fold당 train~330에서 calib 10% 감당 확인, 아니면 Round 2 이연).

## Done When

측정 전부 scaffold-split 5-fold held-out. 게이트 = primary 2개; 나머지 exploratory.

**Primary gate 1 — 신호+유의성+baseline.** latent+리간드 head held-out 평균 Spearman ρ(pred, logDC50)
≥ **0.55** 且 bootstrap 95% CI 하한 > 0(H0 ρ≤0 기각). **KILL iff ρ<0.55.** baseline-beat: baseline과
latent를 **동일 5-fold**에서 평가, beat = 95% CI 비겹침 OR within-fold label-shuffle permutation
(10k, α=0.05, two-tailed on ρ_latent−ρ_baseline). **escape valve**: 재계산 baseline CI가 0을 포함하거나
하한 ≤0.35면 gate1은 ρ≥0.55 & CI하한>0으로 축소(baseline 비교 생략).

**Primary gate 2 — 일반화.** 대형 12 scaffold(135 화합물)에서: **5-fold CV(~27/fold) ρ ≥ 0.50를
primary로**(검정력 충분). 12-scaffold LOSO(~11/fold)는 **진단으로 보고**(power 부족). 단 Phase 0.5
power-sim에서 5-fold도 부족(CI>±0.20/power<0.70)이면 gate2 재설계. 소형(≤4) 253화합물은 exploratory.

**pose-conditioned(primary 아님, report-only).** K=4-6을 처음부터 한 배치로 생성하므로 별도 K-scale
gate는 없다. pose-conditioned latent은 v1에서 exploratory(Δρ+CI+permutation 보고, 미채택). z-probe는
배치 출력에서 산출해 "z가 계면 belief를 담나"를 진단(비블로킹); 미달이면 pose-conditioned 신뢰 안 하고
trunk+리간드 결론을 정본으로.

**Exploratory(보고만, gate 아님; Bonferroni α=0.05/3).**
- pose-conditioned Δρ(vs trunk+리간드) + 95% CI + permutation p (v1 채택 안 함).
- hard-pair(89, fold당 ~18): fold별 binomial(H0 p=0.5, two-tailed) → Fisher χ²(2k).
- tier AUROC(A-vs-C, held-out): fold별 → bootstrap-pooled 95% CI.
- label-permuted null: logDC50를 fold 내 shuffle, 1 seed, ρ_null>0.10이면 누수 flag.

**금지.** DockQ hit을 pose 선택기준/potency proxy로 쓰지 않음.

go/no-go: primary 1 AND 2 통과 → Round 2. gate1 미달 → KILL.

## Implementation Steps

1. **Phase 1 (zero-GPU).** 388 pair/fold 테이블 고정. **label 3후보 계산 + 사전등록 선택규칙 적용,
   문서 고정.** `assay_diversity_check`(>1 blocking). **censoring 스캔**(rate + certain-order drop pair
   수 abs/% + fold별 n; >15%면 GBDT 제외 결정). RDKit2D descriptor(388) 계산. K=4-6 입력 YAML(388×K, seed 다양).
   verify: pairs 테이블 일치; label 규칙 문서화; assay=1 or blocking; censoring 리포트; ligand-desc 388행.
   ※ Phase 1·0.5·2는 서로 독립이라 병렬 진행. Phase 2(hook)만 Phase 3의 critical-path 선행조건.
2. **Phase 0.5 (zero-GPU) — power sim.** hand-contact baseline으로 12-scaffold 5-fold와 LOSO의 per-fold
   CI 폭/power 시뮬. 5-fold 부족 시 gate2 재설계. verify: expected per-fold n + CI 폭 문서.
3. **Phase 2 (host repo, additive).** boltz2.py `--dump_latent` hook(s,z + token map + confidence-repr,
   기본 OFF). smoke: 1 compound shape·NaN·기존출력 byte-불변.
4. **Phase 3 (⛔ SLURM 승인 게이트) — 단일 병렬 배치.** `sudo -u kim sbatch` **K=4-6 × 388 forward를
   최대 16 GPU 병렬**(production recipe S2_LON/S2_Walt+Pfull+d5; free-GPU selector, 2노드×8 또는 가용
   16장; compound×seed 독립 → 완전 병렬, 몇 시간). trunk latent + pose-conditioned latent + confidence 저장.
   token-map 견고성(<99.5% 매핑이면 halt+hand-debug+log). **z-probe는 배치 출력 subset(~10 compound)
   에서 VAV1 마스킹으로 산출**(비블로킹 진단; 임계 미달이면 pose-conditioned 신뢰 안 함).
   seed-stability(within-compound pose RMSD 분산) 산출.
   verify: K×388 latent+pose 저장; token 매핑 ≥99.5%; z-probe drop; seed-stability median; pose hit-rate(참고).
5. **Phase 4 (zero-GPU).** interface-masked-pool(<5Å) → PCA(32-50, 규칙 위) → +RDKit2D(append).
   contact-freq QC(compound<50%면 flag; >5%가 <50%면 halt+pooling 수정). full-s,z + pose-conditioned 집계 저장.
   verify: `features.parquet`(388, 차원 고정) + contact-freq 히스토그램.
6. **Phase 5 — baseline + grid + head.** 5a: hand-contact baseline 388 재계산(ARG796 feature: rotamer
   모델·거리컷≤5Å·입력=hit pose·388셋 동일, same CV, bootstrap CI). 5b: loss-grid(위). 5c: co-primary
   (A/B/C) 학습, top-2 loss, 5-7 seed 독립(median, per-seed 병기, inflation ρ_ens/ρ_best<1.1), early stop.
   5d: baseline 5종(hand-contact-388, geometry-only, latent-only, ligand-only, label-permuted-null).
   verify: `train_head.py --cv scaffold --report` → §Done When 표.
7. **Phase 5-gate.** primary gate1(ρ≥0.55+CI하한>0+baseline-beat/escape)·gate2(대형 5-fold ρ≥0.50) 판정.
   pose-conditioned Δρ는 exploratory 보고(미채택). 통과 → Round 2(K↑/Dmax/counterfactual). gate1 미달 → KILL.
8. **Phase 6 — ablation.** feature(trunk/+ligand/+pose-conditioned), model-class, pooling(pooled vs full),
   loss, split(random vs scaffold vs 대형 LOSO), 중요도 삼각. `results_v1.md`에 primary gate + pose Δρ 보고.

## Change Discipline

- simplest adequate: frozen Boltz-2 + 계면-pool latent + 리간드 desc + 소형 co-primary + pairwise rank.
  pose-conditioned/multi-task/K↑는 gate 후.
- new abstractions: latent hook(gated), pooling/PCA/ligand-desc/co-primary 학습기/baseline 재계산/
  assay-check/z-probe/power-sim — 전부 신규·격리.
- unrelated code touched: 없음(boltz2.py additive hook 1개).

## Verification

- `train_head.py --cv scaffold --report`: fold별 ρ/τ+CI, 388-baseline 비교(CI/permutation+escape),
  대형 5-fold ρ(+LOSO 진단), per-seed vs ensemble(+inflation), pose Δρ, hard-pair Fisher, tier AUROC CI,
  label-null, model-class, top-k. (Bonferroni α=0.05/3 for 3 exploratory.)
- smoke: `predict --dump_latent` 1 compound → 불변.
- z-probe: 배치 출력 subset VAV1 마스킹 → distogram inter-chain 저하(진단, 비블로킹).

## Risks

- **gross pose가 DC50 신호 약함(n=8 시사, 단정 불가)** → pose-conditioned v1 미채택(exploratory),
  무게중심 trunk+리간드, DockQ 선택기준 배제, gate1 실패 시 pose 재고.
- 구조 embedding 약함 가능 → RDKit2D 헤지 + 강정규화 + PCA(단 ablation으로 기여 확인).
- z-신호 부재 → 배치 출력 z-probe가 진단, pose-conditioned 미신뢰(trunk+리간드 결론).
- 검정력: 대형 scaffold 12개 → 5-fold(~27/fold) primary + power-sim 사전확인; LOSO 진단.
- censored: >15% dropout이면 GBDT 제외; certain-order pair.
- lookahead: label 사전등록 규칙; 사후 재선택 금지.
- regression: hook 기본 OFF + byte-불변 smoke. WIP 충돌: 1파일 additive + 조율.

## Rollback

- 신규·격리 산출 삭제 롤백. boltz2.py hook은 surgical hunk revert(WIP 무손실).
- production 분리 → 실패 무손상. GPU는 K=4-6×388 단일 배치(≤16 GPU) 1회 상한, 취소 가능.
- KILL 시 산출(데이터셋·pair·latent·pose·ligand-desc·baseline·power-sim)은 Round 2/앵커 재시도 재사용.
