---
name: gpu-dashboard-submit
description: Submit a high-QoS GPU job. First check whether the submitting account already has high in sacctmgr; if yes, CLI sbatch works. Accounts lacking high need the dashboard or admin qos grant. Use for high-QoS GPU runs such as metadynamics resume or extension, while still respecting the GPU approval gate.
argument-hint: "<intent — e.g. 'resume crl metad from bias' | new run | path to existing .sh>"
allowed-tools: Read Write Edit Bash(ls:*) Bash(cat:*) Bash(stat:*) Bash(grep:*) Bash(find:*) Bash(squeue:*) Bash(sacct:*) Bash(sacctmgr:*) Bash(srun:*) Bash(git -C * status:*) Bash(git -C * log:*)
---

# /gpu-dashboard-submit — Submit a high-QoS GPU job (CLI-first, dashboard fallback)

**FIRST check: does the submitting account already have `high` in its association?**
`sacctmgr -P show assoc user=<acct> format=User,QOS -n`. The CLI restriction is
ASSOCIATION-based, not a blanket block:
- **Account HAS high (e.g. `ubuntu`)** → just `sbatch --qos=high ...` via CLI. No
  dashboard, no tokens. This is the path for our GPU work (jobs run as `ubuntu`).
  Verified 2026-06-16: `sbatch --test-only --qos=high` as ubuntu → accepted. Still
  subject to the GPU ★APPROVAL GATE (active contract ≤7d + user go) + the sbatch hook.
- **Account LACKS high (default users, e.g. `kim`)** → `--qos=high` → `Invalid qos
  specification`. Options: (a) admin `sacctmgr modify user <u> set qos+=high` (then
  CLI works like ubuntu), or (b) the web dashboard, which **auto-grants high on
  submit** (its `/submit` endpoint calls `add_user_qos` when the form's QoS=high).

Use the **dashboard path below ONLY for the lacks-high case.** The dashboard builds
the `#SBATCH` header from FORM fields (a script's in-body `#SBATCH --qos=high` is
IGNORED — set QoS in the form's **스케줄링** section); reads scripts from
`/mnt/data/users/<user>/` (`.sh/.bash/.slurm`, not `.sbatch`); and its `/user-scripts`
list does a full recursive `os.walk` that TIMES OUT if the user's dir has many files
(fix: hide big subdirs, e.g. symlink `workspace`→`.workspace`). The agent cannot
click submit — it stages + hands off. (Admin-confirmed 2026-06-16. See memory
`reference-slurm-high-qos-dashboard`.)

This skill produces (a) a validated, staged batch script and (b) a dashboard
submission card. It never runs `sbatch`.

## Dashboard access (how the human reaches it)

Web dashboard = **http://localhost:18080** after VS Code Remote-SSH to the SLURM
head node `10.0.5.62` (auto port-forwards). SSH path: bastion `210.109.81.71`
(user `rocky`, key `keypair-aigen-ai.pem`) → ProxyJump → `10.0.5.62`. The web
account is per-username (lowercase; = Linux + Slurm + `/mnt/data/users/<user>/`).
Menu **Job 제출** = submit (pick a script / select QoS); **Job 현황** = monitor /
cancel / 선점요청(preempt); **QoS 관리** = view/request QoS.

## QoS limits & where each is usable (admin guide 2026-06-16)

| QoS | max GPU | max walltime | CLI sbatch | web dashboard |
|---|---|---|---|---|
| normal | 8 | **7 d** | ✅ | ✅ |
| batch | 4 | 14 d | ✅ | ✅ |
| interactive | 2 | 6 h | ❌ | ✅ |
| **high** | 16 | **3 d** | ❌ | ✅ |
| emergency | 40 | 2 h | ❌ | admin-approve |

**Key tradeoff for long MD**: `high` gives priority + 16-GPU headroom (parallel
walkers) but caps walltime at **3 days**; `normal` is CLI-submittable and allows
**7 days** continuous. For one long single-walker run, `normal` (7 d, no dashboard)
may beat `high` (3 d). For aggregate sampling fast, `high` + parallel walkers wins.
Choose deliberately per run; don't default to high.

## Step 0 — Approval gate (HARD STOP)

A GPU job is a ★APPROVAL GATE. Before doing anything else, verify BOTH:
- An **active contract** for this slice under `.agent/contracts/` updated within the
  last 7 days that covers this run. If absent → STOP, route to `/brainstorm`.
- An **explicit user "go"** for this specific submission in the conversation. If
  absent → STOP and ask.

If either is missing, do not stage a script. Say what's missing.

## Step 1 — Resolve the run

From `$ARGUMENTS` and the slice baton, determine:
- **workdir** (where inputs/outputs live, usually `/mnt/data/users/ubuntu/workspace/<run>`).
- **base script** — reuse the run's existing `*.sh` if present (read it, don't
  reinvent); else build from the driver (`*_md_run.py` / equivalent).
- **resume vs fresh** — for metadynamics resume, the run is continued by **reloading
  the accumulated WT-bias** from `metad_bias/` + last frame (no OpenMM `.chk` is
  written by the current driver). Confirm the bias files exist and are non-empty.
- **resources** — GPU count, walltime, and whether to run **parallel walkers**
  (several seeds sharing the bias dir) — the real payoff of high's higher GPU cap.

## Step 2 — Write / validate the script

Emit (or edit) the batch `.sh` in the workdir with explicit `#SBATCH` headers:
- `--qos=high` (the dashboard honors it on the privileged path; also select high in
  the UI), `--partition=gpu`, `--gres=gpu:<n>`, `--time=<hh:mm:ss>`,
  `--job-name`, `--output`/`--error` to the workdir.
- The compute-node env (`/mnt/data/users/ubuntu/conda_envs/mmgbsa/bin/python`), the
  driver invocation, and — for resume — the bias-reload flag/path.
- OpenCL fallback line if CUDA-PTX mismatch applies (driver 535 / CUDA 12.2 node).

Validate WITHOUT submitting:
- `bash -n <script>` (syntax), paths exist (`stat` inputs/driver/env), bias files
  non-empty if resuming, walltime sane.
- Do NOT run `sbatch --test-only` as the user account if it would reject on `high`
  noise; validate inputs directly instead.

## Step 3 — Emit the dashboard submission card

Print a copy-paste block the human follows in the dashboard:

```
DASHBOARD SUBMIT (high QOS)
  script : <abs path to .sh>
  QOS    : high
  part.  : gpu     gres: gpu:<n>     time: <hh:mm:ss>
  workdir: <abs>
  expect : ~<x> ns/day → ~<y> ns by walltime
  note   : agent cannot click submit — you upload+select high+submit
```

## Step 4 — Hand off + offer monitoring

State that the script is staged and the human submits via the dashboard. Once they
report a job id, offer to monitor — **on the compute node via
`srun --jobid=<id> --overlap` (GPU util sampled over seconds + log step advancing),
never login-node `/mnt` mtimes** (mergerfs serves stale mtimes; see memory
`feedback-slurm-liveness-check`).

## Red Flags

| Rationalization | Reality |
|---|---|
| "I'll just `sbatch --qos=high` from CLI." | Rejected (`Invalid qos specification`). high is dashboard-only. The whole point of this skill. |
| "high will make the run faster." | No — single-job ns/day is node-contention-bound. high buys queue priority + parallel-walker headroom, not raw speed. |
| "Contract is a few days stale, close enough." | The gate is an active contract ≤7 days + explicit user go. If stale, refresh via /brainstorm first. |
| "I'll submit it for them to save a step." | You cannot (CLI ≠ high) and must not (human owns the dashboard click). Prepare, hand off. |
| "Job looks frozen — login-node file hasn't changed in hours." | mergerfs stale mtime. Verify liveness on the node via srun, not login mtimes. |

## Forbidden

- Do NOT run `sbatch` to submit (cannot reach high; gate-blocked anyway).
- Do NOT stage a script without the Step 0 approval gate satisfied.
- Do NOT reinvent a run's existing `.sh` — read and adapt it.
- Do NOT judge a running job's liveness from login-node `/mnt` mtimes.
