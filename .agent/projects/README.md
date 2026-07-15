# Project Harness Index

This directory contains project-specific Codex harness designs for active work
detected from `/home/ubuntu/.cursor` and the current server workspace.

## Active Harness Designs

- `recent-cursor-activity-20260518.md`: evidence from Cursor state, plans,
  transcripts, canvases, and recent output files.
- `aigen-fold-boltz-core-harness.md`: source repository harness for AIGEN-Fold
  (Boltz-2 fork) steering, ranking, docs, and tests.
- `aigen-fold-actual-file-map-20260518.md`: source-backed map of actual project
  files, local/shared divergence, active entrypoints, and verification gates.
- `aigen-fold-fragmap-9nfr-harness.md`: FragMap, 9NFR structural recovery, and
  target-occupancy steering harness.
- `aigen-fold-mmgbsa-slurm-harness.md`: shared workspace, MMGBSA, F105, normtest,
  and SLURM production harness.
- `vav1-ranking-harness.md`: VAV1 ensemble ranking and production-rank harness.
- `arl-threads-coscientist-harness.md`: ARL Co-Scientist (paper discovery →
  ranking → experiment pipeline) project harness. Project-local `AGENTS.md` /
  `CLAUDE.md` are authoritative; `make check` is the required gate.

## Use Order

1. Read `/home/ubuntu/AGENTS.md`.
2. Read the project-specific harness document here.
3. Read the relevant project files or plans named in that harness.
4. Create a task contract under `.agent/contracts/` for large or production
   changes.
5. Run the listed verification gates before reporting completion.
