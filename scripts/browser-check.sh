#!/usr/bin/env bash
set -euo pipefail

echo "[browser-check] starting"

if [ -f package.json ] && npm run | grep -q "playwright"; then
  echo "[browser-check] running playwright checks"
  npm run playwright --if-present
else
  echo "[browser-check] no scripted browser checks found"
  echo "[browser-check] use Chrome/Computer Use with .agent/qa/browser-checklist.md"
fi

echo "[browser-check] finished"
