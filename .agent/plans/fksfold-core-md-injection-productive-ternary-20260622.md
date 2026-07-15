---
contract: .agent/contracts/fksfold-core-md-injection-productive-ternary-20260622.md
slice: aigen-fold-core
status: done
total_tasks: 11
estimated_total_min: 47
---

# Plan — MD-injection productive-ternary (#12가 productive 삼원복합체를 올바르게 예측하게 하나)

목표: #12(MD-유래 binding 계면 prior) 주입이 진짜 degrader의 productive VAV1 ternary를 *올바르게* 예측하게
하나. 올바름 = productive 기하(물리, no crystal). 순환성 차단 = **G1**(촉매기하 emergent, 주입 안 함) +
**G2**(stability, #12-off relax 생존+multi-seed). 활성 데이터 = 진짜 degrader *필터*(판별 아님).

흐름 원칙: zero-GPU 단계는 **실험을 죽일 수 있는 전제 하나(G1 순환성 성립성, Task 1)만** 앞에 둔다 — 헤드룸은
옛 데이터 proxy 게이트가 아니라 글루8 결과 *인용*(Task 2) + smoke의 #12-off control arm(Task 5)이 직접 답한다.
정당화되면 GPU는 풍부하니 넉넉히 돌린다(diagnose-before-scale).

GPU 태스크(5, 6, 8)는 ★sbatch 승인 게이트 — /execute-plan 일시정지. 인프라 = overlay-mount #12 + un-containerize/
free-GPU(kim batch) 경로(md-interface-injection-surface·vav1-ubq 선례 재사용). 채점/판별기 = vav1-ubq
`glue8_pose_scan`/`crl_confirm` 류 재사용(읽기 전용 소비). 시간 추정 = 에이전트 diff 작성 시간(GPU wall-clock 별도).

---

## Task 1: G1 순환성 성립성 게이트 (zero-GPU, kill-gate)

- **Status**: done (commit d2bdf3d — GATE: PASS, 계면-satisfied yet near-attack 5%/17.4Å span)
- **Prereq tasks**: none
- **Files touched**: `analysis/crl_integrative/g1_feasibility_20260622.md` (new) + 분석 스크립트 `g1_emergent_freedom.py`
- **Change shape**: MD prior 프레임(`crl_frame...nearattack.pdb`, 읽기 전용)을 구조 분석 — **CRBN↔VAV1 binding
  계면(#2/#3)을 고정하면 촉매 배향(라이신→Ub near-attack)에 자유도가 *남는가***(=emergent 여지). 측정: 계면-고정
  하에 VAV1 강체 자유도/라이신 배향 분포가 near-attack를 *강제*하는지(좁으면 자유도 0=주입과 등가) vs 넓은지.
  **GATE**: 계면 고정이 near-attack를 사실상 결정하면 G1 불가능 → **STOP**(순환, GPU 무의미; 재설계). zero-GPU.
  (참고로 baseline #12-off productive≈0 헤드룸은 글루8 결과로 *이미* 알려짐 — Task 2서 입력 인용, Task 5 control
  arm서 직접 재확인; 별도 게이트로 두지 않음.)
- **Verification**: `test -f analysis/crl_integrative/g1_feasibility_20260622.md` && grep -qiE 'GATE.*(PASS|STOP)' 그것 → 계면-고정 후 near-attack 자유도 수치(예: 배향 분산/strain 범위) + GATE 판정 존재
- **Estimated time**: 5 min
- **Rollback (if this task only)**: `rm analysis/crl_integrative/g1_feasibility_20260622.md analysis/crl_integrative/g1_emergent_freedom.py`

## Task 2: Pre-registration lock (treatment 전 freeze·commit)

- **Status**: done (commit 950bcd9 — 7 degrader/8 seed, 4축 컷, Δ≥+0.10 endpoint)
- **Prereq tasks**: 1
- **Files touched**: `analysis/crl_integrative/PREREGISTER_productive_ternary_20260622.md` (new)
- **Change shape**: 동결 — (a) 테스트 degrader 집합: MRT6160 컨트롤 + `normtest_metadata.csv`서 실제 active
  부분집합 N(선택 규칙 명시: 진짜 degrader 필터, MW/logP 다양), (b) **G1 #12 주입 경계**: binding 계면(#2 원자거리
  +#3 사이드체인)만 주입, 촉매 배향(라이신→Ub near-attack)·glue 포즈(#5)는 *미주입=emergent 축*(Task 1 성립성
  통과 전제), (c) productive 4축 컷, (d) **G2 stability** 정의(relax-survival 컷 + multi-seed 일치율·seed 목록),
  (e) Δ-margin + 방향, (f) **헤드룸 입력 인용**: 글루8 #12-off productive≈0(`CAMP/glue8_pose_scan.csv`/
  `glue8_separation_gate`) — Task 5 control arm이 이 셋업서 직접 재확인.
- **Verification**: `git -C /home/ubuntu/FKSFold-Boltz_Advancement log --oneline -1 -- analysis/crl_integrative/PREREGISTER_productive_ternary_20260622.md` 존재(=커밋됨) ; 파일에 (a)-(e) 5필드 전부 비공란
- **Estimated time**: 5 min
- **Rollback (if this task only)**: `git revert` 해당 커밋 / `rm` 파일

## Task 3: Binding-interface-only #12 payload 추출기 (G1 핵심)

- **Status**: done (commit dc39a47 — 119 pair/69 pos/101 CA, 촉매·글루 구조적 배제 검증)
- **Prereq tasks**: 2
- **Files touched**: `analysis/crl_integrative/extract_binding_iface_mdref.py` (new); 출력 `*_mdref_bindingonly.json`
- **Change shape**: MD prior 프레임(`crl_frame...nearattack.pdb`, 읽기 전용)에서 **CRBN↔VAV1 binding 계면만**
  (#2 원자쌍 거리 + #3 사이드체인 위치) 추출해 #12 `md_reference_config`로 인코딩. **촉매 라이신 위치·glue 포즈
  (#5)는 제외**(emergent로 둘 축). 선행 VAV1 추출을 catalytic-축-제외로 일반화.
- **Verification**: `python analysis/crl_integrative/extract_binding_iface_mdref.py --dry` → config 산출 ; `python -c "import json;d=json.load(open('...mdref_bindingonly.json'));assert not d.get('lysine_attack') and not d.get('glue_pos')"` (촉매/glue 항 부재)
- **Estimated time**: 5 min
- **Rollback (if this task only)**: `rm analysis/crl_integrative/extract_binding_iface_mdref.py *_mdref_bindingonly.json`

## Task 4: Paired 생성 런처 (#12 off/on, binding-only)

- **Status**: done (commit 5a233e9 manifest; 런처=/mnt .../run_paired_gen.sh, dry-run 208셀 검증, --submit는 sbatch 게이트)
- **Prereq tasks**: 3
- **Files touched**: `/mnt/kfs2/.../md_injection_productive_20260622/run_paired_gen.sh` (new, /mnt 워크스페이스) + 드라이버 복사
- **Change shape**: degrader별 2 arm(#12 off / on, 그 외 동일 seed·MD prior·config) × multi-seed 생성 런처.
  #12 live = overlay-mount staged 사본(md-injection-surface 스테이징 재사용). free-GPU selector(memory.free>75GB)
  + un-containerize(kim --qos=batch) 경로. compute 노드 /home 미마운트 → 드라이버 /mnt 복사.
- **Verification**: `bash -n run_paired_gen.sh` exit 0 ; `grep -cE 'md_reference|mdref_bindingonly|CHIRAL|overlay' run_paired_gen.sh` ≥1 ; dry-run이 예상 셀 수(=degrader×seed×2) 출력
- **Estimated time**: 5 min
- **Rollback (if this task only)**: `rm -rf /mnt/.../md_injection_productive_20260622/run_paired_gen.sh`

## Task 5: SMOKE — #12 발화 + G1 무결성 + control-arm 헤드룸 재확인 (★GPU 승인 게이트)

- **Status**: done — SMOKE PASS (job 8206, 12/12 cells, 18m57s). #12 발화(atom_pairs=119/pos=69/CA=101, grad_ok); control silent; control marginal_frac=0.0000(헤드룸 確); 촉매토큰 0; 인프라 end-to-end OK. SMOKE_VERDICT.md in /mnt.
- **Prereq tasks**: 4
- **Files touched**: `/mnt/.../md_injection_productive_20260622/smoke/` (산출) ; `SMOKE_VERDICT.md`
- **Change shape**: treatment 1 + control(#12-off) 1 셀(np 소, sampling_steps 소) 제출. 확인 = (i) treatment
  로그 `[MDRef]` active + **촉매-restraint 라인 0개**(G1 무결성: binding만 주입), (ii) control silent + 양쪽
  model_0, (iii) **헤드룸 직접 재확인**: control(#12-off) 포즈를 productive 채점 → ≈0/저조면 헤드룸 확정(이 셋업·이
  discriminator로). control이 이미 productive면 STOP(헤드룸 0).
- **Verification**: treatment 로그 `grep -c '\[MDRef\]'` ≥1 AND `grep -ci 'lysine_attack\|catalytic_restraint' 로그`=0 ; control 로그 `grep -c '\[MDRef\]'`=0 ; control 포즈 productive score ≈0(헤드룸 PASS) 기록 ; 양쪽 `model_0` 존재
- **Estimated time**: 5 min (에이전트) + GPU 수분
- **Rollback (if this task only)**: `scancel` smoke job ; `rm -rf .../smoke/`

## Task 6: Paired 생성 풀런 (★GPU 승인 게이트)

- **Status**: in-progress — job 8210 RUNNING (kim, qos=batch, **4 GPU**[batch 캡], host-10-0-5-73, 16:19 시작). 실측 0.93 gen/min → ETA ~22.4h vs 24h 한도(마진 ~1.6h, 얇음). walltime 연장 불가(kim 권한無)·GPU 증설 불가(normal 8-cap=8098 사용중, high=대시보드 18080 down). **완화: 런처 idempotent(model_0 있으면 skip, L158) → timeout 시 재제출하면 잔여만 마저 = 무손실.** 폴링 b1khg0jaq가 큐-exit(완료OR timeout) 시 재호출 → %확인, <100%면 재제출(잔여), 그 후 Task 7 채점. 산출 /mnt/kfs2/.../md_injection_productive_20260622/out/.
- **Prereq tasks**: 5
- **Files touched**: `/mnt/.../md_injection_productive_20260622/out/` (생성 산출)
- **Change shape**: 사전등록 전 degrader × seed × {off,on} 풀 페어드 생성. SMOKE afterok 의존 체인(smoke 실패 시
  자동취소). 출력은 빈-브랜치 kfs로 라우팅(디스크풀 회피, vav1-ubq 선례).
- **Verification**: 산출 셀 수 = 사전등록 N×seed×2 ; 모든 treatment 셀 로그에 `[MDRef]` active ; 모든 셀 `model_0` 존재 ; `scontrol show job`/sacct rc=0
- **Estimated time**: 3 min (제출+수거) + GPU wall-clock
- **Rollback (if this task only)**: `scancel` job ; `rm -rf .../out/`

## Task 7: G1 emergent + productive yield 채점

- **Status**: done (commit d939d1b script; e95d155). 전체 1248 재채점 완료 → productive_paired.csv.
- **Prereq tasks**: 6
- **Files touched**: `analysis/crl_integrative/score_productive_paired.py` (new, glue8_pose_scan 채점 재사용) ; `out/productive_paired.csv`
- **Change shape**: 각 포즈 productive 4축 채점(near-attack·clash·register·삼원). **near-attack = 미주입
  emergent 축** 별도 컬럼. degrader별 productive yield/quality(#12 on vs off) 산출. G1 = treatment서 near-attack가
  emergent하게 나오나.
- **Verification**: `column -t out/productive_paired.csv | head` → 포즈별 4축 + degrader별 yield(on/off) + emergent(near-attack) 컬럼 분리 존재 ; `wc -l` ≈ 포즈수+1
- **Estimated time**: 5 min
- **Rollback (if this task only)**: `rm analysis/crl_integrative/score_productive_paired.py out/productive_paired.csv`

## Task 8: G2 stability — #12-off relax 생존 + multi-seed (★GPU 승인 게이트)

- **Status**: N/A — moot (primary endpoint FAIL → no positive ON-productive signal to stabilize; GPU relax 미실행, endpoint_verdict.json에 기록).
- **Prereq tasks**: 6, 7
- **Files touched**: `/mnt/.../md_injection_productive_20260622/relax/` (산출) ; `analysis/crl_integrative/score_stability.py` (new) ; `out/stability.csv`
- **Change shape**: treatment productive 포즈에 **#12 끈 짧은 MD relaxation** → productive 기하 생존(snap-back
  여부) + 생성 런의 multi-seed 일치율. 켤 때만 productive·끄면 무너지면 forced artifact flag.
- **Verification**: `column -t out/stability.csv` → degrader별 relax-survival fraction + multi-seed agreement 존재 ; relax job sacct rc=0
- **Estimated time**: 5 min (에이전트) + GPU
- **Rollback (if this task only)**: `scancel` relax job ; `rm -rf .../relax/ analysis/crl_integrative/score_stability.py out/stability.csv`

## Task 9: Aggregate + endpoint 판정

- **Status**: done (e95d155) — verdict **FAIL** (0/13·meanΔ−0.0096·K810 0/13). +진단 3종(rigid-artifact 캘리브·flexible-arm ~40% achievable·full-VAV1 steric inconclusive)·딥리서치(degron=SH3·ub-site 없음·K810 가설).
- **Prereq tasks**: 7, 8
- **Files touched**: `analysis/crl_integrative/aggregate_productive_ternary.py` (new) ; `out/endpoint_verdict.json`
- **Change shape**: yield(on/off) + G1(emergent) + G2(stability) 결합 → 사전등록 공식대로 PASS/FAIL
  (#12-on이 productive 올바름을 margin 이상 올림 AND G1·G2 통과).
- **Verification**: `python -c "import json;v=json.load(open('out/endpoint_verdict.json'));assert v['verdict'] in('PASS','FAIL')"` ; verdict이 prereg 공식 인용
- **Estimated time**: 4 min
- **Rollback (if this task only)**: `rm analysis/crl_integrative/aggregate_productive_ternary.py out/endpoint_verdict.json`

## Task 10: 최종 리포트

- **Status**: done (e95d155) — analysis/crl_integrative/md_injection_productive_ternary_results_20260622.md.
- **Prereq tasks**: 9
- **Files touched**: `analysis/crl_integrative/md_injection_productive_ternary_results_20260622.md` (new)
- **Change shape**: 전체 writeup — Δproductive 표 + G1(emergent 증빙) + G2(stability 증빙) + 선결 헤드룸 +
  PASS/FAIL + 정직한 한계(crystal GT 무존, productive 기하=물리 self-consistency 가정).
- **Verification**: 리포트에 Done-When 불릿 전부 대응(endpoint·G1·G2·headroom·한계) ; verdict이 endpoint_verdict.json과 일치
- **Estimated time**: 5 min
- **Rollback (if this task only)**: `rm` 리포트

## Task 11: Handoff + baton 갱신

- **Status**: in-progress (baton 갱신 + handoff.sh + status.sh index 실행 중).
- **Prereq tasks**: 10
- **Files touched**: `.agent/status/aigen-fold-core.md` ; (contract status if PASS)
- **Change shape**: slice baton `remaining_actions`에 결과(PASS/FAIL + 산출물 경로) 기록, contract PASS면
  status:approved→done. `./scripts/handoff.sh claude aigen-fold-core` + `./scripts/status.sh index`.
- **Verification**: `grep -q productive-ternary .agent/status/aigen-fold-core.md` ; `git -C /home/ubuntu log --oneline -1` = handoff 스냅샷 ; CURRENT.md 재생성됨
- **Estimated time**: 3 min
- **Rollback (if this task only)**: baton 편집 되돌림(handoff 전 상태)
