#!/usr/bin/env bash
set -euo pipefail

DRY_RUN=0
if [ "${1:-}" = "--dry-run" ]; then
  DRY_RUN=1
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILLS_DIR="$ROOT/skills"
REGISTRY="$ROOT/.agent/skills/registry.md"

echo "[skills-sync] starting"

if [ ! -d "$SKILLS_DIR" ]; then
  echo "[skills-sync] missing skills directory: $SKILLS_DIR" >&2
  exit 1
fi

if [ ! -f "$REGISTRY" ]; then
  echo "[skills-sync] missing registry: $REGISTRY" >&2
  exit 1
fi

echo "[skills-sync] skills:"
find "$SKILLS_DIR" -maxdepth 2 -name SKILL.md -print | sort

CODEX_SKILLS_DIR="$HOME/.codex/skills"

if [ "$DRY_RUN" -eq 1 ]; then
  echo "[skills-sync] dry-run: would mirror to $CODEX_SKILLS_DIR"
  if [ -d "$CODEX_SKILLS_DIR" ]; then
    echo "[skills-sync] dry-run drift check:"
    drift=0
    while IFS= read -r src; do
      rel="${src#"$SKILLS_DIR"/}"
      dst="$CODEX_SKILLS_DIR/$rel"
      if [ ! -f "$dst" ]; then
        echo "  MISSING $rel"
        drift=1
      elif ! cmp -s "$src" "$dst"; then
        echo "  DRIFT $rel"
        drift=1
      fi
    done < <(find "$SKILLS_DIR" -maxdepth 2 -name SKILL.md -print | sort)
    if [ "$drift" -eq 0 ]; then
      echo "  OK source and Codex mirror match for managed SKILL.md files"
    fi
  else
    echo "[skills-sync] dry-run drift check skipped: $CODEX_SKILLS_DIR not present"
  fi
else
  if [ -d "$CODEX_SKILLS_DIR" ]; then
    echo "[skills-sync] mirroring $SKILLS_DIR/ -> $CODEX_SKILLS_DIR/"
    rsync -a \
      --include='*/' --include='SKILL.md' --exclude='*' \
      "$SKILLS_DIR"/ "$CODEX_SKILLS_DIR"/
  else
    echo "[skills-sync] $CODEX_SKILLS_DIR not present; skipping codex mirror"
  fi
fi

echo "[skills-sync] finished"
