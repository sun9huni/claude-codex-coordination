# ARL Co-Scientist Harness

Project-local Codex/Claude harness for `/home/ubuntu/arl-threads-coscientist`.

This repo is its **own** system of record. It ships with `AGENTS.md` and
`CLAUDE.md` at the project root and a `Makefile`-driven verification flow.
Workspace-level rules in `/home/ubuntu/AGENTS.md` apply only where the project
files are silent.

## Scope

- Paper/code discovery, ranking, hypothesis -> code -> experiment -> review
  pipeline. LangGraph-based agent graph.
- Code lives under `arl/` with strict layer deps (core cannot import higher
  layers). Tests under `tests/unit/`, `tests/architecture/`,
  `tests/integration/`.
- Active phase work tracked as `PHASE3{1..7}_*.md` at repo root (e.g.
  `PHASE37_PRODUCTION_HARDENING.md`).

## Authoritative Files (read before editing)

- `arl-threads-coscientist/AGENTS.md` — short, normative project rules
  (<=150 lines, enforced).
- `arl-threads-coscientist/CLAUDE.md` — same rules expanded with critical
  test-runtime warnings.
- `arl-threads-coscientist/docs/README.md` — docs index.
- `arl-threads-coscientist/docs/architecture/layers.md`,
  `boundaries.md` — invariants the `make arch` gate enforces.
- The relevant `PHASE3*_*.md` for active milestone scope.

## Invariants (do not bypass)

1. Layer deps fixed: core never imports higher layers.
2. Side-effects only in `social/`, `discovery/`, `experiment/`, `gitops/`,
   `db/`.
3. HTTP only via `resilient_get()`. LLM only via `call_llm_structured()`.
4. Config only via `Settings` (`ARL_` prefix). No `os.environ` outside
   `arl/config.py`.
5. No broad `except Exception`. Graph nodes use `@safe_node`.
6. Experiments use `ExperimentBackend` + `gpu_allocator`.
7. Artifacts under `artifacts/run-{run_id}/`.

## Verification Gates

Run from the project root. The required gate is `make check`.

```bash
cd arl-threads-coscientist
make check        # fmt + lint + arch + unit-test + docs   (< 3 min)
```

Optional task-specific gates:

| Change kind | Gate |
| --- | --- |
| Format/lint only | `make fmt && make lint` |
| Architecture rule changes | `make arch` |
| New behavior | add `tests/unit/` test + `make test` |
| Docs / link / index | `make docs` |
| Weekly health scan | `make doctor` (non-blocking) |

## Forbidden Without Explicit Approval

- `make ci-full`, `make test-integration`, `make test-all` — **human-only**.
  These hit real Docker / LLM / DB and can run 30+ minutes.
- Multiple pytest / make processes in parallel.
- pytest in background without `--timeout=30` (or default).
- Editing `.env`, `.env.*`, `secrets/`, lockfiles.
- Writing to `main` / `master`.
- Adding a dependency without updating `pyproject.toml` + tests + docs.

## Stop Conditions

- `make check` exceeds 3 minutes -> stop, `pkill -9 pytest`, investigate hang.
- `make arch` fails -> stop and fix the layer violation; do not silence the
  check or relax `docs/architecture/layers.md`.
- Any change touches a boundary module (`social/`, `discovery/`, etc.) **and**
  changes its public surface -> require an updated boundary contract before
  proceeding.
- PHASE file scope expanded beyond what the user requested -> stop and ask.

## Boundary With Other Harnesses

- This project is independent of FKSFold-Boltz. Do not cross-edit between
  `arl-threads-coscientist/` and `FKSFold-Boltz_Advancement/` in the same
  task.
- The workspace `.agent/skills/registry.md` and `docs/` apply only to the
  shared harness, not to this project's internal `docs/`.

## Remote / Compute

- Experiments run inside Docker via `DockerExperimentBackend`. Treat real
  Docker / GPU sessions as production-like — gated by the rules above.
- No SLURM submission from this project (unlike FKSFold-MMGBSA).

## Open Questions To Resolve On First Real Task

- Which `PHASE3*` milestone is currently in progress, and what is its
  acceptance criterion?
- Are there project-local Skills under `arl-threads-coscientist/skills/` that
  should be registered in the workspace registry, or should they stay
  project-local?
