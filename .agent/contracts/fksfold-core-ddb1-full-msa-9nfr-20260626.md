---
status: done
slice: aigen-fold-core
topic: ddb1-full-msa-9nfr
date: 2026-06-26
owner: claude
approved_by: sunghoon.kim
requested: 2026-06-26
cross_slice: []
triggers_matched:
  - "SLURM/GPU submission — DDB1 full-MSA 4체인 생성 런"
  - "shared-storage writes — /mnt 워크스페이스 생성 출력"
---

# DDB1 ΔBPA + Full MSA 4체인 — 9NFR CRBN 방향 수정 (MSA 보강 실험)

## Purpose

직전 DDB1 ΔBPA co-input 실험(job 8398)이 CRBN_RMSD 개선 없이 실패(20.6Å)한 근본 원인 2가지
가 확인됐다:

1. **DDB1 ΔBPA가 CRBN 접촉 잔기 63%를 제거함**: 9UUM 기준 DDB1-CRBN Cα≤8Å 접촉 32개 중
   20개가 BPA 도메인(seqid 1-396)에 위치 — ΔBPA 사용으로 이 20개가 전부 누락됨.
2. **DDB1 MSA = 1행 (쿼리 서열만)**: Boltz가 DDB1-CRBN 공진화 신호를 전혀 갖지 못해
   DDB1이 CRBN 옆에 있어도 인터페이스를 형성할 이유를 모름.

이번 실험은 원인 2(MSA 부재)를 먼저 수정한다: DDB1 ΔBPA 서열에 대한 실제 MSA(MMseqs2/
JackHMMER 기반)를 계산하여 4체인 입력에 적용. CRBN_RMSD와 DockQ가 얼마나 개선되는지
측정하고, 결과에 따라 DDB1 full 1140AA(원인 1 수정) 진행 여부를 결정한다.

## Current State

- **기존 입력 (4체인, DDB1 single-seq MSA)**: arm0 CRBN_RMSD 20.62-21.99Å,
  DockQ 0.016-0.048, cone_dist 14-18Å.
  WS: `/mnt/kfs2/data/users/ubuntu/ddb1_4chain_9nfr_20260626/`
- **재사용 가능한 인프라**:
  - `inputs/9NFR_ddb1.yaml` (4체인 YAML, DDB1 MSA 경로만 교체)
  - `run_ddb1_9nfr.sh` (ARM-0 × 3 seeds 런처)
  - `score_9nfr_dockq.py`, `score_ik_poscontrol.py`, `contact_recovery.py`
  - CRBN/VAV1 MSA: `/mnt/kfs2/data/users/ubuntu/ik_9nfr_20260625/msa/`
- **필요한 신규 항목**:
  - DDB1 ΔBPA full MSA CSV (MMseqs2 ColabFold API 또는 Boltz 단독 CPU 런으로 생성)
  - 신규 워크스페이스: `ddb1_full_msa_9nfr_20260626/` (기존 WS 건드리지 않음)

## Assumptions And Questions

- assumptions:
  - DDB1 ΔBPA(745AA) MSA는 ColabFold MMseqs2 API(`https://api.colabfold.com`)로
    검색 가능. 결과를 Boltz `key,sequence` CSV 포맷으로 변환.
  - Boltz MSA CSV 포맷: 첫 행 `key,sequence`, 이후 각 행 `<hit_id>,<sequence>`.
    paired MSA가 아닌 unpaired(단일 체인 검색) CSV를 사용.
  - ARM-0만 실행(ARM-2 OOM은 이전 실험에서 확인됨, num_particles=1 고려).
  - 3 seeds(16/42/123)으로 분포 확인.
  - CRBN offset=45 그대로 유지.
- open questions:
  - DDB1 full MSA로도 CRBN_RMSD가 15Å 이상이면 → DDB1 full 1140AA(원인 1) 시도.
  - DDB1 full MSA가 10Å 미만이면 → MRT6160 4체인 DDB1 런 컨트랙트로 진행.
- tradeoffs:
  - ColabFold API vs 로컬 HMMER: API는 즉각적이지만 외부 인터넷 필요.
    대안: Boltz 단독 CPU 런으로 DDB1 단일체인 MSA 자동 생성(외부 의존성 없음).
  - ARM-2 실행 여부: OOM 위험 있음. 이번에는 ARM-0만으로 결과 확인 후 결정.

## Constraints

- allowed change scope:
  - 신규 워크스페이스: `/mnt/kfs2/data/users/ubuntu/ddb1_full_msa_9nfr_20260626/`
  - DDB1 ΔBPA full MSA CSV 파일
  - 신규 4체인 YAML (`9NFR_ddb1_full_msa.yaml`) — 기존 9NFR_ddb1.yaml 복사 후 DDB1 MSA 경로만 교체
  - 신규 런처 (`run_ddb1_full_msa_9nfr.sh`)
  - 결과 문서: `/home/ubuntu/analysis/crl_integrative/ddb1_full_msa_9nfr_results.md`
- forbidden change scope:
  - 기존 `ddb1_4chain_9nfr_20260626/` 워크스페이스 수정 금지 (비교 기준 보존)
  - `boltz_extension/` 소스 코드 변경 금지
  - 9NFR refs 변경 금지
- external constraints:
  - GPU: `sudo -u kim sbatch --qos=batch`
  - 출력: `/mnt/kfs2/data/users/ubuntu/ddb1_full_msa_9nfr_20260626/` (chmod 777)
  - SLURM GPU selector: `memory.free > 75000 MiB`
  - MSA 재사용: CRBN/VAV1 = `/mnt/kfs2/data/users/ubuntu/ik_9nfr_20260625/msa/` 변경 없음
  - DDB1 full MSA: 이번 실험에서 신규 계산

## Non-Goals

- DDB1 full 1140AA 입력 (이번 실험 범위 밖 — MSA 효과 먼저 분리 확인)
- ARM-2 실행 (OOM 위험, ARM-0 결과 먼저)
- GATE 설정 (결과를 보고 다음 실험 여부 결정 — 이번은 탐색적 실험)
- DDB1-CRBN pocket constraints 추가 (변수 분리: MSA 효과만 확인)
- MRT6160 타깃 (9NFR GT 검증 완료 후 진행)

## Done When

- **주 결과**: ARM-0 × 3 seeds CRBN_RMSD + DockQ + cone_dist 측정값 존재.
  검증: `wc -l .../analysis/scores.tsv` → `4` (header + 3 rows)
- **비교 문서**: `/home/ubuntu/analysis/crl_integrative/ddb1_full_msa_9nfr_results.md`
  — 이전 실험(single-seq MSA) 대비 CRBN_RMSD 변화 정량화.
  검증: `test -f .../ddb1_full_msa_9nfr_results.md && grep -c "arm0" .../results.md` → ≥ 1
- **다음 결정**: 결과에 따라 DDB1 full 1140AA 진행 여부 명기.

## Implementation Steps

1. **DDB1 ΔBPA full MSA 생성** (zero-GPU)
   - 방법: Boltz 단독 CPU 런 (single protein = DDB1 ΔBPA, `--use_msa_server`)으로
     자동 MSA 생성 후 출력 `msa/` 디렉토리에서 CSV 추출.
     또는: `curl` + ColabFold API → 파싱 → Boltz CSV 포맷 변환.
   - 저장: `/mnt/kfs2/data/users/ubuntu/ddb1_full_msa_9nfr_20260626/msa/ddb1_chain_D.csv`
   verify: `wc -l ddb1_chain_D.csv` → >> 2 (최소 수백 행 기대)

2. **워크스페이스 생성 + 의존성 스테이징** (zero-GPU)
   - `sudo -u kim mkdir -p` + symlinks (stage/src, closure_spec, MSA, 9NFR.cif, 9UUM.cif)
   verify: `ls .../refs/9NFR.cif .../stage/src` → 존재

3. **9NFR_ddb1_full_msa.yaml 작성** (zero-GPU)
   - 기존 `ddb1_4chain_9nfr_20260626/inputs/9NFR_ddb1.yaml` 복사 후
     chain D `msa:` 경로만 new ddb1 CSV로 교체
   verify: `python3 -c "import yaml; d=yaml.safe_load(open('...')); print([s.get('protein',{}).get('id') for s in d['sequences']])"` → `['A', 'B', None, 'D']`

4. **run_ddb1_full_msa_9nfr.sh 런처 작성 + 드라이런** (zero-GPU)
   - 기존 run_ddb1_9nfr.sh 복사, WS/YAML/job-name만 변경, ARMS=(arm0) only
   verify: 드라이런 → `CELLS=3 (ARM-0 × 3 seeds)`, no MISSING

5. **⛔ GPU GATE — SLURM 제출 + 모니터링**
   - `sudo -u kim sbatch run_ddb1_full_msa_9nfr.sh --submit`
   - 첫 셀 로그 즉시 모니터링: DDB1 chain D MSA 로딩 확인
   verify: `find .../out/ -name "*_model_0.pdb" | wc -l` → `3`

6. **채점 + 결과 문서** (zero-GPU)
   - score_9nfr_dockq.py → CRBN_RMSD + DockQ
   - score_ik_poscontrol.py → cone_dist
   - contact_recovery.py → CR_frac
   - `analysis/scores.tsv` + `ddb1_full_msa_9nfr_results.md` 작성
     (이전 single-seq MSA 결과와 나란히 비교)
   verify: 결과 문서 존재 + 세 seed CRBN_RMSD 수치 포함

## Change Discipline

- simplest adequate approach: 기존 4체인 인프라 그대로, MSA 파일 1개 교체. 코드 변경 없음.
- new abstractions introduced: 없음.
- unrelated code touched: 없음.
- request-to-diff trace: job8398(DDB1 single-seq MSA=FAIL) → MSA 부재가 주요 원인 → full MSA로 교체.

## Verification

- Boltz 로그: DDB1 chain D MSA 행 수가 >100이어야 공진화 신호 로딩 확인
- 채점 스크립트: score_9nfr_dockq.py가 4체인 PDB에서 정상 작동 (이전 실험에서 검증 완료)
- Chrome QA: N/A

## Risks

- **ColabFold API 불가**: 인터넷 미연결 시 API 방법 실패. 대안: Boltz 단독 CPU 런으로 MSA 생성.
- **MSA 파일 포맷 불일치**: Boltz paired/unpaired CSV 구조가 다를 수 있음.
  T1에서 `wc -l` + 헤더 구조 검증 후 진행.
- **DDB1 12개 BPC 접촉만으로 불충분**: MSA를 추가해도 CRBN_RMSD가 크게 개선되지 않을 가능성.
  → 원인 1(BPA 도메인 누락) 해결 필요 → DDB1 full 1140AA로 진행.

## Rollback

- revert strategy: `sudo -u kim scancel <JOBID>` + `sudo -u kim rm -rf /mnt/kfs2/data/users/ubuntu/ddb1_full_msa_9nfr_20260626/`
- containment strategy: 신규 워크스페이스 격리. 기존 `ddb1_4chain_9nfr_20260626/` 보존.

## Progress Log

- 2026-06-26: 초안 작성 — DDB1 ΔBPA single-seq MSA 실패 → full MSA 보강 실험.
