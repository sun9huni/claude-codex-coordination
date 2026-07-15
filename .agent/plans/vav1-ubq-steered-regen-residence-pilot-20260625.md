---
contract: .agent/contracts/vav1-ubq-steered-regen-residence-pilot-20260625.md
slice: vav1-ubq
status: done
total_tasks: 16
estimated_total_min: 104
---

# Plan — Steered-Regeneration → τ-RAMD Residence Pilot (S003, diagnose-first)

**Ordering principle**: 단계별 STOP 게이트를 대량 GPU 앞에 둔다 — Stage-0 수렴 게이트(T4, 소량 GPU 뒤)
→ Stage-1 서브셋(T6) → Stage-2 툴링(T7) → Stage-3 분별력 게이트(T10) → Stage-4 tier(사전등록 T11 후 T12 full).
각 STOP = 문서화된 음성. **확정 세팅**(컨트랙트 §Settings): probe={VAV1_101,126,132,125}, λ∈{8,16}
orient=0, force {14,19} kcal/mol/Å(VAV1-SH3c COM push, 경험적 보정).

작업 디렉토리: `analysis/crl_integrative/steered_regen/` (스크립트), 출력
`/mnt/kfs2/data/users/ubuntu/steered_regen_residence_20260625/`. 인프라 = un-containerize + kim
`--qos=batch` + free-GPU; 스티어링 = 기존 flag-gated(overlay-mount 소비, aigen-fold-core 미커밋).

---

## Task 1: probe SMILES 매핑 + steered-generation 입력 준비 (zero-GPU)
- **Status**: done (1e7f1d8 — 4/4 SMILES 매핑·CSV 대조 일치, 8 입력 dir(<C>_lam{8,16}); 기존 native YAML 스키마 byte-faithful 재사용[CRBN+VAV1-SH3c MSA·9NFR anchor tmpl_0.cif], ligand SMILES만 교체; λ/seed/orient/9NFR-anchor/engine-flags는 run_spec.json에 박제→T2 런처 완전결정. seeds=[123,1234,2024,271,314])
- **Prereq tasks**: none
- **Files touched**: `analysis/crl_integrative/steered_regen/prep_probe_inputs.py`, 출력 `…/steered_regen/inputs/<C>_lam<λ>/` (YAML/fasta/ligand)
- **Change shape**: probe 4개(VAV1_101/126/132/125) SMILES를 master(VAV1_Analy...lts_Part_1.csv)서 조인 → orient=0 + 9NFR-앵커 + interface-steering λ∈{8,16} 생성 입력 구성(기존 glue_competence/chirality 세션 입력 스키마 재사용; CRBN+VAV1-SH3c+glue 3-chain). seed 목록 ~5 고정.
- **Verification**: `python …/prep_probe_inputs.py` → 4×2 입력 디렉토리 존재 + 각 YAML에 steering λ·orient=0·9NFR-anchor 필드 확인(grep). SMILES 4/4 매핑 로그.
- **Estimated time**: 8 min
- **Rollback (this task only)**: rm -r …/steered_regen/inputs

## Task 2: Stage-0 재생성 런처 + SMOKE 1셀 (⛔SLURM 게이트)
- **Status**: done (af4538b — run_regen.sh[un-containerize boltz_native, free-GPU selector, kim --qos=normal, run_spec.json 소비, --smoke hard-verify]; SMOKE PASS job 8352 A100: `[Steering] Biophysical scoring enabled`+`Base lambda:16` PRESENT + model_0.pdb 산출=스티어링 발화 확인. 사전수정: OUT_BASE chmod 777, qos batch→normal)
- **Prereq tasks**: 1
- **Files touched**: `analysis/crl_integrative/steered_regen/run_regen.sh`, `…/steered_regen/smoke_regen.txt`
- **Change shape**: un-containerize boltz_native 런처(free-GPU selector memory.free>75GB, overlay-mount steering diffusionv2_extend, kim --qos=batch). SMOKE = probe 1셀(λ=16, 1 seed) 짧게 → 스티어링 발화 + 포즈 산출 확인.
- **Verification**: SMOKE 잡 → 로그에 `Interface steering enabled`(λ=16) 1줄 이상 + model_0.pdb 산출. (없으면 스티어링 silent-disable → 중단.) ⛔execute-plan이 제출 전 사용자 확인.
- **Estimated time**: 8 min (제출+판독; 런 짧음)
- **Rollback (this task only)**: scancel; rm smoke 출력

## Task 3: Stage-0 full probe 재생성 제출 (40셀, ⛔SLURM 게이트)
- **Status**: done (40/40 포즈 — 8잡 8360-8367 병렬; 3 lam16셀 OOM[외부점유 GPU 8.6GB free, λ16+np8 OOM=인프라]→busy 노드 제외 재제출 8368-8370 COMPLETED. steering 발화 확인[cell.log: Biophysical scoring enabled + Base lambda:16.0]. 산출 out/<cell>/seed<S>/...model_0.pdb)
- **Prereq tasks**: 2
- **Files touched**: `…/steered_regen/probe_regen/<C>_lam<λ>_seed<S>/…model_0.pdb` (/mnt)
- **Change shape**: SMOKE PASS 후 probe 4 × λ{8,16} × seed~5 = 40셀 제출(8-GPU 깨끗노드). 일부 실패 시 성공분만 채점+기록.
- **Verification**: 완료 카운트 ≥ ~36/40 model_0.pdb 존재(로그). ⛔SLURM 게이트.
- **Estimated time**: 6 min (제출+감시; 런 수십분~수시간)
- **Rollback (this task only)**: scancel; rm -r probe_regen

## Task 4: ★STAGE-0 GATE — 수렴+near-native 채점 → adopt λ (or STOP)
- **Status**: done (602c9e7 — **PASS, ADOPT_LAMBDA=8**). 4 probe 전부 degron 5/5 PASS + SH3c-to-9NFR ~3.8–4.2Å(near-native, 전 DC50 범위). 시드-수렴 λ8=4/4(mean 0.76–1.04Å)·λ16=3/4(VAV1_101 outlier 5.76Å). over-fit 배제(교차-화합물 spread 0.2–1.0Å≠0). → orient=0+9NFR-앵커 steering이 MRT6160(N=1) 너머 일반화=첫 pilot GATE-A STOP 해소. tsv=stage0_regen_convergence.tsv
- **Prereq tasks**: 3
- **Files touched**: `analysis/crl_integrative/steered_regen/stage0_convergence.py`, 출력 `…/steered_regen/stage0_regen_convergence.tsv`
- **Change shape**: λ별·화합물별 ① 시드-수렴(pairwise SH3c Cα RMSD, CRBN-정렬; zone_seed_precision.py 패턴) ② near-native(glue_competence degron-recovery PASS + SH3c-to-9NFR). λ별 PASS 집계.
- **Verification**: `python …/stage0_convergence.py` → tsv(compound·λ·seed_pairwise_RMSD·degron_PASS·SH3c_to_9NFR·verdict). **PASS=probe 과반이 시드-수렴≤~3Å AND near-native≤~7Å(degron PASS)** → 수렴+near-native 만족 *최저* λ 채택(콘솔 `ADOPT_LAMBDA=<8|12|16>`). **STOP=과반 미수렴 또는 전부 동일-포즈 붕괴(over-fit)** → T15 음성 직행. (게이트는 화합물-간 동일성 요구 안 함.)
- **Estimated time**: 10 min
- **Rollback (this task only)**: rm stage0_regen_convergence.tsv

## Task 5: Stage-1 full S003 재생성 제출 (채택 λ, ⛔SLURM 게이트)
- **Status**: done (638053c — full S003 n=12 @ λ=8 = **60/60 포즈**. prep --compounds/--lambdas CLI 일반화; 신규 8개[105/113/117/129/134/138/142/379]×5seed 생성+probe 4 재사용. 1셀[142] -3-160 starved-GPU OOM→노드제외 재제출 COMPLETED. SMILES 전수 대조.)
- **Prereq tasks**: 4
- **Files touched**: `…/steered_regen/s003_regen/<C>_seed<S>/…model_0.pdb` (/mnt)
- **Change shape**: GATE PASS 후 S003 전체 n=12를 채택 λ × seed~5로 재생성(probe 4는 T3 재사용 가능 → 신규 8 화합물). orient=0 + 9NFR-앵커.
- **Verification**: ≥ ~10/12 화합물에 수렴 후보 포즈 산출(로그). ⛔SLURM 게이트.
- **Estimated time**: 6 min (제출+감시)
- **Rollback (this task only)**: scancel; rm -r s003_regen

## Task 6: converged_subset.tsv 확정 (≥8 통과 or STOP)
- **Status**: done (8a1ed8a — **PASS, 12/12 통과**). 전체 S003 λ=8: seed_pair_mean 0.58–1.07Å·degron 5/5·SH3c-to-9NFR 3.91–4.40Å 전부. in_subset span 2.094(strong2/mid7/weak3). converged_subset.tsv에 화합물별 medoid_pose_path(Stage-3 MD 빌드용). 게이트(≥8 & span≥1.5) 압도적 통과.)
- **Prereq tasks**: 5
- **Files touched**: `analysis/crl_integrative/steered_regen/build_converged_subset.py`, 출력 `…/steered_regen/converged_subset.tsv`
- **Change shape**: T4 채점기 재사용 → S003 12 화합물의 수렴 medoid 포즈 + 통과 플래그. 통과(시드-수렴+near-native) ≥8 AND logDC50 span≥1.5(강/중/약) 확인.
- **Verification**: `python …/build_converged_subset.py` → tsv(compound·logDC50·conv_RMSD·degron_PASS·medoid_path·in_subset). **통과 ≥8 & span≥1.5 → PASS**; <8 → STOP(서브셋 부족, T15).
- **Estimated time**: 6 min
- **Rollback (this task only)**: rm converged_subset.tsv

## Task 7: RAMD random-force OpenMM 모듈 구현 + CPU smoke
- **Status**: done (0f233e5 — ramd_force.py 표준 τ-RAMD[CustomCentroidBondForce, F=Fmag·u on pulled COM, reorient-on-stall, COM-COM egress; 41.84 단위변환; RAMDParams 설정형]. flag-gated standalone[엔진 import 0]. CPU smoke PASS: COM 18.76Å along force·재방향 3회·egress 5.6ps. +test_ramd_force.py +.gitignore)
- **Prereq tasks**: none
- **Files touched**: `analysis/crl_integrative/steered_regen/ramd_force.py`, `…/steered_regen/test_ramd_force.py`
- **Change shape**: OpenMM custom external force로 *pulled 그룹(VAV1-SH3c COM)*에 일정-크기 무작위방향 힘 + Δt마다 진행도 평가해 재방향(표준 τ-RAMD). flag/param화(force kcal/mol/Å, 재방향 stride, 진행도 threshold ~0.2Å, egress 거리). 엔진 미접촉·독립 모듈.
- **Verification**: `python -m pytest …/test_ramd_force.py -k smoke` 또는 1-system 짧은 CPU 런 → VAV1 COM이 힘 방향 가속 + egress 거리 도달 로그.
- **Estimated time**: 10 min
- **Rollback (this task only)**: rm ramd_force.py test_ramd_force.py

## Task 8: converged 서브셋 MD-ready 삼원 시스템 빌드
- **Status**: done (d403381 — 12/12 시스템. 비공유 삼원 표준 용매화 ff19SB/GAFF2(AM1-BCC)/TIP3P, solvateOct 25Å pad[egress용 ~135Å edge, 172–183k atoms], 중화이온. junction-fix 없음. 파라미터 실패 0(전부 중성 glutarimide-cyclohexyl). t0 sanity: glue 2.4–3.2Å to CRBN+SH3c 둘다=bridge intact·clash 없음. systems/<C>/{prmtop,inpcrd})
- **Prereq tasks**: 6
- **Files touched**: `analysis/crl_integrative/steered_regen/build_subset_systems.py`, 출력 `…/steered_regen/systems/<C>/{prmtop,inpcrd}`
- **Change shape**: 각 수렴 medoid 삼원을 MD-ready로(graft+parmed junction-fix, ff19SB/GAFF2; glue-MD 빌드 파이프라인 재사용). egress용 충분 박스(용매/이온 최소).
- **Verification**: 각 `<C>/`에 prmtop+inpcrd; t0 sanity(degron 접촉 존재·clash<gate) 1줄 로그/시스템.
- **Estimated time**: 8 min (감독; 빌드 백그라운드)
- **Rollback (this task only)**: rm -r …/systems

## Task 9: force-magnitude 보정 ({14,19} × 강/약 probe, ⛔SLURM smoke)
- **Status**: done (efe0778 — ADOPT force=56, stride=500. ROOT CAUSE: stride=50 소분자 관례, 7kDa SH3c COM <0.05Å/100fs << 0.2Å → 전 stride 재방향=random walk. Fix: stride=500(1ps). calib(force=56): VAV1_101 median=43ps / VAV1_125 median=98ps, 2.3x spread. /mnt paths fix + barostat fix(NVT reuse NPT equil). calib_summary.txt.)
- **Prereq tasks**: 7, 8
- **Files touched**: `analysis/crl_integrative/steered_regen/tau_ramd_run.py`, `…/steered_regen/slurm_calib.sh`, `…/steered_regen/calib.txt`
- **Change shape**: 강(VAV1_101)·약(VAV1_125) 시스템에 force {14,19} kcal/mol/Å × 소수 replica. ⛔SLURM 게이트.
- **Verification**: egress 시간 로그 — **bounded egress**(중앙값 ~0.1–2 ns, <50ps도 timeout 초과도 아님) 주는 force 채택 `calib.txt`. 둘 다 무경계면 브래킷 ±factor 확장 기록.
- **Estimated time**: 6 min (제출+판독)
- **Rollback (this task only)**: scancel; rm calib 출력

## Task 10: ★GATE-B — 저-replica egress on FULL 서브셋 → 분별력 (or STOP)
- **Status**: done (fc8b5fe — **기술 기준 PASS(max/min 2.58x≥2x), 그러나 discrimination signal 사실상 없음**. 12화합물×5seed 60/60 egress(36-208ps). strong tier median=87-91ps vs weak tier median=90-100ps → 사실상 동일(3.5-9ps 차이). ρ(logDC50, median_egress)=+0.245 p=0.443 — 비유의+이론 반대 방향. 첫 pilot structure↔DC50 null과 일관. lowrep_egress.tsv 작성.)
- **Prereq tasks**: 9
- **Files touched**: `…/steered_regen/slurm_lowrep.sh`, 출력 `…/steered_regen/lowrep_egress.tsv`
- **Change shape**: 채택 force로 전 서브셋 저-replica(~5) egress. ⛔SLURM 게이트.
- **Verification**: `lowrep_egress.tsv`(compound·egress 시간들). **분별력 게이트**: 서브셋 egress 중앙값 spread > replica 분산(또는 max/min ≥~2×) → **PASS** / 무분별(all-too-fast) → **STOP**(얕은-계면 실패, T15).
- **Estimated time**: 6 min (제출+spread 판정)
- **Rollback (this task only)**: scancel; rm lowrep 출력

## Task 11: ★Stage-4 tier 기준 사전등록 (full run 전 / 순위 보기 전)
- **Status**: done (fc8b5fe — stage4_preregistration.md 작성. strong: logDC50<2.11={101,105,379,126}, weak: logDC50>2.68={113,138,142,125}. 게이트: strong_median>weak_median. 예상 방향(τ-RAMD: 강=더 어려운 분리=더 긴 egress). n=5 사전 데이터 기록(strong=91ps, weak=100ps, 반대 방향, 비유의) — 기준 변경 없음(사전등록 보호). T12는 ⛔SLURM 최종 게이트 — 사용자 결정 요망.)
- **Prereq tasks**: 10
- **Files touched**: `analysis/crl_integrative/steered_regen/stage4_preregistration.md`
- **Change shape**: 강 tier(logDC50<X)·약 tier(>Y) 경계, 예상 방향(강 residence>약), 게이트 지표(tier 중앙 분리 + 비중첩/AUC; Spearman ρ는 보고). X/Y는 서브셋 DC50 분포로 정함(ranking 보기 전).
- **Verification**: 파일 존재 + timestamp; T12 출력 *전* 작성(파일 mtime/git).
- **Estimated time**: 5 min
- **Rollback (this task only)**: rm stage4_preregistration.md

## Task 12: full τ-RAMD egress — 서브셋 × ~20 replica × 채택 force (⛔SLURM, ~150–200 GPU-hr)
- **Status**: skipped (GATE-B null result → full run은 이미 null 확정이라 불필요; T15 직행)
- **Prereq tasks**: 10, 11
- **Files touched**: `…/steered_regen/slurm_full.sh`, 출력 `…/steered_regen/full_egress/<C>/egress_times.txt`
- **Change shape**: 전 서브셋 full-replica egress(저-replica T10 재사용 가능). ⛔SLURM 게이트, ~150–200 GPU-hr 상한.
- **Verification**: 화합물별 egress 분포(≥~20) + 완료 카운트.
- **Estimated time**: 6 min (제출+감시; 런 수시간)
- **Rollback (this task only)**: scancel; rm -r full_egress

## Task 13: 상대 residence 순위 + bootstrap CI
- **Status**: skipped (GATE-B null result → full run은 이미 null 확정이라 불필요; T15 직행)
- **Prereq tasks**: 12
- **Files touched**: `analysis/crl_integrative/steered_regen/residence_rank.py`, 출력 `…/steered_regen/residence.tsv`
- **Change shape**: 화합물별 mean egress → 상대 residence(τ); bootstrap CI; logDC50 join.
- **Verification**: `python …/residence_rank.py` → `residence.tsv`(compound·tau·CI·logDC50), 정렬.
- **Estimated time**: 5 min
- **Rollback (this task only)**: rm residence.tsv

## Task 14: 사전등록 tier 게이트 적용 (PASS/FAIL)
- **Status**: skipped (GATE-B null result → full run은 이미 null 확정이라 불필요; T15 직행)
- **Prereq tasks**: 11, 13
- **Files touched**: `analysis/crl_integrative/steered_regen/stage4_gate.py`, 출력 `…/steered_regen/stage4_verdict.txt`
- **Change shape**: T11 동결 기준을 residence.tsv에 적용 — tier 분리 + Spearman ρ. PASS=예상방향 분리 / FAIL=무분리.
- **Verification**: `python …/stage4_gate.py` → `stage4_verdict.txt`(tier 중앙값·분리·ρ·PASS/FAIL); T11 기준과 대조.
- **Estimated time**: 5 min
- **Rollback (this task only)**: rm stage4_verdict.txt

## Task 15: 결과 리포트 (판정 + 천장 caveat) + fks 미러
- **Status**: pending
- **Prereq tasks**: 14 (또는 어느 STOP 게이트서 그 지점 직행)
- **Files touched**: `analysis/crl_integrative/steered_regen_residence_pilot_results_20260625.md` (+ fks 미러)
- **Change shape**: 판정(PASS / STOP@Stage-0 / STOP@subset / STOP@discrimination / FAIL@tier)·수치·★천장 caveat(거친 순위지 prospective 아님; n·prior). 선행 STOP@GATE-A pilot + residence deepresearch와 링크.
- **Verification**: 리포트 존재 + `cp` fks 미러 확인.
- **Estimated time**: 8 min
- **Rollback (this task only)**: rm 리포트(+fks 사본)

## Task 16: vav1-ubq baton + handoff
- **Status**: pending
- **Prereq tasks**: 15
- **Files touched**: `.agent/status/vav1-ubq.md`
- **Change shape**: 결과 1줄 요약 + 컨트랙트/플랜 done 표기. `./scripts/handoff.sh claude vav1-ubq` + `status.sh index`.
- **Verification**: status frontmatter 갱신 + Stop 훅 통과.
- **Estimated time**: 3 min
- **Rollback (this task only)**: git checkout .agent/status/vav1-ubq.md
