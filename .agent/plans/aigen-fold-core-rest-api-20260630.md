---
contract: .agent/contracts/aigen-fold-core-rest-api-20260630.md
slice: aigen-fold-core
status: done
total_tasks: 7
estimated_total_min: 28
---

# AIGENFold REST API — Implementation Plan

## Task 1: conda env 생성 + AIGENFold 설치 확인

- **Status**: done
- **Prereq tasks**: none
- **Files touched**: (env only, no repo file)
- **Change shape**: `aigenfold_api` conda env 생성 후 `pip install -e /home/ubuntu/AIGENFold` 실행.
  `boltz_extension`에 루트 `__init__.py`가 없으면 생성해 패키지로 만든다.
  FastAPI/uvicorn 등 API 의존성 설치.
- **Verification**:
  ```bash
  /home/ubuntu/miniconda3/envs/aigenfold_api/bin/python -c \
    "import boltz, boltz_extension, fastapi, torch; \
     assert torch.cuda.is_available(), 'no GPU'; print('OK')"
  ```
  → `OK`
- **Estimated time**: 5 min (대부분 pip install 대기)
- **Rollback**: `conda env remove -n aigenfold_api -y`

---

## Task 2: schema.py — Pydantic 요청/응답 모델

- **Status**: done
- **Prereq tasks**: none
- **Files touched**: `AIGENFold/api/__init__.py`, `AIGENFold/api/schema.py`
- **Change shape**: 신규 파일 2개.
  `schema.py`에 아래 모델 정의:
  - `JobStatus` (Enum: queued / running / completed / failed)
  - `PredictResponse(job_id, status, submitted_at)`
  - `JobDetail(job_id, status, submitted_at, started_at, completed_at, error)`
  - `HealthResponse(status, gpu_count, gpu_names, version)`
  `__init__.py`는 빈 파일.
- **Verification**:
  ```bash
  cd /home/ubuntu/AIGENFold && \
  python -c "from api.schema import PredictResponse, JobStatus, HealthResponse; print('OK')"
  ```
  → `OK`
- **Estimated time**: 3 min
- **Rollback**: `rm -rf AIGENFold/api/`

---

## Task 3: jobs.py — SQLite 잡 스토어 + 백그라운드 러너

- **Status**: done
- **Prereq tasks**: 2
- **Files touched**: `AIGENFold/api/jobs.py`
- **Change shape**: 신규 파일.
  - `JobStore`: SQLite 기반 (`:memory:` 아닌 `/tmp/aigenfold_api/jobs.db`).
    `create/get/update/list` 메서드, thread-safe.
  - `free_gpu_indices()`: `nvidia-smi --query-gpu=index,memory.free --format=csv,noheader`
    파싱 → memory.free > 75000 MiB 인 인덱스 리스트 반환.
  - `run_prediction(job_id, input_dir, out_dir, store)`:
    asyncio-compatible (run_in_executor) 래퍼.
    `free_gpu_indices()` 호출 → `CUDA_VISIBLE_DEVICES` 설정 →
    `boltz.main.predict_core(data=input_dir, out_dir=out_dir, devices=N, ...)` 직접 호출.
    완료/실패 시 store 업데이트.
- **Verification**:
  ```bash
  cd /home/ubuntu/AIGENFold && \
  python -c "
  from api.jobs import JobStore, free_gpu_indices
  s = JobStore()
  jid = s.create('test')
  s.update(jid, status='completed')
  print(s.get(jid)['status'])
  gpus = free_gpu_indices()
  print('gpus:', gpus)
  "
  ```
  → `completed` 출력 + gpu 인덱스 리스트 출력
- **Estimated time**: 5 min
- **Rollback**: `rm AIGENFold/api/jobs.py`

---

## Task 4: server.py — FastAPI 앱 + 엔드포인트

- **Status**: done
- **Prereq tasks**: 2, 3
- **Files touched**: `AIGENFold/api/server.py`
- **Change shape**: 신규 파일. FastAPI app with lifespan.
  - `lifespan`: startup 시 `/tmp/aigenfold_api/` 디렉토리 생성, JobStore 초기화.
    (Boltz2 모델은 첫 predict_core 호출 시 자동 로드 — lifespan에서 선로드 불필요.)
  - `GET /health` → `HealthResponse`
  - `POST /v1/predict` → `UploadFile` (yaml) 수신, job_id 생성, input 저장,
    `asyncio.create_task(run_prediction(...))` 백그라운드 등록, `PredictResponse` 반환
  - `GET /v1/jobs/{job_id}` → `JobDetail`
  - `GET /v1/jobs/{job_id}/results` → `FileResponse` (PDB zip) or 404
  - `GET /v1/jobs` → 최근 20개 잡 목록
- **Verification**:
  ```bash
  cd /home/ubuntu/AIGENFold && \
  /home/ubuntu/miniconda3/envs/aigenfold_api/bin/python \
    -c "from api.server import app; print('routes:', [r.path for r in app.routes])"
  ```
  → `/health`, `/v1/predict`, `/v1/jobs/{job_id}`, `/v1/jobs/{job_id}/results`, `/v1/jobs` 포함
- **Estimated time**: 5 min
- **Rollback**: `rm AIGENFold/api/server.py`

---

## Task 5: run.sh — 서버 기동 + ngrok 연결 스크립트

- **Status**: done
- **Prereq tasks**: 4
- **Files touched**: `AIGENFold/api/run.sh`
- **Change shape**: 신규 실행 스크립트.
  ```bash
  #!/usr/bin/env bash
  # 사용법: bash api/run.sh [PORT=8000]
  PORT=${1:-8000}
  CONDA_ENV=/home/ubuntu/miniconda3/envs/aigenfold_api
  REPO=/home/ubuntu/AIGENFold
  export PYTHONPATH="$REPO/src:$PYTHONPATH"
  export AIGENFOLD_CACHE="$REPO/downloads"

  # uvicorn 백그라운드 기동
  "$CONDA_ENV/bin/uvicorn" api.server:app \
    --host 0.0.0.0 --port "$PORT" --workers 1 &
  echo "AIGENFold API started on :$PORT (PID $!)"

  # ngrok이 있으면 자동 연결
  if command -v ngrok &>/dev/null; then
    ngrok http "$PORT"
  else
    echo "ngrok not found — run: ngrok http $PORT"
    wait
  fi
  ```
  chmod +x 포함.
- **Verification**:
  ```bash
  bash -n AIGENFold/api/run.sh && echo "syntax OK"
  ```
  → `syntax OK`
- **Estimated time**: 2 min
- **Rollback**: `rm AIGENFold/api/run.sh`

---

## Task 6: E2E smoke test — /health + /v1/predict 왕복

- **Status**: done
- **Prereq tasks**: 1, 4, 5
- **Files touched**: (없음 — 런타임 검증만)
- **Change shape**: 서버를 실제 기동해 `/health`와 `/v1/predict` 엔드포인트를
  curl로 검증. 잡이 `running` → `completed`로 전환되는지 확인.
  (예측 완료까지 수분 소요 가능 — smoke 단계에서는 `queued` → `running` 전환만 확인)
- **Verification**:
  ```bash
  # 터미널 1
  cd /home/ubuntu/AIGENFold && bash api/run.sh 8000 &
  sleep 5

  # /health
  curl -s http://localhost:8000/health | python -m json.tool

  # /v1/predict 제출
  JOB=$(curl -s -X POST http://localhost:8000/v1/predict \
    -F "yaml=@examples/9nfr/9nfr_mrt6160_dual_pocket.yaml" | python -c \
    "import sys,json; print(json.load(sys.stdin)['job_id'])")
  echo "job_id: $JOB"

  # 상태 확인
  curl -s http://localhost:8000/v1/jobs/$JOB | python -m json.tool
  ```
  → `health.status == "ok"`, `health.gpu_count >= 1`,
    `jobs/{id}.status` 가 `queued` 또는 `running`
- **Estimated time**: 5 min
- **Rollback**: `pkill -f uvicorn`

---

## Task 7: pyproject.toml api 의존성 + 상태 파일 업데이트

- **Status**: done
- **Prereq tasks**: 6
- **Files touched**: `AIGENFold/pyproject.toml`, `.agent/status/aigen-fold-core.md`
- **Change shape**:
  `pyproject.toml`에 optional-deps 추가:
  ```toml
  [project.optional-dependencies]
  api = [
      "fastapi>=0.110",
      "uvicorn[standard]>=0.29",
      "python-multipart>=0.0.9",
      "aiofiles>=23.0",
  ]
  ```
  `.agent/status/aigen-fold-core.md`에 API 완료 기록 추가.
- **Verification**:
  ```bash
  python -c "
  import tomllib
  with open('AIGENFold/pyproject.toml','rb') as f:
      t = tomllib.load(f)
  assert 'api' in t['project']['optional-dependencies']
  print('OK')
  "
  ```
  → `OK`
- **Estimated time**: 3 min
- **Rollback**: `git checkout AIGENFold/pyproject.toml`
