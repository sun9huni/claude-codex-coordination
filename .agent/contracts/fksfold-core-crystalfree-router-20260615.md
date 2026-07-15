---
status: active
slice: aigen-fold-core
topic: crystalfree-router-ablation-geometry-deepternary
date: 2026-06-15
owner: claude
approved_by: user (2026-06-15, "b 진행")
triggers_matched:
  - "SLURM/GPU evaluation run"
  - "multi-target benchmark criteria"
  - "local repo + shared execution workspace"
---

# Crystal-free / objective router wave — ablation ‖ geometry-decouple ‖ DeepTernary GATE-1

설계 문서 `docs/tpd_steering_advancement_design_20260614.md` §4.1의 NOW-병렬 4건 중
사용자가 **스크린 확장(GPU-heavy)을 빼고 라우터/진단 3건을 먼저** 돌리기로 한 wave.
세 항목은 서로 독립 → 동시 진행. n=4를 늘리지는 않으나(스크린 확장이 그 역할),
**대형 GPU(스크린)를 어떻게 쏠지 결정하는 라우터**다.

## 세 항목

### #2 Anchor-only / pocket-OFF ablation  (ROUTER · GPU-low)
**질문**: 유일한 크리스털 의존 입력(타깃 잔기 중 글루 5Å 이내 = `constraints:` 블록)이
load-bearing인가? 빼도 rescue가 살아남으면 파이프라인은 이미 crystal-free.
- **arm**: 각 `{PID}.yaml`에서 `constraints:` 블록만 삭제(=anchor_only) — biophysical_config
  (key_residues_B = CRBN-side anchor, 서열 유래) + w400 conditioning 유지. target-side
  steering OFF는 기존과 동일.
- **대상**: rescue {9OTY, 9H59, 9Q33, 9DWW} + 음성 {8UH6, 9E2U, 9YA9} (+ borderline 9Q03
  probe), 각 3 seed(42/16/123).
  - 6/7 이미 staged: `/mnt/data/users/ubuntu/workspace/ood_enrichment_screen_20260614/stage/inputs/{PID}.yaml`.
  - 9DWW는 12-panel stage(다른 dir)에서 YAML+biophysical config 회수 필요(staging task).
- **사전등록 결정규칙**: rescue **≥3/4** 이 pocket-OFF에서 DockQ≥0.23 유지 → **crystal-free(헤드라인)**;
  붕괴 → glue-pocket load-bearing → 설계 §4.2 대체물 분기(consensus contact / ligand-face) 활성화.
  음성 3 = "anchor만으로도 통과" 가짜양성 배제 대조(음성이 pocket-OFF에서 올라오면 anchor가
  과하게 끌고 있다는 신호).

### #3 Geometry-driven resampling (iPTM 디커플링)  (INDEP · GPU-cheap, config-only)
**질문**: base score의 overconfident-iPTM 지배(`w_threeway` 기본 1.0, gate `mg_crbn_score`)가
실패의 병목인가, 아니면 prior 한계(backbone)인가? — config-only 확인 완료
(`biophysical_scorer.py:52-58,144-148`, 전부 `bio_data.get`).
- **2-arm** (oracle_generation_heldout_{PID}.yaml biophysical config만 수정):
  - **A** = `gate_source: mg_pocket_dist` (iPTM gate 제거, 기하 게이트로 교체)
  - **B** = A + `w_threeway: 0.15`, `w_dist: 0.85` (iPTM threeway down-weight, 기하 거리 up-weight)
- **대상**: 실패 {8UH6, 9E2U, 9H59} + **9Q33 positive control**, 각 arm 3 seed.
- **사전등록 결정규칙**: 8UH6이 B에서 0.017을 벗어나면 → **iPTM 지배가 병목(objective-limited)**;
  A·B 둘 다 안 움직이고 9H59가 유지되면 → **prior 한계(kinase backbone)=objective 막다른길**
  (이 경우 §4.2 심층 샘플링이 우선). 9Q33가 control로 망가지지 않아야 변경이 무해함이 확인됨.

### #4 DeepTernary consensus GATE-1 + glue-conditioning falsifier  (INDEP · **CPU, no-sbatch**)
**질문**: crystal-free 대체물(§4.2)이 viable한가 + DeepTernary가 glue 정체를 푸는가?
- **GATE-1 전제 = 이미 검증(2026-06-15, zero-compute)**: MolecularGlue `train_clusters.json` +
  `MolecularGlue_cluster.tsv`에 CRBN 패밀리 통째 부재 — 테스트 9개(9OTY/9H59/9Q33/9DWW/9NFR/
  8UH6/9E2U/9YA9/9Q03) 전부 absent, 정전 대조 CRBN ternary(8G66/6XK9/6H0F/5FQD/6BN7/4CI1/5V3O/
  8D7U) 전부 0, 8xxx 177개 존재(시점 컷오프 아티팩트 아님 = 구조적 held-out). → DeepTernary는
  CRBN ternary에 진짜 extrapolation = crystal-free surface predictor로 인용 가능.
- **GATE-1 본 실험 (CPU, `predict_cpu.py`)**: monomer DeepTernary MGD 10-seed (rescue 4 + kill
  8UH6·9E2U) → medoid CRBN-target DockQ vs GT, intra-consensus CB spread, crystal 5Å pocket
  Jaccard. 통과 = consensus가 crystal pocket을 4Å 안에 재현.
- **glue-conditioning falsifier**: Nek7 flip쌍(같은 monomer, 글루 A1ISP/9H59 vs A1BX6/9NFQ)의
  inter-glue 변위가 within-glue spread보다 **작으면 glue-blind → per-glue 게이트 KILL**(있으면 통과).
- sbatch 불필요(CPU ~1s/inference). 이 contract의 sbatch 게이트와 무관하게 즉시 실행 가능.

## SLURM plan (#2·#3 만 — #4는 CPU)
- OUT_BASE: `/mnt/data/users/ubuntu/workspace/crystalfree_router_20260615` (신규, 기존 OOD dir 불변).
- 코드 mount: 검증된 OOD-enrichment stage/src 재사용(fragmap 배선 present).
  Image `fksfold-boltz:glueplex-v2`, QoS batch, 1 node, array `%8`, 2h walltime,
  `PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True`.
- runner: `workflow/slurm_ood_enrichment_20260614.sh` JOBS_TSV override 재사용
  (Phase 2에서 입증된 경로). 신규 manifest 2개:
  - `manifest_ablation.tsv` (anchor_only YAML, ~7-8 target × 3 seed = 21-24행)
  - `manifest_geometry.tsv` (2-arm biophysical config, 4 target × 2 arm × 3 seed = 24행)
- 신규 stager(zero-GPU): `{PID}.yaml`→`{PID}_anchoronly.yaml`(constraints 삭제) +
  oracle config 2-arm 변형 생성 + 두 manifest write. 9DWW YAML 회수 포함.

## Required output
- case_id, target, condition(anchoronly|geomA|geomB), seed, output_pdb, confidence_json,
  DockQ, DockQ_status, iptm, complex_ipde, protein_iptm, generation_status, notes.

## Done when
- #2: anchor_only 채점 완료, rescue 4 + 음성 3 per-target median DockQ, 결정규칙 적용(crystal-free
  YES/NO + §4.2 분기 활성 여부 명시).
- #3: 2-arm 채점 완료, 8UH6 이동 여부 + 9H59 유지 여부 → objective-limited vs prior-limited 판정,
  9Q33 control 무해성 확인.
- #4: GATE-1 medoid DockQ + spread + Jaccard 표, glue falsifier 변위 비교 → viable/KILL 판정.
- 세 결정이 contract progress log + baton + (요청 시) Notion에 기록. silent drop 금지.

## Verification
- 제출 전: `bash -n` SLURM, manifest 행수 dry-count, anchor_only YAML에 `constraints:` 실제 부재
  grep, oracle 2-arm YAML에 w_threeway/w_dist/gate_source 값 grep 확인.
- 생성 후: `*_model_0.pdb` + `confidence_*.json` 카운트, steering-engage 로그("[FragMap]"/interface
  steering enabled) 확인 = silent-disable 아님(fragmap 6488 교훈).
- DockQ: `score_heldout_dockq.py`(GT chain map self-DockQ=1.0 기검증).

## Risks
- repo dirty: 신규 파일만 — 기존 미커밋 파일 git 조작/덮어쓰기 금지.
- #2 anchor_only는 biophysical_config의 key_residues_B(서열 유래, 비순환) 유지 — 이게 크리스털
  유래가 아님을 §1 표로 재확인(crystal 의존 입력은 constraints 블록 하나뿐).
- #3 w_threeway down-weight가 co-success를 깨면 안 됨 → 9Q33 control이 가드.
- iPTM/ipDE는 guardrail(success metric 아님) — 비-rescue도 mean_iptm 0.80-0.90 재확인 예상.
- do-not-fork-the-scorer(vav1-ubq mid-flight): scorer 변경 없이 config/manifest만.

## Rollback
- `scancel <jobid>` array 오작동 시. 신규 OUT_BASE는 사용자 승인 후에만 제거.
- 로컬 stager/config 편집 오류 시 되돌리되 기존 dirty 파일 비접촉.

## Progress log
- 2026-06-15 contract 초안(status pending). 사전 zero-compute 검증 완료: #4 GATE-1 전제(CRBN
  MGD-train held-out, PDB-ID 레벨 충분 검증), #3 config-only 노브 실재(biophysical_scorer.py),
  #2 입력 6/7 staged(9DWW 회수 잔여). 승인 시 stager→smoke→submit(#2+#3 동시 array) ‖ #4 CPU 즉시.
- 2026-06-15 사용자 승인 "b 진행" → status active. (b) = 3 라우터 + 스크린 큐레이션 병렬.
- 2026-06-15 **#2+#3 SUBMIT 완료**. stager `scripts/stage_crystalfree_router_20260615.py`, runner
  `workflow/slurm_crystalfree_router_20260615.sh`(config_name col8 오버라이드 추가). smoke 통과:
  anchoronly 8/8 constraints 제거·sequences 보존; geomA=mg_pocket_dist/0.65/0.35, geomB=mg_pocket_dist
  /0.15/0.85(9Q33 control 포함); 9DWW w400_idx=319. **감사: ablation 비순환 확정** — glueprint.
  pocket_residues/anchor_patch=전 타깃 동일(CRBN-side 상수), key_residues_B=ASHIGWKF 유래 → 크리스털
  입력은 `constraints:` 블록 하나뿐. **job 7059=ablation(24행), 7060=geometry(24행)**, array %8 RUNNING.
- 2026-06-15 #4 DeepTernary GATE-1 = 백그라운드 서브에이전트 진행 중(CPU, no-sbatch).
- 2026-06-15 ⚠⚠ **스크린 확장 큐레이션 = RCSB 코퍼스 소진(중대 발견)**. 94 CRBN(Q96SW2) 엔트리 중
  기사용 29 제외→65 triage: 25=ternary-target 없음(CRBN-DDB1 binary), 5=글루 없음(apo/peptide), 28=
  classic ZnF/short-degron(co-success 제외), 2=SD40 fusion 실은 ZnF 단편 → **진짜 OOD-likely ternary
  = 7 PDB / novel target 3개뿐**: CDK2(9D0W,9D0X), HBS1L(11MR), BRD4(8RQ9,6BN7,6BOY,9SAF). 그런데
  CDK2·HBS1L는 12-패널서 이미 **co-success**(Boltz-2가 잘 놓음) → 실효 신규 OOD novel target ≈ BRD4
  하나(+글루 4종). **"n 4→15 RCSB 큐레이션" 전제가 깨짐** → 설계 공동 1위(스크린 확장 L×I 25) 하향
  재검토 필요(escape 경로 = synthetic hard-negative 또는 신규 deposition 대기 또는 기존 4 심층검증).
  7개는 **BRD4 글루-변이 미니패널**(같은 타깃 4글루)로 glue×interface 의존 직접 검증엔 고가치.
  산출물 /tmp/chosen_meta_expansion_20260615.json + examples/heldout/{7}.cif + GT_CHAIN_MAP +7(self-DockQ=1.0).
- 2026-06-15 **#2 ablation 채점 완료 (job 7059, 24/24, 실패 0)**. ROUTER = **부분 crystal-free(split)**:
  rescue **2/4 pocket-OFF 생존** — 9OTY CK1α 0.736→**0.732**(Δ−0.004, 3/3!), 9Q33 PRDM1 0.455→**0.316**
  (3/3) = anchor+w400만으로 재현(crystal-free). **2/4 붕괴** — 9H59 Nek7 0.580→0.007, 9DWW PDE6D
  0.472→0.005 = glue-pocket load-bearing. 음성 3(8UH6 0.022·9E2U 0.015·9YA9 0.027) 전부 낮게 유지
  (spurious lift 0 = anchor 과구동 아님, 생존 2개 진짜). 9Q03 borderline 붕괴(예상). 사전등록 ≥3/4
  미달 → §4.2 대체물 분기 정당화(단 pocket-dependent 절반 회수 목적). reports_crystalfree_router/metrics_ablation.tsv.
- 2026-06-15 **#4 DeepTernary GATE-1 = KILL 확정 (positive-control 검증 통과)**. 6/6 CRBN medoid DockQ
  0.01-0.08. HARNESS SOUND 입증: in-dist 1FAP=0.298(DT 자체 top1 0.444) + control 2개가 DT 자체
  보고값과 |Δ|0.055 일치 + GT self-DockQ=1.0 전부 + 9NFR=0.078(사전 "4Å/0.23" 주장 **재현 안 됨**).
  "관통 blob"은 rigid-body 재조립 아티팩트(좋은 1FAP도 min 0.09Å)=버그 아님; DockQ가 신뢰 엔드포인트.
  → §4.2 대체물 = **DeepTernary 라우팅 금지**(consensus-contact leg 사망). **경쟁 결과: 우리 steering
  (0.46-0.74)이 SOTA DeepTernary(CRBN OOD서 0.01-0.08, 자기 fail-tail)를 능가** = 검증된 우위.
  보고서 deepternary_gate1_20260615.md (+ positive-control 섹션).
- 2026-06-15 #3 geometry(job 7060) = ablation 뒤 RUNNING(~30min). 백그라운드 콜렉터 에이전트가
  7060 종료 감시→채점→objective-limited vs prior-limited 판정 통지 예정.
- 2026-06-15 **#3 geometry 채점 완료 (job 7060, 24/24, 실패 0) = INCONCLUSIVE (NULL/inert; md5로 적발)**.
  콜렉터 에이전트 1차 verdict는 "PRIOR-LIMITED"였으나 **포즈가 geomA≡geomB≡OOD베이스라인 byte-identical**
  (8UH6·9H59 전 seed md5 동일) → fragmap silent-disable 패턴 의심·검증. 결과: config는 정상 적용
  (geomB 로그 "Weights: w_threeway=0.15, w_dist=0.85"; START config=…geomB.yaml)이나 **w_dist_eff=0.000·
  Gate=1.0000이 전 구간 고정** = 거리/기하 항 dormant. **OOD 원본 8UH6 steered 로그도 w_dist_eff=0.000**
  → 거리항은 처음부터 모든 런에서 비활성(rescue=threeway(iPTM)+GD+w400+pocket 기여). 따라서 gate_source/
  weight 변경이 trajectory에 도달 못 함 = 기하 신호가 objective에 진입한 적 없음. **objective-limited vs
  prior-limited = 미해결**(8UH6·9E2U가 production config서 붕괴 유지란 사실만 확인). 진짜 테스트엔 w_dist_eff=0
  원인(stage_based_dist 게이팅 추정) 디버그 선행 필요. reports_crystalfree_router/metrics_geometry.tsv.
  ★교훈 재확인: byte-identical md5 = silent-inert의 시그니처(fragmap 6488과 동형). config 파일만 검증하지
  말고 effective 값(w_dist_eff)+출력 md5까지 봐야 함.
- 2026-06-15 **#2 ablation 확장 (job 7118, ablation scope 확대)**: crystal-free 분류를 4 rescue → 15
  타깃으로 키움(메커니즘 분석 n 보강 — 사용자 "더 진행"). 신규 7: GSPT1 9HNE·CDK2 9NYR·HBS1L 10AY·mTOR
  9NGT(co-success large-globular 대조) + G3BP2 9OS2·ENL 9DUR(OOD-weak) + 8G66(CK1α easy-construct,
  9OTY hard와 within-target 대조). 전부 WITH-pocket steered ref + GT cif 보유; 9NFR은 GT cif 특수경로
  (/home/ubuntu/)라 제외. **검증 질문: "crystal-free = baseline-easy인가?"** — co-success 4가 trivially
  free로 나오면, CK1α/PRDM1(hard-free) vs Nek7/PDE6D(hard-dependent) 분리가 진짜 메커니즘 신호. stager
  ABLATION_EXPAND 추가 재실행, runner가 기존 24 skip + 신규 21 실행. ‖ 병행: A-13 glue-variant 큐레이션
  (백그라운드 CPU 에이전트, 5FQD·5HXB·6XK9·6BN8/9/B). ‖ GPT deep-research(사용자측, 새 distinct 타깃 탐색).
- 2026-06-15 **#2 ablation 확장 결과 (job 7118, 15타깃 crystal-free map)**: co-success 5(GSPT1 9HNE 0.876·
  CDK2 9NYR 0.485·HBS1L 10AY 0.505·mTOR 9NGT 0.743·CK1α-easy 8G66 0.852) **전부 SURVIVES**(trivially free).
  hard rescue 중 **CK1α-9OTY(0.732)·PRDM1-9Q33(0.316) SURVIVES** vs **Nek7-9H59·PDE6D-9DWW·G3BP2-9OS2·
  ENL-9DUR COLLAPSES**(0.005-0.043). → **"crystal-free = baseline-easy" 반증**: CK1α-9OTY/PRDM1은 HARD
  (baseline 붕괴)인데 anchor+w400만으로 rescue=크리스털 불요. **hard 타깃이 2종**: anchor-rescuable(2:
  CK1α·PRDM1) vs pocket-dependent(4: Nek7·PDE6D·G3BP2·ENL). 이게 메커니즘 핵심 질문.
- 2026-06-15 **fishing 결과 (job 7163, 10 alt-glue baseline) = 숨은 HARD 3 발견**: 8RQ9 BRD4-BD2 **0.030**,
  9D0W **0.054**·9D0X **0.027** CDK2-PROTAC = baseline 붕괴(OOD). **같은 타깃 다른 글루/도메인이 OOD로
  뒤집힘**: BRD4-BD1(6BN7 0.786·6BOY 0.869 easy)인데 BD2(8RQ9 0.030 collapse); CDK2-9NYR(co-success)인데
  PROTAC(9D0W/9D0X collapse). glue×interface 의존 강력 재확인 + **신규 steerable hard case 3**(rescue 증거
  확장 가능). 단 셋 다 PROTAC(엄밀 분자글루 아님). 나머지 7은 easy(0.31-0.92). 산출물 reports_crystalfree_router/
  metrics_{ablation,fishing}.tsv.
- 2026-06-15 **hidden-hard steering 결과 (job 7194) = 0/3 rescue**(정직한 음성): 8RQ9 BRD4-BD2 0.030→0.051
  (max 0.216), 9D0W CDK2-PROTAC 0.054→**0.155**, 9D0X 0.027→0.040 — 전부 sub-accept(steering이 약간
  올렸으나 0.23 미달). 셋 다 **PROTAC**(8RQ9 CFT-1297, 9D0W/9D0X A1A1I) → bivalent modality가 glue-tuned
  파이프라인에 안 맞음(이전 9DUR ENL PROTAC kill·9NFQ kill과 일관). **숨은 hard case는 존재하나 rescue
  안 됨**. clean rescue 여전히 **4**(CK1α·Nek7·PRDM1·PDE6D). 교훈: "더 많은 hard 데이터 ≠ 더 많은 rescue"
  — modality(PROTAC) 제약. 9D0W 0.155=VAV1급 partial 신호. metrics_hiddenhard.tsv.
- 2026-06-15 **WEE1 prospective(job baxwaieg8 진행)**: compound 10(SMILES RDKit 검증, monovalent 분자글루,
  EMD-46922 결합) + WEE1-KD(1X8B 289aa) + CRBN, crystal-free(pocket 없음). GT 좌표 없어 DockQ 불가 →
  map-fit 검증(후속). deep-research wf_3f873f07-0bf로 SMILES 확보.
- 2026-06-15(세션3) **WEE1 prospective confidence 수거 완료 (job 7209, 6런)**: aigen crystal-free vs
  baseline — iptm 0.9148 vs 0.9078(+0.007), ipde 0.577 vs 0.624(−0.047, 개선), 3-seed 타이트. GT 없는
  prospective라 confidence는 정확도 증거 아님(Δ방향만 유의=steering이 interface 불확실↓, 작음). 예측
  6× model_0.pdb. map-fit은 fit 도구 부재(ChimeraX/phenix/TEMPy/mrcfile 전무, gemmi만)로 결정 대기.
- 2026-06-15(세션3) **crystal-free split 메커니즘 규명 = baseline prior basin 접근성**(GT 계면 기하 아님).
  GT 실측 반증: CK1α(생존)·Nek7(붕괴)이 glue 매몰 44/37%·glue-share 0.20/0.20·tgt-CRBN PPI 145/182로
  거의 동일 → "glue 깊이 매몰→CF" 가설 기각. 확정: **anchor-only CF DockQ ≈ baseline best-of-N DockQ**
  (Pearson 0.991/Spearman 0.984, n=13; 예측기 baseline best-of-N≥0.20→CF가능 13/13 정확, 0 오류). 메커니즘
  = anchor+w400는 **prior 증폭기**(basin 생성기 아님): prior가 native basin 가지면(CK1α 0.74·PRDM1 0.22)
  anchor가 lock→CF rescue; 없으면(Nek7 0.015·PDE6D 0.007) glue-pocket만이 새 basin 주입=크리스털 필수.
  n=2:2 underpowered 우려 해소(n=13 monotonic). 보고서 crystalfree_split_mechanism_20260615.md +
  analyze_crystalfree_split_20260615.py. caveat: 예측기는 best-of-N=GT 필요(retrospective); prospective
  GT-free proxy(baseline inter-seed multi-modality)가 후속.
