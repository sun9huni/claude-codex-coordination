#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "usage: $0 <ssh-alias> <remote-repo-path>" >&2
  exit 2
fi

HOST="$1"
REMOTE_REPO="$2"

echo "[remote-verify] host=$HOST repo=$REMOTE_REPO"

ssh "$HOST" "cd '$REMOTE_REPO' && pwd && uname -a"
ssh "$HOST" "cd '$REMOTE_REPO' && git status --short && git rev-parse --abbrev-ref HEAD && git rev-parse --short HEAD"

if ssh "$HOST" "cd '$REMOTE_REPO' && test -x ./scripts/verify.sh"; then
  ssh "$HOST" "cd '$REMOTE_REPO' && ./scripts/verify.sh"
else
  ssh "$HOST" "cd '$REMOTE_REPO' && bash ./scripts/verify.sh"
fi

echo "[remote-verify] finished"
