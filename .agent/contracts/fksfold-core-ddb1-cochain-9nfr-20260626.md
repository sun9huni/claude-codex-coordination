---
status: done
slice: aigen-fold-core
topic: ddb1-cochain-9nfr
date: 2026-06-26
owner: claude
approved_by: sunghoon.kim
requested: 2026-06-26
cross_slice: []
triggers_matched:
  - "SLURM/GPU submission — DDB1 4체인 생성 런"
  - "shared-storage writes — /mnt 워크스페이스 생성 출력"
---

# DDB1 BPC 4체인 Co-Input — 9NFR CRBN 방향 수정

## Purpose

Template conditioning 실험(contract `fksfold-core-ddb1-4chain-9nfr-20260626`, jobs 8371→8381)
결과: trunk conditioning만으로 CRBN_RMSD 15.25Å (기준선 18-23Å에서 ~3Å 감소) — GATE(<10Å) FAIL.

근본 원인 확정: **DDB1을 물리적 체인으로 co-input하지 않으면 CRBN TBD가 globally 잘못 배치됨**.
DDB1 BPC 도메인이 CRBN TBD와 직접 접촉(9UUM/CRL4 구조 확인됨)하므로, DDB1을 4번째 단백질
체인으로 추가하면 Boltz가 DDB1-CRBN 접촉을 학습한 Prior에 의해 CRBN을 올바른 방향으로 folding한다.

**가설**: 4체인 입력(CRBN(A)+VAV1(B)+MRT23227(C)+DDB1_BPC(D)) →
ARM-0 CRBN_RMSD < 10Å vs 9NFR 크리스탈 (3 seeds 중 최솟값).

## Current State

- **기존 입력 (3체인)**: CRBN(A) 381AA + VAV1 SH3c(B) 61AA + MRT23227(C) ligand.
  CRBN_RMSD baseline: 18-23Å (DDB1 없음).
- **이미 구현된 인프라 (재사용 가능)**:
  - `score_9nfr_dockq.py`, `contact_recovery.py`, `score_ik_poscontrol.py`
  - `CRLClosureIK`, `CRLClosurePotential`
  - `run_template_9nfr.sh` 패턴 (ARM-0/ARM-2 × 3 seeds)
  - protein-only CIF 생성 방법(`*_prot.cif`), `analysis/crl_integrative/refs/9UUM.cif` 위치 규칙
- **필요한 신규 항목**:
  - DDB1 ΔBPA 서열(UniProt Q16531 human, residues 396-1140, ~745AA)
  - 4체인 YAML (`9NFR_ddb1.yaml`)
  - 신규 런처 (`run_ddb1_9nfr.sh`)

## Assumptions And Questions

- assumptions:
  - DDB1 ΔBPA (residues 396-1140, ~745AA) = BPB+BPC 도메인. BPC가 CRBN TBD에 직접 결합(9UUM 기준 ~40 contact residues). BPA(1-396) 제거 = GPU 메모리 절약.
  - Boltz가 DDB1-CRBN pairwise 접촉을 MSA에서 co-evolution으로 학습했거나, template feature에서 보유 중 → DDB1(D) 체인이 있으면 CRBN(A) conformation이 DDB1-bound 상태로 bias됨.
  - DDB1 MSA: `msa: null` (이 검증 런에서는 DDB1 prior만으로 충분; full MSA 계산은 GATE PASS 후 별도).
  - CRLClosureIK(ARM-2): CRBN(A)-VAV1(B)-MRT23227(C) 삼원 기하에만 적용, DDB1(D)는 무관. 4번째 체인 추가로 IK 로직 영향 없음.
  - CRBN 체인 seqid 오프셋(crbn_offset=45)은 체인 수와 무관 → score_9nfr_dockq.py/contact_recovery.py 변경 불필요.
  - 총 토큰: CRBN(381)+VAV1(61)+MRT23227(~40)+DDB1 ΔBPA(~745) ≈ 1227 → A100 40GB 내 적합.
- open questions:
  - DDB1 ΔBPA 절단 위치: 396 vs 400? 9UUM 구조에서 B체인 첫 residue = seqid 1(MET). ΔBPA 기준 문헌: ~residue 396. 실험에서는 396으로 고정.
  - Boltz pocket constraints: 현재 9NFR.yaml의 pocket constraints(CRBN TBD + VAV1 surface)를 유지. DDB1용 pocket constraint는 추가하지 않음(접촉이 자연히 형성되도록 허용).
- tradeoffs:
  - DDB1 ΔBPA vs full DDB1: ΔBPA 745AA = GPU 메모리 약 35% 절약; BPC 도메인의 CRBN 접촉은 완전히 보존.
  - msa:null vs full MSA: null은 DDB1 co-evolution 신호 손실. 그러나 DDB1이 scaffold 역할이므로 물리적 접촉만으로 CRBN anchor 충분히 제공될 것으로 예상.

## Constraints

- allowed change scope:
  - 신규 워크스페이스: `/mnt/kfs2/data/users/ubuntu/ddb1_4chain_9nfr_20260626/`
  - 신규 YAML: `inputs/9NFR_ddb1.yaml` (4체인, DDB1 msa:null)
  - 신규 런처: `run_ddb1_9nfr.sh` (ARM-0 + ARM-2 × 3 seeds = 6 cells)
  - DDB1 ΔBPA 서열 파일: `inputs/ddb1_bpc_396_1140.fasta` (UniProt Q16531 추출)
  - 결과 문서: `/home/ubuntu/analysis/crl_integrative/ddb1_4chain_9nfr_results.md`
- forbidden change scope:
  - `boltz_extension/` 소스 코드 변경 금지 (additive-only = 설정만)
  - 기존 `ik_9nfr_20260625/` + `template_9nfr_20260626/` 워크스페이스 건드리지 않음
  - 9NFR 크리스탈 refs 변경 금지
  - ARM-1(guidance-only) 제외 (세션7 결론: MRT6160 context에서 ARM-2보다 열등)
  - DDB1 BPA 도메인(residues 1-395) 포함 금지 (GPU 메모리 초과 위험)
- external constraints:
  - GPU: boltz-native un-containerize + `sudo -u kim sbatch --qos=batch`
  - 출력: `/mnt/kfs2/data/users/ubuntu/ddb1_4chain_9nfr_20260626/` (chmod 777)
  - SLURM free-GPU selector: `memory.free > 75000 MiB`
  - MSA 재사용: CRBN/VAV1 MSA = `/mnt/kfs2/data/users/ubuntu/ik_9nfr_20260625/msa/` (변경 없음)
  - DDB1 MSA: null (이 런에서는 skip)

## Non-Goals

- DDB1 full 1140AA 입력 (메모리 위험, 이번 범위 밖)
- DDB1 MSA 계산 (GATE PASS 후 결정)
- MRT6160 타깃 (9NFR GT 검증만)
- DDB1 pocket constraints 추가 (자유 폴딩으로 접촉 자연 형성 확인이 목적)
- TemplateSteering 코드 변경
- CRLClosureIK 파라미터 튜닝

## Done When

- **GATE (주)**: ARM-0 (no potentials, 4체인 vanilla) CRBN_RMSD < 10Å vs 9NFR 크리스탈, 3 seeds 중 최솟값.
  검증: `python3 score_9nfr_dockq.py <arm0_pdb> --gt_cif refs/9NFR.cif` → CRBN_RMSD 출력.
- **결과 문서**: `/home/ubuntu/analysis/crl_integrative/ddb1_4chain_9nfr_results.md` 존재 + 6셀 표 + gate 판정.
  검증: `test -f .../ddb1_4chain_9nfr_results.md && grep -c "GATE" .../ddb1_4chain_9nfr_results.md` → `1` 이상.
- **GATE PASS 시**: → MRT6160 4체인 DDB1 런 컨트랙트로 진행.
- **GATE FAIL 시**: 감소폭 정량화 + DDB1 full chain / MSA 추가 여부 결정.

## Implementation Steps

1. **DDB1 ΔBPA 서열 준비** (zero-GPU)
   - UniProt Q16531 human DDB1 서열에서 residues 396-1140 추출
   - `inputs/ddb1_bpc_396_1140.fasta` 저장
   verify: `python3 -c "from Bio import SeqIO; r=list(SeqIO.parse('ddb1_bpc_396_1140.fasta','fasta'))[0]; print(len(r.seq))"` → `745`

2. **워크스페이스 생성 + 의존성 스테이징** (zero-GPU)
   - `sudo -u kim mkdir -p .../{inputs,logs,out,refs,analysis/crl_integrative/refs}`
   - chmod 777, symlinks (stage/src, closure_spec, MSA), 9NFR GT symlink, 9UUM.cif 복사
   verify: `ls /mnt/kfs2/data/users/ubuntu/ddb1_4chain_9nfr_20260626/refs/9NFR.cif` → exists

3. **9NFR_ddb1.yaml 작성** (zero-GPU)
   - 기존 9NFR.yaml에 chain D(DDB1 ΔBPA) 추가: `protein: {id: D, sequence: <ddb1_seq>, msa: null}`
   - pocket constraints 유지(A+B+C), D체인 constraints 없음
   verify: `python3 -c "import yaml; d=yaml.safe_load(open('9NFR_ddb1.yaml')); print(len(d['sequences']))"` → `4`

4. **run_ddb1_9nfr.sh 런처 작성 + 드라이런** (zero-GPU)
   - run_template_9nfr.sh 패턴 기반, YAML = 9NFR_ddb1.yaml, ARMS=(arm0 arm2), 6 cells
   - `--template_steering_config` 없음, ARM-2: CRLClosureIK 그대로
   verify: `bash run_ddb1_9nfr.sh` (dry-run) → `CELLS=6 (ARM-0 + ARM-2 × 3 seeds)`, no MISSING

5. **⛔ GPU GATE — SLURM 제출**
   - `sudo -u kim sbatch run_ddb1_9nfr.sh --submit`
   - 첫 셀 로그 즉시 모니터링: DDB1 chain D 인식 + CRBN chain A 배치 확인
   verify: `find .../out/ -name "*_model_0.pdb" | wc -l` → `6`

6. **채점 + 결과 문서** (zero-GPU)
   - score_9nfr_dockq.py → CRBN_RMSD + DockQ (4체인 PDB에서 chain A 추출)
   - score_ik_poscontrol.py → cone_dist (chain A + C 기반, D 무관)
   - contact_recovery.py → CR_frac
   - `analysis/scores.tsv` + `ddb1_4chain_9nfr_results.md` 작성
   verify: `wc -l .../analysis/scores.tsv` → `7` (header + 6)

## Change Discipline

- simplest adequate approach: YAML에 chain D 추가 + launcher/YAML 2개 신규. 코드 변경 없음.
- new abstractions introduced: 없음.
- unrelated code touched: 없음.
- request-to-diff trace: T14(CRBN 20Å빗나감=DDB1 absent) → template conditioning GATE FAIL(~3Å 개선뿐) → DDB1 물리적 체인 co-input(이 컨트랙트).

## Verification

- Boltz 로그: `Folding chain D` 또는 DDB1 서열 처리 로그 확인 → 4체인 입력 수용 증거
- `analysis/crl_integrative/ddb1_4chain_9nfr_results.md` 존재 + CRBN_RMSD 표 + gate 판정
- Chrome QA: N/A

## Risks

- **GPU 메모리 초과**: ~1227 토큰 = A100 40GB 이내로 예상되나, Boltz attention이 O(N²). 실패 시 DDB1 BPC 단독(residues ~740-1140, ~400AA)으로 절단.
- **Boltz 4체인 처리 버그**: Boltz가 3체인 입력에서 주로 검증됨. DDB1 chain D 추가 시 pocket constraints chain ID 충돌 가능성(낮음, chain D를 constraints에 포함하지 않으므로).
- **DDB1이 잘못된 결합 모드로 배치될 가능성**: Boltz prior가 DDB1-CRBN 접촉을 충분히 인코딩하지 않았을 경우 DDB1이 CRBN과 떨어져 folding. → ARM-0 로그에서 DDB1 chain D Cα 분포 확인.
- **scoring 오류 (4체인 PDB)**: score_9nfr_dockq.py가 chain A(CRBN)만 추출한다면 4체인 PDB에서 정상 작동. 만약 전체 PDB를 GT에 superpose하려 하면 chain D 존재로 오류 발생 가능. Task 6에서 실행 전 함수 동작 확인 필요.

## Rollback

- revert strategy: `sudo -u kim scancel <JOBID>` + `sudo -u kim rm -rf /mnt/kfs2/data/users/ubuntu/ddb1_4chain_9nfr_20260626/`. 코드 변경 없음.
- containment strategy: 출력 전용 워크스페이스 격리. 기존 ik_9nfr_20260625/ 및 template_9nfr_20260626/ 건드리지 않음.

## Progress Log

- 2026-06-26: initial draft — template conditioning GATE FAIL(15.25Å) → DDB1 물리적 co-input 컨트랙트.
- 2026-06-26: DONE — GATE FAIL (CRBN_RMSD 20.6-22.0Å, baseline 수준). cone_dist 극적 개선(34-51Å→14-18Å). ARM-2 OOM. 결과: analysis/crl_integrative/ddb1_4chain_9nfr_results.md. 플랜: fksfold-core-ddb1-cochain-9nfr-20260626.
