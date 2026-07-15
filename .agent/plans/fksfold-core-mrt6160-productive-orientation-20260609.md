---
contract: .agent/contracts/fksfold-core-mrt6160-productive-orientation-20260609.md
slice: fksfold-core
status: in-progress
total_tasks: 12
estimated_total_min: 68
---

# Plan — MRT6160 productive 방향 파이프라인

> 방향 스캔(기존 multi-seed + 2C 2차 생성) → M1(SH3-5 lysine→E2 Cys, graded)로 productive 방향 선택 →
> 그 구조 surface 분석. **독립 워크스트림**(M-RELATIVITY 미접촉). 설계 잠금: 1A / 2C / M1·SH3-5 /
> E2 다운로드-선정 / 완전복합체 overlay / surface=게이트 / GPU.
>
> **단계 게이트:** Stage 0–2 = zero/minimal GPU. **Task 9(풀 GPU 스캔)은 Task 8(2C smoke GATE) +
> Task 3(pre-reg 동결) 통과 전 금지.** Task 11(surface)은 산출물 정의 동결 전 blocked.
> fksfold-core dirty tree → **신규 파일만 surgical commit**.

---

## ★ SESSION HANDOFF 2026-06-12 (claude, MRT6160 productive-orientation 워크스트림)

> ⚠️ **슬라이스 baton 주의:** `.agent/status/fksfold-core.md` baton은 현재 *다른* 라이브 세션
> (89d90310, multitarget metric panel + job 6884)이 점유 중 → 이 워크스트림은 그 baton을 **건드리지
> 않음**. 본 plan + contract + `.agent/handoffs/state/session-note.md`가 이 작업의 durable 기록.

**완료 (Tasks 1–7 committed):** E2~Ub=6TTU(촉매 Cys D85)+CRL4 scaffold=2HYE 선정(원안 3LRQ=TRIM37
오기 정정) · 완전복합체 overlay 빌더(complete_structure.py) · M1 scorer(SH3-5 lysine→E2 Cys) ·
PRE-REG 동결(PREREGISTRATION_M1.md) · 기존 multi-seed baseline(M1 30–36Å, crystal NULL 30.8Å) ·
회전 template 생성기(make_rotation_template.py, gemmi-on-base) · **2C forced-template steering 엔진
배선**(Approach A: TemplateReferencePotential 재사용 + diffusionv2_extend 명시 GD hook + main.py
template_steering 플러밍, additive). 엔진 commit: 595b841/6fe5ea6/a66cbd7/65a4bb9/f450c88/409a677/f7f5851.

**Task 8 (smoke GATE) = 통과 + reframing.** 인프라 4버그 수정(경로 /home→/mnt staging · template
CIF gemmi 포맷 · GPU cgroup-idx0/UUID 핀닝[job6692] · RECORD=입력stem+walltime). **2C 메커니즘
검증됨** — target=0에서 4 seed 전부 unsteered 125°→θ_obs~23° 급선회. **방향→M1 트렌드 실재**
(클러스터 30–36Å → θ_obs~54° 23.6Å). **weight 실측: 0.1>0.5**(강한 force는 FK resampling이 기각 →
효력 레버=seed 수). **밀집 스캔(p45/p60/p75 ×16seed @0.1, job 6863/6870/6871)**: rigid-M1이
**~24–26Å 바닥**, ≤25Å≈0, best 후보 θ_obs 54/73/78에 흩어짐 → **방향만으론 rigid floor 못 뚫음.**

**PRE-REG AMENDMENT(2026-06-10, PI 사인오프):** rigid-overlay M1 = 상대 방향 **ranker**로 강등;
진짜 productive judge = **flexibility-aware swept-volume 도달성**(Stage 4 앞당김). 근거: rigid CRL–E2
overlay가 유연성을 못 담아 ~24Å 바닥 = metric 한계(서열/방향 문제 아님).

**▶ NEXT (다음 세션):** **swept-volume 도달성 judge 구현** — 상위 M1 후보(θ_obs~54/73/78의 ~24–26Å
pose: outputs/2Con_{p60_seed123, p75_seed256, p75_seed401}) + 대표 unsteered에 대해, lysine Nζ가
CRL/E2~Ub/측쇄 rotamer 유연성 하에 E2 활성부위에 닿는 cone/부피 산출 → 진짜 productive 판정. 그 후
선택 구조 surface(=swept-volume 자체) 산출. 분석툴 smoke_m1.py(θ_obs vs M1), 출력
/mnt/data/users/ubuntu/workspace/mrt6160_orientation_scan_20260609/outputs/. GPU 게이트: 추가 생성 시
contract 유효(승인됨, <7일).

## Stage 0 — 완전복합체 overlay + E2 확보 [zero-GPU]

## Task 1: E2\~Ub / CRL frame 다운로드 + 가장 적합한 것 선정

- **Status**: pending
- **Prereq tasks**: none
- **Status**: done (2026-06-09)
- **Files touched**: `analysis/productive_pose/refs/README.md` (manifest; .pdb 바이너리는 로컬 유지)
- **Change shape**: CRL scaffold + E2\~Ub frame 후보 RCSB 다운로드·평가. ★**자산 정정**: 원안의
  3LRQ는 TRIM37(CUL4A 아님, 오기) → **CRL4 scaffold = 2HYE(DDB1–CUL4A–RBX1)**. **E2\~Ub = 6TTU**
  (CRL1–UBE2D2~Ub, 촉매 CYS D85 resolved). CRL1→CRL4는 공유 RBX1 RING으로 graft. 각 후보 E2 촉매 Cys/
  해상도/CRL 정합성을 README 표로 기록 + 선정 사유. (좌표 .pdb는 ID로 재현 가능 → README만 git, 데이터 정책.)
- **Verification**: `ls refs/2HYE.pdb refs/6TTU.pdb` 존재 + `grep -c "CYS" refs/6TTU.pdb`>0(=334);
  README에 후보 비교표 + 선정(6TTU + 2HYE). ✅ 통과.
- **Estimated time**: 6 min · **Rollback**: refs 파일 + README 항목 삭제

## Task 2: 완전복합체 overlay 스크립트 + 1-pose smoke

- **Status**: done (2026-06-09; smoke seed42 게이트 PASS SH3 0.308Å/CRBN 1.179Å, 촉매 Cys 존재, M1 preview K788=36.2Å)
- **Prereq tasks**: 1
- **Files touched**: `analysis/productive_pose/complete_structure.py`
- **Change shape**: pose의 chain B(VAV1-SH3)에 full-length VAV1(AF-P15498) SH3를 Cα superpose,
  pose의 chain A(CRBN)+DDB1에 **2HYE(DDB1–CUL4A–RBX1)** 를 DDB1 정합으로 superpose → CUL4A–RBX1 배치,
  그 **RBX1 RING에 6TTU의 RBX1–UBE2D2~Ub를 정렬-graft**해 E2 촉매 Cys(D85) 좌표 복원 → **단일 좌표계
  완전복합체**. 9NFR 앵커 정합 RMSD 로그. (lever_arm_sensitivity.py의 superpose 패턴 재사용, distal
  좌표는 보존하되 M1은 SH3-5만 사용.)
- **Verification**: `python complete_structure.py --pose <one>` → 완성 PDB + SH3/CRBN 앵커 RMSD<2Å 로그
  + 완성체에 E2 촉매 Cys 좌표 존재(stdout 확인).
- **Estimated time**: 7 min · **Rollback**: 스크립트 삭제

## Stage 1 — M1 지표 + 소급 scorer [zero-GPU]

## Task 3: ★ PRE-REGISTRATION 동결 (M1 정의 + 방향 grid + 선택 규칙) [USER CHECKPOINT]

- **Status**: done (FROZEN 2026-06-09, 사용자 사인오프 "동결")
- **Prereq tasks**: 2
- **Files touched**: `.agent/scratch/productive_pose/PREREGISTRATION_M1.md`
- **Change shape**: 동결 — (a) **M1** = 완전복합체에서 SH3 5개(K788/804/810/814/815) 중 **best Nζ→E2
  촉매 Cys Sγ 거리**, graded(거리만, M2–M4는 후속); (b) **방향 grid**(θ 범위·step, 회전축 정의); (c)
  **선택 규칙**(M1 최소 거리 pose = productive, tie-break); (d) **NULL band**(9NFR/mrt23227 crystal에서
  M1 정상 거동 기준선); (e) orthogonality(M1은 steered residue 미참조); (f) **링커 lysine 배제 기록** —
  메커니즘이 표적으로 명시한 K766/K770(+K782)을 M1에서 빼는 사유(레버암 34.8/47.0Å=distal급 + flexible
  pLDDT → rigid 거리 무의미; Stage 4 swept-volume에서 정성 포착)를 명시. committor/양자/DC50 0건.
- **Verification**: `grep -c TBD PREREGISTRATION_M1.md`→0; M1·grid·선택규칙·NULL·orthogonality·링커배제
  6항목 존재. **→ 완료 후 일시정지, 사용자에게 보여줄 것.**
- **Estimated time**: 5 min · **Rollback**: 파일 삭제

## Task 4: M1 graded scorer 라이브러리

- **Status**: done (2026-06-09; seed42 m1_min=36.20Å K788 재현, batch+score_m1() reusable)
- **Prereq tasks**: 3
- **Files touched**: `analysis/productive_pose/m1_score.py`
- **Change shape**: 완전복합체 PDB 입력 → SH3-5 Nζ ↔ E2 Cys Sγ 거리 5개 → best(graded) 반환.
  orthogonal(steered residue 미참조). 단일 pose + 배치 모드.
- **Verification**: `python m1_score.py --pose <completed_one>` → best 거리(Å) + lysine별 거리 5개 출력.
- **Estimated time**: 5 min · **Rollback**: 스크립트 삭제

## Task 5: 기존 multi-seed 소급 적용 + NULL band (방향 스캔 1차 arm)

- **Status**: done (2026-06-09; 기존 M1 30.09–36.20Å@θ100–153°, crystal NULL 30.76Å, 판정=2차생성 필요)
- **Prereq tasks**: 4
- **Files touched**: `analysis/productive_pose/m1_baseline.py`,
  `analysis/productive_pose/complete_structure.py`(build_complex 일반화),
  `analysis/productive_pose/M1_BASELINE.md` (+ `m1_existing_poses.csv` 로컬, 데이터정책상 미commit)
- **Change shape**: 기존 MRT6160 multi-seed pose 전부에 overlay+M1 적용 → 방향 vs M1 분포(1차 arm).
  9NFR/mrt23227 crystal에 동일 적용 → NULL band. **이것이 2차 생성 필요성의 baseline**(기존 pose만으로
  productive 방향이 충분히 샘플됐는지 판단).
- **Verification**: `python -c "import pandas;print(pandas.read_csv('m1_existing_poses.csv').describe())"`
  → pose별 M1 분포; M1_BASELINE.md에 NULL band + "2차 생성 필요" 판단.
- **Estimated time**: 5 min · **Rollback**: CSV+md 삭제

## Stage 2 — 2C forced-template orientation steering 배선 [zero-GPU 코드 + smoke]

## Task 6: 회전 full-complex template CIF 생성기

- **Status**: done (2026-06-09; θ=30→30.000° Kabsch 재측정, SH3 centroid 보존, θ=0 no-op)
- **Prereq tasks**: 2
- **Files touched**: `analysis/productive_pose/make_rotation_template.py`
- **Change shape**: CRBN(고정) + VAV1-SH3(chain B)를 앵커 기준 θ만큼 회전한 **target-orientation
  template CIF** 생성(방향 grid의 각 θ별). 이게 2C가 force할 reference 좌표.
- **Verification**: `python make_rotation_template.py --theta 30 --out /tmp/tmpl_30.cif` → CIF 생성 +
  chain B가 θ만큼 회전됐는지 RMSD/각도 로그.
- **Estimated time**: 5 min · **Rollback**: 스크립트 삭제

## Task 7: boltz_extension에 2C forced-template feat 주입 + guidance 활성화 (ADDITIVE)

- **Status**: done (2026-06-09, engine repo 595b841; Approach A=TemplateReferencePotential 재사용+명시 호출, +37/-0 additive, host self-check b/c/d 통과, full 검증=Task 8)
- **Prereq tasks**: 6
- **발견**: interface 경로는 Potential 리스트 미순회 → fragmap식 명시 compute_gradient 호출로 배선(리스트 append 불가).
- **Files touched**: `src/boltz_extension/steering/` (feat 주입 모듈 + steering-config 블록 핸들러)
- **Change shape**: steering-config의 신규 블록(template CIF 경로 + "force chain B within X Å")에서
  `template_cb`/`template_force`(bool mask)/`template_force_threshold`를 생성해 `TemplateReferencePotential`
  이 읽기 전에 feats에 주입 + guidance group `template` 활성화. **ADDITIVE** — 기존 interface/fragmap
  steering 경로 미변경. baked core featurizer 미접촉(mounted editable 레이어에서만).
- **Verification**: 단위 호출에서 주입 후 `feats["template_force"]`가 chain B 원자에 True + threshold 채워짐
  (assert 스크립트 또는 pytest). 기존 steering 경로 회귀 없음(import/구성 smoke).
- **Estimated time**: 8 min · **Rollback**: 신규 모듈/블록 삭제(기존 경로 무영향)

## Task 8: ★ 2C 활성 smoke [GATE — 풀 스캔 전 필수]

- **Status**: in-progress (SLURM **job 6654** RUNNING 2026-06-09; 6638은 경로버그로 재제출). well-powered 16-run: θ∈{0,30,60}×paired 4seed[42/123/777/314] + 4 unsteered control. ⚠️경로버그 FIX: configs/templates가 /home/ubuntu/analysis(compute 미접근)에 있어 즉시 FAILED → prep이 /mnt stage로 복사 + CIF abs경로 rewrite + slurm SCAN_DIR→/mnt 수정. main.py 6fe5ea6 + engine 595b841 staged, pre-stage 2C-string grep 통과. 분석=smoke_analyze.py: θ_obs가 target θ 추적 + unsteered 클러스터(~100–150°)와 분리 + 로그 [TemplateSteering] active/injected. 통과 시 Task 9 full scan, 실패 시 STOP.
- **Prereq tasks**: 7, 3
- **준비물**: orientation_scan/{templates(12 CIF), configs(12 scan+unsteered+template_steering)}, workflow/slurm_mrt6160_orientation_scan_20260609.sh(+prep), TSV 104행(96 2C+8 unsteered). fragmap 미포함(2C 격리; 9NFR fragmap≈0).
- **Files touched**: `analysis/productive_pose/SMOKE_2C.md` (+ 최소 smoke 출력)
- **Change shape**: 1A config + 2C(template θ 1개) 1-seed 최소 생성 → 로그에 forced-template 활성 확인 +
  생성 pose가 **unsteered 대비 target θ 방향으로 측정 가능하게 이동**했는지(Δorientation) 측정. 이동
  없으면 2C 미작동 → STOP·보고(풀 스캔 금지). **이 task는 minimal GPU 가능 — sbatch면 계약 게이트 통과,
  실행 전 사용자 go 확인.**
- **Verification**: `cat SMOKE_2C.md` → "[template] forced restraint active" 로그 + unsteered 대비
  Δorientation(deg) 표 + PASS/FAIL.
- **Estimated time**: 6 min(분석; 생성 wall-clock 별도) · **Rollback**: smoke 출력 삭제

## Stage 3 — 방향-grid 2차 생성 + 선택 [GPU/SLURM — GATED on Task 8+3]

## Task 9: 방향-grid 2C 생성 (SLURM)

- **Status**: pending (★ APPROVAL GATE: sbatch — Task 8 PASS + pre-reg 동결 + 사용자 go 후에만)
- **Prereq tasks**: 8, 5
- **Files touched**: `workflow/slurm_mrt6160_orientation_scan_20260609.sh`,
  `workflow/prep_orientation_scan_stage.sh`
- **Change shape**: 1A config stage-copy(SHARED→stage) + FragMap target_occupancy(λ=20/p=8) + 2C template
  (θ grid) × seeds로 방향-grid 생성. GPU 풍부 → grid×seed 넉넉히. diffusionv2* + boltz_extension mount
  (fragmap smoke-gate 선례 준수).
- **Verification**: `squeue` 제출 확인 → 완료 후 방향별 pose 디렉토리 존재 + 각 cell 2C 활성 로그.
- **Estimated time**: prep 5 min(생성 wall-clock 별도) · **Rollback**: 생성 출력 디렉토리 삭제

## Task 10: 생성 pose M1 채점 → productive orientation 선택

- **Status**: pending
- **Prereq tasks**: 9
- **Files touched**: `analysis/productive_pose/m1_generated.csv`,
  `analysis/productive_pose/PRODUCTIVE_ORIENTATION.md`
- **Change shape**: 생성 pose 전부 overlay+M1 → 1차(기존)+2차(생성) 통합 방향-M1 분포 → 선택 규칙(pre-reg)로
  **MRT6160 productive orientation 1개 선택** + 선택 구조 경로 확정.
- **Verification**: `cat PRODUCTIVE_ORIENTATION.md` → 선택 pose + M1 값 + NULL band 대비 + 선택 근거.
- **Estimated time**: 5 min · **Rollback**: CSV+md 삭제

## Stage 4 — surface 분석 [deliverable = 사용자 정의 게이트]

## Task 11: 선택 구조 E2\~Ub 도달성 cone/swept-volume surface

- **Status**: pending (산출물 = E2\~Ub 도달성 cone/swept-volume, 동결 2026-06-09)
- **Prereq tasks**: 10
- **Files touched**: `analysis/productive_pose/e2_reachability_surface.py`,
  `analysis/productive_pose/REACHABILITY_SURFACE.md`
- **Change shape**: 선택 productive 구조의 완전복합체 overlay에서 SH3-5 lysine Nζ가 E2 촉매 Cys Sγ를 향해
  도달 가능한 **swept-volume/cone** 산출(lysine 측쇄 rotamer + CRL/E2\~Ub 허용 play 샘플링) → 부피
  pseudoatom/맵 + **도달 가능 fraction** + E2 active site overlap 정량. M1(스칼라)의 공간적 확장.
- **Verification**: `python e2_reachability_surface.py --pose <selected>` → swept-volume 출력
  (.pdb pseudoatoms 또는 .dx 맵) + 도달 fraction + active-site overlap 수치; REACHABILITY_SURFACE.md 요약.
- **Estimated time**: 7 min · **Rollback**: 스크립트+산출물 삭제

## Task 12: 파이프라인 리포트 + 핸드오프

- **Status**: pending
- **Prereq tasks**: 10
- **Files touched**: `analysis/productive_pose/MRT6160_PRODUCTIVE_REPORT.md`
- **Change shape**: 방향 스캔(1차+2차) + M1 선택 + (가능 시)surface 종합. 방법·NULL band·선택 근거·한계
  (M1=거리only, AF inter-domain caveat, 2C 검증 결과) 기록.
- **Verification**: `cat MRT6160_PRODUCTIVE_REPORT.md` → 선택 orientation + 재현 경로 + 한계.
- **Estimated time**: 4 min · **Rollback**: 산출물 삭제
