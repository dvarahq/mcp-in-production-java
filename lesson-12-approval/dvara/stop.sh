#!/usr/bin/env bash
# Stops DVARA. --reset also deletes its data and .env, so the next ./start.sh begins from nothing.
set -euo pipefail
cd "$(dirname "$0")"
if [[ ${1:-} == --reset ]]; then
  docker compose down -v
  rm -rf .env .state
else
  docker compose down
fi
