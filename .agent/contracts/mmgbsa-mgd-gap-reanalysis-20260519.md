# Contract: MMGBSA MGD.pdf gap closure + Composite QC — normtest143

- Date: 2026-05-19 (rev3)
- Owner: claude
- Slice: `mmgbsa`
- Workstream: **normtest143 only** (F105은 별도 세션, [[feedback-mmgbsa-workstream-split]])
- Status: **draft, awaiting user approval before any execution**
- Linked status: `.agent/status/mmgbsa.md`
- Linked source: `/home/ubuntu/f105_pdbs_upload/MGD.pdf`

## Why this contract

MGD.pdf 권장안 적용 + 현재 trajectory 활용 비효율 해소 + composite QC 도입을 한 번에 묶음. MD/trajectory는 무수정, 후처리 + 분석 추가만 수행.

### 확인된 gap (현재 → 권장)
| 항목 | 현재 | 변경안 | 근거 |
|---|---|---|---|
| `intdiel` | 1.0 | **4.0** | MGD: PPI/하전 계면용 effective dielectric |
| frame window | `start=1 end=50 interval=1` (50 frames, 0-5 ns) | **`start=21 end=200 interval=2` (90 frames, 2-20 ns)** | trajectory 75% 폐기 + equilibration 잔여 영향 제거 |
| composite QC | ΔG/component만 | **+ interface RMSD + BSA + H-bond + per-residue decomp** | MGD 권장 4개 모두 추가 |
| Stage 1/2 (MD) | 무수정 | 무수정 | 같은 trajectory 재사용 |

### 검증할 가설
- H1. `intdiel=4` 적용 시 `ddEEL`/`ddEGB` 절댓값 축소, ddPolar 부호 변화 가능.
- H2. 2-20 ns 안정 구간 사용으로 `dG_std` 감소, logDC50 상관 개선 가능.
- H3. composite QC가 ΔΔG보다 강한 ranking signal 제공 가능. 특히 BSA/interface RMSD가 ternary engagement 정량화에 유효한지.
- H4. 현재 단일 최강 신호인 `ddEEL` (Pearson −0.268)가 새 조건에서 유지될지 약화될지.

## Action plan (3 step gating)

### Step 1: Single-compound dry-run (SLURM, GPU placeholder)
- 대상: **VAV1_461** (top hit, logDC50=1.006, runA=−46.93, runB=−37.07, ddTOTAL=−9.86, ddEEL=−8.86)
- 실행: **SLURM normal QoS**, 1 node, **16 CPU**, `--gres=gpu:1` (placeholder; GPU 사용 안 함, 스케줄링 보장용)
- gmx_MMPBSA / gmx rms/sasa/hbond / sander 모두 CPU bound. GPU placeholder는 partition 정책상 GPU 파티션 안에서 CPU job을 안정적으로 잡기 위함.
- shared workspace 안에서 새 `mmpbsa_intdiel4_2to20ns/` subdir 생성
- 작업:
  1. `gb_run.in` 복사 후 `intdiel=4.0`, frame window `start=21 end=200 interval=2` 적용
  2. RunA + RunB gmx_MMPBSA 재실행 (기존 `centered_fixed.xtc` 재사용)
  3. composite QC 4종 계산 (별도 스크립트, 아래)
  4. 새 ΔG/component를 기존 결과와 비교 표 작성
- 검증 기준 (Done):
  - 두 run 모두 정상 수렴, `FINAL_RESULTS_MMPBSA.dat` 생성
  - `ddEEL`/`ddEGB` 절댓값이 기존 대비 의미 있게 변경 (방향성 보존 또는 합리적 변화)
  - `dG_std`가 50 frames vs 90 frames에서 감소하는지 확인
  - composite QC 4종 모두 finite, 합리적 범위
- 추정 시간: **10-20분** (1 compound × 2 runs × 90 frames + QC, 16 CPU 병렬)

### Step 2: 사용자 검토 → 전수 batch 승인 게이트
- dry-run 결과 표 검토
- 변경이 합리적이면 92 batch 진행 승인
- 비합리적 결과(NaN, 폭증 등)면 contract 수정 후 재시도

### Step 3: 92-compound batch (SLURM normal QoS)
- 대상: RunA 55 + RunB 37 = **92 component rows**
- SLURM: **normal QoS, 1 node, 32 CPU**, `--gres=gpu:1` (placeholder), **`POST_PARALLEL=16`**
- 출력: `mmpbsa_intdiel4_2to20ns/` subdir per compound
- `merge_normtest143_stage4_ddg.py`로 새 TSV 생성, 파일명 suffix `_intdiel4_90f`
- 추정 시간: **30-60분** (32 CPU, 동시 16 compound, gmx_MMPBSA + QC 4종 포함)
- Walltime 안전 마진: 2시간 요청

## Composite QC specification

각 compound × run당 다음 4종 계산. 별도 헬퍼 스크립트(`.agent/scratch/composite_qc_one.py`)로 묶고, 결과는 `qc_metrics.json`에 1 row 저장. 최종적으로 `mmgbsa_qc_metrics.tsv`로 집계.

### QC1: Interface RMSD
- 정의: CRBN-LIG-VAV1(RunA) 또는 CRBN-LIG(RunB) 계면 residue Cα RMSD over time
- 계면 residue 정의: complex 첫 frame에서 ligand heavy atom 4.5 Å 이내 protein residue
- 도구: `gmx rms` (with index for interface residues)
- 출력: mean RMSD (nm), std (nm), max (nm)
- 해석: 낮을수록 안정. 일반 기준 < 0.2 nm = stable, > 0.4 nm = drifting

### QC2: BSA (Buried Surface Area)
- 정의: SASA(complex) − SASA(receptor alone) − SASA(ligand alone) = burial 면적
- 도구: `gmx sasa` 3회 (complex / receptor / ligand index group)
- 출력: mean BSA (nm²), std (nm²)
- 해석: ternary engagement 강도. RunA − RunB가 ternary-specific burial.
- 참고: BSA는 보통 PROTAC ternary에서 8-15 nm² 범위

### QC3: H-bond occupancy
- 정의: protein-ligand interface H-bond의 trajectory 상 평균 점유율
- 도구: `gmx hbond -num -hbm` (donor/acceptor: ligand vs protein interface)
- 출력: total H-bond count mean, std, top 5 occupant H-bond list (donor-acceptor pair + 점유율 %)
- 해석: 특이적 interaction. 50% 이상 점유 H-bond이 있으면 strong contact.

### QC4: Per-residue decomposition
- 도구: gmx_MMPBSA `&decomp namelist`, `idecomp=2`, `dec_verbose=3`
- 출력: residue별 ΔG 기여도 (TOTAL/VDW/EEL/POL/SAS)
- 추출: top 10 most-contributing residue per compound × run
- 해석: hot-spot residue 파악. ternary specific residue가 RunA에 등장하는지 확인.

## Cost / time estimate

| 단계 | 범위 | 추정 시간 | 자원 |
|---|---|---|---|
| Step 1 dry-run | VAV1_461 × 2 runs | 10-20분 | SLURM normal, 16 CPU + 1 GPU placeholder |
| Step 3 batch | 92 compounds | 30-60분 | SLURM normal, 32 CPU + 1 GPU placeholder, POST_PARALLEL=16 |
| 분석/집계 | TSV merge + plot | <10분 | inline |

기존 Stage 3 (45분, 37 RunB, 50 frames) 대비:
- frames 50 → 90: ~1.8× compute
- composite QC 추가: ~1.3× compute
- intdiel 변경: 비용 거의 동일
- net 추정: 92 × 2.4× / 37 = 약 **5-6×** Stage 3 time → 4-5시간 직선 추정이지만 16 CPU 병렬로 1-2시간

## Out of scope (별도 contract)
- MD 50-100 ns 재실행 (top hit 후속)
- F105 dataset 동일 적용
- FEP/RBFE/ABFE (MGD 권장 Phase 2/3)
- 3회 independent MD replicas

## Done when
- [ ] Step 1: VAV1_461 dry-run 완료, 기존 대비 변화량 표 작성.
- [ ] Step 2: 사용자가 변화량 합리성 확인 후 batch 승인.
- [ ] Step 3: 92-batch 완료, 신규 TSV `mmgbsa_components_intdiel4_90f.tsv`, `mmgbsa_ddg_components_intdiel4_90f.tsv`, `mmgbsa_qc_metrics.tsv` 생성.
- [ ] Step 4: 신규 데이터로 correlation, ROC, soft-rule, top hit 재평가.
- [ ] Step 5: mmgbsa status 갱신.
- [ ] 기존 결과 + 백업 + 신규 결과 같은 폴더 공존.

## Approval gates
- **이 contract만으로 어떠한 변경도 적용 안 함.**
- Step 1 (SLURM dry-run, 16 CPU + 1 GPU placeholder) 시작에 사용자 명시적 승인.
- Step 3 (SLURM 92-batch, 32 CPU + 1 GPU placeholder) 시작에 별도 승인.
- 백업 정책: 기존 `mmpbsa/`는 그대로 보존, 신규는 `mmpbsa_intdiel4_2to20ns/` subdir 별도.
- 어떠한 MD trajectory/topology/tpr 파일 무수정.
- 어떠한 기존 TSV 덮어쓰기 금지 (suffix로 분리).
- GPU placeholder는 작업이 실제로 GPU 안 쓴다는 점 명시 (다른 GPU job 우선순위 영향 없음).

## Related
- 이전 EEL regex fix: 소급 contract `.agent/contracts/mmgbsa-eel-regex-fix-20260519.md` 미작성 (별도 처리).
- Rescue lane: `.agent/contracts/mmgbsa-runb-rescue-20260519.md`.
- Failure root cause 재분류 (binary fragility + acpype flakiness): 대화 기록.
