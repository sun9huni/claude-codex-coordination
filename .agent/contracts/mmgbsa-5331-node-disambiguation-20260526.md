---
slice: mmgbsa
topic: 5331-node-disambiguation
status: completed
owner: claude
created: 2026-05-26
approved: 2026-05-26
---

# mmgbsa-5331-node-disambiguation

## Purpose

5331 corrected-YAML Stage 1 prep에서 node1 (host-10-0-5-232)이 node0 대비 15pp
낮은 통과율(27.6% vs 43.0%)을 보였다. 활동도 confounder는 반대 방향(node1이
더 활성)으로 작용해 격차를 설명하지 못하므로 **node1 hardware/driver 의심
시그널 잔존** 상태. 본 contract는 node1 NO_PROGRESS_TIMEOUT 후보 10건을
**node0 단일 노드에 재제출**해 통과율을 비교, hardware 가설을 인과적으로
분리한다.

**Pass 정의 (02_nvt isolated)**: `failed_stage.tsv`에 해당 compound가
`error_reason=early_nvt_hang AND fatal_signature=NO_PROGRESS_TIMEOUT` 행을
**갖지 않으면 PASS**. 즉:
- 02_nvt 완주 → PASS
- 02_nvt HARD_TIMEOUT(high step, healthy-but-slow) → PASS
- 03_npt/04_npt/equi_prod에서 실패 (02_nvt는 통과) → **여전히 PASS** (03_npt PME
  stall은 본 contract 대상이 아님)
- 02_nvt NO_PROGRESS_TIMEOUT (low step, hardware-stall pattern) → FAIL

결과에 따라 후속 결정 (H0 p=0.10 conditional, n=10 binomial):
- node0 pass ≥4/10 → host-10-0-5-232 정비/제외 추진 (P=0.013, reject H0).
- node0 pass ≤1/10 → chemotype/compound-intrinsic 확정 (P=0.736 under H0
  = consistent with chemotype). corrected YAML 폐기/v3 회귀 검토 강화.
- node0 pass 2-3/10 → inconclusive, MW/chemotype profile 추가 조사 필요.

## Current State

- 5331 OUT_BASE: `/mnt/data/users/ubuntu/workspace/FKSFold-Boltz_Advancement_shared/outputs/norm143_corrected_seed16_stage1_20260520_111530/`
- 실패 분해: 128 fail / 198 attempts. node0 fail 57, node1 fail 71.
- early_nvt_hang fatal_signature 분포:
  - node0: HARD_TIMEOUT 40, NO_PROGRESS_TIMEOUT 9 (step 4000-5500)
  - node1: HARD_TIMEOUT 27, NO_PROGRESS_TIMEOUT 20 (cluster at step 2000-2500)
- node1의 "step 2500 cluster" 6개 (RunA, VAV1_357/364/369/375/376/377)는
  동일 step에서 멈춤 — GPU sync stall 의심의 smoking gun.
- 5331 staging sources.tsv (`outputs/_mmgbsa_staging/norm143_corrected_sources.tsv`)에
  10 후보 모두 존재. YAML/PDB 경로 유효.

## Assumptions And Questions

- assumptions:
  - 같은 worker 스크립트(`slurm_normtest143_8gpu_seed777_multidir8_worker.sh`)와 같은
    timeout/parameter set으로 다시 돌리면 chemistry-intrinsic 실패는 재현,
    hardware-intrinsic 실패는 사라진다.
  - node0(host-10-0-5-90)의 평균 pass rate ~43%가 균질 baseline. 단 후보군은
    이미 "early NVT stall on node1"로 conditional, 따라서 H0/H1 모두 conditional
    probability로 framing (§Done When 참조).
- open questions:
  - GPU 슬롯별 결정성: 같은 node에서도 GPU0-7 중 일부가 더 stall 경향? 본 contract는
    무시(8 GPU 사용해도 stat 안 깨짐).
  - 6 시간 walltime 내 prep 완주 가능성: 가장 큰 compound도 ~30 min wall이라 안전.
  - 03_npt PME concurrency stall: 8 GPU 동시 03_npt 진입 시 stall 가능 (NVT-resume
    smoke evidence). **본 contract pass 기준은 02_nvt-only로 격리되어 영향받지 않음**.
- tradeoffs:
  - 10건 binomial = 분명한 신호만 잡음. fine-grained p<0.05를 위해 n=15-20이 더
    안전하나 비용 2x. 본 contract는 cheap & informative gate에 우선.
  - **Selection bias 명시**: 후보는 node1 NO_PROGRESS_TIMEOUT 20건 중 step ≤4000
    extreme half. 이는 H1(hardware)에 *유리한* 선택. 해석 규약:
    - "극단 케이스에서 chemotype confirmed면 그 외도 chemotype" (보수적 conclusion)
    - "극단 케이스에서 hardware confirmed면 덜 극단도 hardware일 가능성 높음"
    어느 방향이든 답이 informative. Random sampling은 less-extreme 케이스를 포함해
    signal 희석 위험.

## Constraints

- allowed change scope:
  - 새 SLURM submit script: `scripts/mmgbsa_16gpu_multidir/slurm_mmgbsa_5331_node0_disambig.sh`
    - --nodes=1, --nodelist=host-10-0-5-90, 8 GPU, walltime 6h, RUN_TYPES=A
  - 새 sources.tsv subset: `outputs/_mmgbsa_staging/node_disambig_n10.tsv`
  - 새 OUT_BASE: `/mnt/data/users/kim/mmgbsa_outputs/node_disambig_5331_20260526_*`
  - `.agent/scratch/5331_node_disambig/` 진행 로그
- forbidden change scope:
  - worker 스크립트 수정(`slurm_normtest143_8gpu_seed777_multidir8_worker.sh`)
  - 02_nvt.mdp / 03_npt.mdp 수정
  - 기존 5331 OUT_BASE 변경
  - 5331 NVT-resume contract (`mmgbsa-5331-nvt-resume-20260521.md`) 별개로 진행
- external constraints:
  - `sudo -u kim sbatch` 필수 (kim 권한 SLURM 계정)
  - partition=gpu, qos=high (5331과 동일)
  - host-10-0-5-90 가용 확인: 위에서 mixed 상태 확인됨 (idle 슬롯 있음)

## Non-Goals

- node1 hardware 진단 자체 (GPU driver/version inspection, dmesg 분석)는 별도
- 5331 ready 70건의 Stage 2 진입
- corrected YAML vs v3 paired 비교 (별도 contract)
- 03_npt PME stall 진단

## Done When

1. 10/10 candidate compounds submit & 6 시간 내 02_nvt 단계 도달
   (acpype → 00_min → 01_nvt → 02_nvt). 02_nvt 진입 못한 케이스는 별도 분석.
2. 결과 ledger `node_disambig_5331_*/{ready_for_mmpbsa_prod.tsv,failed_stage.tsv}` 생성.
3. **Pass 정의 (02_nvt isolated)**: compound가 `failed_stage.tsv`에
   `error_reason=early_nvt_hang AND fatal_signature=NO_PROGRESS_TIMEOUT` 행을
   **갖지 않음**. (02_nvt 완주 OR HARD_TIMEOUT at high step OR 후속 stage 실패 모두 PASS.)
4. Pass 수에 따른 verdict:
   - pass ≥4: hardware 가설 채택 (binomial p=0.013, reject H0), 후속 node1 제외 contract 진행.
   - pass ≤1: chemotype 가설 채택 (consistent with H0 p=0.10), corrected YAML 부적합 추가 증거.
   - pass 2-3: inconclusive, MW/chemotype profile 추가 분석 필요.
5. `.agent/status/mmgbsa.md` 갱신 (node disambiguation result + verdict).

### Statistical detail (conditional probability framing)

후보군은 "node1에서 early NVT NO_PROGRESS stall한" 케이스라 unconditional
population rate가 아닌 conditional P(pass on node0 | failed early on node1)을 비교.

- H0 (chemotype-intrinsic): 이 compound들은 chemistry-broken (NVT를 어떤 node에서도
  통과 못함) → p(pass on node0) ≈ 0.10. 보수적 추정.
- H1 (hardware-intrinsic): node1 fault만 제거하면 이 compound들은 normal →
  p(pass on node0) ≈ 0.43 (node0 baseline) 또는 더 높음.

n=10 binomial under H0 p=0.10:
- X≥4: P=0.013 → reject H0, accept hardware
- X=3: P=0.070 → leaning hardware (marginal)
- X=2: P=0.264 → inconclusive
- X≤1: P=0.736 → consistent with chemotype (cannot reject H0)

n=10 binomial under H1 p=0.43:
- X≥4: P=0.778 → high power to detect hardware
- X≥6: P=0.232 → over-conservative

**결정 경계**: ≥4 hardware, ≤1 chemotype, 2-3 MW/profile 분석.

## Implementation Steps

1. **Reconnaissance** (완료): node1 NO_PROGRESS_TIMEOUT 20건 중 step ≤4000 cluster 10건 선정.
   - VAV1_357, 364, 369, 375, 376, 377 (step 2500 cluster, RunA)
   - VAV1_419, 469 (step 2000, RunA)
   - VAV1_411 (step 3500, RunA) — top hit DC50 1.99 nM, fragmap 5395 winner
   - VAV1_438 (step 4000, RunA)
   verify: 모두 sources.tsv에 존재 확인 (위에서 grep으로 검증됨).

2. **Subset sources.tsv 생성**: `outputs/_mmgbsa_staging/node_disambig_n10.tsv` —
   원본 header + 10 row.
   verify: `wc -l == 11`, 모든 yaml/pdb 경로가 `[ -f $path ]` 통과.

3. **SLURM script 작성**: `slurm_mmgbsa_5331_node0_disambig.sh` —
   `slurm_mmgbsa_norm143_corrected_stage1.sh` 기반, 단일 노드(--nodes=1
   --nodelist=host-10-0-5-90), 8 GPU, walltime 6h, RUN_TYPES=A 만.
   STAGING_TSV override.
   verify: `bash -n slurm_mmgbsa_5331_node0_disambig.sh` 통과.

4. **사용자 승인 게이트**: contract status=approved 받은 뒤 진행.

5. **Submit**: `sudo -u kim sbatch scripts/mmgbsa_16gpu_multidir/slurm_mmgbsa_5331_node0_disambig.sh`.
   verify: jobid 반환, squeue 1줄.

6. **Monitor & verdict**:
   - background로 squeue/tail 모니터
   - 종료 후 `ready_for_mmpbsa_prod.tsv`(node0 split) row 수 = pass count
   - mmgbsa-stage-check subagent로 cross-check (optional)
   verify: 위 §Done When 3번 verdict 결정 + status.md 갱신.

## Change Discipline

- simplest adequate approach: 기존 worker 재사용 + nodelist pin + subset table.
  새 worker / mdp 수정 안 함.
- new abstractions introduced: 없음 (단 sources.tsv subset, slurm wrapper만).
- unrelated code touched: 없음.
- pre-existing dead code noticed: 5330 zombie partial dir (out of scope).
- request-to-diff trace: 사용자 "진행" + "Node disambiguation 재실행" 선택 (2026-05-26).

## Verification

- task-specific:
  - 02_nvt NO_PROGRESS fail count:
    ```
    awk -F'\t' 'NR>1 && $6=="early_nvt_hang" && $14=="NO_PROGRESS_TIMEOUT" {print $1}' \
      $OUT/node0/failed_stage.tsv | sort -u | wc -l
    ```
    PASS = 10 - fail_count.
  - 02_nvt step distribution (sanity): `awk -F'\t' 'NR>1 && $6=="early_nvt_hang" {print $1, $14, $8}' $OUT/node0/failed_stage.tsv`
    → step 2000-4000 cluster 재현 여부 (재현 = chemotype 가설 지지).
  - 03_npt 결과는 별도 트래킹 (본 contract verdict와 독립):
    `awk -F'\t' 'NR>1 && $6!="early_nvt_hang" {print $1, $6, $14}' $OUT/node0/failed_stage.tsv`
  - GPU 노드 확인: `scontrol show job $JOBID | grep NodeList` → host-10-0-5-90
- manual check: VAV1_411 (top hit DC50 1.99 nM) 운명 — 02_nvt pass면 fragmap 5395
  winner를 mmgbsa workstream에 회수 가능, cross-workstream 가치 큼.

## Risks

- regression risk: 없음 (read-only 재실행, 새 OUT_BASE).
- integration risk: 동시 5331-nvt-resume contract와 GPU 충돌 가능 — 단,
  resume contract는 ad hoc, 본 contract도 6h short. Schedule conflict 최소.
- hidden dependency risk: host-10-0-5-90 자체가 stall 가능성. mitigation: 같은
  노드의 다른 compound가 5331에서 pass(43%)했으므로 baseline은 신뢰 가능.

## Rollback

- revert strategy: 결과 OUT_BASE 삭제하면 5331 원본 영향 없음.
- containment strategy: --time=6:00:00로 walltime 자동 컷, 무한 자원 점유 방지.
- failure mode: 모두 fail (예: 호스트 다운) → contract suspend, host-10-0-5-90
  scontrol show node 점검 후 재시도.

## Progress Log

- 2026-05-26 v1: contract drafted, 사용자 승인 대기.
- 2026-05-26 v2: self-audit fix — pass 기준을 ready_list 등록 → 02_nvt-only로
  격리 (03_npt PME stall confound 차단). H0 framing을 unconditional population →
  conditional (early-fail set 한정) p=0.10으로 정정. 임계값 ≥6→≥4, ≤2→≤1.
  Selection bias 명시.
- 2026-05-26 v3: host-10-0-5-90이 5+일 long job (5519, junyoungpark)으로 점유 →
  test host를 host-10-0-5-36으로 전환. 같은 A100×8 + 같은 /5 network segment
  (host-10-0-5-90/5-232와 동일 switch). 노드 ID 변경은 H1 framing에 영향 없음
  ("anywhere-but-node1" 가설). 단 baseline 43%는 5331 host-10-0-5-90 측정치라
  host-10-0-5-36 baseline은 unknown — conservative H1 lower bound으로 해석.
  --exclude=host-10-0-5-232 safety guard 추가. Job 5626 cancelled, 재제출 예정.
- 2026-05-26 14:26:45: SLURM 5627 COMPLETED (3:37:34 elapsed, host-10-0-5-36).
  **Verdict: 10/10 PASS** (binomial P(10|10,H0 p=0.10) = 1e-10, H0 fully reject).
  All compounds (VAV1_357/364/369/375/376/377/411/419/438/469) completed full
  equilibration (00_min through equi_prod) producing valid xtc 7-10MB +
  cpt 2.3-3.3MB + tpr 3.9-5MB. Same compounds at 5331 (host-10-0-5-232) stalled
  at 02_nvt step 2000-4000. **Conclusion: HARDWARE hypothesis confirmed — host-10-0-5-232
  정비/제외 권고.**
  Cross-workstream win: VAV1_411 (top hit DC50 1.99 nM, fragmap Phase 8/10 winner)
  recovered to mmgbsa workstream.
  Side finding (orthogonal): `failed_stage.tsv` worker bug — all 10 rows mis-recorded
  as `stage=prepare, error_reason=parameterization_failed, wall_sec=0` (placeholder
  defaults) despite full equi completion. `ready_for_mmpbsa_prod.tsv` empty because
  mmpbsa final stage didn't run to completion (separate issue, doesn't affect verdict).
  Worker status-tracking patch needed as a separate contract.
  status: completed.
