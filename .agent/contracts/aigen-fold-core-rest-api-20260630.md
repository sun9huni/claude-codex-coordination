# AIGENFold REST API

**Status**: done

## Purpose

외부 웹 클라이언트(프론트엔드 서비스)가 HTTP로 AIGENFold 구조 예측 잡을
제출·조회·결과 다운로드할 수 있도록 FastAPI 서버를 구축하고 ngrok으로 노출한다.

## Current State

- 코드베이스: `/home/ubuntu/AIGENFold` (pyproject.toml `aigenfold`)
- CLI 진입점: `boltz-fks predict` (내부 패키지명 `boltz`/`boltz_extension` 유지)
- 현재 실행: SLURM + kim sbatch + boltz_native rootfs (FK Steering 포함)
- 로그인 노드 GPU: A100 × 8 직접 접근 가능
- `tpd_boltz2` env: 업스트림 boltz (`/tmp/boltz_upstream`) — FK Steering 미설치
- 모델 가중치: `/home/ubuntu/AIGENFold/downloads/boltz2_conf.ckpt`, `boltz2_aff.ckpt`

## Assumptions And Questions

- assumptions:
  - 전용 conda env `aigenfold_api` (Python 3.11)를 새로 생성해 `pip install -e .`
  - 로그인 노드 GPU를 API 서버가 직접 점유 (SLURM 우회)
  - 잡 상태 추적은 SQLite (인프라 DB 불필요)
  - Auth 없음 (내부/신뢰 네트워크 기준)
- open questions:
  - GPU 동시 사용 제한 (API + 다른 SLURM 잡 충돌) — 요청 시점에 memory.free > 75GB 인 GPU를 선택, 전부 사용
- tradeoffs:
  - 로그인 노드 직접 GPU: 빠르고 단순하나 SLURM 잡과 GPU 경합 가능
  - SLURM 우회: 큐 대기 없이 즉시 실행 가능

## Constraints

- allowed change scope:
  - 신규 파일: `AIGENFold/api/` 디렉토리 (server.py, jobs.py, schema.py, run.sh)
  - `pyproject.toml`에 api optional-deps 추가
  - 전용 conda env 생성 스크립트
- forbidden change scope:
  - `src/boltz/`, `src/boltz_extension/` 수정 금지
  - WIP 파일 (`crl_closure_ik.py`, `crl_closure_potential.py`) 건드리지 않음
  - 기존 SLURM 스크립트 수정 금지
- external constraints:
  - `ngrok` 설치 필요 (또는 기존 설치 확인)
  - FastAPI, uvicorn, python-multipart 신규 의존성 (api env 한정)

## Non-Goals

- 웹 UI / 프론트엔드 HTML
- 다중 사용자 / 팀 계정 / OAuth
- 결과 장기 보관 (PostgreSQL, S3 등)
- SLURM 제출 backend (직접 GPU 실행)
- `boltz`/`boltz_extension` 패키지명 변경

## Done When

1. `conda activate aigenfold_api && uvicorn api.server:app` 가 에러 없이 기동
2. `curl http://localhost:8000/health` → `{"status": "ok", "gpu": true}`
3. `curl -X POST http://localhost:8000/v1/predict -F "yaml=@examples/9nfr/9nfr_mrt6160_dual_pocket.yaml"` → `{"job_id": "..."}`
4. `curl http://localhost:8000/v1/jobs/{job_id}` → status `running` → `completed`
5. `curl http://localhost:8000/v1/jobs/{job_id}/results` → PDB 파일 다운로드 성공
6. ngrok URL로 위 5번이 동일하게 동작

## Implementation Steps

1. **env 생성 + AIGENFold 설치**
   ```bash
   conda create -n aigenfold_api python=3.11 -y
   conda activate aigenfold_api
   pip install -e /home/ubuntu/AIGENFold[cuda]
   pip install fastapi uvicorn[standard] python-multipart aiofiles
   ```
   verify: `python -c "import boltz, boltz_extension; import torch; print(torch.cuda.is_available())"`

2. **api/ 디렉토리 구조**
   ```
   AIGENFold/api/
     __init__.py
     server.py      # FastAPI app, lifespan (model load)
     jobs.py        # SQLite job store + background runner
     schema.py      # Pydantic request/response models
     run.sh         # uvicorn 기동 + ngrok 연결 스크립트
   ```

3. **핵심 엔드포인트**
   - `GET  /health`                  → GPU 상태 + 버전
   - `POST /v1/predict`              → YAML 파일 업로드 → job_id 반환
   - `GET  /v1/jobs/{job_id}`        → 상태 (queued/running/completed/failed)
   - `GET  /v1/jobs/{job_id}/results`→ PDB zip 다운로드
   - `GET  /v1/jobs`                 → 최근 잡 목록

4. **실행 모델**
   - 서버 startup: Boltz2 모델 GPU 로드 (1회)
   - 요청 수신: input YAML → `/tmp/aigenfold_api/{job_id}/input/` 저장
   - 백그라운드 asyncio task: `boltz.main` Python API 직접 호출 (subprocess 아님)
   - 완료: `/tmp/aigenfold_api/{job_id}/output/` → 결과 서빙

5. **ngrok 연결**
   - `ngrok http 8000` 또는 `run.sh`에 자동 포함

## Change Discipline

- simplest adequate approach: FastAPI + asyncio background task + SQLite
- new abstractions introduced: JobStore (SQLite wrapper), PredictRequest (Pydantic)
- unrelated code touched: 없음
- request-to-diff trace: api/ 신규 6파일, pyproject.toml 1줄 추가

## Verification

```bash
# env 검증
conda activate aigenfold_api
python -c "import boltz, boltz_extension, fastapi; import torch; assert torch.cuda.is_available()"

# API E2E
uvicorn api.server:app --reload &
curl http://localhost:8000/health
curl -X POST http://localhost:8000/v1/predict \
  -F "yaml=@AIGENFold/examples/9nfr/9nfr_mrt6160_dual_pocket.yaml"
# → job_id 확인 후 polling → PDB 다운로드
```

## Risks

- regression risk: 없음 (기존 코드 미수정)
- GPU 경합: 요청 시점 memory.free > 75GB 인 GPU만 선택 (기존 free-GPU selector 패턴 재사용). SLURM 잡이 많을 경우 가용 GPU 수 감소 가능
- 모델 로드 시간: Boltz2 초기 로드 ~30초 (서버 cold start만 해당)

## Rollback

- `pkill -f uvicorn` + ngrok 종료 → 즉시 원복
- conda env 삭제: `conda env remove -n aigenfold_api`
- 생성 파일: `AIGENFold/api/` 디렉토리 삭제 (git tracked)

## Progress Log

- 2026-06-30: contract drafted
- 2026-06-30: implementation complete. Plan .agent/plans/aigen-fold-core-rest-api-20260630.md (7 tasks, 5 commits).
  E2E verified: POST /v1/predict (9nfr_dual_pocket.yaml) → completed → PDB in results.zip.
  Notes: devices=1 per request (Lightning DDP can't spawn from uvicorn thread); /health uses nvidia-smi.
  Extra fixes: src/boltz/data/ copied from upstream, boring_utils stub created in env.
- 2026-07-06: POST /v1/ternary added as 2-stage CRBN-VAV1 ternary prediction standard.
  commit 00008aa. 4 files: api/pipeline.py (new), api/jobs.py, api/schema.py, api/server.py.
  Pipeline validated: job 15504 (9NFR own glue 2.9Å, MRT6160 2.8Å, 96% within 5Å).
  Smoke PASS (imports, YAML structure, schema, routes).
